--[[----------------------------------------------------------------------------

ImageProcessor.lua
Image Processing Utilities for Instagram Carousel Generation

This module provides utilities for splitting and processing images
for Instagram carousel posts.

------------------------------------------------------------------------------]]

local LrLogger = import 'LrLogger'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local LrApplication = import 'LrApplication'

local logger = LrLogger('ImageProcessor')
logger:enable("print")

local ImageProcessor = {}

--------------------------------------------------------------------------------
-- Helper function to get image dimensions from file
-- This uses external tools if available, or returns nil

function ImageProcessor.getImageDimensions(imagePath)
    -- Try to use ImageMagick's identify command if available
    local success, result = LrTasks.pcall(function()
        local command
        if WIN_ENV then
            command = 'magick identify -format "%w %h" "' .. imagePath .. '"'
        else
            command = 'identify -format "%w %h" "' .. imagePath .. '" 2>/dev/null'
        end
        
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            if output then
                local width, height = output:match("(%d+)%s+(%d+)")
                if width and height then
                    return tonumber(width), tonumber(height)
                end
            end
        end
        return nil, nil
    end)
    
    if success and result then
        return result
    end
    
    return nil, nil
end

--------------------------------------------------------------------------------
-- Split image into carousel tiles

function ImageProcessor.splitImageIntoTiles(sourcePath, outputDir, tileWidth, tileHeight, params)
    logger:info(string.format("Splitting image: %s", sourcePath))
    logger:info(string.format("Tile size: %dx%d", tileWidth, tileHeight))
    
    local tiles = {}
    
    -- Get source image dimensions
    local sourceWidth, sourceHeight = ImageProcessor.getImageDimensions(sourcePath)
    
    if not sourceWidth or not sourceHeight then
        logger:warn("Could not determine source image dimensions, using metadata from Lightroom")
        -- In this case, we'll rely on Lightroom's export process
        return nil, "Could not determine image dimensions"
    end
    
    logger:info(string.format("Source image size: %dx%d", sourceWidth, sourceHeight))
    
    -- Calculate number of tiles needed
    local numTiles = math.ceil(sourceWidth / tileWidth)
    
    logger:info(string.format("Number of tiles: %d", numTiles))
    
    -- Check if we need to handle overflow
    local totalWidth = numTiles * tileWidth
    local widthDiff = totalWidth - sourceWidth
    
    if widthDiff > 0 then
        logger:info(string.format("Image needs %d px of padding/cropping", widthDiff))
        
        if params.overflowHandling == 'crop' then
            -- Crop the image to fit perfectly
            sourceWidth = sourceWidth - (sourceWidth % tileWidth)
            numTiles = sourceWidth / tileWidth
            logger:info(string.format("Cropping to %dx%d for perfect fit", sourceWidth, sourceHeight))
        else
            -- Add bands (handled in the tile creation step)
            logger:info("Will add bands to fit perfectly")
        end
    end
    
    -- Generate tile splits using ImageMagick if available
    local success, error = ImageProcessor.splitWithImageMagick(
        sourcePath, 
        outputDir, 
        tileWidth, 
        tileHeight, 
        numTiles,
        params
    )
    
    if success then
        -- Collect generated tile paths
        for i = 0, numTiles - 1 do
            local tilePath = LrPathUtils.child(outputDir, string.format("tile_%d.jpg", i))
            if LrFileUtils.exists(tilePath) then
                table.insert(tiles, tilePath)
            end
        end
    end
    
    return tiles
end

--------------------------------------------------------------------------------
-- Split image using ImageMagick

function ImageProcessor.splitWithImageMagick(sourcePath, outputDir, tileWidth, tileHeight, numTiles, params)
    local baseName = LrPathUtils.leafName(sourcePath)
    local nameWithoutExt = LrPathUtils.removeExtension(baseName)
    
    -- Construct ImageMagick command for splitting
    local command
    
    if params.overflowHandling == 'addBands' then
        -- Add bands with background color and optional frame
        local bgColor = string.format("rgb(%d,%d,%d)", 
            math.floor(params.backgroundColor.r * 255),
            math.floor(params.backgroundColor.g * 255),
            math.floor(params.backgroundColor.b * 255)
        )
        
        local frameOpts = ""
        if params.enableFrame then
            local frameColor = string.format("rgb(%d,%d,%d)",
                math.floor(params.frameColor.r * 255),
                math.floor(params.frameColor.g * 255),
                math.floor(params.frameColor.b * 255)
            )
            frameOpts = string.format(' -bordercolor "%s" -border %d', frameColor, params.frameSize)
        end
        
        -- Build command to add bands and split
        if WIN_ENV then
            command = string.format(
                'magick "%s" -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage "%s"',
                sourcePath,
                bgColor,
                tileWidth * numTiles,
                tileHeight,
                frameOpts,
                tileWidth,
                tileHeight,
                LrPathUtils.child(outputDir, "tile_%d.jpg")
            )
        else
            command = string.format(
                'convert "%s" -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage "%s"',
                sourcePath,
                bgColor,
                tileWidth * numTiles,
                tileHeight,
                frameOpts,
                tileWidth,
                tileHeight,
                LrPathUtils.child(outputDir, "tile_%%d.jpg")
            )
        end
    else
        -- Crop mode
        if WIN_ENV then
            command = string.format(
                'magick "%s" -crop %dx%d +repage "%s"',
                sourcePath,
                tileWidth,
                tileHeight,
                LrPathUtils.child(outputDir, "tile_%d.jpg")
            )
        else
            command = string.format(
                'convert "%s" -crop %dx%d +repage "%s"',
                sourcePath,
                tileWidth,
                tileHeight,
                LrPathUtils.child(outputDir, "tile_%%d.jpg")
            )
        end
    end
    
    logger:info("Executing ImageMagick command:")
    logger:info(command)
    
    -- Execute the command
    local success, result = LrTasks.pcall(function()
        local handle = io.popen(command .. " 2>&1")
        if handle then
            local output = handle:read("*a")
            local exitCode = handle:close()
            logger:info("ImageMagick output: " .. tostring(output))
            return exitCode == true or exitCode == 0
        end
        return false
    end)
    
    if not success or not result then
        logger:error("Failed to execute ImageMagick command")
        return false, "ImageMagick execution failed"
    end
    
    return true
end

--------------------------------------------------------------------------------

return ImageProcessor

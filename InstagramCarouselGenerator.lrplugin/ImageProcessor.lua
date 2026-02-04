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
local LrSystemInfo = import 'LrSystemInfo'

local logger = LrLogger('ImageProcessor')
logger:enable("print")

local ImageProcessor = {}

--------------------------------------------------------------------------------
-- Platform Detection

local function isWindows()
    -- Use Lightroom SDK's platform detection
    local platform = LrSystemInfo.osVersion()
    return string.find(platform:lower(), "windows") ~= nil
end

local WIN_ENV = isWindows()

--------------------------------------------------------------------------------
-- ImageMagick Path Detection for macOS
-- On macOS, ImageMagick installed via Homebrew may not be in the system PATH
-- when launched from Lightroom. We search common installation locations.

local imageMagickPath = nil  -- Cache the found path

local function findImageMagickOnMac()
    -- Common paths where ImageMagick might be installed on macOS
    local commonPaths = {
        "/opt/homebrew/bin",     -- Homebrew on Apple Silicon
        "/usr/local/bin",        -- Homebrew on Intel Macs
        "/opt/local/bin",        -- MacPorts
        "/usr/bin",              -- System path
        ""                       -- Empty string = rely on PATH
    }
    
    for _, basePath in ipairs(commonPaths) do
        local convertCmd
        if basePath ~= "" then
            convertCmd = basePath .. "/convert"
        else
            convertCmd = "convert"
        end
        
        -- Check if the convert command exists and works
        local success, result = LrTasks.pcall(function()
            local command = convertCmd .. " -version 2>/dev/null"
            local handle = io.popen(command)
            if handle then
                local output = handle:read("*a")
                handle:close()
                
                if output and (string.find(output, "ImageMagick") or string.find(output, "Version")) then
                    return true
                end
            end
            return false
        end)
        
        if success and result then
            logger:info("Found ImageMagick at: " .. (basePath ~= "" and basePath or "system PATH"))
            return basePath
        end
    end
    
    return nil
end

local function getImageMagickCommand(commandName)
    -- For Windows, use 'magick' command
    if WIN_ENV then
        return "magick"
    end
    
    -- For macOS/Unix, find the ImageMagick path if not already cached
    if imageMagickPath == nil then
        imageMagickPath = findImageMagickOnMac() or false  -- Use false to indicate "not found but checked"
    end
    
    if imageMagickPath and imageMagickPath ~= "" then
        return imageMagickPath .. "/" .. commandName
    elseif imageMagickPath == "" then
        return commandName  -- Use system PATH
    else
        return commandName  -- Not found, try anyway
    end
end

--------------------------------------------------------------------------------
-- Constants

local TILE_NAME_PATTERN = "tile_%d.jpg"
local TILE_NAME_PATTERN_WIN = "tile_%d.jpg"
local TILE_NAME_PATTERN_UNIX = "tile_%%d.jpg"

--------------------------------------------------------------------------------
-- Helper function to escape shell arguments

local function escapeShellArg(arg)
    -- Escape shell arguments to prevent command injection
    if WIN_ENV then
        -- Windows: escape quotes and wrap in quotes
        return '"' .. arg:gsub('"', '""') .. '"'
    else
        -- Unix: use single quotes and escape any single quotes
        return "'" .. arg:gsub("'", "'\\''") .. "'"
    end
end

--------------------------------------------------------------------------------
-- Check if ImageMagick is installed and available

function ImageProcessor.checkImageMagickAvailable()
    -- Try to run ImageMagick version command
    local success, result = LrTasks.pcall(function()
        local command
        if WIN_ENV then
            -- Windows: try 'magick' command
            command = 'magick -version'
        else
            -- Unix/macOS: use path-aware convert command
            local convertCmd = getImageMagickCommand("convert")
            command = convertCmd .. ' -version 2>/dev/null'
        end
        
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            local exitCode = handle:close()
            
            -- Check if output contains "ImageMagick" or "Version"
            if output and (string.find(output, "ImageMagick") or string.find(output, "Version")) then
                logger:info("ImageMagick detected: " .. output:sub(1, 100))
                return true
            end
        end
        return false
    end)
    
    if success and result then
        return true
    else
        logger:warn("ImageMagick not detected on system")
        return false
    end
end

--------------------------------------------------------------------------------
-- Helper function to get image dimensions from file
-- This uses external tools if available, or returns nil

function ImageProcessor.getImageDimensions(imagePath)
    -- Try to use ImageMagick's identify command if available
    local success, result = LrTasks.pcall(function()
        local command
        if WIN_ENV then
            command = 'magick identify -format "%w %h" ' .. escapeShellArg(imagePath)
        else
            local identifyCmd = getImageMagickCommand("identify")
            command = identifyCmd .. ' -format "%w %h" ' .. escapeShellArg(imagePath) .. ' 2>/dev/null'
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
    
    -- First, check if ImageMagick is available
    if not ImageProcessor.checkImageMagickAvailable() then
        logger:error("ImageMagick is not available on this system")
        return nil, "ImageMagick not installed or not in PATH"
    end
    
    local tiles = {}
    
    -- Get source image dimensions
    local sourceWidth, sourceHeight = ImageProcessor.getImageDimensions(sourcePath)
    
    if not sourceWidth or not sourceHeight then
        logger:warn("Could not determine source image dimensions")
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
            local tilePath = LrPathUtils.child(outputDir, string.format(TILE_NAME_PATTERN, i))
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
        -- Clamp color values to valid range [0, 1]
        local function clamp(value)
            return math.max(0, math.min(1, value or 0))
        end
        
        local bgColor = string.format("rgb(%d,%d,%d)", 
            math.floor(clamp(params.backgroundColor.r) * 255),
            math.floor(clamp(params.backgroundColor.g) * 255),
            math.floor(clamp(params.backgroundColor.b) * 255)
        )
        
        local frameOpts = ""
        if params.enableFrame then
            local frameColor = string.format("rgb(%d,%d,%d)",
                math.floor(clamp(params.frameColor.r) * 255),
                math.floor(clamp(params.frameColor.g) * 255),
                math.floor(clamp(params.frameColor.b) * 255)
            )
            -- Clamp frame size to reasonable range
            local frameSize = math.max(1, math.min(100, params.frameSize or 10))
            frameOpts = string.format(' -bordercolor "%s" -border %d', frameColor, frameSize)
        end
        
        -- Build command to add bands and split
        if WIN_ENV then
            command = string.format(
                'magick %s -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage %s',
                escapeShellArg(sourcePath),
                bgColor,
                tileWidth * numTiles,
                tileHeight,
                frameOpts,
                tileWidth,
                tileHeight,
                escapeShellArg(LrPathUtils.child(outputDir, TILE_NAME_PATTERN_WIN))
            )
        else
            local convertCmd = getImageMagickCommand("convert")
            command = string.format(
                '%s %s -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage %s',
                convertCmd,
                escapeShellArg(sourcePath),
                bgColor,
                tileWidth * numTiles,
                tileHeight,
                frameOpts,
                tileWidth,
                tileHeight,
                escapeShellArg(LrPathUtils.child(outputDir, TILE_NAME_PATTERN_UNIX))
            )
        end
    else
        -- Crop mode
        if WIN_ENV then
            command = string.format(
                'magick %s -crop %dx%d +repage %s',
                escapeShellArg(sourcePath),
                tileWidth,
                tileHeight,
                escapeShellArg(LrPathUtils.child(outputDir, TILE_NAME_PATTERN_WIN))
            )
        else
            local convertCmd = getImageMagickCommand("convert")
            command = string.format(
                '%s %s -crop %dx%d +repage %s',
                convertCmd,
                escapeShellArg(sourcePath),
                tileWidth,
                tileHeight,
                escapeShellArg(LrPathUtils.child(outputDir, TILE_NAME_PATTERN_UNIX))
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

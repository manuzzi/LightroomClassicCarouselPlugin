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
local imageMagickCmd = nil   -- Cache the command name (magick or convert)

local function findImageMagickOnMac()
    -- Common paths where ImageMagick might be installed on macOS
    local commonPaths = {
        "/opt/homebrew/bin",     -- Homebrew on Apple Silicon
        "/usr/local/bin",        -- Homebrew on Intel Macs
        "/opt/local/bin",        -- MacPorts
        "/usr/bin",              -- System path
        ""                       -- Empty string = rely on PATH
    }
    
    -- First try to find 'magick' command (ImageMagick v7+)
    for _, basePath in ipairs(commonPaths) do
        local magickCmd
        if basePath ~= "" then
            magickCmd = basePath .. "/magick"
        else
            magickCmd = "magick"
        end
        
        -- Check if the magick command exists and works
        local success, result = LrTasks.pcall(function()
            local command = magickCmd .. " -version 2>/dev/null"
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
            logger:info("Found ImageMagick 'magick' at: " .. (basePath ~= "" and basePath or "system PATH"))
            return basePath, "magick"
        end
    end
    
    -- Fallback: try to find 'convert' command (older ImageMagick or legacy symlink)
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
            logger:info("Found ImageMagick 'convert' at: " .. (basePath ~= "" and basePath or "system PATH"))
            return basePath, "convert"
        end
    end
    
    return nil, nil
end

local function getImageMagickCommand(commandName)
    -- For Windows, use 'magick' command (ImageMagick v7+)
    if WIN_ENV then
        if commandName == "convert" or commandName == "identify" then
            -- On Windows with ImageMagick v7, use 'magick' for all operations
            return "magick"
        end
        return "magick"
    end
    
    -- For macOS/Unix, find the ImageMagick path if not already cached
    -- imageMagickPath states: nil = not checked, false = checked and not found, string = found path
    if imageMagickPath == nil then
        local path, cmd = findImageMagickOnMac()
        imageMagickPath = path or false
        imageMagickCmd = cmd or "convert"
    end
    
    -- Determine which command to use
    local actualCmd
    if imageMagickCmd == "magick" then
        -- Using modern ImageMagick v7 - 'magick' command handles everything
        actualCmd = "magick"
    else
        -- Using older ImageMagick or 'convert' command
        actualCmd = commandName
    end
    
    if imageMagickPath and imageMagickPath ~= "" then
        return imageMagickPath .. "/" .. actualCmd
    else
        -- Not found or found in system PATH - use command name directly
        return actualCmd
    end
end

--------------------------------------------------------------------------------
-- Constants

-- Output tile name pattern - uses zero-padded two-digit numbering (00, 01, 02, ...)
local TILE_NAME_PATTERN = "tile_%02d.jpg"

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
    -- Note: LrTasks.pcall returns (success, firstReturnValue) so we need to
    -- return dimensions as a table to preserve both width and height
    local success, result = LrTasks.pcall(function()
        local command
        if WIN_ENV then
            command = 'magick identify -format "%w %h" ' .. escapeShellArg(imagePath)
        else
            local identifyCmd = getImageMagickCommand("identify")
            command = identifyCmd .. ' -format "%w %h" ' .. escapeShellArg(imagePath) .. ' 2>/dev/null'
        end
        
        logger:info("Getting image dimensions with command: " .. command)
        
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            logger:info("identify output: " .. tostring(output))
            
            if output then
                local width, height = output:match("(%d+)%s+(%d+)")
                if width and height then
                    -- Return as table to preserve both values through pcall
                    return { width = tonumber(width), height = tonumber(height) }
                end
            end
        end
        return nil
    end)
    
    if success and result and type(result) == "table" and result.width and result.height then
        logger:info(string.format("Image dimensions: %dx%d", result.width, result.height))
        return result.width, result.height
    end
    
    logger:warn("Could not determine image dimensions")
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
    
    -- Get the ImageMagick command (magick or convert depending on version)
    local imageMagickBaseCmd = getImageMagickCommand("convert")
    
    -- Calculate total width for all tiles
    local totalWidth = tileWidth * numTiles
    
    -- Build the output path pattern
    -- Using tile_%02d.jpg format for zero-padded numbering
    local outputPattern = LrPathUtils.child(outputDir, "tile_%02d.jpg")
    
    -- Construct ImageMagick command for splitting
    -- Based on the working command:
    -- magick input.jpg -resize x{height} -gravity center -crop {totalWidth}x{height}+0+0 +repage -crop {tileWidth}x{height} +repage +adjoin tiles_%02d.jpg
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
        
        -- Build command to resize, add bands, and split
        -- The sequence:
        -- 1. Resize to target height (maintaining aspect ratio)
        -- 2. Set background color and use -extent to add bands if needed
        -- 3. Crop to exact total width
        -- 4. Split into tiles
        if WIN_ENV then
            command = string.format(
                'magick %s -resize x%d -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage +adjoin %s',
                escapeShellArg(sourcePath),
                tileHeight,
                bgColor,
                totalWidth,
                tileHeight,
                frameOpts,
                tileWidth,
                tileHeight,
                escapeShellArg(outputPattern)
            )
        else
            command = string.format(
                '%s %s -resize x%d -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage +adjoin %s',
                imageMagickBaseCmd,
                escapeShellArg(sourcePath),
                tileHeight,
                bgColor,
                totalWidth,
                tileHeight,
                frameOpts,
                tileWidth,
                tileHeight,
                escapeShellArg(outputPattern)
            )
        end
    else
        -- Crop mode - resize to height, crop to exact width, then split
        if WIN_ENV then
            command = string.format(
                'magick %s -resize x%d -gravity center -crop %dx%d+0+0 +repage -crop %dx%d +repage +adjoin %s',
                escapeShellArg(sourcePath),
                tileHeight,
                totalWidth,
                tileHeight,
                tileWidth,
                tileHeight,
                escapeShellArg(outputPattern)
            )
        else
            command = string.format(
                '%s %s -resize x%d -gravity center -crop %dx%d+0+0 +repage -crop %dx%d +repage +adjoin %s',
                imageMagickBaseCmd,
                escapeShellArg(sourcePath),
                tileHeight,
                totalWidth,
                tileHeight,
                tileWidth,
                tileHeight,
                escapeShellArg(outputPattern)
            )
        end
    end
    
    logger:info("Executing ImageMagick command:")
    logger:info(command)
    
    -- Execute the command and capture both output and error
    local commandOutput = ""
    local success, result = LrTasks.pcall(function()
        local handle = io.popen(command .. " 2>&1")
        if handle then
            local output = handle:read("*a")
            commandOutput = output or ""
            local exitCode = handle:close()
            logger:info("ImageMagick output: " .. tostring(output))
            -- In Lua, handle:close() returns true on success, or nil/false followed by error info on failure
            -- exitCode == true means success on some Lua versions
            -- exitCode == 0 means success when exitCode is a number
            if exitCode == true or exitCode == 0 then
                return true
            end
            -- If there's no output (empty string), it might still be success
            -- as ImageMagick doesn't always output text on success
            if output == nil or output == "" then
                return true
            end
            return false
        end
        return false
    end)
    
    if not success then
        logger:error("Failed to execute ImageMagick command: pcall failed")
        return false, "ImageMagick execution failed: " .. tostring(commandOutput)
    end
    
    if not result then
        logger:error("ImageMagick command returned error: " .. commandOutput)
        return false, "ImageMagick error: " .. (commandOutput ~= "" and commandOutput or "Unknown error")
    end
    
    return true
end

--------------------------------------------------------------------------------

return ImageProcessor

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
-- Constants

local TILE_NAME_PATTERN = "tile_%d.jpg"
local TILE_NAME_PATTERN_WIN = "tile_%d.jpg"
local TILE_NAME_PATTERN_UNIX = "tile_%%d.jpg"

-- Common macOS paths where ImageMagick might be installed
local MACOS_MAGICK_PATHS = {
    "/opt/homebrew/bin/magick",  -- Apple Silicon Homebrew
    "/usr/local/bin/magick",      -- Intel Homebrew
    "/opt/local/bin/magick",      -- MacPorts
    "magick"                      -- System PATH
}

--------------------------------------------------------------------------------
-- Bundled ImageMagick binary path (cached)

local cachedMagickPath = nil

--------------------------------------------------------------------------------
-- Get the path to the bundled ImageMagick binary

local function getBundledMagickPath()
    -- Cache the result to avoid repeated file system checks
    if cachedMagickPath ~= nil then
        return cachedMagickPath
    end
    
    -- Get the plugin's directory path using _PLUGIN global
    local pluginPath = _PLUGIN.path
    if not pluginPath then
        logger:warn("Could not determine plugin path")
        cachedMagickPath = false
        return false
    end
    
    local binPath
    local magickBinary
    
    if WIN_ENV then
        binPath = LrPathUtils.child(pluginPath, "bin")
        binPath = LrPathUtils.child(binPath, "win")
        magickBinary = LrPathUtils.child(binPath, "magick.exe")
    else
        binPath = LrPathUtils.child(pluginPath, "bin")
        binPath = LrPathUtils.child(binPath, "mac")
        magickBinary = LrPathUtils.child(binPath, "magick")
    end
    
    -- Check if the bundled binary exists
    if LrFileUtils.exists(magickBinary) then
        logger:info("Found bundled ImageMagick at: " .. magickBinary)
        cachedMagickPath = magickBinary
        return magickBinary
    else
        logger:info("No bundled ImageMagick found at: " .. magickBinary)
        cachedMagickPath = false
        return false
    end
end

--------------------------------------------------------------------------------
-- Get the ImageMagick command (bundled or system)

local function getMagickCommand()
    -- First, try to use bundled binary
    local bundledPath = getBundledMagickPath()
    if bundledPath then
        return bundledPath
    end
    
    -- Fallback to system PATH
    if WIN_ENV then
        return "magick"
    else
        -- On macOS, try common Homebrew paths if 'magick' is not in PATH
        -- This helps when Lightroom doesn't inherit the user's shell PATH
        return "magick"
    end
end

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
    -- First, check for bundled binary
    local bundledPath = getBundledMagickPath()
    if bundledPath then
        -- Verify the bundled binary works
        local success, result = LrTasks.pcall(function()
            local command = escapeShellArg(bundledPath) .. " -version 2>&1"
            local handle = io.popen(command)
            if handle then
                local output = handle:read("*a")
                handle:close()
                if output and string.find(output, "ImageMagick") then
                    logger:info("Bundled ImageMagick works: " .. output:sub(1, 100))
                    return true
                end
            end
            return false
        end)
        
        if success and result then
            return true, bundledPath
        end
    end
    
    -- Try to run ImageMagick version command from system PATH
    local success, result = LrTasks.pcall(function()
        if WIN_ENV then
            -- Windows: try 'magick' command
            local handle = io.popen('magick -version 2>&1')
            if handle then
                local output = handle:read("*a")
                handle:close()
                
                -- Check if output contains "ImageMagick"
                if output and string.find(output, "ImageMagick") then
                    logger:info("ImageMagick detected: " .. output:sub(1, 100))
                    return true
                end
            end
        else
            -- macOS: try 'magick' command with common Homebrew paths
            for _, path in ipairs(MACOS_MAGICK_PATHS) do
                local testCommand = path .. " -version 2>&1"
                local handle = io.popen(testCommand)
                if handle then
                    local output = handle:read("*a")
                    handle:close()
                    if output and string.find(output, "ImageMagick") then
                        logger:info("ImageMagick found at: " .. path)
                        return true, path
                    end
                end
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
-- Get the working ImageMagick command path

function ImageProcessor.getWorkingMagickPath()
    -- First, check for bundled binary
    local bundledPath = getBundledMagickPath()
    if bundledPath then
        -- Verify the bundled binary works
        local pcallSuccess, binaryWorks = LrTasks.pcall(function()
            local command = escapeShellArg(bundledPath) .. " -version 2>&1"
            local handle = io.popen(command)
            if handle then
                local output = handle:read("*a")
                handle:close()
                if output and string.find(output, "ImageMagick") then
                    return true
                end
            end
            return false
        end)
        
        if pcallSuccess and binaryWorks then
            return bundledPath
        end
    end
    
    -- Check system paths
    if WIN_ENV then
        local handle = io.popen("magick -version 2>&1")
        if handle then
            local output = handle:read("*a")
            handle:close()
            if output and string.find(output, "ImageMagick") then
                return "magick"
            end
        end
    else
        -- macOS: check multiple common locations
        for _, path in ipairs(MACOS_MAGICK_PATHS) do
            local testCommand = path .. " -version 2>&1"
            local handle = io.popen(testCommand)
            if handle then
                local output = handle:read("*a")
                handle:close()
                if output and string.find(output, "ImageMagick") then
                    return path
                end
            end
        end
    end
    
    return nil
end

--------------------------------------------------------------------------------
-- Helper function to get image dimensions from file
-- This uses external tools if available, or returns nil

function ImageProcessor.getImageDimensions(imagePath)
    -- Get the working ImageMagick path
    local magickPath = ImageProcessor.getWorkingMagickPath()
    if not magickPath then
        logger:warn("No working ImageMagick path found for getImageDimensions")
        return nil, nil
    end
    
    -- Try to use ImageMagick's identify command
    local success, result = LrTasks.pcall(function()
        local command
        if WIN_ENV then
            -- On Windows, use 'magick identify' syntax
            command = escapeShellArg(magickPath) .. ' identify -format "%w %h" ' .. escapeShellArg(imagePath) .. ' 2>&1'
        else
            -- On macOS/Unix, use 'magick identify' syntax (ImageMagick 7)
            command = escapeShellArg(magickPath) .. ' identify -format "%w %h" ' .. escapeShellArg(imagePath) .. ' 2>&1'
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
    
    -- Get the working ImageMagick path
    local magickPath = ImageProcessor.getWorkingMagickPath()
    if not magickPath then
        logger:error("No working ImageMagick path found")
        return false, "ImageMagick not installed or not in PATH"
    end
    
    -- Escape the magick path for shell use
    local escapedMagickPath = escapeShellArg(magickPath)
    
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
        
        -- Build command to add bands and split (using ImageMagick 7 'magick' command)
        if WIN_ENV then
            command = string.format(
                '%s %s -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage %s',
                escapedMagickPath,
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
            command = string.format(
                '%s %s -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage %s',
                escapedMagickPath,
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
                '%s %s -crop %dx%d +repage %s',
                escapedMagickPath,
                escapeShellArg(sourcePath),
                tileWidth,
                tileHeight,
                escapeShellArg(LrPathUtils.child(outputDir, TILE_NAME_PATTERN_WIN))
            )
        else
            command = string.format(
                '%s %s -crop %dx%d +repage %s',
                escapedMagickPath,
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

--[[----------------------------------------------------------------------------

ImageProcessor.lua
Image Processing Utilities for Instagram Carousel Generation

This module provides utilities for splitting and processing images
for Instagram carousel posts using ImageMagick.

------------------------------------------------------------------------------]]

local LrLogger = import 'LrLogger'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local LrPrefs = import 'LrPrefs'
local LrSystemInfo = import 'LrSystemInfo'

-- Create a logger for this module
local logger = LrLogger('ImageProcessor')

-- Get log level from preferences (default to INFO)
local function getLogLevel()
    local prefs = LrPrefs.prefsForPlugin()
    return prefs.logLevel or "info"
end

-- Enable logging based on preference
local function updateLogLevel()
    -- Always enable logging - filtering is done in the log helper functions
    logger:enable("print")
end

updateLogLevel()

local ImageProcessor = {}

--------------------------------------------------------------------------------
-- Platform Detection

local function isWindows()
    local platform = LrSystemInfo.osVersion()
    return string.find(platform:lower(), "windows") ~= nil
end

local WIN_ENV = isWindows()

--------------------------------------------------------------------------------
-- Logging Helpers

local function logDebug(message)
    local level = getLogLevel()
    if level == "debug" then
        logger:info("[DEBUG] " .. message)
    end
end

local function logInfo(message)
    local level = getLogLevel()
    if level == "debug" or level == "info" then
        logger:info("[INFO] " .. message)
    end
end

local function logWarn(message)
    local level = getLogLevel()
    if level == "debug" or level == "info" or level == "warn" then
        logger:warn("[WARN] " .. message)
    end
end

local function logError(message)
    logger:error("[ERROR] " .. message)
end

--------------------------------------------------------------------------------
-- ImageMagick Path Detection

local imageMagickPath = nil
local imageMagickCmd = nil

local function findImageMagickOnMac()
    local commonPaths = {
        "/opt/homebrew/bin",     -- Homebrew on Apple Silicon
        "/usr/local/bin",        -- Homebrew on Intel Macs
        "/opt/local/bin",        -- MacPorts
        "/usr/bin",              -- System path
        ""                       -- Empty string = rely on PATH
    }
    
    -- Try 'magick' command first (ImageMagick v7+)
    for _, basePath in ipairs(commonPaths) do
        local cmd = basePath ~= "" and (basePath .. "/magick") or "magick"
        local command = cmd .. " -version 2>/dev/null"
        
        logDebug("Checking for magick at: " .. cmd)
        
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            if output and string.find(output, "ImageMagick") then
                logInfo("Found ImageMagick 'magick' at: " .. (basePath ~= "" and basePath or "system PATH"))
                return basePath, "magick"
            end
        end
    end
    
    -- Fallback to 'convert' command
    for _, basePath in ipairs(commonPaths) do
        local cmd = basePath ~= "" and (basePath .. "/convert") or "convert"
        local command = cmd .. " -version 2>/dev/null"
        
        logDebug("Checking for convert at: " .. cmd)
        
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            if output and string.find(output, "ImageMagick") then
                logInfo("Found ImageMagick 'convert' at: " .. (basePath ~= "" and basePath or "system PATH"))
                return basePath, "convert"
            end
        end
    end
    
    return nil, nil
end

local function getImageMagickCommand()
    if WIN_ENV then
        return "magick"
    end
    
    if imageMagickPath == nil then
        local path, cmd = findImageMagickOnMac()
        imageMagickPath = path or false
        imageMagickCmd = cmd or "magick"
    end
    
    if imageMagickPath and imageMagickPath ~= "" then
        return imageMagickPath .. "/" .. imageMagickCmd
    else
        return imageMagickCmd or "magick"
    end
end

--------------------------------------------------------------------------------
-- Shell Argument Escaping

local function escapeShellArg(arg)
    if WIN_ENV then
        return '"' .. arg:gsub('"', '""') .. '"'
    else
        return "'" .. arg:gsub("'", "'\\''") .. "'"
    end
end

--------------------------------------------------------------------------------
-- Check ImageMagick Availability

function ImageProcessor.checkImageMagickAvailable()
    local cmd = getImageMagickCommand()
    local command = cmd .. " -version 2>&1"
    
    logDebug("Checking ImageMagick with command: " .. command)
    
    local handle = io.popen(command)
    if handle then
        local output = handle:read("*a")
        handle:close()
        
        if output and string.find(output, "ImageMagick") then
            logInfo("ImageMagick is available")
            return true
        end
    end
    
    logWarn("ImageMagick not available")
    return false
end

--------------------------------------------------------------------------------
-- Split Panoramic Image into Carousel Tiles
-- 
-- This function takes a rendered image and splits it into carousel tiles
-- based on the target tile size and user preferences.
--
-- Parameters:
--   sourcePath: Path to the source image (already rendered by Lightroom)
--   outputDir: Directory to save the tiles
--   tileWidth: Target width of each tile
--   tileHeight: Target height of each tile
--   params: Table with additional parameters:
--     - overflowHandling: 'addBands' or 'crop'
--     - backgroundColor: {r, g, b} values from 0-1
--     - frameColor: {r, g, b} values from 0-1
--     - frameSize: Frame size in pixels
--     - enableFrame: Boolean to enable frame
--     - sourceWidth: Width of source image (from Lightroom)
--     - sourceHeight: Height of source image (from Lightroom)

function ImageProcessor.splitImageIntoTiles(sourcePath, outputDir, tileWidth, tileHeight, params)
    logInfo("=== Starting tile split operation ===")
    logInfo("Source: " .. sourcePath)
    logInfo("Output directory: " .. outputDir)
    logInfo("Target tile size: " .. tileWidth .. "x" .. tileHeight)
    logDebug("Overflow handling: " .. tostring(params.overflowHandling))
    logDebug("Enable frame: " .. tostring(params.enableFrame))
    
    -- Check ImageMagick
    if not ImageProcessor.checkImageMagickAvailable() then
        logError("ImageMagick is not available")
        return nil, "ImageMagick not installed or not in PATH"
    end
    
    -- Get source dimensions from params (passed from Lightroom export)
    local sourceWidth = params.sourceWidth
    local sourceHeight = params.sourceHeight
    
    logInfo("Source image dimensions: " .. sourceWidth .. "x" .. sourceHeight)
    
    -- Calculate the number of tiles based on source image width
    -- The image is already rendered at the correct height by Lightroom
    local numTiles = math.ceil(sourceWidth / tileWidth)
    
    -- Ensure at least 1 tile and maximum 10 (Instagram carousel limit)
    numTiles = math.max(1, math.min(numTiles, 10))
    
    logInfo("Calculated number of tiles: " .. numTiles)
    
    -- Calculate total width needed for all tiles
    local totalWidth = numTiles * tileWidth
    
    logDebug("Total width for tiles: " .. totalWidth)
    
    -- Execute the split
    local success, errorMsg = ImageProcessor.executeSplit(
        sourcePath,
        outputDir,
        tileWidth,
        tileHeight,
        numTiles,
        totalWidth,
        params
    )
    
    if not success then
        logError("Split failed: " .. (errorMsg or "Unknown error"))
        return nil, errorMsg
    end
    
    -- Collect generated tiles
    local tiles = {}
    for i = 0, numTiles - 1 do
        local tilePath = LrPathUtils.child(outputDir, string.format("tile_%02d.jpg", i))
        if LrFileUtils.exists(tilePath) then
            table.insert(tiles, tilePath)
            logDebug("Found tile: " .. tilePath)
        else
            logWarn("Expected tile not found: " .. tilePath)
        end
    end
    
    logInfo("Successfully created " .. #tiles .. " tiles")
    return tiles
end

--------------------------------------------------------------------------------
-- Execute the ImageMagick split command

function ImageProcessor.executeSplit(sourcePath, outputDir, tileWidth, tileHeight, numTiles, totalWidth, params)
    local magickCmd = getImageMagickCommand()
    local outputPattern = LrPathUtils.child(outputDir, "tile_%02d.jpg")
    
    -- Build the ImageMagick command
    -- Command structure based on working example:
    -- magick input.jpg -resize x{height} -gravity center -crop {totalWidth}x{height}+0+0 +repage -crop {tileWidth}x{height} +repage +adjoin tiles_%02d.jpg
    
    local command
    
    if params.overflowHandling == 'addBands' then
        -- Add bands mode: resize, add background, optionally add frame, then split
        local function clamp(value)
            return math.max(0, math.min(1, value or 0))
        end
        
        local bgColor = string.format("rgb(%d,%d,%d)", 
            math.floor(clamp(params.backgroundColor.r) * 255),
            math.floor(clamp(params.backgroundColor.g) * 255),
            math.floor(clamp(params.backgroundColor.b) * 255)
        )
        
        logDebug("Background color: " .. bgColor)
        
        local frameOpts = ""
        if params.enableFrame then
            local frameColor = string.format("rgb(%d,%d,%d)",
                math.floor(clamp(params.frameColor.r) * 255),
                math.floor(clamp(params.frameColor.g) * 255),
                math.floor(clamp(params.frameColor.b) * 255)
            )
            local frameSize = math.max(1, math.min(100, params.frameSize or 10))
            frameOpts = string.format(' -bordercolor "%s" -border %d', frameColor, frameSize)
            logDebug("Frame options: " .. frameOpts)
        end
        
        -- Build command: resize to height, add bands with extent, optionally add frame, split
        command = string.format(
            '%s %s -resize x%d -background "%s" -gravity center -extent %dx%d%s -crop %dx%d +repage +adjoin %s',
            magickCmd,
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
        -- Crop mode: resize to height, crop to total width, then split
        command = string.format(
            '%s %s -resize x%d -gravity center -crop %dx%d+0+0 +repage -crop %dx%d +repage +adjoin %s',
            magickCmd,
            escapeShellArg(sourcePath),
            tileHeight,
            totalWidth,
            tileHeight,
            tileWidth,
            tileHeight,
            escapeShellArg(outputPattern)
        )
    end
    
    logDebug("Executing command: " .. command)
    logInfo("Running ImageMagick split command...")
    
    -- Execute the command
    local fullCommand = command .. " 2>&1"
    local handle = io.popen(fullCommand)
    
    if not handle then
        logError("Failed to execute command")
        return false, "Failed to execute ImageMagick command"
    end
    
    local output = handle:read("*a") or ""
    local success = handle:close()
    
    logDebug("Command output: " .. output)
    
    -- Check for success
    if output ~= "" and string.find(output:lower(), "error") then
        logError("ImageMagick error: " .. output)
        return false, "ImageMagick error: " .. output
    end
    
    logInfo("ImageMagick command completed successfully")
    return true
end

--------------------------------------------------------------------------------

return ImageProcessor

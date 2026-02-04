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
-- NEW APPROACH (v1.2.7):
-- 1. Divide the panoramic image into N tiles based on the desired ratio
-- 2. Resize to the requested actual size
--
-- Parameters:
--   sourcePath: Path to the source image (already rendered by Lightroom)
--   outputDir: Directory to save the tiles
--   tileWidth: Target width of each tile (final output size)
--   tileHeight: Target height of each tile (final output size)
--   params: Table with additional parameters:
--     - overflowHandling: 'addBands' or 'crop'
--     - bgColorR, bgColorG, bgColorB: Background color RGB values (0-255)
--     - frameColorR, frameColorG, frameColorB: Frame color RGB values (0-255)
--     - frameSize: Frame size in pixels
--     - enableFrame: Boolean to enable frame
--     - sourceWidth: Width of source image (from Lightroom)
--     - sourceHeight: Height of source image (from Lightroom)
--     - numTiles: Pre-calculated number of tiles (based on ratio)
--     - baseName: Original file name (without extension) for tile naming

function ImageProcessor.splitImageIntoTiles(sourcePath, outputDir, tileWidth, tileHeight, params)
    logInfo("=== Starting tile split operation ===")
    logInfo("Source: " .. sourcePath)
    logInfo("Output directory: " .. outputDir)
    logInfo("Target tile size: " .. tileWidth .. "x" .. tileHeight)
    logDebug("Overflow handling: " .. tostring(params.overflowHandling))
    logDebug("Enable frame: " .. tostring(params.enableFrame))
    
    -- Get base name for tile naming (fallback to "tile" if not provided)
    local baseName = params.baseName or "tile"
    logDebug("Base name for tiles: " .. baseName)
    
    -- Check ImageMagick
    if not ImageProcessor.checkImageMagickAvailable() then
        logError("ImageMagick is not available")
        return nil, "ImageMagick not installed or not in PATH"
    end
    
    -- Get source dimensions from params (passed from Lightroom export)
    local sourceWidth = params.sourceWidth
    local sourceHeight = params.sourceHeight
    
    logInfo("Source image dimensions: " .. sourceWidth .. "x" .. sourceHeight)
    
    -- Use pre-calculated number of tiles if provided, otherwise calculate
    local numTiles
    if params.numTiles and params.numTiles > 0 then
        numTiles = params.numTiles
        logInfo("Using pre-calculated tile count: " .. numTiles)
    else
        -- Fallback: calculate based on tile width
        numTiles = math.ceil(sourceWidth / tileWidth)
        numTiles = math.max(1, math.min(numTiles, 10))
        logInfo("Calculated tile count: " .. numTiles)
    end
    
    -- Calculate total width needed for all tiles
    local totalWidth = numTiles * tileWidth
    
    logDebug("Total width for tiles: " .. totalWidth)
    
    -- Execute the split (baseName is already in params or uses fallback)
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
    
    -- Collect generated tiles (using the new naming pattern: baseName_tile_XX.jpg)
    local tiles = {}
    for i = 0, numTiles - 1 do
        local tilePath = LrPathUtils.child(outputDir, string.format("%s_tile_%02d.jpg", baseName, i))
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
--
-- The image processing logic:
-- For CROP mode:
--   1. Resize width to exactly totalWidth (num_tiles * tile_width)
--   2. Crop top and bottom to get exact tile height (removes overflow)
--   3. Split into tiles
--
-- For BANDS mode (with optional frame):
--   1. If frame enabled: add frame border to image FIRST
--   2. Resize to fit within tile dimensions (maintaining aspect ratio)
--   3. Add background bands on top/bottom if needed
--   4. Split into tiles

function ImageProcessor.executeSplit(sourcePath, outputDir, tileWidth, tileHeight, numTiles, totalWidth, params)
    local magickCmd = getImageMagickCommand()
    
    -- Use baseName for tile naming (e.g., "originalfile_tile_00.jpg")
    local baseName = params.baseName or "tile"
    local outputPattern = LrPathUtils.child(outputDir, baseName .. "_tile_%02d.jpg")
    
    -- Helper function to format RGB color for ImageMagick
    -- Now using direct RGB values (0-255) from the UI
    local function formatBgColor()
        local r = math.floor(math.max(0, math.min(255, params.bgColorR or 255)))
        local g = math.floor(math.max(0, math.min(255, params.bgColorG or 255)))
        local b = math.floor(math.max(0, math.min(255, params.bgColorB or 255)))
        return string.format("rgb(%d,%d,%d)", r, g, b)
    end
    
    local function formatFrameColor()
        local r = math.floor(math.max(0, math.min(255, params.frameColorR or 0)))
        local g = math.floor(math.max(0, math.min(255, params.frameColorG or 0)))
        local b = math.floor(math.max(0, math.min(255, params.frameColorB or 0)))
        return string.format("rgb(%d,%d,%d)", r, g, b)
    end
    
    local command
    
    if params.overflowHandling == 'addBands' then
        -- BANDS MODE:
        -- Add bands on top/bottom to fill the tile height
        
        local bgColor = formatBgColor()
        logDebug("Background color: " .. bgColor)
        
        if params.enableFrame then
            -- WITH FRAME:
            -- 1. Add frame border to image FIRST (around the actual content)
            -- 2. Resize the framed image to fit width
            -- 3. Add bands on top/bottom with background color
            -- 4. Split into tiles
            
            local frameColor = formatFrameColor()
            local frameSize = math.max(1, math.min(100, params.frameSize or 10))
            
            logDebug("Frame color: " .. frameColor)
            logDebug("Frame size: " .. frameSize)
            
            -- The frame is added to the original image, then we resize the framed image
            -- Then add bands around it
            command = string.format(
                '%s %s -bordercolor "%s" -border %d -resize %dx -background "%s" -gravity center -extent %dx%d -crop %dx%d +repage +adjoin %s',
                magickCmd,
                escapeShellArg(sourcePath),
                frameColor,
                frameSize,
                totalWidth,
                bgColor,
                totalWidth,
                tileHeight,
                tileWidth,
                tileHeight,
                escapeShellArg(outputPattern)
            )
        else
            -- WITHOUT FRAME:
            -- 1. Resize to fit width while keeping aspect ratio
            -- 2. Add bands with extent (gravity center adds to top/bottom)
            -- 3. Split into tiles
            command = string.format(
                '%s %s -resize %dx -background "%s" -gravity center -extent %dx%d -crop %dx%d +repage +adjoin %s',
                magickCmd,
                escapeShellArg(sourcePath),
                totalWidth,
                bgColor,
                totalWidth,
                tileHeight,
                tileWidth,
                tileHeight,
                escapeShellArg(outputPattern)
            )
        end
    else
        -- CROP MODE:
        -- Crop top and bottom to fit the tile height (removes overflow, doesn't add anything)
        -- 1. Resize width to exactly totalWidth (maintaining aspect ratio - height will be taller)
        -- 2. Crop to exact tile height using -crop with gravity center (removes top/bottom)
        -- 3. Split into tiles
        
        command = string.format(
            '%s %s -resize %dx -gravity center -crop %dx%d+0+0 +repage -crop %dx%d +repage +adjoin %s',
            magickCmd,
            escapeShellArg(sourcePath),
            totalWidth,
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

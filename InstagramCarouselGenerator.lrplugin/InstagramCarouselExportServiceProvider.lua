--[[----------------------------------------------------------------------------

InstagramCarouselExportServiceProvider.lua
Export Service Provider for Instagram Carousel Generation

This module provides the export service that allows users to export
photos in a format optimized for Instagram carousels.

------------------------------------------------------------------------------]]

-- Access the Lightroom SDK namespaces
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrLogger = import 'LrLogger'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrApplication = import 'LrApplication'
local LrSystemInfo = import 'LrSystemInfo'
local LrPrefs = import 'LrPrefs'
local LrShell = import 'LrShell'

-- Create a logger for this module
local logger = LrLogger('InstagramCarouselExportService')
logger:enable("print")

--------------------------------------------------------------------------------
-- Logging Helpers (matches ImageProcessor)

local function getLogLevel()
    local prefs = LrPrefs.prefsForPlugin()
    return prefs.logLevel or "info"
end

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
-- Export Service Provider Definition

local exportServiceProvider = {}

-- Plugin-specific properties
exportServiceProvider.exportPresetFields = {
    -- Tile aspect ratio (determines how tiles are proportioned)
    { key = 'aspectRatio', default = '4:5' },
    
    -- Short side size options
    { key = 'shortSideSize', default = '1080' },
    { key = 'customShortSide', default = 1080 },
    
    -- Calculated tile dimensions (computed from ratio and short side)
    { key = 'tileWidth', default = 1080 },
    { key = 'tileHeight', default = 1350 },
    
    -- Seamless mode (split panoramas)
    { key = 'seamlessMode', default = true },
    
    -- Overflow handling
    { key = 'overflowHandling', default = 'addBands' },
    { key = 'backgroundColor', default = { r = 1, g = 1, b = 1 } },
    { key = 'frameColor', default = { r = 0, g = 0, b = 0 } },
    { key = 'frameSize', default = 10 },
    { key = 'enableFrame', default = false },
    
    -- Open export folder after export
    { key = 'openExportFolder', default = false },
}

-- Allow this plugin to export all files
exportServiceProvider.allowFileFormats = { 'JPEG', 'TIFF', 'PNG' }
exportServiceProvider.allowColorSpaces = { 'sRGB', 'AdobeRGB' }

-- Can export to a specific folder
exportServiceProvider.canExportToTemporaryLocation = true

-- Export service name
exportServiceProvider.exportName = "Instagram Carousel"

--------------------------------------------------------------------------------
-- Helper function to calculate tile dimensions from ratio and short side

local function calculateTileDimensions(aspectRatio, shortSide)
    local width, height
    
    if aspectRatio == '4:5' then
        -- Portrait: width is short side, height is longer
        width = shortSide
        height = math.floor(shortSide * 5 / 4)
    elseif aspectRatio == '1:1' then
        -- Square: both sides equal
        width = shortSide
        height = shortSide
    elseif aspectRatio == '5:4' then
        -- Landscape: height is short side, width is longer
        height = shortSide
        width = math.floor(shortSide * 5 / 4)
    elseif aspectRatio == '16:9' then
        -- Wide landscape: height is short side
        height = shortSide
        width = math.floor(shortSide * 16 / 9)
    elseif aspectRatio == '9:16' then
        -- Vertical: width is short side
        width = shortSide
        height = math.floor(shortSide * 16 / 9)
    else
        -- Default to 4:5
        width = shortSide
        height = math.floor(shortSide * 5 / 4)
    end
    
    return width, height
end

--------------------------------------------------------------------------------
-- UI for Export Dialog

function exportServiceProvider.sectionsForTopOfDialog(f, propertyTable)
    local bind = LrView.bind
    local share = LrView.share
    
    -- Helper to update tile dimensions when ratio or short side changes
    local function updateTileDimensions()
        local shortSide
        if propertyTable.shortSideSize == 'custom' then
            shortSide = propertyTable.customShortSide
        else
            shortSide = tonumber(propertyTable.shortSideSize) or 1080
        end
        
        local width, height = calculateTileDimensions(propertyTable.aspectRatio, shortSide)
        propertyTable.tileWidth = width
        propertyTable.tileHeight = height
    end
    
    -- Update dimensions when aspect ratio changes
    propertyTable:addObserver('aspectRatio', function(props, key, value)
        updateTileDimensions()
    end)
    
    -- Update dimensions when short side size changes
    propertyTable:addObserver('shortSideSize', function(props, key, value)
        updateTileDimensions()
    end)
    
    -- Update dimensions when custom short side changes
    propertyTable:addObserver('customShortSide', function(props, key, value)
        if propertyTable.shortSideSize == 'custom' then
            updateTileDimensions()
        end
    end)
    
    -- Initialize tile dimensions
    updateTileDimensions()
    
    return {
        {
            title = "Instagram Carousel Settings",
            synopsis = bind 'seamlessMode',
            
            -- Aspect Ratio Selection
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Tile Aspect Ratio:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:popup_menu {
                    value = bind 'aspectRatio',
                    items = {
                        { title = "4:5 (Portrait)", value = '4:5' },
                        { title = "1:1 (Square)", value = '1:1' },
                        { title = "5:4 (Landscape)", value = '5:4' },
                        { title = "16:9 (Wide)", value = '16:9' },
                        { title = "9:16 (Vertical)", value = '9:16' },
                    },
                },
            },
            
            -- Short Side Size Selection
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Short Side Size:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:popup_menu {
                    value = bind 'shortSideSize',
                    items = {
                        { title = "1080 px (Instagram standard)", value = '1080' },
                        { title = "2160 px (2x)", value = '2160' },
                        { title = "3240 px (3x)", value = '3240' },
                        { title = "4320 px (4x)", value = '4320' },
                        { title = "Custom", value = 'custom' },
                    },
                },
            },
            
            -- Custom Short Side (only visible when custom is selected)
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Custom Size:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:edit_field {
                    value = bind 'customShortSide',
                    width_in_digits = 5,
                    min = 100,
                    max = 8640,
                    precision = 0,
                    enabled = LrBinding.keyEquals('shortSideSize', 'custom'),
                },
                
                f:static_text {
                    title = "px",
                },
            },
            
            -- Calculated Tile Size (read-only display)
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Tile Size:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:static_text {
                    title = bind {
                        keys = {'tileWidth', 'tileHeight'},
                        operation = function(binder, values, fromTable)
                            return string.format("%d x %d px", 
                                values.tileWidth or 1080, 
                                values.tileHeight or 1350)
                        end,
                    },
                    font = '<system/bold>',
                },
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:checkbox {
                    title = "Enable Seamless Carousel Mode (split panoramas)",
                    value = bind 'seamlessMode',
                    checked_value = true,
                    unchecked_value = false,
                },
            },
        },
        
        {
            title = "Overflow Handling",
            synopsis = bind 'overflowHandling',
            
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "When image doesn't fit perfectly:",
                    alignment = 'left',
                    width = share 'label_width',
                },
            },
            
            f:row {
                spacing = f:control_spacing(),
                
                f:radio_button {
                    title = "Add bands with optional frame",
                    value = bind 'overflowHandling',
                    checked_value = 'addBands',
                },
            },
            
            f:row {
                spacing = f:control_spacing(),
                
                f:radio_button {
                    title = "Crop to fit perfectly",
                    value = bind 'overflowHandling',
                    checked_value = 'crop',
                },
            },
        },
        
        {
            title = "Band & Frame Settings",
            synopsis = bind 'enableFrame',
            
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Background Color:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:color_well {
                    value = bind 'backgroundColor',
                    enabled = LrBinding.keyEquals('overflowHandling', 'addBands'),
                },
            },
            
            f:row {
                f:checkbox {
                    title = "Enable Frame",
                    value = bind 'enableFrame',
                    checked_value = true,
                    unchecked_value = false,
                    enabled = LrBinding.keyEquals('overflowHandling', 'addBands'),
                },
            },
            
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Frame Color:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:color_well {
                    value = bind 'frameColor',
                    enabled = LrBinding.keyEquals('enableFrame', true),
                },
            },
            
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Frame Size:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:edit_field {
                    value = bind 'frameSize',
                    width_in_digits = 5,
                    min = 1,
                    max = 100,
                    precision = 0,
                    enabled = LrBinding.keyEquals('enableFrame', true),
                },
                
                f:static_text {
                    title = "px",
                },
            },
        },
        
        {
            title = "After Export",
            
            f:row {
                f:checkbox {
                    title = "Open export folder after export",
                    value = bind 'openExportFolder',
                    checked_value = true,
                    unchecked_value = false,
                },
            },
        },
    }
end

--------------------------------------------------------------------------------
-- Get image dimensions using ImageMagick (more reliable than Lightroom)

local function getImageDimensionsFromFile(imagePath)
    local isWindows = string.find(string.lower(LrSystemInfo.osVersion()), "windows") ~= nil
    
    -- Find ImageMagick
    local magickCmd = "magick"
    if not isWindows then
        local commonPaths = {"/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin", ""}
        for _, basePath in ipairs(commonPaths) do
            local cmd = basePath ~= "" and (basePath .. "/magick") or "magick"
            local testCmd = cmd .. " -version 2>/dev/null"
            local handle = io.popen(testCmd)
            if handle then
                local output = handle:read("*a")
                handle:close()
                if output and string.find(output, "ImageMagick") then
                    magickCmd = cmd
                    break
                end
            end
        end
    end
    
    -- Use identify to get dimensions
    local escPath
    if isWindows then
        escPath = '"' .. imagePath:gsub('"', '""') .. '"'
    else
        escPath = "'" .. imagePath:gsub("'", "'\\''") .. "'"
    end
    
    local command = magickCmd .. ' identify -format "%w %h" ' .. escPath .. ' 2>&1'
    logDebug("Getting dimensions with: " .. command)
    
    local handle = io.popen(command)
    if handle then
        local output = handle:read("*a")
        handle:close()
        
        logDebug("Identify output: " .. tostring(output))
        
        if output then
            local width, height = output:match("(%d+)%s+(%d+)")
            if width and height then
                return tonumber(width), tonumber(height)
            end
        end
    end
    
    return nil, nil
end

--------------------------------------------------------------------------------
-- Process Rendered Photos

function exportServiceProvider.processRenderedPhotos(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local exportParams = exportContext.propertyTable
    
    -- Import the image processor
    local ImageProcessor = require 'ImageProcessor'
    
    -- Get tile dimensions from calculated values
    local tileWidth = exportParams.tileWidth
    local tileHeight = exportParams.tileHeight
    
    logInfo("========================================")
    logInfo("Starting Instagram Carousel Export v1.2.2")
    logInfo("========================================")
    logInfo("Tile aspect ratio: " .. exportParams.aspectRatio)
    logInfo("Short side size: " .. exportParams.shortSideSize)
    logInfo("Tile size: " .. tileWidth .. "x" .. tileHeight)
    logInfo("Seamless mode: " .. tostring(exportParams.seamlessMode))
    logInfo("Overflow handling: " .. exportParams.overflowHandling)
    logDebug("Background color: R=" .. tostring(exportParams.backgroundColor.r) .. 
             " G=" .. tostring(exportParams.backgroundColor.g) .. 
             " B=" .. tostring(exportParams.backgroundColor.b))
    logDebug("Enable frame: " .. tostring(exportParams.enableFrame))
    logDebug("Open export folder: " .. tostring(exportParams.openExportFolder))
    
    -- Get the photos to be exported
    local nPhotos = exportSession:countRenditions()
    
    logInfo("Number of photos to export: " .. nPhotos)
    
    -- Progress scope
    local progressScope = exportContext:configureProgress({
        title = "Instagram Carousel Export",
    })
    
    -- Track completed renditions for progress
    local completedRenditions = 0
    
    -- Track last export directory for opening after export
    local lastExportDir = nil
    
    -- Iterate through each photo
    for i, rendition in exportContext:renditions() do
        
        -- Check if user cancelled
        if progressScope:isCanceled() then
            logInfo("Export cancelled by user")
            break
        end
        
        -- Update progress - rendering phase
        progressScope:setCaption(string.format("Rendering photo %d of %d...", i, nPhotos))
        
        local success, pathOrMessage = rendition:waitForRender()
        
        if success then
            logInfo("Successfully rendered photo " .. i .. ": " .. pathOrMessage)
            
            -- Track export directory
            lastExportDir = LrPathUtils.parent(pathOrMessage)
            
            -- If seamless mode is enabled, split the image into tiles
            if exportParams.seamlessMode then
                -- Update progress - processing phase
                progressScope:setCaption(string.format("Processing photo %d of %d: splitting into tiles...", i, nPhotos))
                
                logInfo("Seamless mode enabled - splitting image into carousel tiles")
                
                -- Step 1: Get the dimensions of the rendered image
                logDebug("Step 1: Getting source image dimensions...")
                progressScope:setCaption(string.format("Photo %d of %d: reading dimensions...", i, nPhotos))
                
                local sourceWidth, sourceHeight = getImageDimensionsFromFile(pathOrMessage)
                
                if not sourceWidth or not sourceHeight then
                    -- Fallback: try to use the photo's dimensions from Lightroom
                    local photo = rendition.photo
                    if photo then
                        local dimensions = photo:getRawMetadata('dimensions')
                        if dimensions then
                            -- Note: These are original dimensions, not exported
                            logWarn("Could not get exported dimensions, using original: " .. 
                                   dimensions.width .. "x" .. dimensions.height)
                            -- For panoramas, assume the width is proportionally larger
                            sourceWidth = dimensions.width
                            sourceHeight = dimensions.height
                        end
                    end
                end
                
                if not sourceWidth or not sourceHeight then
                    logError("Could not determine source image dimensions")
                    LrDialogs.message("Warning", 
                        "Could not determine image dimensions.\n\n" ..
                        "Please ensure ImageMagick is installed and accessible.\n\n" ..
                        "Original file has been exported without splitting.",
                        "warning")
                else
                    logInfo("Source dimensions: " .. sourceWidth .. "x" .. sourceHeight)
                    
                    -- Step 2: Calculate optimal tile count based on aspect ratio
                    -- The key insight: divide the panorama based on the RATIO, then resize
                    logDebug("Step 2: Calculating optimal tile count based on ratio...")
                    
                    -- Calculate tile aspect ratio
                    local tileRatio = tileWidth / tileHeight
                    local sourceRatio = sourceWidth / sourceHeight
                    
                    -- Calculate how many tiles fit based on the ratio
                    local numTiles = math.floor(sourceRatio / tileRatio + 0.5)
                    numTiles = math.max(1, math.min(numTiles, 10))  -- Instagram limit
                    
                    logInfo("Optimal tile count: " .. numTiles .. " (source ratio: " .. 
                           string.format("%.2f", sourceRatio) .. ", tile ratio: " .. 
                           string.format("%.2f", tileRatio) .. ")")
                    
                    -- Get the directory of the exported file
                    local exportDir = LrPathUtils.parent(pathOrMessage)
                    local fileName = LrPathUtils.leafName(pathOrMessage)
                    local baseName = LrPathUtils.removeExtension(fileName)
                    
                    -- Create output directory for tiles
                    local tileDir = LrPathUtils.child(exportDir, baseName .. "_carousel")
                    LrFileUtils.createDirectory(tileDir)
                    
                    -- Update lastExportDir to the tile directory
                    lastExportDir = tileDir
                    
                    logDebug("Tile output directory: " .. tileDir)
                    
                    -- Step 3 & 4: Call ImageMagick to split the image
                    logDebug("Step 3 & 4: Calling ImageMagick to apply processing and split...")
                    progressScope:setCaption(string.format("Photo %d of %d: creating %d tiles...", i, nPhotos, numTiles))
                    
                    local tiles, errorMsg = ImageProcessor.splitImageIntoTiles(
                        pathOrMessage,
                        tileDir,
                        tileWidth,
                        tileHeight,
                        {
                            overflowHandling = exportParams.overflowHandling,
                            backgroundColor = exportParams.backgroundColor,
                            frameColor = exportParams.frameColor,
                            frameSize = exportParams.frameSize,
                            enableFrame = exportParams.enableFrame,
                            sourceWidth = sourceWidth,
                            sourceHeight = sourceHeight,
                            numTiles = numTiles,  -- Pass calculated tile count
                        }
                    )
                    
                    if tiles and #tiles > 0 then
                        logInfo("Successfully created " .. #tiles .. " carousel tiles")
                        
                        -- Delete the original exported file since we have tiles
                        LrFileUtils.delete(pathOrMessage)
                        logDebug("Deleted original export: " .. pathOrMessage)
                    else
                        logWarn("Failed to split image into tiles - keeping original export")
                        
                        -- Provide detailed error message
                        local errorDetails = errorMsg or "Unknown error"
                        local platform = string.find(string.lower(LrSystemInfo.osVersion()), "windows") and "Windows" or "macOS"
                        
                        local messageText
                        if string.find(errorDetails, "not installed") or string.find(errorDetails, "not in PATH") then
                            messageText = "Could not split image into carousel tiles. ImageMagick is not installed or not accessible.\n\n" ..
                                        "Original file has been exported without splitting.\n\n" ..
                                        "To enable image splitting, please install ImageMagick:\n"
                            if platform == "Windows" then
                                messageText = messageText .. 
                                            "- Download from https://imagemagick.org\n" ..
                                            "- During installation, make sure to check 'Add to PATH'\n" ..
                                            "- Restart Lightroom after installation"
                            else
                                messageText = messageText ..
                                            "- Install via Homebrew: brew install imagemagick\n" ..
                                            "- Or download from https://imagemagick.org\n" ..
                                            "- Restart Lightroom after installation"
                            end
                        else
                            messageText = "Could not split image into carousel tiles.\n\n" ..
                                        "Error: " .. errorDetails .. "\n\n" ..
                                        "Original file has been exported without splitting."
                        end
                        
                        LrDialogs.message("Warning", messageText, "info")
                    end
                end
            else
                logInfo("Seamless mode disabled - exporting as single image")
            end
        else
            logError("Failed to export photo " .. i .. ": " .. pathOrMessage)
        end
        
        -- Update completed count and progress
        completedRenditions = completedRenditions + 1
        progressScope:setPortionComplete(completedRenditions, nPhotos)
    end
    
    logInfo("========================================")
    logInfo("Export complete")
    logInfo("========================================")
    
    -- Open export folder if requested
    if exportParams.openExportFolder and lastExportDir then
        logInfo("Opening export folder: " .. lastExportDir)
        LrShell.revealInShell(lastExportDir)
    end
end

--------------------------------------------------------------------------------

return exportServiceProvider

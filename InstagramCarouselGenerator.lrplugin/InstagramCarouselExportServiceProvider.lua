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
    { key = 'carouselWidth', default = 1080 },
    { key = 'carouselHeight', default = 1080 },
    { key = 'seamlessMode', default = true },
    { key = 'aspectRatio', default = '1:1' },
    { key = 'customWidth', default = 1080 },
    { key = 'customHeight', default = 1080 },
    { key = 'overflowHandling', default = 'addBands' },
    { key = 'backgroundColor', default = { r = 1, g = 1, b = 1 } },
    { key = 'frameColor', default = { r = 0, g = 0, b = 0 } },
    { key = 'frameSize', default = 10 },
    { key = 'enableFrame', default = false },
}

-- Allow this plugin to export all files
exportServiceProvider.allowFileFormats = { 'JPEG', 'TIFF', 'PNG' }
exportServiceProvider.allowColorSpaces = { 'sRGB', 'AdobeRGB' }

-- Can export to a specific folder
exportServiceProvider.canExportToTemporaryLocation = true

-- Export service name
exportServiceProvider.exportName = "Instagram Carousel"

--------------------------------------------------------------------------------
-- UI for Export Dialog

function exportServiceProvider.sectionsForTopOfDialog(f, propertyTable)
    local bind = LrView.bind
    local share = LrView.share
    
    -- Update carousel dimensions when aspect ratio changes
    propertyTable:addObserver('aspectRatio', function(propertyTable, key, value)
        if value == '4:5' then
            propertyTable.carouselWidth = 1080
            propertyTable.carouselHeight = 1350
        elseif value == '1:1' then
            propertyTable.carouselWidth = 1080
            propertyTable.carouselHeight = 1080
        elseif value == '5:4' then
            propertyTable.carouselWidth = 1350
            propertyTable.carouselHeight = 1080
        elseif value == '16:9' then
            propertyTable.carouselWidth = 1920
            propertyTable.carouselHeight = 1080
        elseif value == '9:16' then
            propertyTable.carouselWidth = 1080
            propertyTable.carouselHeight = 1920
        elseif value == 'custom' then
            propertyTable.carouselWidth = propertyTable.customWidth
            propertyTable.carouselHeight = propertyTable.customHeight
        end
    end)
    
    return {
        {
            title = "Instagram Carousel Settings",
            synopsis = bind 'seamlessMode',
            
            -- Aspect Ratio Selection
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Aspect Ratio:",
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
                        { title = "Custom", value = 'custom' },
                    },
                },
            },
            
            -- Carousel Size (updates automatically based on ratio)
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Frame Size:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:edit_field {
                    value = bind 'carouselWidth',
                    width_in_digits = 5,
                    min = 100,
                    max = 4096,
                    precision = 0,
                    enabled = bind 'aspectRatio',
                    enabled_value = 'custom',
                },
                
                f:static_text {
                    title = "x",
                },
                
                f:edit_field {
                    value = bind 'carouselHeight',
                    width_in_digits = 5,
                    min = 100,
                    max = 4096,
                    precision = 0,
                    enabled = bind 'aspectRatio',
                    enabled_value = 'custom',
                },
                
                f:static_text {
                    title = "px",
                },
            },
            
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
                    enabled = bind 'overflowHandling',
                    enabled_value = 'addBands',
                },
            },
            
            f:row {
                f:checkbox {
                    title = "Enable Frame",
                    value = bind 'enableFrame',
                    checked_value = true,
                    unchecked_value = false,
                    enabled = bind 'overflowHandling',
                    enabled_value = 'addBands',
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
                    enabled = bind 'enableFrame',
                    enabled_value = true,
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
                    enabled = bind 'enableFrame',
                    enabled_value = true,
                },
                
                f:static_text {
                    title = "px",
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
    
    logInfo("========================================")
    logInfo("Starting Instagram Carousel Export")
    logInfo("========================================")
    logInfo("Tile size: " .. exportParams.carouselWidth .. "x" .. exportParams.carouselHeight)
    logInfo("Seamless mode: " .. tostring(exportParams.seamlessMode))
    logInfo("Aspect ratio: " .. exportParams.aspectRatio)
    logInfo("Overflow handling: " .. exportParams.overflowHandling)
    logDebug("Background color: R=" .. tostring(exportParams.backgroundColor.r) .. 
             " G=" .. tostring(exportParams.backgroundColor.g) .. 
             " B=" .. tostring(exportParams.backgroundColor.b))
    logDebug("Enable frame: " .. tostring(exportParams.enableFrame))
    
    -- Get the photos to be exported
    local nPhotos = exportSession:countRenditions()
    
    logInfo("Number of photos to export: " .. nPhotos)
    
    -- Progress scope
    local progressScope = exportContext:configureProgress({
        title = "Instagram Carousel Export",
    })
    
    -- Track completed renditions for progress
    local completedRenditions = 0
    
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
                    
                    -- Step 2: Calculate optimal tile count
                    logDebug("Step 2: Calculating optimal tile count...")
                    local tileWidth = exportParams.carouselWidth
                    local tileHeight = exportParams.carouselHeight
                    
                    local numTiles = math.ceil(sourceWidth / tileWidth)
                    numTiles = math.max(1, math.min(numTiles, 10))  -- Instagram limit
                    
                    logInfo("Optimal tile count: " .. numTiles .. " (based on " .. 
                           sourceWidth .. " / " .. tileWidth .. ")")
                    
                    -- Get the directory of the exported file
                    local exportDir = LrPathUtils.parent(pathOrMessage)
                    local fileName = LrPathUtils.leafName(pathOrMessage)
                    local baseName = LrPathUtils.removeExtension(fileName)
                    
                    -- Create output directory for tiles
                    local tileDir = LrPathUtils.child(exportDir, baseName .. "_carousel")
                    LrFileUtils.createDirectory(tileDir)
                    
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
end

--------------------------------------------------------------------------------

return exportServiceProvider

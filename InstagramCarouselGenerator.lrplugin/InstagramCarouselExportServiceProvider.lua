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

-- Create a logger for this module
local logger = LrLogger('InstagramCarouselExportService')
logger:enable("print")

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
-- Process Rendered Photos

function exportServiceProvider.processRenderedPhotos(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local exportParams = exportContext.propertyTable
    
    -- Import the image processor
    local ImageProcessor = require 'ImageProcessor'
    
    logger:info("Processing rendered photos for Instagram carousel")
    logger:info(string.format("Tile size: %dx%d", exportParams.carouselWidth, exportParams.carouselHeight))
    logger:info(string.format("Seamless mode: %s", tostring(exportParams.seamlessMode)))
    logger:info(string.format("Aspect ratio: %s", exportParams.aspectRatio))
    logger:info(string.format("Overflow handling: %s", exportParams.overflowHandling))
    
    -- Get the photos to be exported
    local nPhotos = exportSession:countRenditions()
    
    logger:info(string.format("Number of photos to export: %d", nPhotos))
    
    -- Progress scope
    local progressScope = LrDialogs.showModalProgressDialog({
        title = "Instagram Carousel Export",
        caption = "Processing photos...",
        functionContext = functionContext,
    })
    
    -- Iterate through each photo
    for i, rendition in exportContext:renditions() do
        
        -- Update progress
        if progressScope then
            progressScope:setCaption(string.format("Processing photo %d of %d", i, nPhotos))
            progressScope:setPortionComplete(i - 1, nPhotos)
        end
        
        local success, pathOrMessage = rendition:waitForRender()
        
        if success then
            logger:info(string.format("Successfully rendered photo %d: %s", i, pathOrMessage))
            
            -- If seamless mode is enabled, split the image into tiles
            if exportParams.seamlessMode then
                logger:info("Seamless mode enabled - splitting image into carousel tiles")
                
                -- Get the directory of the exported file
                local exportDir = LrPathUtils.parent(pathOrMessage)
                local fileName = LrPathUtils.leafName(pathOrMessage)
                local baseName = LrPathUtils.removeExtension(fileName)
                
                -- Create output directory for tiles
                local tileDir = LrPathUtils.child(exportDir, baseName .. "_carousel")
                LrFileUtils.createDirectory(tileDir)
                
                -- Split the image
                local tiles, errorMsg = ImageProcessor.splitImageIntoTiles(
                    pathOrMessage,
                    tileDir,
                    exportParams.carouselWidth,
                    exportParams.carouselHeight,
                    {
                        overflowHandling = exportParams.overflowHandling,
                        backgroundColor = exportParams.backgroundColor,
                        frameColor = exportParams.frameColor,
                        frameSize = exportParams.frameSize,
                        enableFrame = exportParams.enableFrame,
                    }
                )
                
                if tiles and #tiles > 0 then
                    logger:info(string.format("Successfully created %d carousel tiles", #tiles))
                    
                    -- Delete the original exported file since we have tiles
                    LrFileUtils.delete(pathOrMessage)
                else
                    logger:warn("Failed to split image into tiles - keeping original export")
                    
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
            else
                logger:info("Seamless mode disabled - exporting as single image")
            end
        else
            logger:error(string.format("Failed to export photo %d: %s", i, pathOrMessage))
        end
    end
    
    -- Close progress dialog
    if progressScope then
        progressScope:done()
    end
    
    logger:info("Export complete")
end

--------------------------------------------------------------------------------

return exportServiceProvider

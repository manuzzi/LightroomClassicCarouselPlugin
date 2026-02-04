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
    
    return {
        {
            title = "Instagram Carousel Settings",
            synopsis = bind 'seamlessMode',
            
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = "Carousel Size:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:edit_field {
                    value = bind 'carouselWidth',
                    width_in_digits = 5,
                    min = 100,
                    max = 4096,
                    precision = 0,
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
                },
                
                f:static_text {
                    title = "px",
                },
            },
            
            f:row {
                f:checkbox {
                    title = "Enable Seamless Carousel Mode",
                    value = bind 'seamlessMode',
                    checked_value = true,
                    unchecked_value = false,
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
    
    logger:info("Processing rendered photos for Instagram carousel")
    logger:info(string.format("Carousel size: %dx%d", exportParams.carouselWidth, exportParams.carouselHeight))
    logger:info(string.format("Seamless mode: %s", tostring(exportParams.seamlessMode)))
    
    -- Get the photos to be exported
    local nPhotos = exportSession:countRenditions()
    
    logger:info(string.format("Number of photos to export: %d", nPhotos))
    
    -- Iterate through each photo
    for i, rendition in exportContext:renditions() do
        local success, pathOrMessage = rendition:waitForRender()
        
        if success then
            logger:info(string.format("Successfully exported photo %d: %s", i, pathOrMessage))
            -- Future enhancement: Apply carousel transformations here
        else
            logger:error(string.format("Failed to export photo %d: %s", i, pathOrMessage))
        end
    end
    
    logger:info("Export complete")
end

--------------------------------------------------------------------------------

return exportServiceProvider

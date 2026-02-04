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
    
    -- Background color as separate RGB values (0-255 range for easy use)
    { key = 'bgColorR', default = 255 },
    { key = 'bgColorG', default = 255 },
    { key = 'bgColorB', default = 255 },
    
    -- Frame color as separate RGB values (0-255 range)
    { key = 'frameColorR', default = 0 },
    { key = 'frameColorG', default = 0 },
    { key = 'frameColorB', default = 0 },
    
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

-- Hide the Video panel (this plugin is for photos only)
exportServiceProvider.hideSections = { 'video' }

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
            title = LOC "$$$/InstagramCarousel/Export/Section/Carousel=Instagram Carousel Settings",
            synopsis = bind 'seamlessMode',
            
            f:row {
                f:checkbox {
                    title = LOC "$$$/InstagramCarousel/Export/Label/SeamlessMode=Enable Seamless Carousel Mode (split panoramas)",
                    value = bind 'seamlessMode',
                    checked_value = true,
                    unchecked_value = false,
                },
            },
            
            f:spacer { height = 10 },
            
            -- Aspect Ratio Selection
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Export/Label/AspectRatio=Tile Aspect Ratio:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:popup_menu {
                    value = bind 'aspectRatio',
                    enabled = bind 'seamlessMode',
                    items = {
                        { title = LOC "$$$/InstagramCarousel/AspectRatio/4x5=4:5 (Portrait)", value = '4:5' },
                        { title = LOC "$$$/InstagramCarousel/AspectRatio/1x1=1:1 (Square)", value = '1:1' },
                        { title = LOC "$$$/InstagramCarousel/AspectRatio/5x4=5:4 (Landscape)", value = '5:4' },
                        { title = LOC "$$$/InstagramCarousel/AspectRatio/16x9=16:9 (Wide)", value = '16:9' },
                        { title = LOC "$$$/InstagramCarousel/AspectRatio/9x16=9:16 (Vertical)", value = '9:16' },
                    },
                },
            },
            
            -- Short Side Size Selection
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Export/Label/ShortSideSize=Short Side Size:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:popup_menu {
                    value = bind 'shortSideSize',
                    enabled = bind 'seamlessMode',
                    items = {
                        { title = LOC "$$$/InstagramCarousel/Size/1080=1080 px (Instagram standard)", value = '1080' },
                        { title = LOC "$$$/InstagramCarousel/Size/2160=2160 px (2x)", value = '2160' },
                        { title = LOC "$$$/InstagramCarousel/Size/3240=3240 px (3x)", value = '3240' },
                        { title = LOC "$$$/InstagramCarousel/Size/4320=4320 px (4x)", value = '4320' },
                        { title = LOC "$$$/InstagramCarousel/Size/Custom=Custom", value = 'custom' },
                    },
                },
            },
            
            -- Custom Short Side (only visible when custom is selected)
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Export/Label/CustomSize=Custom Size:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:edit_field {
                    value = bind 'customShortSide',
                    width_in_digits = 5,
                    min = 100,
                    max = 8640,
                    precision = 0,
                    enabled = LrBinding.andAllKeys('seamlessMode', LrBinding.keyEquals('shortSideSize', 'custom')),
                },
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Export/Label/Pixels=px",
                },
            },
            
            -- Calculated Tile Size (read-only display)
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Export/Label/TileSize=Tile Size:",
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
        },
        
        {
            title = LOC "$$$/InstagramCarousel/Export/Section/Overflow=Overflow Handling",
            synopsis = bind 'overflowHandling',
            
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Overflow/WhenDoesntFit=When image doesn't fit perfectly:",
                    alignment = 'left',
                    width = share 'label_width',
                },
            },
            
            f:row {
                spacing = f:control_spacing(),
                
                f:radio_button {
                    title = LOC "$$$/InstagramCarousel/Overflow/AddBands=Add bands with optional frame",
                    value = bind 'overflowHandling',
                    checked_value = 'addBands',
                    enabled = bind 'seamlessMode',
                },
            },
            
            f:row {
                spacing = f:control_spacing(),
                
                f:radio_button {
                    title = LOC "$$$/InstagramCarousel/Overflow/CropToFit=Crop to fit perfectly",
                    value = bind 'overflowHandling',
                    checked_value = 'crop',
                    enabled = bind 'seamlessMode',
                },
            },
        },
        
        {
            title = LOC "$$$/InstagramCarousel/Export/Section/BandFrame=Band & Frame Settings",
            synopsis = bind 'enableFrame',
            
            -- Row 1: Band Color RGB sliders
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/BandColor=Band Color:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:static_text {
                    title = "R:",
                },
                
                f:edit_field {
                    value = bind 'bgColorR',
                    width_in_digits = 3,
                    min = 0,
                    max = 255,
                    precision = 0,
                    enabled = LrBinding.andAllKeys('seamlessMode', LrBinding.keyEquals('overflowHandling', 'addBands')),
                },
                
                f:static_text {
                    title = "G:",
                },
                
                f:edit_field {
                    value = bind 'bgColorG',
                    width_in_digits = 3,
                    min = 0,
                    max = 255,
                    precision = 0,
                    enabled = LrBinding.andAllKeys('seamlessMode', LrBinding.keyEquals('overflowHandling', 'addBands')),
                },
                
                f:static_text {
                    title = "B:",
                },
                
                f:edit_field {
                    value = bind 'bgColorB',
                    width_in_digits = 3,
                    min = 0,
                    max = 255,
                    precision = 0,
                    enabled = LrBinding.andAllKeys('seamlessMode', LrBinding.keyEquals('overflowHandling', 'addBands')),
                },
                
                f:spacer { width = 10 },
                
                f:checkbox {
                    title = LOC "$$$/InstagramCarousel/Label/EnableFrame=Enable Frame",
                    value = bind 'enableFrame',
                    checked_value = true,
                    unchecked_value = false,
                    enabled = LrBinding.andAllKeys('seamlessMode', LrBinding.keyEquals('overflowHandling', 'addBands')),
                },
            },
            
            -- Row 2: Frame Color RGB sliders and Frame size
            f:row {
                spacing = f:control_spacing(),
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/FrameColor=Frame Color:",
                    alignment = 'right',
                    width = share 'label_width',
                },
                
                f:static_text {
                    title = "R:",
                },
                
                f:edit_field {
                    value = bind 'frameColorR',
                    width_in_digits = 3,
                    min = 0,
                    max = 255,
                    precision = 0,
                    enabled = LrBinding.andAllKeys('seamlessMode', 'enableFrame'),
                },
                
                f:static_text {
                    title = "G:",
                },
                
                f:edit_field {
                    value = bind 'frameColorG',
                    width_in_digits = 3,
                    min = 0,
                    max = 255,
                    precision = 0,
                    enabled = LrBinding.andAllKeys('seamlessMode', 'enableFrame'),
                },
                
                f:static_text {
                    title = "B:",
                },
                
                f:edit_field {
                    value = bind 'frameColorB',
                    width_in_digits = 3,
                    min = 0,
                    max = 255,
                    precision = 0,
                    enabled = LrBinding.andAllKeys('seamlessMode', 'enableFrame'),
                },
                
                f:spacer { width = 10 },
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/FrameSize=Size:",
                },
                
                f:edit_field {
                    value = bind 'frameSize',
                    width_in_digits = 3,
                    min = 1,
                    max = 100,
                    precision = 0,
                    enabled = LrBinding.andAllKeys('seamlessMode', 'enableFrame'),
                },
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Export/Label/Pixels=px",
                },
            },
        },
        
        {
            title = LOC "$$$/InstagramCarousel/Export/Section/AfterExport=After Export",
            
            f:row {
                f:checkbox {
                    title = LOC "$$$/InstagramCarousel/Label/OpenFolder=Open export folder after export",
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
    logInfo("Starting Instagram Carousel Export v1.4.0")
    logInfo("========================================")
    logInfo("Tile aspect ratio: " .. exportParams.aspectRatio)
    logInfo("Short side size: " .. exportParams.shortSideSize)
    logInfo("Tile size: " .. tileWidth .. "x" .. tileHeight)
    logInfo("Seamless mode: " .. tostring(exportParams.seamlessMode))
    logInfo("Overflow handling: " .. exportParams.overflowHandling)
    
    -- Log color values (now using direct RGB values 0-255)
    logDebug("Background color: R=" .. tostring(exportParams.bgColorR) .. 
             " G=" .. tostring(exportParams.bgColorG) .. 
             " B=" .. tostring(exportParams.bgColorB))
    logDebug("Frame color: R=" .. tostring(exportParams.frameColorR) .. 
             " G=" .. tostring(exportParams.frameColorG) .. 
             " B=" .. tostring(exportParams.frameColorB))
    logDebug("Enable frame: " .. tostring(exportParams.enableFrame))
    logDebug("Open export folder: " .. tostring(exportParams.openExportFolder))
    
    -- Get the photos to be exported
    local nPhotos = exportSession:countRenditions()
    
    logInfo("Number of photos to export: " .. nPhotos)
    
    -- Progress scope (localized)
    local progressScope = exportContext:configureProgress({
        title = LOC "$$$/InstagramCarousel/Progress/ExportTitle=Instagram Carousel Export",
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
        
        -- Update progress - rendering phase (localized with placeholders)
        progressScope:setCaption(LOC("$$$/InstagramCarousel/Progress/Rendering=Rendering photo ^1 of ^2...", i, nPhotos))
        
        local success, pathOrMessage = rendition:waitForRender()
        
        if success then
            logInfo("Successfully rendered photo " .. i .. ": " .. pathOrMessage)
            
            -- Track export directory
            lastExportDir = LrPathUtils.parent(pathOrMessage)
            
            -- If seamless mode is enabled, split the image into tiles
            if exportParams.seamlessMode then
                -- Update progress - processing phase (localized)
                progressScope:setCaption(LOC("$$$/InstagramCarousel/Progress/Processing=Processing photo ^1 of ^2: splitting into tiles...", i, nPhotos))
                
                logInfo("Seamless mode enabled - splitting image into carousel tiles")
                
                -- Step 1: Get the dimensions of the rendered image
                logDebug("Step 1: Getting source image dimensions...")
                progressScope:setCaption(LOC("$$$/InstagramCarousel/Progress/ReadingDimensions=Photo ^1 of ^2: reading dimensions...", i, nPhotos))
                
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
                    LrDialogs.message(
                        LOC "$$$/InstagramCarousel/Warning/Title=Warning", 
                        LOC "$$$/InstagramCarousel/Warning/DimensionsNotDetermined=Could not determine image dimensions.\n\nPlease ensure ImageMagick is installed and accessible.\n\nOriginal file has been exported without splitting.", 
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
                    -- Round to nearest integer: if ratio is 2.4, use 2 tiles; if 2.6, use 3 tiles
                    local exactTiles = sourceRatio / tileRatio
                    local numTiles = math.floor(exactTiles + 0.5)  -- Standard rounding
                    numTiles = math.max(1, math.min(numTiles, 10))  -- Instagram limit
                    
                    logInfo("Optimal tile count: " .. numTiles .. " (source ratio: " .. 
                           string.format("%.2f", sourceRatio) .. ", tile ratio: " .. 
                           string.format("%.2f", tileRatio) .. ", exact tiles: " ..
                           string.format("%.2f", exactTiles) .. ")")
                    
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
                    progressScope:setCaption(LOC("$$$/InstagramCarousel/Progress/CreatingTiles=Photo ^1 of ^2: creating ^3 tiles...", i, nPhotos, numTiles))
                    
                    local tiles, errorMsg = ImageProcessor.splitImageIntoTiles(
                        pathOrMessage,
                        tileDir,
                        tileWidth,
                        tileHeight,
                        {
                            overflowHandling = exportParams.overflowHandling,
                            -- Pass RGB values directly (0-255 range)
                            bgColorR = exportParams.bgColorR,
                            bgColorG = exportParams.bgColorG,
                            bgColorB = exportParams.bgColorB,
                            frameColorR = exportParams.frameColorR,
                            frameColorG = exportParams.frameColorG,
                            frameColorB = exportParams.frameColorB,
                            frameSize = exportParams.frameSize,
                            enableFrame = exportParams.enableFrame,
                            sourceWidth = sourceWidth,
                            sourceHeight = sourceHeight,
                            numTiles = numTiles,  -- Pass calculated tile count
                            baseName = baseName,  -- Pass original file name for tile naming
                        }
                    )
                    
                    if tiles and #tiles > 0 then
                        logInfo("Successfully created " .. #tiles .. " carousel tiles")
                        
                        -- Delete the original exported file since we have tiles
                        LrFileUtils.delete(pathOrMessage)
                        logDebug("Deleted original export: " .. pathOrMessage)
                    else
                        logWarn("Failed to split image into tiles - keeping original export")
                        
                        -- Provide detailed error message (localized)
                        local errorDetails = errorMsg or "Unknown error"
                        local platform = string.find(string.lower(LrSystemInfo.osVersion()), "windows") and "Windows" or "macOS"
                        
                        local messageText
                        if string.find(errorDetails, "not installed") or string.find(errorDetails, "not in PATH") then
                            messageText = LOC "$$$/InstagramCarousel/Warning/ImageMagickNotInstalled=Could not split image into carousel tiles. ImageMagick is not installed or not accessible.\n\nOriginal file has been exported without splitting.\n\nTo enable image splitting, please install ImageMagick:" .. "\n"
                            if platform == "Windows" then
                                messageText = messageText .. LOC "$$$/InstagramCarousel/ImageMagick/InstallWindows=To install:\n1. Download from https://imagemagick.org\n2. Run the installer\n3. Make sure to check 'Add to PATH' during installation\n4. Restart Lightroom"
                            else
                                messageText = messageText .. LOC "$$$/InstagramCarousel/ImageMagick/InstallMac=To install:\n1. Using Homebrew: brew install imagemagick\n2. Or download from https://imagemagick.org\n3. Restart Lightroom after installation"
                            end
                        else
                            messageText = LOC("$$$/InstagramCarousel/Warning/ImageMagickError=Could not split image into carousel tiles.\n\nError: ^1\n\nOriginal file has been exported without splitting.", errorDetails)
                        end
                        
                        LrDialogs.message(LOC "$$$/InstagramCarousel/Warning/Title=Warning", messageText, "info")
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

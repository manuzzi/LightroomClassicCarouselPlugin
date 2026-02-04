--[[----------------------------------------------------------------------------

TranslationProvider.lua
Localization Module for Instagram Carousel Generator

This module provides localized strings for the plugin using Adobe's ZStrings
localization system. The LOC function automatically selects the appropriate
translation based on the system language.

Supported languages: English, Italian, German, Spanish, French

------------------------------------------------------------------------------]]

local LrLocalization = import 'LrLocalization'

-- Create the translation module
local TranslationProvider = {}

--------------------------------------------------------------------------------
-- Helper function to get localized string using ZStrings format
-- ZStrings format: LOC "$$$/Path/Key=Default English Text"
-- Adobe Lightroom will automatically use translations from TranslatedStrings folder

-- Note: For languages without explicit translation files, the default (English) is used.
-- The translations are provided inline using the LOC function format.

--------------------------------------------------------------------------------
-- Plugin Info and Metadata

TranslationProvider.pluginName = LOC "$$$/InstagramCarousel/PluginName=Instagram Carousel Generator"
TranslationProvider.pluginVersion = LOC "$$$/InstagramCarousel/PluginVersion=Version 1.4.0"
TranslationProvider.exportServiceName = LOC "$$$/InstagramCarousel/ExportServiceName=Instagram Carousel"

--------------------------------------------------------------------------------
-- Plugin Info Provider Section Titles

TranslationProvider.sectionTitleMain = LOC "$$$/InstagramCarousel/Section/Main=Instagram Carousel Generator"
TranslationProvider.sectionTitleCredits = LOC "$$$/InstagramCarousel/Section/Credits=Credits & Support"
TranslationProvider.sectionTitleImageMagick = LOC "$$$/InstagramCarousel/Section/ImageMagick=ImageMagick Status"
TranslationProvider.sectionTitleLogging = LOC "$$$/InstagramCarousel/Section/Logging=Logging Settings"

--------------------------------------------------------------------------------
-- Plugin Description

TranslationProvider.pluginDescription = LOC "$$$/InstagramCarousel/Description=Instagram Carousel Generator helps you create seamless carousel posts for Instagram directly from Adobe Lightroom Classic.\n\nNew features: Aspect ratio presets, image splitting for panoramas, customizable bands and frames."

--------------------------------------------------------------------------------
-- Credits & Support Labels

TranslationProvider.labelDevelopedBy = LOC "$$$/InstagramCarousel/Label/DevelopedBy=Developed by:"
TranslationProvider.labelEmail = LOC "$$$/InstagramCarousel/Label/Email=Email:"
TranslationProvider.labelWebsite = LOC "$$$/InstagramCarousel/Label/Website=Website:"
TranslationProvider.labelGitHub = LOC "$$$/InstagramCarousel/Label/GitHub=GitHub:"
TranslationProvider.labelPayPal = LOC "$$$/InstagramCarousel/Label/PayPal=PayPal:"
TranslationProvider.labelLicense = LOC "$$$/InstagramCarousel/Label/License=License:"

TranslationProvider.supportMessage = LOC "$$$/InstagramCarousel/Support/Message=If you find this plugin useful, please consider supporting its development:"
TranslationProvider.donateViaPayPal = LOC "$$$/InstagramCarousel/Support/Donate=Donate via PayPal"
TranslationProvider.licenseText = LOC "$$$/InstagramCarousel/License/Text=MIT License - Copyright (c) 2026 Marco Manuzzi"
TranslationProvider.imageMagickCredits = LOC "$$$/InstagramCarousel/Credits/ImageMagick=This plugin uses ImageMagick® for image processing:"
TranslationProvider.imageMagickLicense = LOC "$$$/InstagramCarousel/License/ImageMagick=License: Apache 2.0 License"

--------------------------------------------------------------------------------
-- ImageMagick Status

TranslationProvider.labelStatus = LOC "$$$/InstagramCarousel/Label/Status=Status:"
TranslationProvider.labelVersion = LOC "$$$/InstagramCarousel/Label/Version=Version:"
TranslationProvider.labelLocation = LOC "$$$/InstagramCarousel/Label/Location=Location:"

TranslationProvider.statusInstalled = LOC "$$$/InstagramCarousel/Status/Installed=✓ Installed"
TranslationProvider.statusNotInstalled = LOC "$$$/InstagramCarousel/Status/NotInstalled=✗ Not Installed"
TranslationProvider.statusUnknown = LOC "$$$/InstagramCarousel/Status/Unknown=Unknown"
TranslationProvider.statusSystemPath = LOC "$$$/InstagramCarousel/Status/SystemPath=System PATH"

TranslationProvider.imageMagickAvailable = LOC "$$$/InstagramCarousel/ImageMagick/Available=ImageMagick is properly installed. You can use seamless carousel mode to split panoramic images."
TranslationProvider.imageMagickRequired = LOC "$$$/InstagramCarousel/ImageMagick/Required=ImageMagick is required for splitting panoramic images into carousel tiles."

TranslationProvider.btnTestImageMagick = LOC "$$$/InstagramCarousel/Button/TestImageMagick=Test ImageMagick"

--------------------------------------------------------------------------------
-- ImageMagick Installation Instructions

TranslationProvider.imageMagickInstallWindows = LOC "$$$/InstagramCarousel/ImageMagick/InstallWindows=To install:\n1. Download from https://imagemagick.org\n2. Run the installer\n3. Make sure to check 'Add to PATH' during installation\n4. Restart Lightroom"

TranslationProvider.imageMagickInstallMac = LOC "$$$/InstagramCarousel/ImageMagick/InstallMac=To install:\n1. Using Homebrew: brew install imagemagick\n2. Or download from https://imagemagick.org\n3. Restart Lightroom after installation"

TranslationProvider.imageMagickNotAccessible = LOC "$$$/InstagramCarousel/ImageMagick/NotAccessible=ImageMagick is not installed or not accessible."

TranslationProvider.imageMagickSearchedPaths = LOC "$$$/InstagramCarousel/ImageMagick/SearchedPaths=Searched paths:\n• /opt/homebrew/bin (Homebrew on Apple Silicon)\n• /usr/local/bin (Homebrew on Intel Macs)\n• /opt/local/bin (MacPorts)\n• /usr/bin (System)\n• System PATH"

--------------------------------------------------------------------------------
-- ImageMagick Test Dialog Messages

TranslationProvider.testImageMagickFailed = LOC "$$$/InstagramCarousel/Dialog/TestFailed=ImageMagick Test Failed"
TranslationProvider.testImageMagickSuccess = LOC "$$$/InstagramCarousel/Dialog/TestSuccess=ImageMagick Test Successful"

TranslationProvider.imageMagickWorkingMsg = LOC "$$$/InstagramCarousel/ImageMagick/WorkingMsg=ImageMagick is working correctly!\n\nVersion: ^1\nLocation: ^2\n\nYou can use seamless carousel mode to split panoramic images."

TranslationProvider.imageMagickTestFailedMsg = LOC "$$$/InstagramCarousel/ImageMagick/TestFailedMsg=ImageMagick was detected but the test command failed.\n\nPlease try reinstalling ImageMagick and restart Lightroom."

--------------------------------------------------------------------------------
-- Logging Settings

TranslationProvider.labelLogLevel = LOC "$$$/InstagramCarousel/Label/LogLevel=Log Level:"
TranslationProvider.logLevelDebug = LOC "$$$/InstagramCarousel/LogLevel/Debug=Debug (verbose)"
TranslationProvider.logLevelInfo = LOC "$$$/InstagramCarousel/LogLevel/Info=Info (default)"
TranslationProvider.logLevelWarn = LOC "$$$/InstagramCarousel/LogLevel/Warn=Warning"
TranslationProvider.logLevelError = LOC "$$$/InstagramCarousel/LogLevel/Error=Error only"

TranslationProvider.loggingHelpText = LOC "$$$/InstagramCarousel/Logging/HelpText=Set to 'Debug' for detailed logging when troubleshooting issues.\nLogs can be viewed in Lightroom's Console (Help > System Info > Show Log File)."

--------------------------------------------------------------------------------
-- Export Service Provider - Section Titles

TranslationProvider.exportSectionCarousel = LOC "$$$/InstagramCarousel/Export/Section/Carousel=Instagram Carousel Settings"
TranslationProvider.exportSectionOverflow = LOC "$$$/InstagramCarousel/Export/Section/Overflow=Overflow Handling"
TranslationProvider.exportSectionBandFrame = LOC "$$$/InstagramCarousel/Export/Section/BandFrame=Band & Frame Settings"
TranslationProvider.exportSectionAfterExport = LOC "$$$/InstagramCarousel/Export/Section/AfterExport=After Export"

--------------------------------------------------------------------------------
-- Export Service Provider - Labels

TranslationProvider.labelSeamlessMode = LOC "$$$/InstagramCarousel/Export/Label/SeamlessMode=Enable Seamless Carousel Mode (split panoramas)"
TranslationProvider.labelAspectRatio = LOC "$$$/InstagramCarousel/Export/Label/AspectRatio=Tile Aspect Ratio:"
TranslationProvider.labelShortSideSize = LOC "$$$/InstagramCarousel/Export/Label/ShortSideSize=Short Side Size:"
TranslationProvider.labelCustomSize = LOC "$$$/InstagramCarousel/Export/Label/CustomSize=Custom Size:"
TranslationProvider.labelTileSize = LOC "$$$/InstagramCarousel/Export/Label/TileSize=Tile Size:"
TranslationProvider.labelPixels = LOC "$$$/InstagramCarousel/Export/Label/Pixels=px"

--------------------------------------------------------------------------------
-- Aspect Ratio Options

TranslationProvider.aspectRatio4x5 = LOC "$$$/InstagramCarousel/AspectRatio/4x5=4:5 (Portrait)"
TranslationProvider.aspectRatio1x1 = LOC "$$$/InstagramCarousel/AspectRatio/1x1=1:1 (Square)"
TranslationProvider.aspectRatio5x4 = LOC "$$$/InstagramCarousel/AspectRatio/5x4=5:4 (Landscape)"
TranslationProvider.aspectRatio16x9 = LOC "$$$/InstagramCarousel/AspectRatio/16x9=16:9 (Wide)"
TranslationProvider.aspectRatio9x16 = LOC "$$$/InstagramCarousel/AspectRatio/9x16=9:16 (Vertical)"

--------------------------------------------------------------------------------
-- Short Side Size Options

TranslationProvider.size1080 = LOC "$$$/InstagramCarousel/Size/1080=1080 px (Instagram standard)"
TranslationProvider.size2160 = LOC "$$$/InstagramCarousel/Size/2160=2160 px (2x)"
TranslationProvider.size3240 = LOC "$$$/InstagramCarousel/Size/3240=3240 px (3x)"
TranslationProvider.size4320 = LOC "$$$/InstagramCarousel/Size/4320=4320 px (4x)"
TranslationProvider.sizeCustom = LOC "$$$/InstagramCarousel/Size/Custom=Custom"

--------------------------------------------------------------------------------
-- Overflow Handling

TranslationProvider.overflowWhenDoesntFit = LOC "$$$/InstagramCarousel/Overflow/WhenDoesntFit=When image doesn't fit perfectly:"
TranslationProvider.overflowAddBands = LOC "$$$/InstagramCarousel/Overflow/AddBands=Add bands with optional frame"
TranslationProvider.overflowCropToFit = LOC "$$$/InstagramCarousel/Overflow/CropToFit=Crop to fit perfectly"

--------------------------------------------------------------------------------
-- Band & Frame Settings

TranslationProvider.labelBandColor = LOC "$$$/InstagramCarousel/Label/BandColor=Band Color:"
TranslationProvider.labelFrameColor = LOC "$$$/InstagramCarousel/Label/FrameColor=Frame Color:"
TranslationProvider.labelEnableFrame = LOC "$$$/InstagramCarousel/Label/EnableFrame=Enable Frame"
TranslationProvider.labelFrameSize = LOC "$$$/InstagramCarousel/Label/FrameSize=Size:"

--------------------------------------------------------------------------------
-- After Export

TranslationProvider.labelOpenFolder = LOC "$$$/InstagramCarousel/Label/OpenFolder=Open export folder after export"

--------------------------------------------------------------------------------
-- Export Progress Messages

TranslationProvider.progressExportTitle = LOC "$$$/InstagramCarousel/Progress/ExportTitle=Instagram Carousel Export"
TranslationProvider.progressRendering = LOC "$$$/InstagramCarousel/Progress/Rendering=Rendering photo ^1 of ^2..."
TranslationProvider.progressProcessing = LOC "$$$/InstagramCarousel/Progress/Processing=Processing photo ^1 of ^2: splitting into tiles..."
TranslationProvider.progressReadingDimensions = LOC "$$$/InstagramCarousel/Progress/ReadingDimensions=Photo ^1 of ^2: reading dimensions..."
TranslationProvider.progressCreatingTiles = LOC "$$$/InstagramCarousel/Progress/CreatingTiles=Photo ^1 of ^2: creating ^3 tiles..."

--------------------------------------------------------------------------------
-- Warning and Error Messages

TranslationProvider.warningTitle = LOC "$$$/InstagramCarousel/Warning/Title=Warning"
TranslationProvider.warningDimensionsNotDetermined = LOC "$$$/InstagramCarousel/Warning/DimensionsNotDetermined=Could not determine image dimensions.\n\nPlease ensure ImageMagick is installed and accessible.\n\nOriginal file has been exported without splitting."

TranslationProvider.warningImageMagickNotInstalled = LOC "$$$/InstagramCarousel/Warning/ImageMagickNotInstalled=Could not split image into carousel tiles. ImageMagick is not installed or not accessible.\n\nOriginal file has been exported without splitting.\n\nTo enable image splitting, please install ImageMagick:"

TranslationProvider.warningImageMagickError = LOC "$$$/InstagramCarousel/Warning/ImageMagickError=Could not split image into carousel tiles.\n\nError: ^1\n\nOriginal file has been exported without splitting."

--------------------------------------------------------------------------------
-- Help Menu Items

TranslationProvider.helpAbout = LOC "$$$/InstagramCarousel/Help/About=About Instagram Carousel Generator"

--------------------------------------------------------------------------------
-- Return the translation provider module
return TranslationProvider

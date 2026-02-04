--[[----------------------------------------------------------------------------

Info.lua
Instagram Carousel Generator Plugin for Adobe Lightroom Classic

Main plugin metadata and initialization file.

------------------------------------------------------------------------------]]

return {
    -- SDK Version Information
    LrSdkVersion = 15.1,
    LrSdkMinimumVersion = 11.0,
    
    -- Plugin Information (localized with ZStrings)
    LrPluginName = LOC "$$$/InstagramCarousel/PluginName=Instagram Carousel Generator",
    LrPluginInfoUrl = "https://github.com/manuzzi/LightroomClassicCarouselPlugin",
    
    -- Unique Plugin Identifier (reverse domain notation)
    LrToolkitIdentifier = "com.manuzzi.lightroom.instagramcarousel",
    
    -- Main Plugin Module
    LrInitPlugin = "InstagramCarouselGenerator.lua",
    
    -- Plugin Version
    VERSION = { 
        major = 1, 
        minor = 4, 
        revision = 0,
        build = 0,
    },
    
    -- Export Service Provider (localized)
    LrExportServiceProvider = {
        title = LOC "$$$/InstagramCarousel/ExportServiceName=Instagram Carousel",
        file = "InstagramCarouselExportServiceProvider.lua",
    },
    
    -- Help Menu Items (localized)
    LrHelpMenuItems = {
        {
            title = LOC "$$$/InstagramCarousel/Help/About=About Instagram Carousel Generator",
            file = "Documentation/About.txt",
        },
    },
    
    -- Plugin Metadata
    LrPluginInfoProvider = "PluginInfoProvider.lua",
}

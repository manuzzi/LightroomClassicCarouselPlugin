--[[----------------------------------------------------------------------------

Info.lua
Instagram Carousel Generator Plugin for Adobe Lightroom Classic

Main plugin metadata and initialization file.

------------------------------------------------------------------------------]]

return {
    -- SDK Version Information
    LrSdkVersion = 15.1,
    LrSdkMinimumVersion = 11.0,
    
    -- Plugin Information
    LrPluginName = "Instagram Carousel Generator",
    LrPluginInfoUrl = "https://github.com/manuzzi/LightroomClassicCarouselPlugin",
    
    -- Unique Plugin Identifier (reverse domain notation)
    LrToolkitIdentifier = "com.manuzzi.lightroom.instagramcarousel",
    
    -- Main Plugin Module
    LrInitPlugin = "InstagramCarouselGenerator.lua",
    
    -- Plugin Version
    VERSION = { 
        major = 1, 
        minor = 2, 
        revision = 4,
        build = 0,
    },
    
    -- Export Service Provider
    LrExportServiceProvider = {
        title = "Instagram Carousel",
        file = "InstagramCarouselExportServiceProvider.lua",
    },
    
    -- Help Menu Items
    LrHelpMenuItems = {
        {
            title = "About Instagram Carousel Generator",
            file = "Documentation/About.txt",
        },
    },
    
    -- Plugin Metadata
    LrPluginInfoProvider = "PluginInfoProvider.lua",
}

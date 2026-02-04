--[[----------------------------------------------------------------------------

PluginInfoProvider.lua
Plugin Info Provider for Instagram Carousel Generator

Provides additional information about the plugin in the Plugin Manager.

------------------------------------------------------------------------------]]

local LrView = import 'LrView'
local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrSystemInfo = import 'LrSystemInfo'
local LrColor = import 'LrColor'

local pluginInfoProvider = {}

--------------------------------------------------------------------------------
-- Check ImageMagick availability

local function checkImageMagick()
    local success, result = LrTasks.pcall(function()
        local command
        local isWindows = string.find(string.lower(LrSystemInfo.osVersion()), "windows") ~= nil
        
        if isWindows then
            command = 'magick -version'
        else
            command = 'convert -version 2>/dev/null'
        end
        
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            if output and (string.find(output, "ImageMagick") or string.find(output, "Version")) then
                -- Extract version if possible
                local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                return true, version
            end
        end
        return false, nil
    end)
    
    if success and result then
        return result
    else
        return false, nil
    end
end

--------------------------------------------------------------------------------
-- Section for Top of Plugin Manager Dialog

function pluginInfoProvider.sectionsForTopOfDialog(f, propertyTable)
    -- Check ImageMagick status
    local imageMagickInstalled, imageMagickVersion = checkImageMagick()
    local isWindows = string.find(string.lower(LrSystemInfo.osVersion()), "windows") ~= nil
    
    return {
        {
            title = "Instagram Carousel Generator",
            
            f:static_text {
                title = "Instagram Carousel Generator helps you create seamless carousel posts for Instagram directly from Adobe Lightroom Classic.\n\nNew features: Aspect ratio presets, image splitting for panoramas, customizable bands and frames.",
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 4,
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = "Version 1.1.0",
                font = '<system/bold>',
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:static_text {
                    title = "GitHub:",
                    width = 60,
                },
                
                f:static_text {
                    title = "https://github.com/manuzzi/LightroomClassicCarouselPlugin",
                    fill_horizontal = 1,
                    mouse_down = function()
                        LrHttp.openUrlInBrowser("https://github.com/manuzzi/LightroomClassicCarouselPlugin")
                    end,
                },
            },
        },
        
        {
            title = "ImageMagick Status",
            
            f:row {
                f:static_text {
                    title = "Status:",
                    width = 80,
                },
                
                f:static_text {
                    title = imageMagickInstalled and "✓ Installed" or "✗ Not Installed",
                    text_color = imageMagickInstalled and LrColor("green") or LrColor("red"),
                    font = '<system/bold>',
                },
            },
            
            imageMagickInstalled and f:row {
                f:static_text {
                    title = "Version:",
                    width = 80,
                },
                
                f:static_text {
                    title = imageMagickVersion or "Unknown",
                },
            } or f:column {},
            
            f:spacer { height = 5 },
            
            imageMagickInstalled and f:static_text {
                title = "ImageMagick is properly installed. You can use seamless carousel mode to split panoramic images.",
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 2,
            } or f:static_text {
                title = "ImageMagick is required for splitting panoramic images into carousel tiles.\n\n" ..
                        (isWindows and 
                         "To install:\n1. Download from https://imagemagick.org\n2. Run the installer\n3. Make sure to check 'Add to PATH' during installation\n4. Restart Lightroom" or
                         "To install:\n1. Using Homebrew: brew install imagemagick\n2. Or download from https://imagemagick.org\n3. Restart Lightroom after installation"),
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = isWindows and 6 or 5,
            },
        },
    }
end

--------------------------------------------------------------------------------

return pluginInfoProvider

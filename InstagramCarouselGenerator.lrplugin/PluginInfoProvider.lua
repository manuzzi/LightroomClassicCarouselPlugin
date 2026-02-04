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
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local pluginInfoProvider = {}

--------------------------------------------------------------------------------
-- Constants

-- Common macOS paths where ImageMagick might be installed
local MACOS_MAGICK_PATHS = {
    "/opt/homebrew/bin/magick",  -- Apple Silicon Homebrew
    "/usr/local/bin/magick",      -- Intel Homebrew
    "/opt/local/bin/magick",      -- MacPorts
    "magick"                      -- System PATH
}

--------------------------------------------------------------------------------
-- Platform detection

local function isWindows()
    return string.find(string.lower(LrSystemInfo.osVersion()), "windows") ~= nil
end

--------------------------------------------------------------------------------
-- Check for bundled ImageMagick binary

local function checkBundledImageMagick()
    local pluginPath = _PLUGIN.path
    if not pluginPath then
        return false, nil
    end
    
    local binPath
    local magickBinary
    
    if isWindows() then
        binPath = LrPathUtils.child(pluginPath, "bin")
        binPath = LrPathUtils.child(binPath, "win")
        magickBinary = LrPathUtils.child(binPath, "magick.exe")
    else
        binPath = LrPathUtils.child(pluginPath, "bin")
        binPath = LrPathUtils.child(binPath, "mac")
        magickBinary = LrPathUtils.child(binPath, "magick")
    end
    
    -- Check if bundled binary exists
    if not LrFileUtils.exists(magickBinary) then
        return false, nil
    end
    
    -- Verify it works
    local success, result = LrTasks.pcall(function()
        local command
        if isWindows() then
            command = '"' .. magickBinary .. '" -version 2>&1'
        else
            command = "'" .. magickBinary .. "' -version 2>&1"
        end
        
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            if output and string.find(output, "ImageMagick") then
                local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                return true, version
            end
        end
        return false, nil
    end)
    
    if success and result then
        return result
    end
    return false, nil
end

--------------------------------------------------------------------------------
-- Check for system ImageMagick (with common paths for macOS)

local function checkSystemImageMagick()
    local success, result = LrTasks.pcall(function()
        if isWindows() then
            local handle = io.popen('magick -version 2>&1')
            if handle then
                local output = handle:read("*a")
                handle:close()
                
                if output and string.find(output, "ImageMagick") then
                    local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                    return true, version, "system PATH"
                end
            end
        else
            -- macOS: Check multiple common locations
            for _, path in ipairs(MACOS_MAGICK_PATHS) do
                local handle = io.popen(path .. " -version 2>&1")
                if handle then
                    local output = handle:read("*a")
                    handle:close()
                    
                    if output and string.find(output, "ImageMagick") then
                        local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                        return true, version, path
                    end
                end
            end
        end
        return false, nil, nil
    end)
    
    if success and result then
        return result
    end
    return false, nil, nil
end

--------------------------------------------------------------------------------
-- Section for Top of Plugin Manager Dialog

function pluginInfoProvider.sectionsForTopOfDialog(f, propertyTable)
    -- Check ImageMagick status (bundled first, then system)
    local bundledInstalled, bundledVersion = checkBundledImageMagick()
    local systemInstalled, systemVersion, systemPath = checkSystemImageMagick()
    
    local imageMagickInstalled = bundledInstalled or systemInstalled
    local imageMagickVersion = bundledInstalled and bundledVersion or systemVersion
    local winPlatform = isWindows()
    
    -- Determine source text for display
    local imageMagickSourceText
    if bundledInstalled then
        imageMagickSourceText = "Bundled with plugin"
    elseif systemInstalled and systemPath then
        imageMagickSourceText = "System: " .. systemPath
    else
        imageMagickSourceText = "System PATH"
    end
    
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
                title = "Version 1.2.0",
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
            
            imageMagickInstalled and f:row {
                f:static_text {
                    title = "Source:",
                    width = 80,
                },
                
                f:static_text {
                    title = imageMagickSourceText,
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
                        "The plugin includes bundled binaries, but they may need to be installed.\n" ..
                        "Please check the bin/ folder in the plugin directory.\n\n" ..
                        (winPlatform and 
                         "Alternative: Install from https://imagemagick.org\nMake sure to check 'Add to PATH' during installation.\nRestart Lightroom after installation." or
                         "Alternative: Install via Homebrew: brew install imagemagick\nOr download from https://imagemagick.org\nRestart Lightroom after installation."),
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 8,
            },
        },
    }
end

--------------------------------------------------------------------------------

return pluginInfoProvider

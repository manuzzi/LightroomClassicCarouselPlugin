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
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'
local LrBinding = import 'LrBinding'
local LrPathUtils = import 'LrPathUtils'

-- Load translation provider for localized strings
local Str = require 'TranslationProvider'

local pluginInfoProvider = {}

--------------------------------------------------------------------------------
-- Platform Detection

local function isWindows()
    return string.find(string.lower(LrSystemInfo.osVersion()), "windows") ~= nil
end

--------------------------------------------------------------------------------
-- ImageMagick Path Detection for macOS

local function findImageMagickOnMac()
    local commonPaths = {
        "/opt/homebrew/bin",     -- Homebrew on Apple Silicon
        "/usr/local/bin",        -- Homebrew on Intel Macs
        "/opt/local/bin",        -- MacPorts
        "/usr/bin",              -- System path
        ""                       -- Empty string = rely on PATH
    }
    
    -- First try to find 'magick' command (ImageMagick v7+)
    for _, basePath in ipairs(commonPaths) do
        local magickCmd
        if basePath ~= "" then
            magickCmd = basePath .. "/magick"
        else
            magickCmd = "magick"
        end
        
        local command = magickCmd .. " -version 2>/dev/null"
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            if output and (string.find(output, "ImageMagick") or string.find(output, "Version")) then
                local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                return true, version, basePath
            end
        end
    end
    
    -- Fallback: try to find 'convert' command
    for _, basePath in ipairs(commonPaths) do
        local convertCmd
        if basePath ~= "" then
            convertCmd = basePath .. "/convert"
        else
            convertCmd = "convert"
        end
        
        local command = convertCmd .. " -version 2>/dev/null"
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            if output and (string.find(output, "ImageMagick") or string.find(output, "Version")) then
                local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                return true, version, basePath
            end
        end
    end
    
    return false, nil, nil
end

--------------------------------------------------------------------------------
-- Check ImageMagick availability

local function checkImageMagick()
    local success, result = LrTasks.pcall(function()
        if isWindows() then
            local command = 'magick -version'
            local handle = io.popen(command)
            if handle then
                local output = handle:read("*a")
                handle:close()
                
                if output and (string.find(output, "ImageMagick") or string.find(output, "Version")) then
                    local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                    return { installed = true, version = version, path = "System PATH" }
                end
            end
            return { installed = false, version = nil, path = nil }
        else
            local installed, version, path = findImageMagickOnMac()
            return { installed = installed, version = version, path = path }
        end
    end)
    
    if success and result then
        return result.installed, result.version, result.path
    else
        return false, nil, nil
    end
end

--------------------------------------------------------------------------------
-- Test ImageMagick function

local function testImageMagick()
    LrFunctionContext.callWithContext("testImageMagick", function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)
        
        LrTasks.startAsyncTask(function()
            local installed, version, path = checkImageMagick()
            
            if not installed then
                local platformMsg
                if isWindows() then
                    platformMsg = Str.imageMagickNotAccessible .. "\n\n" .. Str.imageMagickInstallWindows
                else
                    platformMsg = Str.imageMagickNotAccessible .. "\n\n" .. Str.imageMagickInstallMac .. "\n\n" .. Str.imageMagickSearchedPaths
                end
                
                LrDialogs.message(Str.testImageMagickFailed, platformMsg, "critical")
                return
            end
            
            -- Try to run a simple ImageMagick command to verify it works
            local testCommand
            local convertCmd
            
            if isWindows() then
                testCommand = 'magick -version'
                convertCmd = "magick"
            else
                if path and path ~= "" then
                    convertCmd = path .. "/magick"
                else
                    convertCmd = "magick"
                end
                testCommand = convertCmd .. ' -version 2>/dev/null'
            end
            
            local testSuccess, testResult = LrTasks.pcall(function()
                local handle = io.popen(testCommand)
                if handle then
                    local output = handle:read("*a")
                    handle:close()
                    return output
                end
                return nil
            end)
            
            if testSuccess and testResult and string.find(testResult, "ImageMagick") then
                local versionStr = version or Str.statusUnknown
                local locationStr = (path and path ~= "" and path or Str.statusSystemPath)
                -- Use LOC with placeholders for the success message
                local successMsg = LOC("$$$/InstagramCarousel/ImageMagick/WorkingMsg=ImageMagick is working correctly!\n\nVersion: ^1\nLocation: ^2\n\nYou can use seamless carousel mode to split panoramic images.", versionStr, locationStr)
                
                LrDialogs.message(Str.testImageMagickSuccess, successMsg, "info")
            else
                LrDialogs.message(Str.testImageMagickFailed, Str.imageMagickTestFailedMsg, "warning")
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- Section for Top of Plugin Manager Dialog

function pluginInfoProvider.sectionsForTopOfDialog(f, propertyTable)
    -- Check ImageMagick status
    local imageMagickInstalled, imageMagickVersion, imageMagickPath = checkImageMagick()
    local isWindowsPlatform = isWindows()
    
    -- Get current log level preference
    local prefs = LrPrefs.prefsForPlugin()
    if not prefs.logLevel then
        prefs.logLevel = "info"  -- Default
    end
    
    -- Get the plugin logo path
    local pluginPath = LrPathUtils.child(_PLUGIN.path, "ManuzziPhotoLogo.png")
    
    return {
        {
            title = Str.sectionTitleMain,
            
            f:picture {
                value = pluginPath,
                width = 256,
                height = 256,
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = Str.pluginDescription,
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 4,
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = Str.pluginVersion,
                font = '<system/bold>',
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:static_text {
                    title = Str.labelGitHub,
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
            title = Str.sectionTitleCredits,
            
            f:row {
                f:static_text {
                    title = Str.labelDevelopedBy,
                    width = 80,
                },
                
                f:static_text {
                    title = "Marco Manuzzi",
                    font = '<system/bold>',
                },
            },
            
            f:row {
                f:static_text {
                    title = Str.labelEmail,
                    width = 80,
                },
                
                f:static_text {
                    title = "marco@manuzzi.photo",
                    text_color = LrColor("blue"),
                    mouse_down = function()
                        LrHttp.openUrlInBrowser("mailto:marco@manuzzi.photo")
                    end,
                },
            },
            
            f:row {
                f:static_text {
                    title = Str.labelWebsite,
                    width = 80,
                },
                
                f:static_text {
                    title = "https://www.manuzzi.photo",
                    text_color = LrColor("blue"),
                    mouse_down = function()
                        LrHttp.openUrlInBrowser("https://www.manuzzi.photo")
                    end,
                },
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = Str.supportMessage,
                fill_horizontal = 1,
                width_in_chars = 50,
            },
            
            f:spacer { height = 5 },
            
            f:row {
                f:static_text {
                    title = Str.labelPayPal,
                    width = 80,
                },
                
                f:static_text {
                    title = Str.donateViaPayPal,
                    text_color = LrColor("blue"),
                    font = '<system/bold>',
                    mouse_down = function()
                        LrHttp.openUrlInBrowser("https://paypal.me/MarcoManuzzi50?locale.x=it_IT&country.x=IT")
                    end,
                },
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:static_text {
                    title = Str.labelLicense,
                    width = 80,
                },
                
                f:static_text {
                    title = Str.licenseText,
                },
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = Str.imageMagickCredits,
                fill_horizontal = 1,
                width_in_chars = 50,
            },
            
            f:spacer { height = 5 },
            
            f:row {
                f:static_text {
                    title = "ImageMagick:",
                    width = 80,
                },
                
                f:static_text {
                    title = "https://imagemagick.org",
                    text_color = LrColor("blue"),
                    mouse_down = function()
                        LrHttp.openUrlInBrowser("https://imagemagick.org")
                    end,
                },
            },
            
            f:row {
                f:static_text {
                    title = "",  -- Empty label for alignment with ImageMagick row above
                    width = 80,
                },
                
                f:static_text {
                    title = Str.imageMagickLicense,
                    text_color = LrColor("blue"),
                    mouse_down = function()
                        LrHttp.openUrlInBrowser("https://imagemagick.org/script/license.php")
                    end,
                },
            },
        },
        
        {
            title = Str.sectionTitleImageMagick,
            
            f:row {
                f:static_text {
                    title = Str.labelStatus,
                    width = 80,
                },
                
                f:static_text {
                    title = imageMagickInstalled and Str.statusInstalled or Str.statusNotInstalled,
                    text_color = imageMagickInstalled and LrColor("green") or LrColor("red"),
                    font = '<system/bold>',
                },
            },
            
            imageMagickInstalled and f:row {
                f:static_text {
                    title = Str.labelVersion,
                    width = 80,
                },
                
                f:static_text {
                    title = imageMagickVersion or Str.statusUnknown,
                },
            } or f:column {},
            
            imageMagickInstalled and f:row {
                f:static_text {
                    title = Str.labelLocation,
                    width = 80,
                },
                
                f:static_text {
                    title = (imageMagickPath and imageMagickPath ~= "") and imageMagickPath or Str.statusSystemPath,
                },
            } or f:column {},
            
            f:spacer { height = 5 },
            
            imageMagickInstalled and f:static_text {
                title = Str.imageMagickAvailable,
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 2,
            } or f:static_text {
                title = Str.imageMagickRequired .. "\n\n" ..
                        (isWindowsPlatform and Str.imageMagickInstallWindows or Str.imageMagickInstallMac),
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = isWindowsPlatform and 6 or 5,
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:push_button {
                    title = Str.btnTestImageMagick,
                    action = function()
                        testImageMagick()
                    end,
                },
            },
        },
        
        {
            title = Str.sectionTitleLogging,
            
            f:row {
                f:static_text {
                    title = Str.labelLogLevel,
                    width = 80,
                },
                
                f:popup_menu {
                    value = LrView.bind {
                        key = 'logLevel',
                        bind_to_object = prefs,
                    },
                    items = {
                        { title = Str.logLevelDebug, value = "debug" },
                        { title = Str.logLevelInfo, value = "info" },
                        { title = Str.logLevelWarn, value = "warn" },
                        { title = Str.logLevelError, value = "error" },
                    },
                    immediate = true,
                },
            },
            
            f:spacer { height = 5 },
            
            f:static_text {
                title = Str.loggingHelpText,
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 2,
            },
        },
    }
end

--------------------------------------------------------------------------------

return pluginInfoProvider

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
                    platformMsg = LOC "$$$/InstagramCarousel/ImageMagick/NotAccessible=ImageMagick is not installed or not accessible." .. "\n\n" .. 
                                  LOC "$$$/InstagramCarousel/ImageMagick/InstallWindows=To install:\n1. Download from https://imagemagick.org\n2. Run the installer\n3. Make sure to check 'Add to PATH' during installation\n4. Restart Lightroom"
                else
                    platformMsg = LOC "$$$/InstagramCarousel/ImageMagick/NotAccessible=ImageMagick is not installed or not accessible." .. "\n\n" .. 
                                  LOC "$$$/InstagramCarousel/ImageMagick/InstallMac=To install:\n1. Using Homebrew: brew install imagemagick\n2. Or download from https://imagemagick.org\n3. Restart Lightroom after installation" .. "\n\n" ..
                                  LOC "$$$/InstagramCarousel/ImageMagick/SearchedPaths=Searched paths:\n• /opt/homebrew/bin (Homebrew on Apple Silicon)\n• /usr/local/bin (Homebrew on Intel Macs)\n• /opt/local/bin (MacPorts)\n• /usr/bin (System)\n• System PATH"
                end
                
                LrDialogs.message(LOC "$$$/InstagramCarousel/Dialog/TestFailed=ImageMagick Test Failed", platformMsg, "critical")
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
                local versionStr = version or LOC "$$$/InstagramCarousel/Status/Unknown=Unknown"
                local locationStr = (path and path ~= "" and path or LOC "$$$/InstagramCarousel/Status/SystemPath=System PATH")
                local successMsg = LOC("$$$/InstagramCarousel/ImageMagick/WorkingMsg=ImageMagick is working correctly!\n\nVersion: ^1\nLocation: ^2\n\nYou can use seamless carousel mode to split panoramic images.", versionStr, locationStr)
                
                LrDialogs.message(LOC "$$$/InstagramCarousel/Dialog/TestSuccess=ImageMagick Test Successful", successMsg, "info")
            else
                LrDialogs.message(LOC "$$$/InstagramCarousel/Dialog/TestFailed=ImageMagick Test Failed", 
                    LOC "$$$/InstagramCarousel/ImageMagick/TestFailedMsg=ImageMagick was detected but the test command failed.\n\nPlease try reinstalling ImageMagick and restart Lightroom.", 
                    "warning")
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
            title = LOC "$$$/InstagramCarousel/Section/Main=Instagram Carousel Generator",
            
            f:picture {
                value = pluginPath,
                width = 256,
                height = 256,
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = LOC "$$$/InstagramCarousel/Description=Instagram Carousel Generator helps you create seamless carousel posts for Instagram directly from Adobe Lightroom Classic.\n\nNew features: Aspect ratio presets, image splitting for panoramas, customizable bands and frames.",
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 4,
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = LOC "$$$/InstagramCarousel/PluginVersion=Version 1.4.0",
                font = '<system/bold>',
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/GitHub=GitHub:",
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
            title = LOC "$$$/InstagramCarousel/Section/Credits=Credits & Support",
            
            f:row {
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/DevelopedBy=Developed by:",
                    width = 80,
                },
                
                f:static_text {
                    title = "Marco Manuzzi",
                    font = '<system/bold>',
                },
            },
            
            f:row {
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/Email=Email:",
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
                    title = LOC "$$$/InstagramCarousel/Label/Website=Website:",
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
                title = LOC "$$$/InstagramCarousel/Support/Message=If you find this plugin useful, please consider supporting its development:",
                fill_horizontal = 1,
                width_in_chars = 50,
            },
            
            f:spacer { height = 5 },
            
            f:row {
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/PayPal=PayPal:",
                    width = 80,
                },
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Support/Donate=Donate via PayPal",
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
                    title = LOC "$$$/InstagramCarousel/Label/License=License:",
                    width = 80,
                },
                
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/License/Text=MIT License - Copyright (c) 2026 Marco Manuzzi",
                },
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = LOC "$$$/InstagramCarousel/Credits/ImageMagick=This plugin uses ImageMagick® for image processing:",
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
                    title = LOC "$$$/InstagramCarousel/License/ImageMagick=License: Apache 2.0 License",
                    text_color = LrColor("blue"),
                    mouse_down = function()
                        LrHttp.openUrlInBrowser("https://imagemagick.org/script/license.php")
                    end,
                },
            },
        },
        
        {
            title = LOC "$$$/InstagramCarousel/Section/ImageMagick=ImageMagick Status",
            
            f:row {
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/Status=Status:",
                    width = 80,
                },
                
                f:static_text {
                    title = imageMagickInstalled and LOC "$$$/InstagramCarousel/Status/Installed=✓ Installed" or LOC "$$$/InstagramCarousel/Status/NotInstalled=✗ Not Installed",
                    text_color = imageMagickInstalled and LrColor("green") or LrColor("red"),
                    font = '<system/bold>',
                },
            },
            
            imageMagickInstalled and f:row {
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/Version=Version:",
                    width = 80,
                },
                
                f:static_text {
                    title = imageMagickVersion or LOC "$$$/InstagramCarousel/Status/Unknown=Unknown",
                },
            } or f:column {},
            
            imageMagickInstalled and f:row {
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/Location=Location:",
                    width = 80,
                },
                
                f:static_text {
                    title = (imageMagickPath and imageMagickPath ~= "") and imageMagickPath or LOC "$$$/InstagramCarousel/Status/SystemPath=System PATH",
                },
            } or f:column {},
            
            f:spacer { height = 5 },
            
            imageMagickInstalled and f:static_text {
                title = LOC "$$$/InstagramCarousel/ImageMagick/Available=ImageMagick is properly installed. You can use seamless carousel mode to split panoramic images.",
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 2,
            } or f:static_text {
                title = LOC "$$$/InstagramCarousel/ImageMagick/Required=ImageMagick is required for splitting panoramic images into carousel tiles." .. "\n\n" ..
                        (isWindowsPlatform and LOC "$$$/InstagramCarousel/ImageMagick/InstallWindows=To install:\n1. Download from https://imagemagick.org\n2. Run the installer\n3. Make sure to check 'Add to PATH' during installation\n4. Restart Lightroom" or LOC "$$$/InstagramCarousel/ImageMagick/InstallMac=To install:\n1. Using Homebrew: brew install imagemagick\n2. Or download from https://imagemagick.org\n3. Restart Lightroom after installation"),
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = isWindowsPlatform and 6 or 5,
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:push_button {
                    title = LOC "$$$/InstagramCarousel/Button/TestImageMagick=Test ImageMagick",
                    action = function()
                        testImageMagick()
                    end,
                },
            },
        },
        
        {
            title = LOC "$$$/InstagramCarousel/Section/Logging=Logging Settings",
            
            f:row {
                f:static_text {
                    title = LOC "$$$/InstagramCarousel/Label/LogLevel=Log Level:",
                    width = 80,
                },
                
                f:popup_menu {
                    value = LrView.bind {
                        key = 'logLevel',
                        bind_to_object = prefs,
                    },
                    items = {
                        { title = LOC "$$$/InstagramCarousel/LogLevel/Debug=Debug (verbose)", value = "debug" },
                        { title = LOC "$$$/InstagramCarousel/LogLevel/Info=Info (default)", value = "info" },
                        { title = LOC "$$$/InstagramCarousel/LogLevel/Warn=Warning", value = "warn" },
                        { title = LOC "$$$/InstagramCarousel/LogLevel/Error=Error only", value = "error" },
                    },
                    immediate = true,
                },
            },
            
            f:spacer { height = 5 },
            
            f:static_text {
                title = LOC "$$$/InstagramCarousel/Logging/HelpText=Set to 'Debug' for detailed logging when troubleshooting issues.\nLogs can be viewed in Lightroom's Console (Help > System Info > Show Log File).",
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 2,
            },
        },
    }
end

--------------------------------------------------------------------------------

return pluginInfoProvider

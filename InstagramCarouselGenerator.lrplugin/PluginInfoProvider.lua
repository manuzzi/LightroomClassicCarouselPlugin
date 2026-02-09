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
local LrLogger = import 'LrLogger'

local logger = LrLogger('InstagramCarouselPluginInfoProvider')
logger:enable('print')

local function getVersionString()
    local version = _PLUGIN and _PLUGIN.VERSION
    if not version then
        local infoPath = LrPathUtils.child(_PLUGIN.path, "Info.lua")
        local ok, info = pcall(dofile, infoPath)
        if ok and type(info) == "table" then
            version = info.VERSION
        end
    end

    if not version then
        return nil
    end

    local major = tonumber(version.major) or 0
    local minor = tonumber(version.minor) or 0
    local revision = tonumber(version.revision) or 0
    local build = tonumber(version.build) or 0

    local base = string.format("%d.%d.%d", major, minor, revision)
    if build > 0 then
        return base .. "." .. tostring(build)
    end
    return base
end

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
                    platformMsg = "ImageMagick is not installed or not accessible.\n\n" ..
                                  "To install:\n" ..
                                  "1. Download from https://imagemagick.org\n" ..
                                  "2. Run the installer\n" ..
                                  "3. Make sure to check 'Add to PATH' during installation\n" ..
                                  "4. Restart Lightroom"
                else
                    platformMsg = "ImageMagick is not installed or not accessible.\n\n" ..
                                  "To install:\n" ..
                                  "1. Using Homebrew: brew install imagemagick\n" ..
                                  "2. Or download from https://imagemagick.org\n" ..
                                  "3. Restart Lightroom after installation\n\n" ..
                                  "Searched paths:\n" ..
                                  "• /opt/homebrew/bin (Homebrew on Apple Silicon)\n" ..
                                  "• /usr/local/bin (Homebrew on Intel Macs)\n" ..
                                  "• /opt/local/bin (MacPorts)\n" ..
                                  "• /usr/bin (System)\n" ..
                                  "• System PATH"
                end
                
                LrDialogs.message("ImageMagick Test Failed", platformMsg, "critical")
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
                local successMsg = "ImageMagick is working correctly!\n\n" ..
                                   "Version: " .. (version or "Unknown") .. "\n" ..
                                   "Location: " .. (path and path ~= "" and path or "System PATH") .. "\n\n" ..
                                   "You can use seamless carousel mode to split panoramic images."
                
                LrDialogs.message("ImageMagick Test Successful", successMsg, "info")
            else
                LrDialogs.message("ImageMagick Test Failed", 
                    "ImageMagick was detected but the test command failed.\n\n" ..
                    "Please try reinstalling ImageMagick and restart Lightroom.", 
                    "warning")
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- Version Comparison

local function parseVersion(versionString)
    if not versionString then
        return nil
    end
    
    -- Remove 'v' prefix if present
    local cleanVersion = versionString:match("^v?(.+)$")
    
    -- Parse version numbers
    local major, minor, revision, build = cleanVersion:match("^(%d+)%.(%d+)%.(%d+)%.?(%d*)$")
    
    if not major then
        -- Try without build number
        major, minor, revision = cleanVersion:match("^(%d+)%.(%d+)%.(%d+)$")
    end
    
    if not major then
        return nil
    end
    
    return {
        major = tonumber(major) or 0,
        minor = tonumber(minor) or 0,
        revision = tonumber(revision) or 0,
        build = tonumber(build) or 0,
    }
end

local function compareVersions(v1, v2)
    -- Returns: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
    if not v1 or not v2 then
        return 0
    end
    
    if v1.major ~= v2.major then
        return v1.major > v2.major and 1 or -1
    end
    
    if v1.minor ~= v2.minor then
        return v1.minor > v2.minor and 1 or -1
    end
    
    if v1.revision ~= v2.revision then
        return v1.revision > v2.revision and 1 or -1
    end
    
    if v1.build ~= v2.build then
        return v1.build > v2.build and 1 or -1
    end
    
    return 0
end

--------------------------------------------------------------------------------
-- Check for Updates

local function checkForUpdates(propertyTable)
    LrFunctionContext.callWithContext("checkForUpdates", function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)
        
        LrTasks.startAsyncTask(function()
            local prefs = LrPrefs.prefsForPlugin()
            
            -- Update UI to show checking status
            if propertyTable then
                propertyTable.updateCheckStatus = "Checking for updates..."
                propertyTable.updateAvailable = false
            end
            
            logger:info("Checking for updates...")
            
            -- GitHub API URL for latest release
            local apiUrl = "https://api.github.com/repos/manuzzi/LightroomClassicCarouselPlugin/releases/latest"
            
            local success, response = LrTasks.pcall(function()
                local result, hdrs = LrHttp.get(apiUrl)
                return result, hdrs
            end)
            
            if not success then
                logger:warn("Failed to check for updates: network error")
                if propertyTable then
                    propertyTable.updateCheckStatus = "Failed to check for updates (network error)"
                    propertyTable.updateAvailable = false
                end
                LrDialogs.message("Update Check Failed", 
                    "Could not connect to GitHub to check for updates.\n\n" ..
                    "Please check your internet connection and try again.", 
                    "warning")
                return
            end
            
            local result, hdrs = response, nil
            if type(response) == "table" then
                result, hdrs = response[1], response[2]
            end
            
            if not result or result == "" then
                logger:warn("Failed to check for updates: empty response")
                if propertyTable then
                    propertyTable.updateCheckStatus = "Failed to check for updates"
                    propertyTable.updateAvailable = false
                end
                return
            end
            
            -- Parse JSON response manually (Lua doesn't have built-in JSON parser)
            -- Extract fields more carefully to avoid matching wrong html_url
            local latestVersion = result:match('"tag_name"%s*:%s*"([^"]+)"')
            
            -- For html_url, match the one that's part of the release object (before assets_url)
            -- We look for the pattern where html_url appears before "assets_url"
            local htmlUrlPattern = '"html_url"%s*:%s*"(https://github%.com/[^"]+/releases/tag/[^"]+)"'
            local releaseUrl = result:match(htmlUrlPattern)
            
            -- Fallback: try to find any release URL pattern
            if not releaseUrl then
                releaseUrl = result:match('"html_url"%s*:%s*"(https://github%.com/[^"]+)"')
            end
            
            local releaseName = result:match('"name"%s*:%s*"([^"]+)"')
            
            if not latestVersion then
                logger:warn("Failed to parse update response")
                if propertyTable then
                    propertyTable.updateCheckStatus = "Failed to parse update information"
                    propertyTable.updateAvailable = false
                end
                return
            end
            
            logger:info("Latest version from GitHub: " .. latestVersion)
            
            -- Get current version
            local currentVersionString = getVersionString()
            logger:info("Current version: " .. (currentVersionString or "Unknown"))
            
            -- Parse and compare versions
            local currentVersion = parseVersion(currentVersionString)
            local latestVersionParsed = parseVersion(latestVersion)
            
            if not currentVersion or not latestVersionParsed then
                logger:warn("Failed to parse version numbers")
                if propertyTable then
                    propertyTable.updateCheckStatus = "Failed to compare versions"
                    propertyTable.updateAvailable = false
                end
                return
            end
            
            local comparison = compareVersions(latestVersionParsed, currentVersion)
            
            -- Store update information in preferences
            prefs.lastUpdateCheck = os.time()
            prefs.latestVersion = latestVersion
            prefs.latestVersionUrl = releaseUrl
            
            if comparison > 0 then
                -- New version available
                logger:info("New version available: " .. latestVersion)
                if propertyTable then
                    propertyTable.updateCheckStatus = "⬆ Update available: " .. latestVersion
                    propertyTable.updateAvailable = true
                    propertyTable.latestVersionUrl = releaseUrl
                end
                
                local updateMsg = "A new version is available!\n\n" ..
                                  "Current version: " .. currentVersionString .. "\n" ..
                                  "Latest version: " .. latestVersion .. "\n\n" ..
                                  (releaseName and releaseName ~= "" and "Release: " .. releaseName .. "\n\n" or "") ..
                                  "Click OK to visit the download page."
                
                local dialogResult = LrDialogs.confirm(updateMsg, "Update Available", "OK", "Cancel")
                if dialogResult == "ok" and releaseUrl then
                    LrHttp.openUrlInBrowser(releaseUrl)
                end
            else
                -- Already up to date
                logger:info("Plugin is up to date")
                if propertyTable then
                    propertyTable.updateCheckStatus = "✓ You have the latest version (" .. currentVersionString .. ")"
                    propertyTable.updateAvailable = false
                end
                
                LrDialogs.message("No Updates Available", 
                    "You are already using the latest version (" .. currentVersionString .. ").", 
                    "info")
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- Section for Top of Plugin Manager Dialog

function pluginInfoProvider.sectionsForTopOfDialog(f, propertyTable)
    local versionString = getVersionString() or "Unknown"
    -- Check ImageMagick status
    local imageMagickInstalled, imageMagickVersion, imageMagickPath = checkImageMagick()
    local isWindowsPlatform = isWindows()
    
    -- Get current log level preference
    local prefs = LrPrefs.prefsForPlugin()
    if not prefs.logLevel then
        prefs.logLevel = "info"  -- Default
    end
    
    -- Initialize update check properties
    if not propertyTable.updateCheckStatus then
        local lastCheck = prefs.lastUpdateCheck
        local latestVersion = prefs.latestVersion
        
        if lastCheck and latestVersion then
            local currentVersion = parseVersion(versionString)
            local latestVersionParsed = parseVersion(latestVersion)
            
            if currentVersion and latestVersionParsed then
                local comparison = compareVersions(latestVersionParsed, currentVersion)
                if comparison > 0 then
                    propertyTable.updateCheckStatus = "⬆ Update available: " .. latestVersion
                    propertyTable.updateAvailable = true
                    propertyTable.latestVersionUrl = prefs.latestVersionUrl
                else
                    propertyTable.updateCheckStatus = "✓ Up to date"
                    propertyTable.updateAvailable = false
                end
            else
                propertyTable.updateCheckStatus = "Click 'Check for Updates' to check"
                propertyTable.updateAvailable = false
            end
        else
            propertyTable.updateCheckStatus = "Click 'Check for Updates' to check"
            propertyTable.updateAvailable = false
        end
    end
    
    -- Get the plugin icon path
    local pluginIconPath = LrPathUtils.child(_PLUGIN.path, "PluginIcon.png")
    
    return {
        {
            title = "Instagram Carousel Generator",
            
            f:picture {
                value = pluginIconPath,
                width = 128,
                height = 128,
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = "Instagram Carousel Generator helps you create seamless carousel posts for Instagram directly from Adobe Lightroom Classic.",
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 2,
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = "Version " .. versionString,
                font = '<system/bold>',
            },
        },
        
        {
            title = "Updates",
            
            f:row {
                f:static_text {
                    title = "Current Version:",
                    width = 100,
                },
                
                f:static_text {
                    title = versionString,
                    font = '<system/bold>',
                },
            },
            
            f:spacer { height = 5 },
            
            f:row {
                f:static_text {
                    title = "Status:",
                    width = 100,
                },
                
                f:static_text {
                    title = LrView.bind('updateCheckStatus'),
                    text_color = LrView.bind {
                        key = 'updateAvailable',
                        transform = function(value, fromTable)
                            return value and LrColor("green") or LrColor("black")
                        end,
                    },
                    fill_horizontal = 1,
                },
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:push_button {
                    title = "Check for Updates",
                    action = function()
                        checkForUpdates(propertyTable)
                    end,
                },
                
                f:push_button {
                    title = "Download Latest",
                    enabled = LrView.bind('updateAvailable'),
                    action = function()
                        local url = propertyTable.latestVersionUrl or "https://github.com/manuzzi/LightroomClassicCarouselPlugin/releases/latest"
                        LrHttp.openUrlInBrowser(url)
                    end,
                },
            },
        },
        
        {
            title = "Credits & Support",
            
            f:picture {
                value = LrPathUtils.child(_PLUGIN.path, "ManuzziPhotoLogo.png"),
                width = 128,
                height = 128,
            },
            
            f:spacer { height = 10 },
            
            f:row {
                f:static_text {
                    title = "Developed by:",
                    width = 80,
                },
                
                f:static_text {
                    title = "Marco Manuzzi",
                    font = '<system/bold>',
                },
            },
            
            f:row {
                f:static_text {
                    title = "Email:",
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
                    title = "Website:",
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
                title = "If you find this plugin useful, please consider supporting its development:",
                fill_horizontal = 1,
                width_in_chars = 50,
            },
            
            f:spacer { height = 5 },
            
            f:row {
                f:static_text {
                    title = "PayPal:",
                    width = 80,
                },
                
                f:static_text {
                    title = "Donate via PayPal",
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
                    title = "License:",
                    width = 80,
                },
                
                f:static_text {
                    title = "MIT License - Copyright (c) 2026 Marco Manuzzi",
                },
            },
            
            f:spacer { height = 10 },
            
            f:static_text {
                title = "This plugin uses ImageMagick® for image processing:",
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
                    title = "License: Apache 2.0 License",
                    text_color = LrColor("blue"),
                    mouse_down = function()
                        LrHttp.openUrlInBrowser("https://imagemagick.org/script/license.php")
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
                    title = "Location:",
                    width = 80,
                },
                
                f:static_text {
                    title = (imageMagickPath and imageMagickPath ~= "") and imageMagickPath or "System PATH",
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
                        (isWindowsPlatform and 
                         "To install:\n1. Download from https://imagemagick.org\n2. Run the installer\n3. Make sure to check 'Add to PATH' during installation\n4. Restart Lightroom" or
                         "To install:\n1. Using Homebrew: brew install imagemagick\n2. Or download from https://imagemagick.org\n3. Restart Lightroom after installation"),
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = isWindowsPlatform and 6 or 5,
            },
            
            f:row {
                f:push_button {
                    title = "Test ImageMagick",
                    action = function()
                        testImageMagick()
                    end,
                },
            },
        },
        
        {
            title = "Logging Settings",
            
            f:row {
                f:static_text {
                    title = "Log Level:",
                    width = 80,
                },
                
                f:popup_menu {
                    value = LrView.bind {
                        key = 'logLevel',
                        bind_to_object = prefs,
                    },
                    items = {
                        { title = "Debug (verbose)", value = "debug" },
                        { title = "Info (default)", value = "info" },
                        { title = "Warning", value = "warn" },
                        { title = "Error only", value = "error" },
                    },
                    immediate = true,
                },
            },
            
            f:spacer { height = 5 },
            
            f:static_text {
                title = "Set to 'Debug' for detailed logging when troubleshooting issues.\nLogs can be viewed in Lightroom's Console (Help > System Info > Show Log File).",
                fill_horizontal = 1,
                width_in_chars = 50,
                height_in_lines = 2,
            },
        },
    }
end

--------------------------------------------------------------------------------

return pluginInfoProvider

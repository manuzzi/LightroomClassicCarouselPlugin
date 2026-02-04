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

local pluginInfoProvider = {}

--------------------------------------------------------------------------------
-- Platform Detection

local function isWindows()
    return string.find(string.lower(LrSystemInfo.osVersion()), "windows") ~= nil
end

--------------------------------------------------------------------------------
-- ImageMagick Path Detection for macOS
-- On macOS, ImageMagick installed via Homebrew may not be in the system PATH
-- when launched from Lightroom. We search common installation locations.

local function findImageMagickOnMac()
    -- Common paths where ImageMagick might be installed on macOS
    local commonPaths = {
        "/opt/homebrew/bin",     -- Homebrew on Apple Silicon
        "/usr/local/bin",        -- Homebrew on Intel Macs
        "/opt/local/bin",        -- MacPorts
        "/usr/bin",              -- System path
        ""                       -- Empty string = rely on PATH
    }
    
    for _, basePath in ipairs(commonPaths) do
        local convertCmd
        if basePath ~= "" then
            convertCmd = basePath .. "/convert"
        else
            convertCmd = "convert"
        end
        
        -- Check if the convert command exists and works
        -- Note: 2>/dev/null is Unix shell syntax (safe since this function is only called on macOS)
        local command = convertCmd .. " -version 2>/dev/null"
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*a")
            handle:close()
            
            if output and (string.find(output, "ImageMagick") or string.find(output, "Version")) then
                -- Extract version if possible
                local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                return true, version, basePath
            end
        end
    end
    
    return false, nil, nil
end

--------------------------------------------------------------------------------
-- Check ImageMagick availability with path-aware detection

local function checkImageMagick()
    local success, result = LrTasks.pcall(function()
        if isWindows() then
            -- Windows: try 'magick' command
            local command = 'magick -version'
            local handle = io.popen(command)
            if handle then
                local output = handle:read("*a")
                handle:close()
                
                if output and (string.find(output, "ImageMagick") or string.find(output, "Version")) then
                    local version = output:match("Version: ImageMagick ([%d%.%-]+)")
                    return true, version, "System PATH"
                end
            end
            return false, nil, nil
        else
            -- macOS/Unix: use path-aware detection
            return findImageMagickOnMac()
        end
    end)
    
    if success and result then
        return result
    else
        return false, nil, nil
    end
end

--------------------------------------------------------------------------------
-- Test ImageMagick function - runs a simple command to verify it works

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
                    convertCmd = path .. "/convert"
                else
                    convertCmd = "convert"
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
-- Section for Top of Plugin Manager Dialog

function pluginInfoProvider.sectionsForTopOfDialog(f, propertyTable)
    -- Check ImageMagick status
    local imageMagickInstalled, imageMagickVersion, imageMagickPath = checkImageMagick()
    local isWindowsPlatform = isWindows()
    
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
            
            f:spacer { height = 10 },
            
            f:row {
                f:push_button {
                    title = "Test ImageMagick",
                    action = function()
                        testImageMagick()
                    end,
                },
            },
        },
    }
end

--------------------------------------------------------------------------------

return pluginInfoProvider

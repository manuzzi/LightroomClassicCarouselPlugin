--[[----------------------------------------------------------------------------

About.lua
Instagram Carousel Generator Plugin for Adobe Lightroom Classic

Displays plugin information in the Help menu.

------------------------------------------------------------------------------]]

local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'

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

-- Show About dialog
LrFunctionContext.callWithContext("showAboutDialog", function(context)
    LrTasks.startAsyncTask(function()
        -- Read the About.txt content
        local pluginPath = _PLUGIN.path
        local aboutFilePath = LrPathUtils.child(pluginPath, "Documentation/About.txt")
        local aboutText = LrFileUtils.readFile(aboutFilePath) or "About information not available."
        local versionString = getVersionString()
        if versionString and aboutText then
            local replaced = aboutText:gsub("Version:%s*[%d%.%-]+", "Version: " .. versionString, 1)
            if replaced == aboutText then
                aboutText = "Version: " .. versionString .. "\n\n" .. aboutText
            else
                aboutText = replaced
            end
        end
        
        -- Show the dialog
        local title = "About Instagram Carousel Generator"
        if versionString then
            title = title .. " (v" .. versionString .. ")"
        end
        LrDialogs.message(title, aboutText, "info")
    end)
end)

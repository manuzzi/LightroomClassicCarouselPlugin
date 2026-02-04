--[[----------------------------------------------------------------------------

InstagramCarouselGenerator.lua
Main plugin initialization module

This module initializes the Instagram Carousel Generator plugin for
Adobe Lightroom Classic. It sets up the plugin's core functionality
and prepares it for user interaction.

------------------------------------------------------------------------------]]

-- Access the Lightroom SDK namespaces
local LrLogger = import 'LrLogger'

-- Create a logger for this plugin
local logger = LrLogger('InstagramCarouselGeneratorPlugin')
logger:enable("print")

-- Log plugin initialization
logger:info("Instagram Carousel Generator plugin initialized")

-- Return empty table - actual functionality will be in the export service provider
return {}

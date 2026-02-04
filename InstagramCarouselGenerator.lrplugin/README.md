# Instagram Carousel Generator Plugin

A Lightroom Classic plugin for creating seamless Instagram carousel posts.

## Overview

This plugin provides export capabilities optimized for Instagram's carousel format, allowing photographers to easily prepare their images for multi-image Instagram posts.

## Structure

```
InstagramCarouselGenerator.lrplugin/
├── Info.lua                                    # Plugin metadata and configuration
├── InstagramCarouselGenerator.lua              # Main plugin initialization
├── InstagramCarouselExportServiceProvider.lua  # Export service implementation
├── PluginInfoProvider.lua                      # Plugin Manager UI
├── Documentation/
│   └── About.txt                               # User documentation
└── Resources/
    └── Images/                                 # Plugin icons and images
```

## Features

- **Optimized Export**: Export photos in Instagram's recommended square format (1080x1080px)
- **Seamless Mode**: Enable special processing for creating connected carousel posts
- **Flexible Sizing**: Customize export dimensions to suit your needs
- **Multiple Formats**: Support for JPEG, TIFF, and PNG formats

## Development

This plugin is written in Lua using the Adobe Lightroom SDK.

### Key Components

- **Info.lua**: Defines plugin metadata, SDK version requirements, and service providers
- **InstagramCarouselExportServiceProvider.lua**: Implements the export dialog and processing logic
- **PluginInfoProvider.lua**: Provides information displayed in the Lightroom Plugin Manager

## Installation

See the main repository README for installation instructions.

## License

See LICENSE file in the repository root.

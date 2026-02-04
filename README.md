# Instagram Carousel Generator for Lightroom Classic

Adobe Lightroom Classic plugin for creating seamless Instagram carousel posts.

## Overview

The Instagram Carousel Generator is a Lightroom Classic plugin that helps photographers create and export photos optimized for Instagram's carousel format. With support for seamless panoramic carousels and customizable export settings, this plugin streamlines the process of preparing multi-image Instagram posts.

## Features

- 🖼️ **Instagram-Optimized Export**: Default 1080x1080px export settings perfect for Instagram
- 🔄 **Seamless Carousel Mode**: Special processing for connected panoramic posts
- ⚙️ **Customizable Dimensions**: Adjust export size to your specific needs
- 📁 **Multiple Formats**: Support for JPEG, TIFF, and PNG export
- 🎨 **Color Space Options**: sRGB and Adobe RGB support

## Installation

### Manual Installation

1. Download or clone this repository
2. Locate the plugin folder:
   - The plugin is in the `InstagramCarouselGenerator.lrplugin` directory
3. Copy the entire `InstagramCarouselGenerator.lrplugin` folder to:
   - **macOS**: `~/Library/Application Support/Adobe/Lightroom Classic/Plugins/`
   - **Windows**: `%APPDATA%\Adobe\Lightroom Classic\Plugins\`
4. Open Adobe Lightroom Classic
5. Go to `File > Plug-in Manager`
6. Click `Add` button
7. Navigate to and select the `InstagramCarouselGenerator.lrplugin` folder
8. Click `Done`

## Usage

1. Select the photos you want to export for Instagram in the Library module
2. Go to `File > Export` (or press `Cmd+Shift+E` / `Ctrl+Shift+E`)
3. In the Export dialog, select `Instagram Carousel` from the export service dropdown
4. Configure your carousel settings:
   - **Carousel Size**: Set width and height (default: 1080x1080px)
   - **Seamless Mode**: Enable for connected panoramic carousels
5. Configure other export settings as needed (file format, quality, etc.)
6. Click `Export`

## Plugin Structure

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

## Development

This plugin is built using the Adobe Lightroom SDK and written in Lua.

### Requirements

- Adobe Lightroom Classic (SDK version 11.0 or higher)
- The plugin is compatible with both macOS and Windows

### Key Files

- **Info.lua**: Plugin metadata, SDK version, and service provider registration
- **InstagramCarouselExportServiceProvider.lua**: Export dialog UI and photo processing logic
- **PluginInfoProvider.lua**: Information displayed in Lightroom's Plugin Manager

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

See the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or feature requests, please open an issue on GitHub:
https://github.com/manuzzi/LightroomClassicCarouselPlugin/issues

# Instagram Carousel Generator for Lightroom Classic

Adobe Lightroom Classic plugin for creating seamless Instagram carousel posts.

## Overview

The Instagram Carousel Generator is a Lightroom Classic plugin that helps photographers create and export photos optimized for Instagram's carousel format. With support for seamless panoramic carousels and customizable export settings, this plugin streamlines the process of preparing multi-image Instagram posts.

## Features

- 🖼️ **Instagram-Optimized Export**: Multiple aspect ratio presets (4:5, 1:1, 5:4, 16:9, 9:16) perfect for Instagram
- 🔄 **Seamless Carousel Mode**: Automatically splits panoramic photos into multiple edge-to-edge seamless tiles
- 📐 **Aspect Ratio Presets**: Standard Instagram frame sizes with custom ratio option
- 🎨 **Smart Overflow Handling**: Choose to add bands with optional frames or crop to fit perfectly
- 🌈 **Customizable Styling**: Adjustable background and frame colors with customizable frame width
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
9. **Verify ImageMagick Status**: In the Plugin Manager, check the "ImageMagick Status" section to ensure it shows "✓ Installed" (green) for seamless carousel functionality

## Usage

### Checking ImageMagick Installation

Before using seamless carousel mode, verify ImageMagick is installed:

1. Go to `File > Plug-in Manager`
2. Select `Instagram Carousel Generator`
3. Check the **ImageMagick Status** section:
   - **✓ Installed** (green) - Ready to split panoramas
   - **✗ Not Installed** (red) - Follow the installation instructions shown

### Exporting Photos

1. Select the photos you want to export for Instagram in the Library module
2. Go to `File > Export` (or press `Cmd+Shift+E` / `Ctrl+Shift+E`)
3. In the Export dialog, select `Instagram Carousel` from the export service dropdown
4. Configure your carousel settings:
   - **Aspect Ratio**: Choose from Instagram standard ratios (4:5, 1:1, 5:4, 16:9, 9:16) or custom
   - **Frame Size**: Automatically set based on aspect ratio (customizable for custom ratio)
   - **Seamless Mode**: Enable to split panoramic photos into multiple carousel tiles
   - **Overflow Handling**: Choose how to handle images that don't fit perfectly:
     - Add bands with optional frame (for centered images with background)
     - Crop to fit perfectly (for edge-to-edge fills)
   - **Band & Frame Settings** (when using bands):
     - Background color (default: white)
     - Frame color (default: black)
     - Frame size in pixels (default: 10px)
5. Configure other export settings as needed (file format, quality, etc.)
6. Click `Export`

### ImageMagick Dependency

For seamless carousel mode (image splitting), ImageMagick is required. The plugin supports two modes:

#### Option 1: Bundled Binaries (Recommended)
The plugin includes a `bin/` folder where you can place ImageMagick binaries for automatic detection:
- **macOS**: Place the `magick` binary in `bin/mac/`
- **Windows**: Place `magick.exe` in `bin/win/`

This eliminates the need for system-wide installation and ensures compatibility.

#### Option 2: System Installation (Fallback)
If bundled binaries are not present, the plugin will search for ImageMagick in:
- **macOS**: `/opt/homebrew/bin/magick` (Apple Silicon), `/usr/local/bin/magick` (Intel), system PATH
- **Windows**: System PATH

To install system-wide:
- **macOS**: `brew install imagemagick`
- **Windows**: Download from [https://imagemagick.org](https://imagemagick.org) (check "Add to PATH" during installation)

If ImageMagick is not available, photos will be exported as single images without splitting.

## Plugin Structure

```
InstagramCarouselGenerator.lrplugin/
├── Info.lua                                    # Plugin metadata and configuration
├── InstagramCarouselGenerator.lua              # Main plugin initialization
├── InstagramCarouselExportServiceProvider.lua  # Export service implementation
├── ImageProcessor.lua                          # Image processing with ImageMagick
├── PluginInfoProvider.lua                      # Plugin Manager UI
├── bin/                                        # Bundled ImageMagick binaries
│   ├── mac/                                    # macOS binaries (place 'magick' here)
│   └── win/                                    # Windows binaries (place 'magick.exe' here)
├── Documentation/
│   └── About.txt                               # User documentation
└── Resources/
    └── Images/                                 # Plugin icons and images
```

## Detailed Usage Guide

For comprehensive usage examples, troubleshooting, and best practices, see the [Usage Guide](InstagramCarouselGenerator.lrplugin/Documentation/USAGE.md).

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

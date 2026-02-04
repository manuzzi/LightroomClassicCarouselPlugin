# Changelog

All notable changes to the Instagram Carousel Generator plugin will be documented in this file.

## [1.4.0] - 2026-02-04

### Added
- **Multi-language localization support**: Plugin now automatically detects and uses the system language using Adobe ZStrings localization system
- **Supported languages**: English, Italian, German, Spanish, French
- **TranslationProvider module**: New centralized translation system for all user-facing strings
- **TranslatedStrings folder**: Contains translation files for all supported languages

### Changed
- All user interface text in Plugin Manager, Export Dialog, and progress messages are now localized
- Updated version number to 1.4.0
- Documentation updated to reflect multi-language support

## [1.3.0] - 2026-02-04

### Added
- **Logging Settings**: New configurable log level (Debug, Info, Warning, Error only) in Plugin Manager
- **Enhanced diagnostics**: Improved logging throughout the plugin for better troubleshooting

### Changed
- Streamlined Plugin Manager UI organization
- Improved error messages for better user guidance

## [1.2.7] - 2026-02-04

### Fixed
- **Band and Frame colors not applied correctly**: Replaced problematic color_well widget with direct RGB input fields. Colors are now specified using three numeric fields (R, G, B) with values from 0-255, which provides reliable and predictable color selection.

### Changed
- **UI Redesign**: Band Color and Frame Color are now set using separate R, G, B input fields instead of a color picker widget
  - Default Band Color: White (R=255, G=255, B=255)
  - Default Frame Color: Black (R=0, G=0, B=0)
- Simplified color handling in ImageProcessor - no more complex LrColor parsing needed

## [1.2.6] - Previous Release

### Added
- **ImageMagick detection improvements**: Enhanced path detection for macOS (Homebrew on Apple Silicon and Intel, MacPorts)
- **Plugin Manager status display**: ImageMagick availability status shown in Plugin Manager with version and location info
- **Test ImageMagick button**: Verify ImageMagick installation directly from Plugin Manager
- **Enhanced error messages**: Platform-specific installation instructions when ImageMagick is not found

### Changed
- Improved ImageMagick command path resolution for cross-platform compatibility
- Better fallback handling when ImageMagick is not available

## [1.2.0] - Previous Release

### Added
- **Short side size presets**: 1080px, 2160px (2x), 3240px (3x), 4320px (4x), and Custom
- **Calculated tile size display**: Read-only display showing resulting tile dimensions
- **Open export folder option**: Optionally open the export folder after export completes

### Changed
- Improved tile dimension calculation based on aspect ratio and short side size
- Reorganized export dialog for better user experience

## [1.1.0] - Initial Release

### Features
- **Instagram-optimized export**: Multiple aspect ratio presets (4:5, 1:1, 5:4, 16:9, 9:16) perfect for Instagram
- **Seamless carousel mode**: Automatically splits panoramic photos into multiple edge-to-edge seamless tiles
- **Smart overflow handling**: Choose to add bands with optional frame or crop to fit perfectly
- **Customizable background and frame colors**: Full control over styling
- **Multiple format support**: JPEG, TIFF, and PNG export formats
- **Color space options**: sRGB and Adobe RGB support

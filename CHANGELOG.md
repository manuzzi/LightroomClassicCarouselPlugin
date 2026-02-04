# Changelog

All notable changes to the Instagram Carousel Generator plugin will be documented in this file.

## [1.2.7] - 2026-02-04

### Fixed
- **Band and Frame colors not applied correctly**: Replaced problematic color_well widget with direct RGB input fields. Colors are now specified using three numeric fields (R, G, B) with values from 0-255, which provides reliable and predictable color selection.

### Changed
- **UI Redesign**: Band Color and Frame Color are now set using separate R, G, B input fields instead of a color picker widget
  - Default Band Color: White (R=255, G=255, B=255)
  - Default Frame Color: Black (R=0, G=0, B=0)
- Simplified color handling in ImageProcessor - no more complex LrColor parsing needed

## [1.2.6] - Previous Release

### Features
- ImageMagick detection improvements
- Plugin Manager status display for ImageMagick availability
- Enhanced error messages with platform-specific installation instructions

## [1.1.0] - Initial Release

### Features
- Instagram-optimized export with multiple aspect ratio presets (4:5, 1:1, 5:4, 16:9, 9:16)
- Seamless carousel mode for splitting panoramic photos into edge-to-edge tiles
- Smart overflow handling with bands or crop options
- Customizable background and frame colors
- Support for JPEG, TIFF, and PNG export formats
- sRGB and Adobe RGB color space options

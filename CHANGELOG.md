# Changelog

All notable changes to the Instagram Carousel Generator plugin will be documented in this file.

## [1.2.7] - 2026-02-04

### Fixed
- **Band and Frame colors not applied correctly from color wheel**: Fixed color value extraction to properly handle LrColor objects returned by Lightroom's color_well widget. The color picker now correctly applies the selected colors for bands and frames when processing images.

### Changed
- Updated color handling to support both LrColor objects (with method-based access like `red()`, `green()`, `blue()`) and plain table formats (with property access like `r`, `g`, `b` or `red`, `green`, `blue`).

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

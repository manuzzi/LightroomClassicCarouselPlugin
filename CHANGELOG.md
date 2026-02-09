# Changelog

All notable changes to the Instagram Carousel Generator plugin will be documented in this file.

## [1.5.2] - 2026-02-09

### Added
- Plugin icon placed in the Resources directory
- Plugin icon displayed in the README, About dialog, and Plugin Manager
- `LrPluginIcon` property in Info.lua for native Lightroom plugin icon support

### Changed
- About dialog now uses a custom modal with the plugin icon
- Plugin Manager header uses the new plugin icon

## [1.5.0] - 2026-02-05

### Added
- Update check feature in Plugin Manager
  - Automatic version comparison with GitHub releases
  - "Check for Updates" button to manually check for new versions
  - "Download Latest" button to open the latest release page
  - Status display showing current version and update availability
  - Persistent storage of last check time and latest version information
  - Cross-platform support (macOS and Windows)

## [1.4.0] - 2026-02-05

### Added
- Reintroduced `color_well` pickers for Band and Frame colors.

### Changed
- Greyed out RGB fields to prevent manual edits when using the color picker.
- Hid or disabled Band & Frame settings when Crop mode is selected.
- Refactored helper logic with `roundToInt` for maintainability.

### Updated
- Funding metadata.

## [1.3.0] - 2026-02-04

### Added
- Plugin logo.
- ImageMagick software credits with Apache 2.0 license link.

### Changed
- Updated the plugin admin panel with credits, donation info, license, logo, and version.

## [1.2.7] - 2026-02-04

### Fixed
- Band and Frame color application when using the color wheel.

### Changed
- Replaced `color_well` with RGB input fields for reliable color selection.
- Refactored duplicate color formatting helpers.

### Updated
- Added PayPal donation link in the README.
- Ignored macOS `.DS_Store` files.

## [1.2.6] - 2026-02-04

### Added
- Original filename appended to tile names.

### Changed
- UI improvements: hide Video panel, rearranged Band settings, and disabled controls when Seamless mode is off.
- Improved label clarity (Band Color, Frame Size).

### Fixed
- Frame color parsing for `r/g/b` and `red/green/blue` formats.
- Background color logging with safe access checks.
- ImageMagick location detection issues.

### Removed
- Redundant `baseName` assignment.

## [1.2.3] - 2026-02-04

### Fixed
- Crop mode and frame application order.

### Changed
- Improved rounding clarity in tile count calculation.

## [1.2.2] - 2026-02-04

### Added
- Ratio-based tile splitting.
- Short-side size options.
- Open export folder option.

### Fixed
- Crop mode behavior.
- Band positioning.
- Frame color error.
- Progress bar updates.

## [1.2.0] - 2026-02-04

### Added
- Initial tagged release.

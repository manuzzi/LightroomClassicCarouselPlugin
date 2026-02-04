# ImageMagick Detection Fix - Implementation Summary

## Problem Statement

Users were receiving error messages stating ImageMagick was not installed, but the actual root cause was that:
- On macOS, Lightroom doesn't inherit the user's shell PATH
- Homebrew installs ImageMagick to `/opt/homebrew/bin` (Apple Silicon) or `/usr/local/bin` (Intel)
- The plugin was looking for `convert` command which may not be in the PATH that Lightroom sees
- No way to bundle ImageMagick binaries with the plugin

## Solution Overview (Version 1.2.0)

### 1. Bundled Binary Support

**New Feature:** The plugin now supports bundled ImageMagick binaries in the `bin/` folder.

**Directory Structure:**
```
InstagramCarouselGenerator.lrplugin/
├── bin/
│   ├── mac/
│   │   └── magick         # macOS ImageMagick binary
│   └── win/
│       └── magick.exe     # Windows ImageMagick binary
```

**Benefits:**
- Self-contained plugin with no external dependencies
- Works regardless of system PATH configuration
- Consistent behavior across all installations

### 2. Smart Binary Detection

The plugin now searches for ImageMagick in the following order:

1. **Bundled Binary** (highest priority)
   - Windows: `{plugin}/bin/win/magick.exe`
   - macOS: `{plugin}/bin/mac/magick`

2. **System Paths** (fallback for macOS)
   - `/opt/homebrew/bin/magick` (Apple Silicon Homebrew)
   - `/usr/local/bin/magick` (Intel Homebrew)
   - `/opt/local/bin/magick` (MacPorts)
   - System PATH

3. **Windows System PATH** (fallback for Windows)
   - `magick` command in PATH

### 3. Unified ImageMagick 7 Commands

**Change:** All commands now use the ImageMagick 7 `magick` command instead of legacy `convert`.

**Reason:** ImageMagick 7 uses `magick` as the main command, with `convert`, `identify`, etc. as subcommands. This provides:
- Forward compatibility with newer ImageMagick versions
- Consistent command syntax across platforms
- Better support for bundled portable binaries

### 4. Enhanced Plugin Manager Display

The ImageMagick Status section now shows:
- Whether ImageMagick is installed
- Version number
- **Source:** Whether using bundled binary or system installation
- Platform-specific installation instructions when not found

## Technical Details

### Path Detection Logic

```lua
function getWorkingMagickPath()
    -- 1. Check bundled binary first
    local bundledPath = getBundledMagickPath()
    if bundledPath and binaryWorks(bundledPath) then
        return bundledPath
    end
    
    -- 2. Check system paths (macOS)
    local paths = {
        "/opt/homebrew/bin/magick",  -- Apple Silicon
        "/usr/local/bin/magick",      -- Intel Homebrew
        "/opt/local/bin/magick",      -- MacPorts
        "magick"                      -- System PATH
    }
    
    -- Test each path and return first working one
    ...
end
```

### Caching

Binary path detection results are cached to avoid repeated file system checks during a session.

### Shell Escaping

All paths and arguments are properly escaped for both Windows and Unix shells to prevent command injection.

## Files Modified

1. **ImageProcessor.lua** (major refactor)
   - Added `getBundledMagickPath()` function
   - Added `getWorkingMagickPath()` function
   - Updated all ImageMagick commands to use detected path
   - Changed from `convert`/`identify` to `magick` command
   - Added path caching

2. **PluginInfoProvider.lua**
   - Added bundled binary detection
   - Added system path checking with multiple locations
   - Updated UI to show source of ImageMagick binary
   - Updated version to 1.2.0

3. **Info.lua**
   - Updated version to 1.2.0

4. **README.md**
   - Added documentation for bundled binaries
   - Updated plugin structure diagram
   - Added installation instructions for both options

5. **bin/mac/README.txt** (new)
   - Instructions for obtaining macOS binary

6. **bin/win/README.txt** (new)
   - Instructions for obtaining Windows binary

## Testing

### With Bundled Binaries

1. Place ImageMagick binary in appropriate `bin/` folder
2. Open Plugin Manager → Status shows "✓ Installed", Source: "Bundled with plugin"
3. Export with seamless mode → Image splits correctly

### Without Bundled Binaries (System Fallback)

1. Ensure `bin/` folders have only README files
2. Install ImageMagick via Homebrew/system
3. Open Plugin Manager → Status shows "✓ Installed", Source: "/opt/homebrew/bin/magick"
4. Export with seamless mode → Image splits correctly

### Without Any ImageMagick

1. Remove bundled binaries
2. Uninstall system ImageMagick
3. Open Plugin Manager → Status shows "✗ Not Installed"
4. Export with seamless mode → Shows warning, exports single image

## Obtaining Binaries

### macOS
```bash
# Install via Homebrew
brew install imagemagick

# Copy to plugin
cp /opt/homebrew/bin/magick /path/to/plugin/bin/mac/
chmod +x /path/to/plugin/bin/mac/magick
```

### Windows
1. Download portable version from https://imagemagick.org
2. Extract and copy `magick.exe` to `bin/win/`

## Security Considerations

- Shell arguments are properly escaped
- Bundled binaries should be from trusted sources only
- Path checking uses absolute paths when possible
- Error output is captured and logged, not displayed to users

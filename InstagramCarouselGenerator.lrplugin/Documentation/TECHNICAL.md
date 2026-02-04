# Instagram Carousel Export - Technical Flow

## Export Process Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        User Selects Photo(s)                         │
│                     in Lightroom Library Module                      │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      File > Export Dialog                            │
│            Select "Instagram Carousel" Export Service                │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Configure Export Settings                         │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ 1. Aspect Ratio Selection                                  │    │
│  │    • 4:5, 1:1, 5:4, 16:9, 9:16, or Custom                 │    │
│  │                                                             │    │
│  │ 2. Seamless Carousel Mode                                  │    │
│  │    ☑ Enable splitting for panoramas                       │    │
│  │                                                             │    │
│  │ 3. Overflow Handling (if seamless mode enabled)           │    │
│  │    ○ Add bands with optional frame                        │    │
│  │    ○ Crop to fit perfectly                                │    │
│  │                                                             │    │
│  │ 4. Band & Frame Settings (if "add bands" selected)        │    │
│  │    • Background Color: [Color Picker]                     │    │
│  │    ☑ Enable Frame                                         │    │
│  │    • Frame Color: [Color Picker]                          │    │
│  │    • Frame Size: [1-100] px                               │    │
│  └────────────────────────────────────────────────────────────┘    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 Click "Export" Button                                │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│    InstagramCarouselExportServiceProvider.processRenderedPhotos()   │
│                                                                       │
│  For each photo:                                                     │
│  1. Lightroom renders photo to temporary location                   │
│  2. Check if seamless mode enabled                                  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
          Seamless Mode OFF      Seamless Mode ON
                    │                     │
                    ▼                     ▼
       ┌──────────────────────┐  ┌────────────────────────────────────┐
       │  Export as Single    │  │   ImageProcessor.splitImageIntoTiles│
       │  Image               │  │                                     │
       │                      │  │  1. Get image dimensions            │
       │  Done ✓              │  │  2. Calculate number of tiles       │
       └──────────────────────┘  │  3. Check overflow                  │
                                 └──────────┬──────────────────────────┘
                                            │
                                            ▼
                            ┌───────────────────────────────┐
                            │  Overflow Handling Decision   │
                            └───────────┬───────────────────┘
                                        │
                            ┌───────────┴───────────┐
                            │                       │
                     Add Bands Mode         Crop Mode
                            │                       │
                            ▼                       ▼
              ┌───────────────────────┐   ┌─────────────────────┐
              │ ImageMagick Command:  │   │ ImageMagick Command:│
              │                       │   │                     │
              │ 1. Extend canvas with │   │ 1. Crop image to    │
              │    background color   │   │    fit tile width   │
              │ 2. Center image       │   │    exactly          │
              │ 3. Add border (frame) │   │ 2. Split into tiles │
              │    if enabled         │   │                     │
              │ 4. Split into tiles   │   │                     │
              └───────────┬───────────┘   └──────────┬──────────┘
                          │                          │
                          └──────────┬───────────────┘
                                     │
                                     ▼
                   ┌──────────────────────────────────────┐
                   │  Generate Tiles                      │
                   │                                      │
                   │  tile_0.jpg, tile_1.jpg, ...        │
                   │                                      │
                   │  Saved to:                           │
                   │  [export_dir]/[filename]_carousel/   │
                   └──────────────┬───────────────────────┘
                                  │
                                  ▼
                   ┌──────────────────────────────────────┐
                   │  Delete Original Single Export       │
                   │  (replaced by carousel tiles)        │
                   └──────────────┬───────────────────────┘
                                  │
                                  ▼
                   ┌──────────────────────────────────────┐
                   │         Export Complete ✓            │
                   │                                      │
                   │  User can now upload tiles to        │
                   │  Instagram in sequence               │
                   └──────────────────────────────────────┘
```

## ImageProcessor Module Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ImageProcessor.lua                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Constants:                                                           │
│  • TILE_NAME_PATTERN = "tile_%d.jpg"                                │
│  • Platform-specific patterns for Windows/Unix                       │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Security Functions:                                                  │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ escapeShellArg(arg)                                          │   │
│  │ • Prevents command injection                                │   │
│  │ • Platform-specific escaping                                │   │
│  │ • Windows: Escape quotes, wrap in quotes                    │   │
│  │ • Unix: Use single quotes, escape single quotes             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Image Analysis:                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ getImageDimensions(imagePath)                                │   │
│  │ • Uses ImageMagick's 'identify' command                     │   │
│  │ • Returns width, height                                      │   │
│  │ • Secure: Uses escapeShellArg()                             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Main Processing:                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ splitImageIntoTiles(sourcePath, outputDir, tileW, tileH,    │   │
│  │                     params)                                  │   │
│  │                                                              │   │
│  │ 1. Get source image dimensions                              │   │
│  │ 2. Calculate number of tiles needed                         │   │
│  │ 3. Check for overflow                                       │   │
│  │ 4. Call splitWithImageMagick()                              │   │
│  │ 5. Collect generated tile paths                             │   │
│  │ 6. Return array of tile paths                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ImageMagick Integration:                                             │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ splitWithImageMagick(sourcePath, outputDir, tileW, tileH,   │   │
│  │                      numTiles, params)                       │   │
│  │                                                              │   │
│  │ Input Validation:                                            │   │
│  │ • Clamp color values to [0, 1]                              │   │
│  │ • Clamp frame size to [1, 100]                              │   │
│  │                                                              │   │
│  │ Command Construction:                                        │   │
│  │ • Platform detection (WIN_ENV)                              │   │
│  │ • Secure argument escaping                                  │   │
│  │ • Background color: rgb(r,g,b)                              │   │
│  │ • Frame: -bordercolor + -border                             │   │
│  │ • Extent: Centers and pads image                            │   │
│  │ • Crop: Splits into tiles                                   │   │
│  │                                                              │   │
│  │ Execution:                                                   │   │
│  │ • Uses io.popen() for command execution                     │   │
│  │ • Captures stdout/stderr                                    │   │
│  │ • Returns success/failure status                            │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Tile Calculation Examples

### Example 1: Perfect Division
```
Input:
  Image: 4320 × 1080 px
  Tile:  1080 × 1080 px

Calculation:
  Tiles needed = ⌈4320 / 1080⌉ = 4
  Total width = 4 × 1080 = 4320 px
  Overflow = 4320 - 4320 = 0 px

Result:
  ┌─────┬─────┬─────┬─────┐
  │  1  │  2  │  3  │  4  │  4 perfect tiles
  └─────┴─────┴─────┴─────┘
```

### Example 2: With Overflow (Add Bands)
```
Input:
  Image: 5000 × 1080 px
  Tile:  1080 × 1080 px

Calculation:
  Tiles needed = ⌈5000 / 1080⌉ = 5
  Total width = 5 × 1080 = 5400 px
  Overflow = 5400 - 5000 = 400 px
  Bands = 400 / 2 = 200 px each side

Result (Add Bands):
  ┌───┬─────┬─────┬─────┬─────┬─────┬───┐
  │200│  1  │  2  │  3  │  4  │  5  │200│
  │ B │     │     │     │     │     │ B │  5 tiles with bands
  └───┴─────┴─────┴─────┴─────┴─────┴───┘
  B = Band (background color)
```

### Example 3: With Overflow (Crop)
```
Input:
  Image: 5000 × 1080 px
  Tile:  1080 × 1080 px

Calculation:
  Tiles needed = ⌊5000 / 1080⌋ = 4
  Total width = 4 × 1080 = 4320 px
  Cropped = 5000 - 4320 = 680 px removed

Result (Crop):
  ┌─────┬─────┬─────┬─────┐
  │  1  │  2  │  3  │  4  │  4 perfect tiles
  └─────┴─────┴─────┴─────┘
  680px cropped from right side
```

## Security Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Security Layers                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Layer 1: Input Validation                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ • Color values clamped to [0, 1]                            │   │
│  │ • Frame size clamped to [1, 100]                            │   │
│  │ • Tile dimensions validated by Lightroom                    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  Layer 2: Command Injection Prevention                               │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ • All file paths escaped via escapeShellArg()              │   │
│  │ • Platform-specific escaping (Windows/Unix)                │   │
│  │ • No raw string concatenation in commands                  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  Layer 3: Resource Protection                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ • Frame size limited to prevent excessive memory use       │   │
│  │ • Tile count naturally limited by image dimensions         │   │
│  │ • ImageMagick execution in controlled environment          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  Layer 4: Error Handling                                             │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ • LrTasks.pcall() wraps all external command execution    │   │
│  │ • Graceful fallback when ImageMagick unavailable          │   │
│  │ • User-friendly error messages                             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

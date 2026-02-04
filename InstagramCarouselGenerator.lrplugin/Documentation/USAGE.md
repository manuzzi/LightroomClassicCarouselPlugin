# Instagram Carousel Export - Usage Examples

## Overview

The Instagram Carousel Generator plugin now supports advanced image splitting and formatting for Instagram carousel posts. This document provides examples of how to use the new features.

## Basic Export Workflow

### 1. Standard Square Export (1:1)

Perfect for standard Instagram posts:
1. Select your photo in Lightroom
2. Go to File > Export
3. Choose "Instagram Carousel" as the export service
4. Select aspect ratio: "1:1 (Square)"
5. Frame size will automatically be set to 1080x1080px
6. Click Export

### 2. Portrait Export (4:5)

Ideal for vertical photos:
1. Follow steps 1-3 above
2. Select aspect ratio: "4:5 (Portrait)"
3. Frame size will automatically be set to 1080x1350px
4. Click Export

### 3. Landscape Export (5:4)

Great for landscape photos:
1. Follow steps 1-3 above
2. Select aspect ratio: "5:4 (Landscape)"
3. Frame size will automatically be set to 1350x1080px
4. Click Export

## Panoramic Photo Splitting

### Seamless Carousel Mode

When you have a wide panoramic photo that you want to split into multiple Instagram posts that form a seamless carousel:

1. Select your panoramic photo
2. Go to File > Export
3. Choose "Instagram Carousel"
4. Select your desired aspect ratio (e.g., "1:1 (Square)")
5. **Check "Enable Seamless Carousel Mode (split panoramas)"**
6. Choose overflow handling method (see below)
7. Click Export

The plugin will:
- Calculate how many tiles are needed to fit your panorama
- Split the image into edge-to-edge seamless tiles
- Save tiles in a subfolder named "[original_filename]_carousel"
- Each tile will be ready to upload to Instagram

### Overflow Handling Options

When your panoramic image doesn't divide evenly into the frame size:

#### Option 1: Add Bands with Optional Frame

This option centers your image and adds colored bands to fill the remaining space:

1. Select "Add bands with optional frame" radio button
2. Choose a background color (default: white)
   - Click the color well to choose any color
3. Optionally enable frame:
   - Check "Enable Frame"
   - Choose frame color (default: black)
   - Set frame size in pixels (default: 10px)
4. Click Export

**Example Use Case:**
- Panorama is 5000px wide, tiles are 1080px each
- 5 tiles will be created (5 × 1080 = 5400px)
- The last 400px will be filled with white bands on top and bottom
- A black frame can be added for aesthetic effect

#### Option 2: Crop to Fit Perfectly

This option crops the top and bottom of your panorama to fit perfectly:

1. Select "Crop to fit perfectly" radio button
2. Click Export

**Example Use Case:**
- Panorama is 5000px wide, tiles are 1080px each
- Image will be cropped to 4320px (4 × 1080)
- The rightmost 680px will be removed
- All 4 tiles will have edge-to-edge content

## Custom Aspect Ratios

For non-standard Instagram sizes or custom projects:

1. Select aspect ratio: "Custom"
2. Enter your desired width and height in pixels
3. Minimum: 100px, Maximum: 4096px
4. Both width and height fields will become editable
5. Configure other settings as desired
6. Click Export

## Requirements

### ImageMagick Installation

For seamless carousel mode (image splitting) to work, ImageMagick must be installed:

**macOS:**
```bash
brew install imagemagick
```

**Windows:**
1. Download from https://imagemagick.org
2. Run the installer
3. Ensure "Add to PATH" is checked during installation

**Verification:**
Open Terminal (macOS) or Command Prompt (Windows) and run:
```bash
convert -version    # macOS/Linux
magick -version     # Windows
```

### What Happens Without ImageMagick?

If ImageMagick is not installed:
- Photos will be exported as single images
- No splitting will occur
- You'll see a warning message with installation instructions
- The original export will still complete successfully

## Tips and Best Practices

### 1. Choosing the Right Aspect Ratio

- **1:1 (Square)**: Universal, works everywhere on Instagram
- **4:5 (Portrait)**: Takes up more vertical space in feed
- **16:9 (Wide)**: Great for landscape panoramas
- **9:16 (Vertical)**: Story-style format for feed posts

### 2. When to Use Seamless Mode

- Wide panoramic landscapes
- Multi-image storytelling sequences
- Before/after comparisons that span multiple posts
- Architectural photography that needs full width

### 3. Choosing Overflow Handling

**Use "Add Bands":**
- When you want to preserve all image content
- For artistic effect with frames
- When the background color complements your image

**Use "Crop":**
- When edge-to-edge is more important than preserving all content
- For pure panoramic landscapes
- When you want maximum impact without borders

### 4. Frame Styling

- White background + black frame = classic look
- Match background to dominant image color = cohesive feel
- Thin frames (5-10px) = subtle
- Thick frames (20-50px) = bold statement

## Troubleshooting

### Problem: Images not splitting

**Solution:** Install ImageMagick (see Requirements section)

### Problem: Wrong number of tiles created

**Check:**
- Your original image dimensions
- Selected tile size
- Make sure the panorama is wide enough to warrant multiple tiles

### Problem: Colors look wrong in bands/frames

**Check:**
- Color values in the color wells
- Export color space settings (should be sRGB for Instagram)

### Problem: Export takes a long time

**This is normal for:**
- Large panoramic images (10000+ pixels wide)
- High-resolution exports
- Multiple photos in batch export

## Examples of Tile Calculations

### Example 1: Perfect Division
- Panorama: 4320px × 1080px
- Tile size: 1080px × 1080px
- Result: 4 tiles exactly (4320 ÷ 1080 = 4)
- No overflow handling needed

### Example 2: With Overflow
- Panorama: 5000px × 1080px
- Tile size: 1080px × 1080px
- Result: 5 tiles (5000 ÷ 1080 = 4.63, rounded up to 5)
- Overflow: 400px needed (5 × 1080 - 5000 = 400px)
- Options:
  - Add bands: Image centered, 200px bands on each side
  - Crop: Image reduced to 4320px width (loses 680px)

### Example 3: Portrait Tiles
- Panorama: 3000px × 1350px
- Tile size: 1080px × 1350px (4:5 ratio)
- Result: 3 tiles (3000 ÷ 1080 = 2.78, rounded up to 3)
- Overflow: 240px needed
- Options:
  - Add bands: Image centered, 120px bands on each side
  - Crop: Image reduced to 2160px width

## Support

For issues or questions:
- GitHub: https://github.com/manuzzi/LightroomClassicCarouselPlugin/issues
- Ensure you have the latest version (1.1.0 or higher)
- Check that ImageMagick is properly installed for splitting features

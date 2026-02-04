ImageMagick macOS Binaries
==========================

This folder should contain the ImageMagick binaries for macOS.

Required file:
- magick (ImageMagick 7.x universal binary)

To obtain this file:
1. Install ImageMagick via Homebrew: brew install imagemagick
2. Copy the magick binary to this folder:
   - For Apple Silicon: cp /opt/homebrew/bin/magick ./
   - For Intel Macs: cp /usr/local/bin/magick ./
3. The binary may need to have execute permissions: chmod +x magick

Alternatively, you can build a universal binary or include both architectures.

The plugin will automatically use this bundled binary instead of requiring
users to install ImageMagick system-wide.

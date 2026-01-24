#!/bin/bash

# App Icon Generator for macOS
# Converts SVG or resizes a 1024x1024 PNG to all required icon sizes

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Required sizes for macOS app icons (size@scale = actual pixels)
declare -a SIZES=(
    "16:1:16"      # 16x16 @1x
    "16:2:32"      # 16x16 @2x
    "32:1:32"      # 32x32 @1x
    "32:2:64"      # 32x32 @2x
    "128:1:128"    # 128x128 @1x
    "128:2:256"    # 128x128 @2x
    "256:1:256"    # 256x256 @1x
    "256:2:512"    # 256x256 @2x
    "512:1:512"    # 512x512 @1x
    "512:2:1024"   # 512x512 @2x
)

# Check if we have a source image
SVG_FILE="AppIcon.svg"
PNG_SOURCE="AppIcon_1024.png"

convert_svg_to_png() {
    local svg="$1"
    local png="$2"
    local size="$3"

    # Try rsvg-convert first (best quality)
    if command -v rsvg-convert &> /dev/null; then
        rsvg-convert -w "$size" -h "$size" "$svg" -o "$png"
        return $?
    fi

    # Try Inkscape
    if command -v inkscape &> /dev/null; then
        inkscape -w "$size" -h "$size" "$svg" -o "$png" 2>/dev/null
        return $?
    fi

    # Try ImageMagick convert
    if command -v convert &> /dev/null; then
        convert -background none -density 300 -resize "${size}x${size}" "$svg" "$png"
        return $?
    fi

    return 1
}

resize_png() {
    local source="$1"
    local dest="$2"
    local size="$3"

    sips -z "$size" "$size" "$source" --out "$dest" &> /dev/null
    return $?
}

# Generate icons from SVG
generate_from_svg() {
    echo "Generating icons from SVG..."

    # First create a high-res PNG from SVG
    if ! convert_svg_to_png "$SVG_FILE" "$PNG_SOURCE" 1024; then
        echo "Error: Could not convert SVG. Install one of these tools:"
        echo "  brew install librsvg    (recommended)"
        echo "  brew install inkscape"
        echo "  brew install imagemagick"
        return 1
    fi

    echo "Created 1024x1024 source PNG"
    generate_from_png
}

# Generate icons from existing 1024x1024 PNG
generate_from_png() {
    if [ ! -f "$PNG_SOURCE" ]; then
        echo "Error: $PNG_SOURCE not found"
        return 1
    fi

    echo "Generating icon sizes from PNG..."

    for size_spec in "${SIZES[@]}"; do
        IFS=':' read -r size scale pixels <<< "$size_spec"

        if [ "$scale" == "1" ]; then
            filename="icon_${size}x${size}.png"
        else
            filename="icon_${size}x${size}@2x.png"
        fi

        resize_png "$PNG_SOURCE" "$filename" "$pixels"
        echo "  Created $filename (${pixels}x${pixels})"
    done

    update_contents_json
    echo "Done! Icons generated successfully."
}

# Update Contents.json with filenames
update_contents_json() {
    cat > Contents.json << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
    echo "  Updated Contents.json"
}

# Main logic
if [ -f "$SVG_FILE" ]; then
    generate_from_svg
elif [ -f "$PNG_SOURCE" ]; then
    generate_from_png
else
    echo "Usage: Place either AppIcon.svg or AppIcon_1024.png in this directory"
    echo "Then run this script to generate all icon sizes."
    exit 1
fi

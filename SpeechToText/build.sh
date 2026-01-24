#!/bin/bash

# Build script for SpeechToText - Personal Use
# Creates a release .app bundle without code signing

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="SpeechToText"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="$PROJECT_NAME.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "  Building $PROJECT_NAME for personal use"
echo "========================================"
echo ""

# Clean previous build
echo -e "${YELLOW}Cleaning previous build...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build using xcodebuild
echo -e "${YELLOW}Building release configuration...${NC}"
xcodebuild -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    build

# Find and copy the built app
BUILT_APP=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME" -type d | head -1)

if [ -z "$BUILT_APP" ]; then
    echo -e "${RED}Error: Could not find built app${NC}"
    exit 1
fi

# Copy to build directory
cp -R "$BUILT_APP" "$BUILD_DIR/$APP_NAME"

echo ""
echo -e "${GREEN}========================================"
echo "  Build Complete!"
echo "========================================${NC}"
echo ""
echo "App location: $BUILD_DIR/$APP_NAME"
echo ""
echo "To install to Applications folder, run:"
echo "  cp -R \"$BUILD_DIR/$APP_NAME\" /Applications/"
echo ""
echo "Or run directly:"
echo "  open \"$BUILD_DIR/$APP_NAME\""
echo ""

# Ask if user wants to copy to Applications
read -p "Copy to /Applications now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Remove existing version if present
    if [ -d "/Applications/$APP_NAME" ]; then
        echo "Removing existing version..."
        rm -rf "/Applications/$APP_NAME"
    fi
    cp -R "$BUILD_DIR/$APP_NAME" /Applications/
    echo -e "${GREEN}Installed to /Applications/$APP_NAME${NC}"
    echo ""
    echo "You can now launch it from Spotlight or run:"
    echo "  open /Applications/$APP_NAME"
fi

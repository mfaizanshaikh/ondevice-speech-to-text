#!/bin/bash

# Build script for SpeechToText - Personal Use
# Creates a release .app bundle with adhoc signing and proper entitlements

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="SpeechToText"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="$PROJECT_NAME.app"
ENTITLEMENTS="$PROJECT_DIR/$PROJECT_NAME/$PROJECT_NAME.entitlements"

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
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
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

# Re-sign the app with entitlements for proper permission handling
echo -e "${YELLOW}Signing app with entitlements...${NC}"
if [ -f "$ENTITLEMENTS" ]; then
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$BUILD_DIR/$APP_NAME"
    echo -e "${GREEN}App signed with entitlements${NC}"

    # Verify the signature
    echo -e "${YELLOW}Verifying signature...${NC}"
    codesign -dv --entitlements - "$BUILD_DIR/$APP_NAME" 2>&1 | head -20
else
    echo -e "${RED}Warning: Entitlements file not found at $ENTITLEMENTS${NC}"
    echo -e "${RED}App will not have proper microphone/accessibility permissions${NC}"
fi

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
    echo -e "${YELLOW}IMPORTANT: If you previously granted permissions to an older build:${NC}"
    echo "  1. Open System Settings > Privacy & Security > Microphone"
    echo "  2. Remove SpeechToText from the list (click -, then remove)"
    echo "  3. Do the same for Accessibility"
    echo "  4. Launch the app and grant permissions again"
    echo ""
    echo "You can now launch it from Spotlight or run:"
    echo "  open /Applications/$APP_NAME"
fi

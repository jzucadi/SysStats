#!/bin/bash

# SysStats DMG Packaging Script
# Creates a distributable DMG file from the built application

set -e

# Configuration
APP_NAME="SysStats"
BUNDLE_ID="com.example.SysStats"
VERSION="${1:-1.0}"
BUILD_DIR="${2:-build/Release}"
OUTPUT_DIR="${3:-dist}"
DMG_NAME="${APP_NAME}-${VERSION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SysStats DMG Packaging Script ===${NC}"
echo "Version: ${VERSION}"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project directory
cd "$PROJECT_DIR"

# Check if app exists
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${YELLOW}App not found at ${APP_PATH}${NC}"
    echo "Building Release configuration..."

    # Try to build with xcodebuild
    if command -v xcodebuild &> /dev/null; then
        xcodebuild -scheme "$APP_NAME" -configuration Release -derivedDataPath build clean build
        APP_PATH="build/Build/Products/Release/${APP_NAME}.app"
    else
        echo -e "${RED}Error: xcodebuild not available. Please build in Xcode first:${NC}"
        echo "  1. Open SysStats.xcodeproj in Xcode"
        echo "  2. Select Product > Archive (or Product > Build for Release)"
        echo "  3. Export the app to ${BUILD_DIR}/"
        exit 1
    fi
fi

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Could not find ${APP_NAME}.app${NC}"
    echo "Please build the app first in Xcode (Product > Build)"
    exit 1
fi

echo -e "${GREEN}Found app at: ${APP_PATH}${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create temporary directory for DMG contents
TMP_DIR=$(mktemp -d)
DMG_CONTENTS="${TMP_DIR}/dmg"
mkdir -p "$DMG_CONTENTS"

echo "Preparing DMG contents..."

# Copy app to temporary directory
cp -R "$APP_PATH" "$DMG_CONTENTS/"

# Create symbolic link to Applications folder
ln -s /Applications "$DMG_CONTENTS/Applications"

# Create DMG
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"
TMP_DMG="${TMP_DIR}/${DMG_NAME}-temp.dmg"

echo "Creating DMG..."

# Remove existing DMG if present
rm -f "$DMG_PATH"

# Create DMG using hdiutil
hdiutil create -srcfolder "$DMG_CONTENTS" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    "$TMP_DMG"

# Mount the DMG
echo "Configuring DMG appearance..."
MOUNT_DIR="/Volumes/${APP_NAME}"

# Unmount if already mounted
if [ -d "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" -quiet || true
fi

hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR"

# Set DMG window appearance using AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 900, 400}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 72
        set position of item "${APP_NAME}.app" of container window to {125, 150}
        set position of item "Applications" of container window to {375, 150}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Sync and unmount
sync
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
echo "Compressing DMG..."
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

# Clean up
rm -rf "$TMP_DIR"

# Calculate checksum
echo ""
echo -e "${GREEN}=== DMG Created Successfully ===${NC}"
echo "Output: ${DMG_PATH}"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "SHA-256 Checksum:"
shasum -a 256 "$DMG_PATH"

echo ""
echo -e "${YELLOW}Note: For distribution, you should:${NC}"
echo "  1. Sign the app with a Developer ID certificate"
echo "  2. Notarize the DMG with Apple"
echo ""
echo "To notarize, run:"
echo "  xcrun notarytool submit \"${DMG_PATH}\" --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --password YOUR_APP_SPECIFIC_PASSWORD --wait"

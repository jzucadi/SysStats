#!/bin/bash

# SysStats Release Build Script
# Builds the app in Release configuration and optionally creates a DMG

set -e

# Configuration
APP_NAME="SysStats"
VERSION="${1:-1.0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SysStats Release Build Script ===${NC}"
echo "Version: ${VERSION}"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project directory
cd "$PROJECT_DIR"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found${NC}"
    echo "Please ensure Xcode is installed and run:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/
rm -rf dist/

# Build Release configuration
echo "Building Release configuration..."
xcodebuild -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    clean build

# Check if build succeeded
APP_PATH="build/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Build failed - app not found${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"
echo "App location: ${APP_PATH}"

# Ask about DMG creation
echo ""
read -p "Create DMG for distribution? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Create dist directory
    mkdir -p dist

    # Copy app to dist
    cp -R "$APP_PATH" "dist/"

    # Run DMG creation script
    "$SCRIPT_DIR/create-dmg.sh" "$VERSION" "dist" "dist"
fi

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "Next steps for distribution:"
echo "  1. Sign with Developer ID: codesign --deep --force --verify --verbose --sign \"Developer ID Application: YOUR_NAME\" dist/${APP_NAME}.app"
echo "  2. Create DMG: ./scripts/create-dmg.sh ${VERSION}"
echo "  3. Notarize: xcrun notarytool submit dist/${APP_NAME}-${VERSION}.dmg ..."

#!/bin/bash

set -e

echo "Cleaning previous builds..."
rm -rf build/linux/x64/release/bundle
rm -rf flatpak-bundle
rm -rf build-dir
rm -rf repo
rm -f yantrium.flatpak

echo "Building Flutter app for Linux..."
flutter clean
flutter pub get
flutter build linux --release

echo "Preparing bundle for Flatpak..."
BUNDLE_DIR="build/linux/x64/release/bundle"
FLATPAK_BUNDLE_DIR="flatpak-bundle"

# Clean and create bundle directory
rm -rf "$FLATPAK_BUNDLE_DIR"
mkdir -p "$FLATPAK_BUNDLE_DIR"

# Copy the built bundle
cp -r "$BUNDLE_DIR"/* "$FLATPAK_BUNDLE_DIR/"

# Copy desktop file for URI scheme registration
if [ -f "com.yantrium.yantrium.desktop" ]; then
    cp com.yantrium.yantrium.desktop "$FLATPAK_BUNDLE_DIR/"
fi

# FVP bundles FFmpeg in mdk-sdk-linux.tar.xz, which should be in bundle/lib
if [ -d "$BUNDLE_DIR/lib" ]; then
    echo "FVP libraries (including FFmpeg) should be in bundle/lib"
    ls -la "$BUNDLE_DIR/lib" | head -20 || true
fi

echo "Building Flatpak..."
flatpak-builder --force-clean --repo=repo build-dir com.yantrium.yantrium.json

echo "Building Flatpak bundle..."
flatpak build-bundle repo yantrium.flatpak com.yantrium.yantrium

echo ""
echo "=========================================="
echo "Flatpak bundle created: yantrium.flatpak"
echo "=========================================="
echo ""
echo "To install on any Linux system:"
echo "  1. Install Flatpak (if not already installed):"
echo "     - Fedora: sudo dnf install flatpak"
echo "     - Ubuntu/Debian: sudo apt install flatpak"
echo "     - Arch: sudo pacman -S flatpak"
echo ""
echo "  2. Install the bundle:"
echo "     flatpak install --user yantrium.flatpak"
echo ""
echo "  3. Run the app:"
echo "     flatpak run com.yantrium.yantrium"
echo ""
echo "The bundle is portable and can be distributed to any Linux system!"






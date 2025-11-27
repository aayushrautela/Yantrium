#!/bin/bash

# Build script for torrent-sidecar on multiple platforms
# Run from the sidecar directory

set -e

OUTPUT_DIR="../assets/sidecar"
mkdir -p "$OUTPUT_DIR"

echo "Building torrent-sidecar for multiple platforms..."

# Windows (amd64)
echo "Building for Windows amd64..."
GOOS=windows GOARCH=amd64 go build -ldflags "-s -w" -o "$OUTPUT_DIR/torrent-sidecar-windows-x64.exe" main.go
echo "✓ Windows build complete"

# Linux (amd64) - Static binary for Flatpak compatibility
echo "Building for Linux amd64 (static)..."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o "$OUTPUT_DIR/torrent-sidecar-linux-x64" main.go
echo "✓ Linux build complete"

# macOS (amd64)
echo "Building for macOS amd64..."
GOOS=darwin GOARCH=amd64 go build -ldflags "-s -w" -o "$OUTPUT_DIR/torrent-sidecar-macos-x64" main.go
echo "✓ macOS build complete"

# macOS (arm64) - Apple Silicon
echo "Building for macOS arm64..."
GOOS=darwin GOARCH=arm64 go build -ldflags "-s -w" -o "$OUTPUT_DIR/torrent-sidecar-macos-arm64" main.go
echo "✓ macOS ARM64 build complete"

echo ""
echo "Build complete! Binaries created in $OUTPUT_DIR:"
ls -la "$OUTPUT_DIR"

echo ""
echo "File sizes:"
du -h "$OUTPUT_DIR"/*

echo ""
echo "Verifying static linkage (Linux):"
if command -v ldd >/dev/null 2>&1; then
    echo "Linux binary dependencies:"
    ldd "$OUTPUT_DIR/torrent-sidecar-linux-x64" 2>/dev/null || echo "No dynamic dependencies (static binary)"
else
    echo "ldd not available, skipping dependency check"
fi

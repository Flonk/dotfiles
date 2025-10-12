#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

echo "Building Cava Plugin for Quickshell..."

# Check dependencies
echo "Checking dependencies..."
if ! pkg-config --exists cava; then
    echo "Error: libcava not found. Please install libcava-dev"
    echo "On Arch: sudo pacman -S cava"
    echo "On Ubuntu/Debian: sudo apt install libcava-dev"
    exit 1
fi

if ! pkg-config --exists libpipewire-0.3; then
    echo "Error: pipewire development files not found. Please install libpipewire-dev"
    echo "On Arch: sudo pacman -S pipewire"
    echo "On Ubuntu/Debian: sudo apt install libpipewire-0.3-dev"
    exit 1
fi

echo "Dependencies OK"

# Create and enter build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure and build
echo "Configuring CMake..."
cmake .. -DCMAKE_BUILD_TYPE=Release

echo "Building..."
make -j$(nproc)

echo "Build complete!"
echo ""
echo "Plugin built successfully in: $BUILD_DIR"
echo "To use in your Quickshell config, make sure the build directory is in your QML import path."
echo ""
echo "Example usage in QML:"
echo "import CavaPlugin 1.0"
echo ""
echo "CavaProvider {"
echo "    bars: 20"
echo "    onValuesChanged: {"
echo "        // values is a QVector<double> with spectrum data"
echo "        console.log('Spectrum:', values)"
echo "    }"
echo "}"
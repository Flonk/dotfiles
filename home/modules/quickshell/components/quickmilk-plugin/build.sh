#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

echo "Building Quickmilk audio visualizer for Quickshell..."

# Check dependencies
echo "Checking dependencies..."
if ! pkg-config --exists libpipewire-0.3; then
    echo "Error: pipewire development files not found. Please install libpipewire-dev"
    echo "On Arch: sudo pacman -S pipewire"
    echo "On Ubuntu/Debian: sudo apt install libpipewire-0.3-dev"
    exit 1
fi

if ! pkg-config --exists fftw3; then
    echo "Error: FFTW (fftw3) development files not found."
    echo "On Arch: sudo pacman -S fftw"
    echo "On Ubuntu/Debian: sudo apt install libfftw3-dev"
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
echo "import Quickmilk 1.0"
echo ""
echo "Quickmilk {"
echo "    id: quickmilk"
echo "    maxBars: 40"
echo "    enableMonstercatFilter: true"
echo "}"
echo ""
echo "QuickmilkDataTexture {"
echo "    hub: quickmilk.hub"
echo "    maxBars: 20"
echo "}"
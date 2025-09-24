# Cava Plugin for Quickshell

This is a C++ plugin that provides audio visualization capabilities to Quickshell using libcava.

## Features

- Real-time audio spectrum analysis using libcava
- PipeWire audio capture integration
- QML-exposed CavaProvider component with reactive properties
- Monstercat-style smoothing filter for nice visual effects
- Configurable number of spectrum bars

## Dependencies

### Arch Linux

```bash
sudo pacman -S cava pipewire cmake qt6-declarative
```

### Ubuntu/Debian

```bash
sudo apt install libcava-dev libpipewire-0.3-dev cmake qt6-declarative-dev
```

### NixOS

Add to your flake/configuration:

```nix
buildInputs = with pkgs; [
  libcava
  pipewire.dev
  cmake
  qt6.qtdeclarative
];
```

## Building

```bash
./build.sh
```

This will:

1. Check for required dependencies
2. Configure CMake build
3. Compile the plugin
4. Create the CavaPlugin QML module

## Usage

### Basic Example

```qml
import QtQuick
import CavaPlugin 1.0

Item {
    CavaProvider {
        id: cava
        bars: 20  // Number of spectrum bars

        onValuesChanged: {
            // values is QVector<double> with normalized data (0.0-1.0)
            console.log("Spectrum data:", values)
        }
    }

    // Simple visualizer
    Row {
        Repeater {
            model: cava.values
            Rectangle {
                width: 4
                height: modelData * 50
                color: "#7dc383"
            }
        }
    }
}
```

### Using the CavaDisplay Component

```qml
import QtQuick
// Make sure the build directory is in your QML import path
import "cava-plugin"

Item {
    CavaDisplay {
        barCount: 25
        maxBarHeight: 40
        barColor: "#ff6b6b"
    }
}
```

## Integration with Your Bar

To use in your Quickshell bar, add the build directory to your import path and use the CavaDisplay component:

```qml
// In your Bar.qml
import "cava-plugin"

// Add to your bar layout
Row {
    // ... your other widgets
    CavaDisplay {
        barCount: 20
        maxBarHeight: 20
    }
}
```

## Properties

### CavaProvider

- `bars: int` - Number of spectrum bars (default: 20)
- `values: QVector<double>` - Current spectrum values (0.0-1.0)

### CavaDisplay

- `barCount: int` - Number of bars to display
- `maxBarHeight: int` - Maximum height of bars in pixels
- `barColor: color` - Color of the spectrum bars

## Technical Details

- Uses libcava's core API for FFT analysis
- PipeWire integration for low-latency audio capture
- 60 FPS update rate for smooth animation
- Applies Monstercat-style smoothing filter
- Thread-safe audio buffer management

## Troubleshooting

### Plugin not found

Make sure the build directory is in your QML import path:

```bash
export QML_IMPORT_PATH="/path/to/your/quickshell/components/cava-plugin/build:$QML_IMPORT_PATH"
```

### No audio data

Check that PipeWire is running and audio is playing:

```bash
pw-top  # Shows PipeWire audio streams
```

### Build errors

Ensure all dependencies are installed and check that pkg-config finds them:

```bash
pkg-config --cflags --libs cava libpipewire-0.3
```

## Credits

Based on the audio visualization implementation from [caelestia-dots/shell](https://github.com/caelestia-dots/shell), simplified and adapted for standalone use.

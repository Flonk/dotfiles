# Shader Plugin for Quickshell

This plugin provides GLSL shader support for Quickshell, allowing you to render animated fragment shaders as QML widgets.

## How It Works

1. **Write GLSL shaders** (`.frag` files) using Qt's GLSL dialect
2. **Compile to QSB** (Qt Shader Bytecode) format using Qt's `qsb` tool
3. **Use in QML** via `ShaderEffect` components wrapped in custom widgets

## File Structure

```
shader-plugin/
├── build.sh                       # Manual build script (for testing)
├── qmldir                         # QML module definition
└── shaders/
    ├── cava/                      # Legacy and modern cava-based visualisers
    │   ├── CavaLegacyShaderWidget.qml
    │   ├── CavaShaderWidget.qml
    │   └── cava_bars.frag
    └── experiment/                # Experimental, audio-reactive orb shader
        ├── QuickMilkExperimentWidget.qml
        ├── experiment.frag
        └── experiment.vert
```

## Shader Format

Shaders must follow Qt's GLSL requirements:

```glsl
#version 440

precision highp float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Add your custom uniforms here
    float iTime;
    vec2 iResolution;
};

void main() {
    // Your shader code here
    fragColor = vec4(1.0, 0.0, 0.0, qt_Opacity);
}
```

## Adding New Shaders

1. Create a new `.frag` (and optional `.vert`) file inside `shaders/<category>/`
2. Create a corresponding QML widget beside it (e.g., `MyShaderWidget.qml`)
3. Add the widget entry to `qmldir` with the relative `shaders/<category>/...` path
4. Rebuild your Nix configuration (or run `./build.sh` for a quick manual compile)

Example widget:

```qml
import QtQuick

Rectangle {
    id: root
    width: 100
    height: 100
    color: "transparent"

    ShaderEffect {
        anchors.fill: parent
        property real iTime: 0
        property vector2d iResolution: Qt.vector2d(width, height)
        fragmentShader: "my_shader.frag.qsb"

        Timer {
            interval: 16
            running: true
            repeat: true
            onTriggered: parent.iTime += 0.016
        }
    }
}
```

## Build Process

The Nix build automatically:

1. Compiles all `.frag` files to `.frag.qsb` using `qsb`
2. Installs compiled shaders to `$out/lib/qt-6/qml/ShaderPlugin/`
3. Copies QML widgets to the same directory
4. Adds the plugin to Quickshell's `QML2_IMPORT_PATH`

## Usage in Quickshell

```qml
import ShaderPlugin

// Use the widget
XorShaderWidget {
    width: 30
    height: 30
}
```

## References

- [Qt Shader Tools](https://doc.qt.io/qt-6/qtshadertools-index.html)
- [QSB Manual](https://doc.qt.io/qt-6/qtshadertools-qsb.html)
- [Qt ShaderEffect](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html)

# GLSL Shader Integration - Setup Complete! 🎉

## What We Built

A complete shader plugin system for your Quickshell bar, following the same pattern as your cava-plugin.

### Files Created

1. **Shader Plugin** (`home/modules/quickshell/components/shader-plugin/`)

   - `xor_texture.frag` - GLSL fragment shader with animated XOR pattern
   - `XorShaderWidget.qml` - QML wrapper widget
   - `qmldir` - QML module definition
   - `build.sh` - Manual build script for testing
   - `README.md` - Documentation

2. **Build Configuration**

   - `shader-plugin.nix` - Nix derivation that compiles shaders using `qsb`

3. **Integration**
   - Updated `quickshell.nix` to include shader plugin in QML import path
   - Updated `BarWindow.qml` to import and use the shader widget

## How It Works

```
GLSL Source (.frag)
    ↓
Compiled by qsb tool (from qt6.qtshadertools)
    ↓
Qt Shader Bytecode (.frag.qsb)
    ↓
Loaded by ShaderEffect in QML
    ↓
Rendered in your Quickshell bar!
```

## What You'll See

A `barHeight × barHeight` (30×30) square in the leftOfCenter section of your bar, displaying an animated XOR texture pattern with shifting colors.

## Next Steps

### 1. Rebuild Your System

```bash
# If you're using home-manager standalone:
home-manager switch

# Or if integrated with NixOS:
sudo nixos-rebuild switch
```

### 2. Restart Quickshell

```bash
# Kill existing quickshell
killall quickshell

# Start it again (should auto-start via systemd)
# Or manually:
quickshell
```

### 3. Testing During Development

Use the dev wrapper to see changes without rebuilding:

```bash
quickshell-dev
```

This watches for QML changes and auto-reloads. However, shader changes require a rebuild since they need compilation.

## Adding New Shaders

1. Create `my_shader.frag` in `shader-plugin/`
2. Create `MyShaderWidget.qml` wrapper
3. Add to `qmldir`: `MyShaderWidget 1.0 MyShaderWidget.qml`
4. Rebuild

## Shader Uniforms Available

Your shaders can access these built-in uniforms:

```glsl
uniform buf {
    mat4 qt_Matrix;        // Transformation matrix
    float qt_Opacity;      // Widget opacity
    float iTime;           // Time in seconds (you add this)
    vec2 iResolution;      // Widget size in pixels (you add this)
}
```

## Customizing the XOR Shader

Edit `xor_texture.frag` to change:

- Animation speed: Modify `iTime * 50.0`
- Color cycling: Adjust the `iTime * 30.0` and `iTime * 60.0` values
- Pattern: Change the XOR operation or add sin/cos functions

## Troubleshooting

### Shader not showing?

- Check Nix build logs: `nix log <path-to-shader-plugin>`
- Verify QML import path: `echo $QML2_IMPORT_PATH`
- Check console for errors: `journalctl --user -u quickshell -f`

### Shader compilation errors?

- Ensure GLSL version is 440
- Check uniform buffer layout matches Qt requirements
- Verify qsb compilation succeeded in Nix build

### Widget not appearing?

- Check import statement in BarWindow.qml
- Verify qmldir module name matches import
- Ensure widget has proper size (width/height)

## Example: Adding a Wave Shader

Create `wave.frag`:

```glsl
#version 440
precision highp float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
};

void main() {
    vec2 uv = qt_TexCoord0;
    float wave = sin(uv.x * 10.0 + iTime) * 0.5 + 0.5;
    fragColor = vec4(wave, uv.y, 1.0 - wave, qt_Opacity);
}
```

Create `WaveShaderWidget.qml`, add to qmldir, rebuild!

## Resources

- Qt Shader Tools: https://doc.qt.io/qt-6/qtshadertools-index.html
- ShaderToy (for inspiration): https://www.shadertoy.com/
- GLSL Reference: https://www.khronos.org/opengl/wiki/Core_Language_(GLSL)

Enjoy your animated shaders! 🎨✨

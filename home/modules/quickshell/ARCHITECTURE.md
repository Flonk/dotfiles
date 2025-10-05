## Shader Plugin Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Quickshell Bar Window                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Left of Center Section:                                         │
│  ┌───────────────┐  ┌──────────────────┐                       │
│  │  XorShader    │  │  Cava Toggle     │                       │
│  │  Widget       │  │  Button          │                       │
│  │  30x30        │  │                  │                       │
│  │  [Animated]   │  │                  │                       │
│  └───────────────┘  └──────────────────┘                       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

Build Pipeline:
───────────────

  xor_texture.frag
        │
        │ (qsb compiler from qt6.qtshadertools)
        ↓
  xor_texture.frag.qsb  ←────┐
        │                     │
        │                     │ referenced by
        ↓                     │
  XorShaderWidget.qml ────────┘
        │
        │ (imported via ShaderPlugin)
        ↓
  BarWindow.qml
        │
        │ (QML2_IMPORT_PATH includes shader-plugin)
        ↓
  Quickshell Runtime


Plugin Structure:
────────────────

shader-plugin.nix (Nix derivation)
    │
    ├─ nativeBuildInputs: qt6.qtshadertools
    │
    ├─ buildPhase: compile *.frag → *.frag.qsb
    │
    └─ installPhase: install to $out/lib/qt-6/qml/ShaderPlugin/
           │
           ├─ xor_texture.frag.qsb
           ├─ XorShaderWidget.qml
           └─ qmldir


Integration Points:
──────────────────

quickshell.nix:
  ├─ shaderPlugin = pkgs.callPackage ./shader-plugin.nix { }
  ├─ QML2_IMPORT_PATH includes shaderPlugin path
  └─ home.packages includes shaderPlugin

BarWindow.qml:
  ├─ import ShaderPlugin
  └─ XorShaderWidget { width: Theme.barHeight; height: Theme.barHeight }


Shader Uniforms Flow:
────────────────────

Timer (QML) → iTime → Shader Uniform Buffer → GPU
                │
Widget Size  → iResolution → Shader Uniform Buffer → GPU
                │
Qt System   → qt_Opacity → Shader Uniform Buffer → GPU
                │
                └─→ Fragment Shader → Rendered Pixels
```

## File Tree

```
dotfiles/home/modules/quickshell/
│
├── quickshell.nix              (Updated: imports shader-plugin)
├── shader-plugin.nix           (New: builds shaders)
├── cava-plugin.nix
│
├── components/
│   ├── BarWindow.qml           (Updated: uses XorShaderWidget)
│   ├── shell.qml
│   ├── Theme.qml
│   │
│   ├── shader-plugin/          (New directory)
│   │   ├── xor_texture.frag         (GLSL source)
│   │   ├── XorShaderWidget.qml      (QML wrapper)
│   │   ├── qmldir                   (Module definition)
│   │   ├── build.sh                 (Manual build script)
│   │   └── README.md
│   │
│   └── cava-plugin/
│       ├── *.cpp, *.h
│       └── CMakeLists.txt
│
├── SHADER_SETUP.md             (New: this guide)
└── README.md
```

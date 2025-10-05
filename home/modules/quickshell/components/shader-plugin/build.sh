#!/usr/bin/env bash
set -euo pipefail

# Compile GLSL shaders to QSB format using Qt's shader tools
qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o xor_texture.frag.qsb xor_texture.frag

echo "Shader compilation complete!"

#!/usr/bin/env bash
set -euo pipefail

# Compile GLSL shaders to QSB format using Qt's shader tools
for shader in xor_texture.frag cava_bars.frag; do
	qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "${shader}.qsb" "$shader"
done

echo "Shader compilation complete!"

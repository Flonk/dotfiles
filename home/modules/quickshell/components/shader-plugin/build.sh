#!/usr/bin/env bash
set -euo pipefail

# Compile GLSL shaders to QSB format using Qt's shader tools
shaders=(
	cava_bars.frag
	audio_orb.frag
	audio_orb.vert
)
)
for shader in "${shaders[@]}"; do
	if [[ ! -f "$shader" ]]; then
		echo "Warning: shader source $shader not found, skipping"
		continue
	fi
	qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "${shader}.qsb" "$shader"
done

echo "Shader compilation complete!"

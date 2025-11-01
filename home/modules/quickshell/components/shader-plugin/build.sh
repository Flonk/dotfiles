#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

# Compile GLSL shaders to QSB format using Qt's shader tools
shaders=(
	"shaders/cava/cava_bars.frag"
	"shaders/experiment/experiment.frag"
	"shaders/experiment/experiment.vert"
)

for shader in "${shaders[@]}"; do
	if [[ ! -f "$shader" ]]; then
		echo "Warning: shader source $shader not found, skipping"
		continue
	fi
	qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "${shader}.qsb" "$shader"
done

echo "Shader compilation complete!"

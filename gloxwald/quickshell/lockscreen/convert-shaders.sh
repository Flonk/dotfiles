#!/usr/bin/env bash
# Convert Shadertoy-style GLSL shaders to Qt 6 .frag.qsb files.
#
# Usage: ./convert-shaders.sh [qsb-path]
#   qsb-path defaults to "qsb" on PATH.
#   ONLY_SCENE=<name>  compile just that one scene (still refreshes default.vert
#                      and assets, which are cheap and shared).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHADER_SRC="$SCRIPT_DIR/shaders/scenes"
PREAMBLE="$SCRIPT_DIR/qt_preamble.glsl"
OUTPUT_DIR="$SCRIPT_DIR/../shell/shaders"
QSB="${1:-qsb}"

mkdir -p "$OUTPUT_DIR"

# Copy texture assets
ASSETS_SRC="$SCRIPT_DIR/shaders/assets"
ASSETS_DST="$OUTPUT_DIR/assets"
mkdir -p "$ASSETS_DST"
cp "$ASSETS_SRC"/*.jpg "$ASSETS_SRC"/*.png "$ASSETS_DST/" 2>/dev/null || true
echo "Assets copied to $ASSETS_DST"

# Compile shared vertex shader
"$QSB" --glsl "300 es,440" -o "$OUTPUT_DIR/default.vert.qsb" "$SCRIPT_DIR/default.vert"
echo "  OK: default.vert"

ok=0
skip=0
fail=0

for scene_dir in "$SHADER_SRC"/*/; do
    name=$(basename "$scene_dir")
    shader="$scene_dir/shader.glsl"

    if [ ! -f "$shader" ]; then continue; fi
    if [ -n "${ONLY_SCENE:-}" ] && [ "$name" != "$ONLY_SCENE" ]; then continue; fi

    output_frag="$OUTPUT_DIR/$name.frag"
    output_qsb="$OUTPUT_DIR/$name.frag.qsb"

    # Helper: build and compile a single .frag from preamble + body parts + main wrapper
    compile_pass() {
        local out_frag="$1" out_qsb="$2" label="$3"
        shift 3

        cp "$PREAMBLE" "$out_frag"
        local body
        for body in "$@"; do
            sed -E '/^#version/d; /^precision\s+/d' "$body" >> "$out_frag"
        done
        cat >> "$out_frag" << 'WRAPPER'

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
WRAPPER

        if "$QSB" --glsl "300 es,440" -o "$out_qsb" "$out_frag" 2>/dev/null; then
            echo "  OK: $label"
            return 0
        else
            echo "FAIL: $label"
            rm -f "$out_qsb"
            return 1
        fi
    }

    # Compile buffer passes (bufferA, bufferB, bufferC, ...)
    for buf in "$scene_dir"/buffer*.glsl; do
        [ -f "$buf" ] || continue
        buf_name=$(basename "$buf" .glsl)
        buf_frag="$OUTPUT_DIR/${name}_${buf_name}.frag"
        buf_qsb="$OUTPUT_DIR/${name}_${buf_name}.frag.qsb"
        if compile_pass "$buf_frag" "$buf_qsb" "${name}/${buf_name}" "$buf"; then
            ok=$((ok + 1))
        else
            fail=$((fail + 1))
        fi
    done

    # Compile main (image) pass: sorted NN_*.glsl parts first, shader.glsl last
    body_parts=()
    for part in "$scene_dir"/[0-9][0-9]_*.glsl; do
        [ -f "$part" ] && body_parts+=("$part")
    done
    body_parts+=("$shader")
    if compile_pass "$output_frag" "$output_qsb" "$name" "${body_parts[@]}"; then
        ok=$((ok + 1))
    else
        fail=$((fail + 1))
    fi
done

# Copy scene.qml files
SCENES_DST="$OUTPUT_DIR/scenes"
mkdir -p "$SCENES_DST"
scenes=0
for scene_dir in "$SHADER_SRC"/*/; do
    name=$(basename "$scene_dir")
    if [ -n "${ONLY_SCENE:-}" ] && [ "$name" != "$ONLY_SCENE" ]; then continue; fi
    if [ -f "$scene_dir/scene.qml" ]; then
        cp "$scene_dir/scene.qml" "$SCENES_DST/$name.qml"
        scenes=$((scenes + 1))
    fi
done
echo "Copied $scenes scene.qml files"

echo ""
echo "Done: $ok ok, $skip skipped, $fail failed"

#!/usr/bin/env bash
# Generate all assets for the GRUB theme (PNGs, fonts, theme.txt)
# Requires: imagemagick (v7), grub2 (for grub-mkfont)
#
# All settings are configurable via environment variables.
# On NixOS:  nix-shell -p imagemagick grub2
set -euo pipefail

# --- Output directory ---
OUT="${GRUB_OUTPUT_DIR:-.}"
mkdir -p "$OUT"

# --- Colors (env vars with defaults matching trump theme) ---
BG_COLOR="${GRUB_BG_COLOR:-#141519}"
BORDER_COLOR="${GRUB_BORDER_COLOR:-#D4A645}"
ACCENT="$BORDER_COLOR"
BAR_BG="${GRUB_BAR_BG:-#1C1D24}"
BAR_FG="${GRUB_BAR_FG:-#8B92A8}"
TEXT_COLOR="${GRUB_TEXT_COLOR:-#ffffff}"
TEXT_DIM="${GRUB_TEXT_DIM:-#555560}"

# --- Dimensions ---
W="${GRUB_WIDTH:-1920}"
H="${GRUB_HEIGHT:-1080}"
BORDER_WIDTH="${GRUB_BORDER_WIDTH:-4}"
SELECT_BORDER="${GRUB_SELECT_BORDER:-2}"
SELECT_PADDING="${GRUB_SELECT_PADDING:-12}"

# --- Paths ---
LOGO_SRC="${GRUB_LOGO:-}"
FONT_FAMILY="${GRUB_FONT_FAMILY:-DejaVu Sans Mono}"
FONT_REGULAR="${GRUB_FONT_REGULAR:-}"
FONT_BOLD="${GRUB_FONT_BOLD:-}"

# Use magick (IMv7) or fall back to convert
IM="magick"
if ! command -v magick &>/dev/null; then
    IM="convert"
fi

echo "=== Generating GRUB theme assets ==="
echo "  Using ImageMagick command: $IM"
echo "  Output directory: $OUT"
echo "  Resolution: ${W}x${H}"

# Helper: hex color → rgba() with alpha
hex_to_rgba() {
    local hex="${1#\#}" alpha="$2"
    printf "rgba(%d,%d,%d,%s)" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}" "$alpha"
}

# --- Background ---
echo "[1/6] Generating background..."
$IM -size "${W}x${H}" xc:"$BG_COLOR" \
    -fill "$BORDER_COLOR" \
    -draw "rectangle 0,0 $(( W - 1 )),$(( BORDER_WIDTH - 1 ))" \
    -draw "rectangle 0,$(( H - BORDER_WIDTH )),$(( W - 1 )),$(( H - 1 ))" \
    -draw "rectangle 0,0 $(( BORDER_WIDTH - 1 )),$(( H - 1 ))" \
    -draw "rectangle $(( W - BORDER_WIDTH )),0,$(( W - 1 )),$(( H - 1 ))" \
    -channel RGBA -depth 8 \
    "PNG32:${OUT}/background.png"

echo "  -> background.png"

# --- Selected item styled box (9-slice: select_*.png) ---
echo "[2/6] Generating selection highlight..."

# The 9-slice approach: we create minimal corner/edge/center pieces
# For a clean look: border with accent color + horizontal padding
BORDER="$SELECT_BORDER"
SLICE_V=$(( SELECT_BORDER + 2 ))    # border + 2px vertical space
SLICE_H=$(( SELECT_BORDER + SELECT_PADDING ))  # border + horizontal padding

# Helper to make a solid color rect
mkslice() {
    local name="$1" w="$2" h="$3" color="$4"
    $IM -size "${w}x${h}" "xc:${color}" "PNG32:${OUT}/${name}"
}

TINT="$(hex_to_rgba "$ACCENT" "0.10")"

# Center - subtle warm tint on selection
$IM -size 8x8 "xc:$TINT" "PNG32:${OUT}/select_c.png"

# Edges - accent border, padding filled with tint
# North: accent top, tint below
$IM -size 8x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,0 7,$(( BORDER - 1 ))" \
    "PNG32:${OUT}/select_n.png"
# South: tint above, accent bottom
$IM -size 8x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - BORDER )) 7,$(( SLICE_V - 1 ))" \
    "PNG32:${OUT}/select_s.png"
# West: accent left, tint padding right
$IM -size ${SLICE_H}x8 "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( BORDER - 1 )),7" \
    "PNG32:${OUT}/select_w.png"
# East: tint padding left, accent right
$IM -size ${SLICE_H}x8 "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle $(( SLICE_H - BORDER )),0 $(( SLICE_H - 1 )),7" \
    "PNG32:${OUT}/select_e.png"

# Corners (width=SLICE_H, height=SLICE_V) - tint fill + border
# NW
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( BORDER - 1 )),$(( SLICE_V - 1 ))" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( SLICE_H - 1 )),$(( BORDER - 1 ))" \
    "PNG32:${OUT}/select_nw.png"
# NE
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle $(( SLICE_H - BORDER )),0 $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( SLICE_H - 1 )),$(( BORDER - 1 ))" \
    "PNG32:${OUT}/select_ne.png"
# SW
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( BORDER - 1 )),$(( SLICE_V - 1 ))" \
    -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - BORDER )) $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" \
    "PNG32:${OUT}/select_sw.png"
# SE
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle $(( SLICE_H - BORDER )),0 $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" \
    -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - BORDER )) $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" \
    "PNG32:${OUT}/select_se.png"

echo "  -> select_*.png"

# --- Inactive item styled box (item_*.png) ---
# Same dimensions as select_*.png but fully transparent
# This ensures all items get identical padding so text doesn't jump
$IM -size 8x8 xc:none "PNG32:${OUT}/item_c.png"
$IM -size 8x${SLICE_V} xc:none "PNG32:${OUT}/item_n.png"
$IM -size 8x${SLICE_V} xc:none "PNG32:${OUT}/item_s.png"
$IM -size ${SLICE_H}x8 xc:none "PNG32:${OUT}/item_w.png"
$IM -size ${SLICE_H}x8 xc:none "PNG32:${OUT}/item_e.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:${OUT}/item_nw.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:${OUT}/item_ne.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:${OUT}/item_sw.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:${OUT}/item_se.png"
echo "  -> item_*.png"

echo "  Selection highlight uses: $ACCENT"

# --- Terminal box styled box (terminal_*.png) ---
echo "[3/6] Generating terminal box..."
# Simple dark background for terminal/console
mkslice "terminal_c.png" 8 8 "$BG_COLOR"
mkslice "terminal_n.png" 8 2 "$BAR_BG"
mkslice "terminal_s.png" 8 2 "$BAR_BG"
mkslice "terminal_e.png" 2 8 "$BAR_BG"
mkslice "terminal_w.png" 2 8 "$BAR_BG"
mkslice "terminal_nw.png" 2 2 "$BAR_BG"
mkslice "terminal_ne.png" 2 2 "$BAR_BG"
mkslice "terminal_sw.png" 2 2 "$BAR_BG"
mkslice "terminal_se.png" 2 2 "$BAR_BG"
echo "  -> terminal_*.png"

# --- Logo ---
echo "[4/6] Copying logo..."
if [[ -n "$LOGO_SRC" && -f "$LOGO_SRC" ]]; then
    cp "$LOGO_SRC" "${OUT}/logo.png"
    echo "  -> logo.png"
else
    echo "  [!] Logo not found (GRUB_LOGO=${LOGO_SRC:-unset})"
fi

# --- Fonts ---
echo "[5/6] Generating fonts..."

# If font paths were provided via env vars, use them; otherwise search the system
FONT_PATH="$FONT_REGULAR"
FONT_BOLD_PATH="$FONT_BOLD"

if [[ -z "$FONT_PATH" ]]; then
    for p in \
        /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf \
        /usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf \
        /usr/share/fonts/TTF/DejaVuSansMono.ttf \
        /usr/share/fonts/dejavu/DejaVuSansMono.ttf \
        /nix/store/*/share/fonts/truetype/DejaVuSansMono.ttf; do
        if [[ -f "$p" ]]; then
            FONT_PATH="$p"
            break
        fi
    done
fi

if [[ -z "$FONT_BOLD_PATH" ]]; then
    for p in \
        /usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf \
        /usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono-Bold.ttf \
        /usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf \
        /usr/share/fonts/dejavu/DejaVuSansMono-Bold.ttf \
        /nix/store/*/share/fonts/truetype/DejaVuSansMono-Bold.ttf; do
        if [[ -f "$p" ]]; then
            FONT_BOLD_PATH="$p"
            break
        fi
    done
fi

# Detect grub-mkfont
MKFONT=""
if command -v grub-mkfont &>/dev/null; then
    MKFONT="grub-mkfont"
elif command -v grub2-mkfont &>/dev/null; then
    MKFONT="grub2-mkfont"
else
    NIX_GRUB=$(nix-build '<nixpkgs>' -A grub2 --no-out-link 2>/dev/null || true)
    if [[ -n "$NIX_GRUB" && -x "$NIX_GRUB/bin/grub-mkfont" ]]; then
        MKFONT="$NIX_GRUB/bin/grub-mkfont"
    fi
fi

# Sanitised font family for filenames: "DejaVu Sans Mono" → "DejaVu_Sans_Mono"
FONT_SLUG="${FONT_FAMILY// /_}"

if [[ -n "$MKFONT" && -n "$FONT_PATH" ]]; then
    "$MKFONT" "$FONT_PATH" -s 12 -o "${OUT}/${FONT_SLUG}_Regular_12.pf2" \
        -n "${FONT_FAMILY} Regular 12"
    "$MKFONT" "$FONT_PATH" -s 14 -o "${OUT}/${FONT_SLUG}_Regular_14.pf2" \
        -n "${FONT_FAMILY} Regular 14"
    "$MKFONT" "$FONT_PATH" -s 18 -o "${OUT}/${FONT_SLUG}_Regular_18.pf2" \
        -n "${FONT_FAMILY} Regular 18"
    echo "  -> ${FONT_SLUG}_Regular_{12,14,18}.pf2"

    if [[ -n "$FONT_BOLD_PATH" ]]; then
        "$MKFONT" "$FONT_BOLD_PATH" -s 18 -o "${OUT}/${FONT_SLUG}_Bold_18.pf2" \
            -n "${FONT_FAMILY} Bold 18"
        echo "  -> ${FONT_SLUG}_Bold_18.pf2"
    else
        echo "  [!] Bold font not found, skipping bold variant"
    fi
else
    echo "  [!] grub-mkfont or font file not found, skipping font generation"
    echo "      MKFONT=$MKFONT"
    echo "      FONT_PATH=$FONT_PATH"
    echo "      Theme will fall back to GRUB's default font"
fi

# --- theme.txt ---
echo "[6/6] Generating theme.txt..."

# Compute logo centering offset (read logo dimensions if file exists)
LOGO_OFFSET_X=0
LOGO_OFFSET_Y=0
if [[ -f "${OUT}/logo.png" ]]; then
    read -r LW LH <<< "$($IM identify -format "%w %h" "${OUT}/logo.png")"
    LOGO_OFFSET_X=$(( LW / 2 ))
    LOGO_OFFSET_Y=$(( LH / 2 ))
fi

cat > "${OUT}/theme.txt" <<THEME
# Skynet GRUB Theme (generated by generate-assets.sh)
title-text: ""
desktop-image: "background.png"
desktop-color: "${BG_COLOR}"
terminal-font: "${FONT_FAMILY} Regular 14"
terminal-box: "terminal_*.png"

+ boot_menu {
    left = 5%
    top = 20%
    width = 40%
    height = 60%

    item_font = "${FONT_FAMILY} Regular 18"
    item_color = "${BAR_FG}"
    selected_item_font = "${FONT_FAMILY} Bold 18"
    selected_item_color = "${TEXT_COLOR}"

    selected_item_pixmap_style = "select_*.png"
    item_pixmap_style = "item_*.png"

    icon_width = 0
    icon_height = 0
    item_icon_space = 0

    item_height = 36
    item_padding = 12
    item_spacing = 8

    scrollbar = false
}

+ progress_bar {
    left = 5%
    top = 90%
    width = 40%
    height = 4

    id = "__timeout__"

    bg_color = "${BAR_BG}"
    fg_color = "${BAR_FG}"
    border_color = "${BAR_BG}"
}

+ label {
    left = 5%
    top = 85%
    width = 40%
    height = 20

    id = "__timeout__"
    color = "${TEXT_DIM}"
    font = "${FONT_FAMILY} Regular 12"
    align = "left"
}

+ label {
    left = 5%
    top = 95%
    width = 40%
    height = 20

    color = "${TEXT_DIM}"
    font = "${FONT_FAMILY} Regular 12"
    align = "left"
    text = "enter: boot | e: edit | c: command line"
}

+ image {
    left = 75%-${LOGO_OFFSET_X}
    top = 50%-${LOGO_OFFSET_Y}
    file = "logo.png"
}
THEME

echo "  -> theme.txt"

echo ""
echo "=== Done! ==="
echo "Generated files in ${OUT}:"
ls -la "${OUT}"/*.png "${OUT}"/*.pf2 "${OUT}"/theme.txt 2>/dev/null || true

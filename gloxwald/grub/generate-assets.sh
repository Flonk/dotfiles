#!/usr/bin/env bash
# Generate assets for the GLOXWALD GRUB theme (PNGs, fonts, theme.txt)
# Requires: imagemagick (v7), grub2 (for grub-mkfont)
set -euo pipefail

OUT="${GRUB_OUTPUT_DIR:-.}"
mkdir -p "$OUT"

# --- Colors ---
BG_COLOR="${GRUB_BG_COLOR:-#141519}"
ACCENT="${GRUB_BORDER_COLOR:-#D4A645}"
BAR_BG="${GRUB_BAR_BG:-#1C1D24}"
BAR_FG="${GRUB_BAR_FG:-#8B92A8}"
TEXT_COLOR="${GRUB_TEXT_COLOR:-#ffffff}"
TEXT_DIM="${GRUB_TEXT_DIM:-#555560}"

# --- Dimensions ---
W="${GRUB_WIDTH:-1920}"
H="${GRUB_HEIGHT:-1080}"

# --- Paths ---
FONT_FAMILY="${GRUB_FONT_FAMILY:-DejaVu Sans Mono}"
FONT_REGULAR="${GRUB_FONT_REGULAR:-}"
FONT_BOLD="${GRUB_FONT_BOLD:-}"
ASCII_ART_FILE="${GRUB_ASCII_ART:-}"

IM="magick"
if ! command -v magick &>/dev/null; then
    IM="convert"
fi

echo "=== Generating GLOXWALD GRUB theme ==="

# Helper: hex → rgba with alpha
hex_to_rgba() {
    local hex="${1#\#}" alpha="$2"
    printf "rgba(%d,%d,%d,%s)" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}" "$alpha"
}

# --- Background (solid color, no border) ---
echo "[1/5] Background..."
$IM -size "${W}x${H}" xc:"$BG_COLOR" -depth 8 "PNG32:${OUT}/background.png"

# --- ASCII art → PNG ---
echo "[2/5] ASCII art..."
if [[ -n "$ASCII_ART_FILE" && -f "$ASCII_ART_FILE" ]]; then
    # Determine font path for rendering
    RENDER_FONT="$FONT_REGULAR"
    if [[ -z "$RENDER_FONT" ]]; then
        RENDER_FONT="DejaVu-Sans-Mono"
    fi

    $IM -background none -fill "$ACCENT" \
        -font "$RENDER_FONT" -pointsize 14 \
        -interline-spacing 0 \
        label:"@${ASCII_ART_FILE}" \
        "PNG32:${OUT}/ascii.png"
    echo "  -> ascii.png"
else
    echo "  [!] No ASCII art file provided, skipping"
fi

# --- Selection highlight (9-slice) ---
echo "[3/5] Selection highlight..."
SELECT_BORDER=2
SELECT_PADDING=12
SLICE_V=$(( SELECT_BORDER + 2 ))
SLICE_H=$(( SELECT_BORDER + SELECT_PADDING ))
TINT="$(hex_to_rgba "$ACCENT" "0.10")"

mkslice() { $IM -size "${2}x${3}" "xc:${4}" "PNG32:${OUT}/${1}"; }

# Selected items
$IM -size 8x8 "xc:$TINT" "PNG32:${OUT}/select_c.png"
$IM -size 8x${SLICE_V} "xc:$TINT" -fill "$ACCENT" -draw "rectangle 0,0 7,$(( SELECT_BORDER - 1 ))" "PNG32:${OUT}/select_n.png"
$IM -size 8x${SLICE_V} "xc:$TINT" -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - SELECT_BORDER )) 7,$(( SLICE_V - 1 ))" "PNG32:${OUT}/select_s.png"
$IM -size ${SLICE_H}x8 "xc:$TINT" -fill "$ACCENT" -draw "rectangle 0,0 $(( SELECT_BORDER - 1 )),7" "PNG32:${OUT}/select_w.png"
$IM -size ${SLICE_H}x8 "xc:$TINT" -fill "$ACCENT" -draw "rectangle $(( SLICE_H - SELECT_BORDER )),0 $(( SLICE_H - 1 )),7" "PNG32:${OUT}/select_e.png"
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" -fill "$ACCENT" -draw "rectangle 0,0 $(( SELECT_BORDER - 1 )),$(( SLICE_V - 1 ))" -fill "$ACCENT" -draw "rectangle 0,0 $(( SLICE_H - 1 )),$(( SELECT_BORDER - 1 ))" "PNG32:${OUT}/select_nw.png"
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" -fill "$ACCENT" -draw "rectangle $(( SLICE_H - SELECT_BORDER )),0 $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" -fill "$ACCENT" -draw "rectangle 0,0 $(( SLICE_H - 1 )),$(( SELECT_BORDER - 1 ))" "PNG32:${OUT}/select_ne.png"
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" -fill "$ACCENT" -draw "rectangle 0,0 $(( SELECT_BORDER - 1 )),$(( SLICE_V - 1 ))" -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - SELECT_BORDER )) $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" "PNG32:${OUT}/select_sw.png"
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" -fill "$ACCENT" -draw "rectangle $(( SLICE_H - SELECT_BORDER )),0 $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - SELECT_BORDER )) $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" "PNG32:${OUT}/select_se.png"

# Inactive items (transparent, same dimensions for consistent padding)
$IM -size 8x8 xc:none "PNG32:${OUT}/item_c.png"
$IM -size 8x${SLICE_V} xc:none "PNG32:${OUT}/item_n.png"
$IM -size 8x${SLICE_V} xc:none "PNG32:${OUT}/item_s.png"
$IM -size ${SLICE_H}x8 xc:none "PNG32:${OUT}/item_w.png"
$IM -size ${SLICE_H}x8 xc:none "PNG32:${OUT}/item_e.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:${OUT}/item_nw.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:${OUT}/item_ne.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:${OUT}/item_sw.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:${OUT}/item_se.png"

# Terminal box
mkslice "terminal_c.png" 8 8 "$BG_COLOR"
mkslice "terminal_n.png" 8 2 "$BAR_BG"
mkslice "terminal_s.png" 8 2 "$BAR_BG"
mkslice "terminal_e.png" 2 8 "$BAR_BG"
mkslice "terminal_w.png" 2 8 "$BAR_BG"
mkslice "terminal_nw.png" 2 2 "$BAR_BG"
mkslice "terminal_ne.png" 2 2 "$BAR_BG"
mkslice "terminal_sw.png" 2 2 "$BAR_BG"
mkslice "terminal_se.png" 2 2 "$BAR_BG"

# --- Fonts ---
echo "[4/5] Fonts..."
FONT_PATH="$FONT_REGULAR"
FONT_BOLD_PATH="$FONT_BOLD"
FONT_SLUG="${FONT_FAMILY// /_}"

MKFONT=""
if command -v grub-mkfont &>/dev/null; then
    MKFONT="grub-mkfont"
elif command -v grub2-mkfont &>/dev/null; then
    MKFONT="grub2-mkfont"
fi

if [[ -n "$MKFONT" && -n "$FONT_PATH" ]]; then
    "$MKFONT" "$FONT_PATH" -s 12 -o "${OUT}/${FONT_SLUG}_Regular_12.pf2" -n "${FONT_FAMILY} Regular 12"
    "$MKFONT" "$FONT_PATH" -s 16 -o "${OUT}/${FONT_SLUG}_Regular_16.pf2" -n "${FONT_FAMILY} Regular 16"
    if [[ -n "$FONT_BOLD_PATH" ]]; then
        "$MKFONT" "$FONT_BOLD_PATH" -s 16 -o "${OUT}/${FONT_SLUG}_Bold_16.pf2" -n "${FONT_FAMILY} Bold 16"
    fi
else
    echo "  [!] grub-mkfont or font not found, skipping"
fi

# --- theme.txt ---
echo "[5/5] theme.txt..."

# Compute ASCII art centering if it exists
ASCII_BLOCK=""
if [[ -f "${OUT}/ascii.png" ]]; then
    read -r AW AH <<< "$($IM identify -format "%w %h" "${OUT}/ascii.png")"
    ASCII_BLOCK="
+ image {
    left = 50%-$(( AW / 2 ))
    top = 30%-$(( AH / 2 ))
    file = \"ascii.png\"
}"
fi

cat > "${OUT}/theme.txt" <<THEME
# GLOXWALD GRUB Theme
title-text: ""
desktop-image: "background.png"
desktop-color: "${BG_COLOR}"
terminal-font: "${FONT_FAMILY} Regular 12"
terminal-box: "terminal_*.png"
${ASCII_BLOCK}

+ boot_menu {
    left = 30%
    top = 45%
    width = 40%
    height = 20%

    item_font = "${FONT_FAMILY} Regular 16"
    item_color = "${BAR_FG}"
    selected_item_font = "${FONT_FAMILY} Bold 16"
    selected_item_color = "${TEXT_COLOR}"

    selected_item_pixmap_style = "select_*.png"
    item_pixmap_style = "item_*.png"

    icon_width = 0
    icon_height = 0
    item_icon_space = 0

    item_height = 32
    item_padding = 10
    item_spacing = 6

    scrollbar = false
}

+ progress_bar {
    left = 30%
    top = 70%
    width = 40%
    height = 3

    id = "__timeout__"

    bg_color = "${BAR_BG}"
    fg_color = "${BAR_FG}"
    border_color = "${BAR_BG}"
}

+ label {
    left = 30%
    top = 74%
    width = 40%
    height = 20

    id = "__timeout__"
    color = "${TEXT_DIM}"
    font = "${FONT_FAMILY} Regular 12"
    align = "center"
}

+ label {
    left = 30%
    top = 78%
    width = 40%
    height = 20

    color = "${TEXT_DIM}"
    font = "${FONT_FAMILY} Regular 12"
    align = "center"
    text = "enter: boot | e: edit | c: command line"
}
THEME

echo "=== Done ==="

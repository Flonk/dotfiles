#!/usr/bin/env bash
# Generate assets for the T3_DESKTOP GRUB theme (PNGs, fonts, theme.txt)
# Requires: imagemagick (v7), grub2 (for grub-mkfont)
set -euo pipefail

OUT="${GRUB_OUTPUT_DIR:-.}"
mkdir -p "$OUT"

# --- Colors (mirrors the greeter: bg/accent themed, white/muted hardcoded there too) ---
BG_COLOR="${GRUB_BG_COLOR:-#1a1a1a}"
ACCENT="${GRUB_BORDER_COLOR:-#ff9529}"
BAR_BG="${GRUB_BAR_BG:-#1C1D24}"
WHITE="#ffffff"
MUTED="#677383"

# --- Dimensions ---
W="${GRUB_WIDTH:-1920}"
H="${GRUB_HEIGHT:-1080}"
# The menu box cannot auto-fit its content, so it is sized for this many entries
ITEMS="${GRUB_MENU_ITEMS:-4}"

# --- Paths ---
FONT_FAMILY="${GRUB_FONT_FAMILY:-DejaVu Sans Mono}"
FONT_REGULAR="${GRUB_FONT_REGULAR:-}"
FONT_BOLD="${GRUB_FONT_BOLD:-}"
ASCII_ART_FILE="${GRUB_ASCII_ART:-}"

IM="magick"
if ! command -v magick &>/dev/null; then
    IM="convert"
fi

echo "=== Generating T3_DESKTOP GRUB theme ==="

# --- Background (solid color, no border) ---
echo "[1/5] Background..."
if [[ -n "${GRUB_BACKGROUND:-}" ]]; then
    $IM "$GRUB_BACKGROUND" -resize "${W}x${H}!" -depth 8 "PNG32:${OUT}/background.png"
    $IM "${OUT}/background.png" -crop "$(( W - 48 ))x$(( H - 84 ))+24+60" +repage -depth 8 "PNG32:${OUT}/terminal.png"
else
    $IM -size "${W}x${H}" xc:"$BG_COLOR" -depth 8 "PNG32:${OUT}/background.png"
fi

# --- ASCII art → PNG ---
echo "[2/5] ASCII art..."
if [[ -n "$ASCII_ART_FILE" && -f "$ASCII_ART_FILE" ]]; then
    # Determine font path for rendering
    RENDER_FONT="$FONT_REGULAR"
    if [[ -z "$RENDER_FONT" ]]; then
        RENDER_FONT="DejaVu-Sans-Mono"
    fi

    $IM -background none -fill "$WHITE" \
        -font "$RENDER_FONT" -pointsize 20 \
        -interline-spacing 0 \
        label:"@${ASCII_ART_FILE}" \
        "PNG32:${OUT}/ascii.png"
    echo "  -> ascii.png"
else
    echo "  [!] No ASCII art file provided, skipping"
fi

# --- Menu box (9-slice rounded border, like the greeter's login box) ---
echo "[3/5] Menu box..."
$IM -size 24x24 xc:none -fill "$MUTED" -draw "roundrectangle 0,0 23,23 3,3" \
    -fill "$BG_COLOR" -draw "roundrectangle 1,1 22,22 2,2" "PNG32:${OUT}/menubox.png"
for slice in nw:+0+0 n:+8+0 ne:+16+0 w:+0+8 c:+8+8 e:+16+8 sw:+0+16 s:+8+16 se:+16+16; do
    $IM "${OUT}/menubox.png" -crop "8x8${slice#*:}" +repage "PNG32:${OUT}/menu_${slice%%:*}.png"
done
rm "${OUT}/menubox.png"

# Terminal box
mkslice() { $IM -size "$2" "xc:$3" "PNG32:${OUT}/$1"; }
for slice in c:8x8 n:8x2 s:8x2 e:2x8 w:2x8 nw:2x2 ne:2x2 sw:2x2 se:2x2; do
    mkslice "terminal_${slice%%:*}.png" "${slice#*:}" none
done

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
    top = 45%-$(( AH + 24 ))
    file = \"ascii.png\"
}"
fi

# 8px slice inset + 10px item_padding top and bottom, 32px items, 6px spacing
BOX_H=$(( 36 + ITEMS * 32 + (ITEMS - 1) * 6 ))

cat > "${OUT}/theme.txt" <<THEME
# T3_DESKTOP GRUB Theme
title-text: ""
desktop-image: "background.png"
desktop-color: "${BG_COLOR}"
terminal-font: "${FONT_FAMILY} Regular 12"
terminal-box: "terminal_*.png"
terminal-left: "24"
terminal-top: "60"
terminal-width: "100%-48"
terminal-height: "100%-84"
${ASCII_BLOCK}

+ boot_menu {
    left = 30%
    top = 45%
    width = 40%
    height = ${BOX_H}

    menu_pixmap_style = "menu_*.png"

    item_font = "${FONT_FAMILY} Regular 16"
    item_color = "${MUTED}"
    selected_item_font = "${FONT_FAMILY} Bold 16"
    selected_item_color = "${ACCENT}"

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
    top = 45%+$(( BOX_H + 24 ))
    width = 40%
    height = 3

    id = "__timeout__"

    bg_color = "${BAR_BG}"
    fg_color = "${ACCENT}"
    border_color = "${BAR_BG}"
}

+ label {
    left = 30%
    top = 45%+$(( BOX_H + 40 ))
    width = 40%
    height = 20

    id = "__timeout__"
    color = "${MUTED}"
    font = "${FONT_FAMILY} Regular 12"
    align = "center"
}

+ label {
    left = 30%
    top = 100%-30
    width = 40%
    height = 20

    color = "${MUTED}"
    font = "${FONT_FAMILY} Regular 12"
    align = "center"
    text = "enter: boot | e: edit | c: command line"
}
THEME

echo "=== Done ==="

#!/usr/bin/env bash
# Generate all assets for the GRUB theme
# Requires: imagemagick (v7), grub2 (for grub-mkfont)
#
# On NixOS:  nix-shell -p imagemagick grub2
set -euo pipefail
cd "$(dirname "$0")"

# Use magick (IMv7) or fall back to convert
IM="magick"
if ! command -v magick &>/dev/null; then
    IM="convert"
fi

echo "=== Generating GRUB theme assets ==="
echo "  Using ImageMagick command: $IM"

# --- Colors (approximate oklch values from nix theme) ---
# trump theme: mainH=50°, mainC=0.19 (wm), appC=0.07 @ h=230° (app)
BG_COLOR="#141519"          # ~app100: L=0.1, very dark blue-gray
BORDER_COLOR="#D4A645"      # ~wm800:  L=0.8, C=0.19, h=50° bright gold
ACCENT="#D4A645"            # same as border (wm800)
BAR_BG="#1C1D24"            # ~app200: L=0.2, muted dark blue
BAR_FG="#8B92A8"            # ~app600: L=0.6, muted blue
TEXT_DIM="#555560"          # ~app400-ish, muted
BORDER_WIDTH=4

# --- Background ---
echo "[1/5] Generating background..."
# Flat fill with 4px border around the rim (like hyprland window border)
# PNG32: + channel RGBA forces GRUB-compatible color type 6
$IM -size 1920x1080 xc:"$BG_COLOR" \
    -fill "$BORDER_COLOR" \
    -draw "rectangle 0,0 1919,$(( BORDER_WIDTH - 1 ))" \
    -draw "rectangle 0,$(( 1080 - BORDER_WIDTH )),1919,1079" \
    -draw "rectangle 0,0 $(( BORDER_WIDTH - 1 )),1079" \
    -draw "rectangle $(( 1920 - BORDER_WIDTH )),0,1919,1079" \
    -channel RGBA -depth 8 \
    "PNG32:background.png"

echo "  -> background.png"

# --- Selected item styled box (9-slice: select_*.png) ---
echo "[2/5] Generating selection highlight..."

# The 9-slice approach: we create minimal corner/edge/center pieces
# For a clean look: 2px border with accent color + horizontal padding
BORDER=2         # border thickness in px
SLICE_V=4        # north/south slice height (2px border + 2px space)
SLICE_H=14       # west/east slice width (2px border + 12px padding)

# Helper to make a solid color rect
mkslice() {
    local name="$1" w="$2" h="$3" color="$4"
    $IM -size "${w}x${h}" "xc:${color}" "PNG32:${name}"
}

TINT="rgba(212,166,69,0.10)"

# Center - subtle warm tint on selection
$IM -size 8x8 "xc:$TINT" "PNG32:select_c.png"

# Edges - 2px accent border, padding filled with tint
# North: 2px accent top, tint below
$IM -size 8x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,0 7,$(( BORDER - 1 ))" \
    "PNG32:select_n.png"
# South: tint above, 2px accent bottom
$IM -size 8x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - BORDER )) 7,$(( SLICE_V - 1 ))" \
    "PNG32:select_s.png"
# West: 2px accent left, tint padding right
$IM -size ${SLICE_H}x8 "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( BORDER - 1 )),7" \
    "PNG32:select_w.png"
# East: tint padding left, 2px accent right
$IM -size ${SLICE_H}x8 "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle $(( SLICE_H - BORDER )),0 $(( SLICE_H - 1 )),7" \
    "PNG32:select_e.png"

# Corners (width=SLICE_H, height=SLICE_V) - tint fill + border
# NW
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( BORDER - 1 )),$(( SLICE_V - 1 ))" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( SLICE_H - 1 )),$(( BORDER - 1 ))" \
    "PNG32:select_nw.png"
# NE
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle $(( SLICE_H - BORDER )),0 $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( SLICE_H - 1 )),$(( BORDER - 1 ))" \
    "PNG32:select_ne.png"
# SW
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle 0,0 $(( BORDER - 1 )),$(( SLICE_V - 1 ))" \
    -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - BORDER )) $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" \
    "PNG32:select_sw.png"
# SE
$IM -size ${SLICE_H}x${SLICE_V} "xc:$TINT" \
    -fill "$ACCENT" -draw "rectangle $(( SLICE_H - BORDER )),0 $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" \
    -fill "$ACCENT" -draw "rectangle 0,$(( SLICE_V - BORDER )) $(( SLICE_H - 1 )),$(( SLICE_V - 1 ))" \
    "PNG32:select_se.png"

echo "  -> select_*.png"

# --- Inactive item styled box (item_*.png) ---
# Same dimensions as select_*.png but fully transparent
# This ensures all items get identical padding so text doesn't jump
$IM -size 8x8 xc:none "PNG32:item_c.png"
$IM -size 8x${SLICE_V} xc:none "PNG32:item_n.png"
$IM -size 8x${SLICE_V} xc:none "PNG32:item_s.png"
$IM -size ${SLICE_H}x8 xc:none "PNG32:item_w.png"
$IM -size ${SLICE_H}x8 xc:none "PNG32:item_e.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:item_nw.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:item_ne.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:item_sw.png"
$IM -size ${SLICE_H}x${SLICE_V} xc:none "PNG32:item_se.png"
echo "  -> item_*.png"

echo "[2.5/5] Selection highlight uses: $ACCENT"

# --- Terminal box styled box (terminal_*.png) ---
echo "[3/5] Generating terminal box..."
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
echo "[4/5] Copying logo..."
LOGO_SRC="$(dirname "$0")/../assets/logos/andamp-amp-blue.png"
if [[ -f "$LOGO_SRC" ]]; then
    cp "$LOGO_SRC" logo.png
    echo "  -> logo.png"
else
    echo "  [!] Logo not found at $LOGO_SRC"
fi

# --- Fonts ---
echo "[5/5] Generating fonts..."
# Try to find DejaVu Sans Mono on the system
FONT_PATH=""
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

FONT_BOLD_PATH=""
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

# Detect the grub-mkfont command (grub-mkfont or grub2-mkfont)
MKFONT=""
if command -v grub-mkfont &>/dev/null; then
    MKFONT="grub-mkfont"
elif command -v grub2-mkfont &>/dev/null; then
    MKFONT="grub2-mkfont"
else
    # NixOS: try to find it in /nix/store via grub2 package
    NIX_GRUB=$(nix-build '<nixpkgs>' -A grub2 --no-out-link 2>/dev/null || true)
    if [[ -n "$NIX_GRUB" && -x "$NIX_GRUB/bin/grub-mkfont" ]]; then
        MKFONT="$NIX_GRUB/bin/grub-mkfont"
    fi
fi

if [[ -n "$MKFONT" && -n "$FONT_PATH" ]]; then
    "$MKFONT" "$FONT_PATH" -s 12 -o "DejaVu_Sans_Mono_Regular_12.pf2" \
        -n "DejaVu Sans Mono Regular 12"
    "$MKFONT" "$FONT_PATH" -s 14 -o "DejaVu_Sans_Mono_Regular_14.pf2" \
        -n "DejaVu Sans Mono Regular 14"
    "$MKFONT" "$FONT_PATH" -s 18 -o "DejaVu_Sans_Mono_Regular_18.pf2" \
        -n "DejaVu Sans Mono Regular 18"
    echo "  -> DejaVu_Sans_Mono_Regular_{12,14,18}.pf2"

    if [[ -n "$FONT_BOLD_PATH" ]]; then
        "$MKFONT" "$FONT_BOLD_PATH" -s 18 -o "DejaVu_Sans_Mono_Bold_18.pf2" \
            -n "DejaVu Sans Mono Bold 18"
        echo "  -> DejaVu_Sans_Mono_Bold_18.pf2"
    else
        echo "  [!] Bold font not found, skipping bold variant"
    fi
else
    echo "  [!] grub-mkfont or font file not found, skipping font generation"
    echo "      MKFONT=$MKFONT"
    echo "      FONT_PATH=$FONT_PATH"
    echo "      Theme will fall back to GRUB's default font"
fi

echo ""
echo "=== Done! ==="
echo "Generated files:"
ls -la *.png *.pf2 2>/dev/null || true

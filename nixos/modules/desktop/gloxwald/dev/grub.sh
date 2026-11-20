#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV="$ROOT/.dev"
G="$DEV/grub"
PIDFILE="$DEV/qemu.pid"

theme() { jq -r --arg k "$1" --arg d "$2" '.[$k] // $d' "$DEV/theme.json"; }

build() {
    local w=$1 h=$2
    local themedir="$G/iso/boot/grub/themes/gloxwald"
    rm -rf "$G/iso"
    mkdir -p "$themedir"

    GRUB_OUTPUT_DIR="$themedir" \
    GRUB_WIDTH="$w" GRUB_HEIGHT="$h" \
    GRUB_BG_COLOR="$(theme app100 '#1a1a1a')" \
    GRUB_BORDER_COLOR="$(theme wm800 '#ff9529')" \
    GRUB_BAR_BG="$(theme app150 '#1C1D24')" \
    GRUB_ASCII_ART="$ROOT/ascii.txt" \
    GRUB_FONT_FAMILY="$(theme fontFamily 'DejaVu Sans Mono')" \
    GRUB_FONT_REGULAR="$GLOXWALD_DEJAVU/DejaVuSansMono.ttf" \
    GRUB_FONT_BOLD="$GLOXWALD_DEJAVU/DejaVuSansMono-Bold.ttf" \
        bash "$ROOT/src/grub/generate-assets.sh"

    {
        echo "insmod all_video"
        echo "insmod gfxterm"
        echo "insmod png"
        echo "set gfxmode=${w}x${h}"
        echo "set gfxpayload=keep"
        echo "terminal_output gfxterm"
        for f in "$themedir"/*.pf2; do
            echo "loadfont /boot/grub/themes/gloxwald/$(basename "$f")"
        done
        echo "set theme=/boot/grub/themes/gloxwald/theme.txt"
        echo "set timeout=30"
        echo "set default=0"
        for entry in "NixOS" "NixOS - All configurations" "Windows Boot Manager" "UEFI Firmware Settings"; do
            echo "menuentry \"$entry\" { echo \"dev preview: nothing to boot\"; sleep 2; }"
        done
    } > "$G/iso/boot/grub/grub.cfg"

    grub-mkrescue --fonts= --locales= --themes= -o "$G/grub.iso" "$G/iso" 2>&1 | grep -v '^xorriso\|^Drive\|^Media\|^libisofs\|^ISO image\|^Written\|^Writing' || true
    echo "built grub.iso at ${w}x${h}"
}

stop() {
    if [[ -f "$PIDFILE" ]]; then
        kill "$(cat "$PIDFILE")" 2>/dev/null || true
        rm -f "$PIDFILE"
    fi
    rm -f "$DEV/qmp.sock"
}

start() {
    stop
    qemu-system-x86_64 \
        -accel kvm -accel tcg \
        -m 256 \
        -vga std \
        -display none \
        -cdrom "$G/grub.iso" \
        -boot d \
        -qmp "unix:$DEV/qmp.sock,server=on,wait=off" \
        -pidfile "$PIDFILE" \
        -daemonize
    echo "qemu running"
}

case "${1:-}" in
build) build "$2" "$3" ;;
start) start ;;
restart) build "$2" "$3" && start ;;
stop) stop ;;
*)
    echo "usage: $0 build W H|start|restart W H|stop" >&2
    exit 1
    ;;
esac

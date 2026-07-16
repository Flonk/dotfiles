#!/usr/bin/env bash
# Preview the GRUB theme using grub2-theme-preview (QEMU/KVM)
#
# This script sets up a Python venv with grub2-theme-preview and launches it.
# It also needs: qemu, grub-mkrescue, xorriso, mtools, OVMF
#
# Usage:
#   ./preview.sh              # default 1920x1080
#   ./preview.sh 1280x720     # custom resolution
set -euo pipefail
cd "$(dirname "$0")"

RESOLUTION="${1:-1920x1080}"

# Set defaults for generate-assets.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export GRUB_ASCII_ART="${GRUB_ASCII_ART:-${SCRIPT_DIR}/../ascii.txt}"
export GRUB_WIDTH="${GRUB_WIDTH:-${RESOLUTION%x*}}"
export GRUB_HEIGHT="${GRUB_HEIGHT:-${RESOLUTION#*x}}"

# Generate/regenerate assets
echo "Generating assets..."
bash generate-assets.sh

# Set up a Python venv with grub2-theme-preview if not already done
VENV_DIR=".venv"
if [[ ! -f "$VENV_DIR/bin/grub2-theme-preview" ]]; then
    echo "Setting up Python venv with grub2-theme-preview..."
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install grub2-theme-preview
fi

# We need these tools available:
#   grub-mkrescue, qemu-system-x86_64, xorriso, mtools
# On NixOS, enter a nix-shell first or have them in PATH.
MISSING=()
for cmd in qemu-system-x86_64 xorriso mcopy; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done

# Check for grub-mkrescue (or grub2-mkrescue)
MKRESCUE=""
if command -v grub-mkrescue &>/dev/null; then
    MKRESCUE="grub-mkrescue"
elif command -v grub2-mkrescue &>/dev/null; then
    MKRESCUE="grub2-mkrescue"
else
    # Try nix store
    NIX_GRUB=$(nix-build '<nixpkgs>' -A grub2 --no-out-link 2>/dev/null || true)
    if [[ -n "$NIX_GRUB" && -x "$NIX_GRUB/bin/grub-mkrescue" ]]; then
        MKRESCUE="$NIX_GRUB/bin/grub-mkrescue"
        export PATH="$NIX_GRUB/bin:$PATH"
    else
        MISSING+=("grub-mkrescue")
    fi
fi

# Check for OVMF
OVMF_PATH=""
for p in \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/ovmf/OVMF_CODE.fd \
    /run/libvirt/nix-ovmf/OVMF_CODE.fd; do
    if [[ -f "$p" ]]; then
        OVMF_PATH="$p"
        break
    fi
done
if [[ -z "$OVMF_PATH" ]]; then
    # Try nix
    NIX_OVMF=$(nix-build '<nixpkgs>' -A OVMF.fd --no-out-link 2>/dev/null || true)
    if [[ -n "$NIX_OVMF" ]]; then
        OVMF_FOUND=$(find "$NIX_OVMF" -name 'OVMF_CODE.fd' 2>/dev/null | head -1)
        if [[ -n "$OVMF_FOUND" ]]; then
            OVMF_PATH="$OVMF_FOUND"
        fi
    fi
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "ERROR: Missing required tools: ${MISSING[*]}"
    echo ""
    echo "On NixOS, run this first:"
    echo "  nix-shell -p qemu xorriso mtools grub2 OVMF.fd"
    echo ""
    echo "Then re-run: ./preview.sh"
    exit 1
fi

echo "Previewing theme at ${RESOLUTION}..."
echo "(Press Ctrl+C or close QEMU window to exit)"
echo ""

EXTRA_ARGS=()
if [[ -n "$OVMF_PATH" ]]; then
    export G2TP_OVMF_IMAGE="$OVMF_PATH"
fi

# On NixOS the grub lib path isn't in the standard location
if [[ ! -d "/usr/lib/grub" ]]; then
    NIX_GRUB_EFI=$(nix-build '<nixpkgs>' -A grub2_efi --no-out-link 2>/dev/null || true)
    if [[ -n "$NIX_GRUB_EFI" && -d "$NIX_GRUB_EFI/lib/grub" ]]; then
        export G2TP_GRUB_LIB="$NIX_GRUB_EFI/lib/grub"
        # Also ensure grub-mkrescue from the EFI package is used
        export PATH="$NIX_GRUB_EFI/bin:$PATH"
    fi
fi

"$VENV_DIR/bin/grub2-theme-preview" \
    --resolution "$RESOLUTION" \
    --timeout 30 \
    "${EXTRA_ARGS[@]}" \
    .

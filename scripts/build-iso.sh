#!/bin/sh
# build-iso.sh — Build a custom Guix System ISO with nonguix drivers.
#
# This produces a bootable ISO that includes the proprietary NVIDIA
# kernel and firmware, so you can install/recover without needing a
# working internet connection first.
#
# Usage:
#   ./scripts/build-iso.sh [output-dir]
#
# The ISO will be written to OUTPUT_DIR (default: /tmp/edict-iso/).

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$CONFIG_DIR/modules"
OUTPUT_DIR="${1:-/tmp/edict-iso}"

# Read substitute URLs from the shared file
SUBSTITUTE_URLS=""
if [ -f "$CONFIG_DIR/substitute-urls.txt" ]; then
    SUBSTITUTE_URLS=$(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "$CONFIG_DIR/substitute-urls.txt" | tr '\n' ' ')
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║  edict — Building custom Guix System ISO         ║"
echo "║  Output: $OUTPUT_DIR"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Config dir:  $CONFIG_DIR"
echo "  Modules dir: $MODULES_DIR"
echo "  Substitutes: $SUBSTITUTE_URLS"
echo ""

mkdir -p "$OUTPUT_DIR"

# Build the ISO image.
# The installer.scm file defines a minimal operating-system with the
# nonguix kernel and NVIDIA drivers pre-loaded.
sudo -E guix system image \
    --image-type=iso9660 \
    --substitute-urls="$SUBSTITUTE_URLS" \
    --cores="$(nproc)" \
    --fallback \
    -L "$MODULES_DIR" \
    "$MODULES_DIR/edict/systems/installer.scm" \
    -r "$OUTPUT_DIR/edict-install.iso"

echo ""
echo "✓ ISO built successfully: $OUTPUT_DIR/edict-install.iso"
echo ""
echo "  Flash to USB with:"
echo "    sudo dd if=$OUTPUT_DIR/edict-install.iso of=/dev/sdX bs=4M status=progress"

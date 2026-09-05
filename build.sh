#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/out"
WORK_DIR="${SCRIPT_DIR}/work"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    echo "Usage: sudo ./build.sh"
    exit 1
fi

echo "Cleaning previous build..."
rm -rf "$WORK_DIR" "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Building RSX ISO..."
mkarchiso -v -w "$WORK_DIR" -o "$OUTPUT_DIR" "$SCRIPT_DIR"

echo ""
echo "Build complete! ISO is at:"
ls -lh "$OUTPUT_DIR"/*.iso

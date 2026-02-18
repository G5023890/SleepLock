#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_PNG="${1:-/Users/grigorymordokhovich/Downloads/icon.png}"
ICONSET_DIR="$PROJECT_DIR/dist/AppIcon.iconset"
OUTPUT_ICNS="$PROJECT_DIR/AppIcon.icns"

if [[ ! -f "$SOURCE_PNG" ]]; then
  echo "Source PNG not found: $SOURCE_PNG" >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR"

for size in 16 32 64 128 256 512; do
  sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

echo "Generated: $OUTPUT_ICNS"

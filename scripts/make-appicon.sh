#!/bin/bash
# Sinh Support/AppIcon.icns từ cartoon.png (squircle 1024px → đủ mọi cỡ).
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build Support
swift scripts/render-appicon.swift cartoon.png build/appicon-1024.png 1024

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

while read -r size name; do
    sips -z "$size" "$size" build/appicon-1024.png --out "$ICONSET/$name" >/dev/null
done <<'EOF'
16 icon_16x16.png
32 icon_16x16@2x.png
32 icon_32x32.png
64 icon_32x32@2x.png
128 icon_128x128.png
256 icon_128x128@2x.png
256 icon_256x256.png
512 icon_256x256@2x.png
512 icon_512x512.png
1024 icon_512x512@2x.png
EOF

iconutil -c icns "$ICONSET" -o Support/AppIcon.icns
echo "OK: Support/AppIcon.icns"

#!/bin/bash
# Build release và đóng gói build/EyeRelax.app (ký ad-hoc để chạy cục bộ).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/EyeRelax.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/EyeRelax "$APP/Contents/MacOS/"
cp Support/Info.plist "$APP/Contents/"

# Resource bundle của SPM (chứa cartoon.png) phải nằm cạnh Resources để
# Bundle.module tìm thấy khi chạy trong .app.
if [ -d .build/release/EyeRelax_EyeRelax.bundle ]; then
    cp -R .build/release/EyeRelax_EyeRelax.bundle "$APP/Contents/Resources/"
fi

# App icon: sinh nếu chưa có.
if [ ! -f Support/AppIcon.icns ]; then
    ./scripts/make-appicon.sh
fi
cp Support/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --deep --sign - "$APP"
echo "OK: $APP"

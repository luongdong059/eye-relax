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

# Resource bundle của SPM (chứa cartoon.png) — bắt buộc phải có. Lấy đường
# dẫn bin thực từ SPM thay vì đoán, và FAIL ngay nếu thiếu: app thiếu bundle
# từng gây crash trên máy người dùng (v0.2.1).
BIN_PATH=$(swift build -c release --show-bin-path)
RESOURCE_BUNDLE="$BIN_PATH/EyeRelax_EyeRelax.bundle"
if [ ! -d "$RESOURCE_BUNDLE" ]; then
    echo "LỖI: không tìm thấy $RESOURCE_BUNDLE" >&2
    exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"

# App icon: sinh nếu chưa có.
if [ ! -f Support/AppIcon.icns ]; then
    ./scripts/make-appicon.sh
fi
cp Support/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --deep --sign - "$APP"
echo "OK: $APP"

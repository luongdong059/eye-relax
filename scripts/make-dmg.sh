#!/bin/bash
# Đóng gói build/EyeRelax.dmg (kèm symlink /Applications để kéo-thả cài đặt).
# Dùng lại build/EyeRelax.app nếu đã có; chưa có thì build.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d build/EyeRelax.app ]; then
    ./scripts/build-app.sh
fi

STAGE=build/dmg-stage
rm -rf "$STAGE" build/EyeRelax.dmg
mkdir -p "$STAGE"
cp -R build/EyeRelax.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Eye Relax" -srcfolder "$STAGE" -ov -format UDZO \
    build/EyeRelax.dmg >/dev/null
rm -rf "$STAGE"
echo "OK: build/EyeRelax.dmg"

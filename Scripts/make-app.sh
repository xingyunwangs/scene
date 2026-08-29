#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="${CONFIGURATION:-release}"
BUILD_DIR="${BUILD_DIR:-.build}"
OUT_DIR="${OUT_DIR:-dist}"
VERSION="${VERSION:-$(tr -d '[:space:]' < VERSION)}"

swift build -c "$CONFIGURATION" --product Scene --build-path "$BUILD_DIR"
BIN_DIR="$(swift build -c "$CONFIGURATION" --product Scene --build-path "$BUILD_DIR" --show-bin-path)"
APP_DIR="$OUT_DIR/Scene.app"
CONTENTS="$APP_DIR/Contents"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/Scene" "$CONTENTS/MacOS/Scene"
chmod +x "$CONTENTS/MacOS/Scene"
cp Resources/Scene.icns "$CONTENTS/Resources/AppIcon.icns"
cp Resources/Scene-Info.plist "$CONTENTS/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$CONTENTS/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP_DIR"
else
  codesign --force --deep --sign - --timestamp=none "$APP_DIR"
fi
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
du -h -d 0 "$APP_DIR"

#!/usr/bin/env bash
# Builds Capt.app from the SwiftPM executable. Usage: Scripts/build.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/Capt.app"
SIGN_IDENTITY="${CAPT_SIGN_IDENTITY:--}"   # "-" = ad-hoc. Set to a Developer ID to keep TCC grants across rebuilds.

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Capt"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Capt"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp NOTICE LICENSE "$APP/Contents/Resources/"   # third-party and source license notices ship with the binary
echo -n "APPL????" > "$APP/Contents/PkgInfo"

codesign --force --sign "$SIGN_IDENTITY" --entitlements Resources/Capt.entitlements \
  --options runtime --timestamp=none "$APP" 2>/dev/null \
  || codesign --force --sign "$SIGN_IDENTITY" --entitlements Resources/Capt.entitlements "$APP"

echo "Built $APP"

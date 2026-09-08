#!/usr/bin/env bash
# Usage: Scripts/package.sh [local|release]
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-local}"
case "$MODE" in local|release) ;; *) echo 'Usage: Scripts/package.sh [local|release]' >&2; exit 1 ;; esac
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'error: bundle version must be X.Y.Z' >&2; exit 1; }
if [ "$MODE" = release ]; then
  : "${CAPT_NOTARY_PROFILE:?Set CAPT_NOTARY_PROFILE to your notarytool Keychain profile}"
  xcrun --find notarytool >/dev/null
  export CAPT_DISTRIBUTION=1
fi
Scripts/build.sh release
APP=build/Capt.app
ARCH=$(lipo -archs "$APP/Contents/MacOS/Capt" | tr ' ' '-')
NAME="Capt-${VERSION}-${ARCH}"
[ "$MODE" = release ] || NAME="${NAME}-local"
mkdir -p build/packages
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/capt-package.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
if [ "$MODE" = release ]; then
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGE/notarize.zip"
  xcrun notarytool submit "$STAGE/notarize.zip" --keychain-profile "$CAPT_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose "$APP"
fi
mkdir "$STAGE/dmg"
ditto "$APP" "$STAGE/dmg/Capt.app"
ln -s /Applications "$STAGE/dmg/Applications"
hdiutil create -volname Capt -srcfolder "$STAGE/dmg" -ov -format UDZO "$STAGE/$NAME.dmg"
if [ "$MODE" = release ]; then
  codesign --force --sign "$CAPT_SIGN_IDENTITY" --timestamp "$STAGE/$NAME.dmg"
  xcrun notarytool submit "$STAGE/$NAME.dmg" --keychain-profile "$CAPT_NOTARY_PROFILE" --wait
  xcrun stapler staple "$STAGE/$NAME.dmg"
  xcrun stapler validate "$STAGE/$NAME.dmg"
fi
ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGE/$NAME.zip"
mv "$STAGE/$NAME.dmg" "$STAGE/$NAME.zip" build/packages/
(cd build/packages && shasum -a 256 "$NAME.dmg" "$NAME.zip" > "$NAME.sha256")
echo "Packaged build/packages/$NAME.{dmg,zip,sha256}"

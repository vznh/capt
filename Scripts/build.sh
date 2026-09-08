#!/usr/bin/env bash
# Builds Capt.app from the SwiftPM executable. Usage: Scripts/build.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
case "$CONFIG" in debug|release) ;; *) echo 'Usage: Scripts/build.sh [debug|release]' >&2; exit 1 ;; esac
APP="build/Capt.app"

# Signing identity resolution, in order of stability:
#   1. Explicit CAPT_SIGN_IDENTITY override (certificate name or SHA-1 hash).
#   2. Auto-selected keychain identity: Developer ID Application, then Apple
#      Development. A stable identity keeps the TCC grant across rebuilds
#      (TN3127): ad-hoc identities change on every build, so macOS re-asks
#      the System Audio Recording permission each time.
#   3. Ad-hoc ("-"). Allowed, but warned about: privacy permissions will be
#      requested again after every rebuild.
resolve_sign_identity() {
  # Explicit override wins, verbatim. "-" means ad-hoc on purpose.
  local req="${CAPT_SIGN_IDENTITY:-}"
  if [ -n "$req" ]; then
    printf '%s' "$req"
    return
  fi

  local identities hash
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  # Prefer Developer ID Application, then Apple Development. No names are
  # hardcoded: the certificate description is read from the keychain output.
  for kind in "Developer ID Application" "Apple Development"; do
    hash="$(printf '%s\n' "$identities" \
      | sed -n "s/^[[:space:]]*[0-9][0-9]*) \([0-9A-Fa-f]\{40\}\) \"${kind}:.*$/\1/p" \
      | head -n 1)"
    if [ -n "$hash" ]; then
      printf '%s' "$hash"
      return
    fi
  done

  printf -- '-'
}

SIGN_IDENTITY="$(resolve_sign_identity)"
TIMESTAMP=--timestamp=none
if [ "${CAPT_DISTRIBUTION:-0}" = 1 ]; then
  # Public downloads require a Developer ID certificate and secure timestamp.
  : "${CAPT_SIGN_IDENTITY:?Set CAPT_SIGN_IDENTITY to a Developer ID Application certificate name}"
  case "$SIGN_IDENTITY" in
    "Developer ID Application: "*) ;;
    *) echo 'error: distribution requires a Developer ID Application certificate name' >&2; exit 1 ;;
  esac
  security find-identity -v -p codesigning | grep -F -- "\"$SIGN_IDENTITY\"" >/dev/null || {
    echo 'error: the requested Developer ID identity is not available in the keychain' >&2; exit 1;
  }
  TIMESTAMP=--timestamp
fi
if [ -z "$SIGN_IDENTITY" ] || [ "$SIGN_IDENTITY" = "-" ]; then
  SIGN_IDENTITY="-"
  echo "warning: Capt.app will be ad-hoc signed (no stable identity selected)." >&2
  echo "warning: privacy permissions may be requested again after each rebuild." >&2
fi
echo "Signing with: $SIGN_IDENTITY" >&2

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Capt"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Capt"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp NOTICE LICENSE "$APP/Contents/Resources/"   # third-party and source license notices ship with the binary
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# Fail loudly rather than silently downgrading: a failed signature means the
# app will not launch correctly, so never continue past it.
if ! codesign --force --sign "$SIGN_IDENTITY" --entitlements Resources/Capt.entitlements \
    --options runtime "$TIMESTAMP" "$APP"; then
  echo "error: signing Capt.app failed with identity '$SIGN_IDENTITY'." >&2
  exit 1
fi

codesign --verify --deep --strict "$APP"
echo "Built $APP"

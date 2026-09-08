#!/usr/bin/env bash
# Build notarized downloads and upload a draft GitHub release for an existing tag.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
TAG="v$VERSION"
command -v gh >/dev/null || { echo 'error: install the GitHub CLI (gh) first' >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo 'error: commit your release changes first' >&2; exit 1; }
[ "$(git rev-parse "$TAG^{commit}")" = "$(git rev-parse HEAD)" ] || {
  echo "error: $TAG must point to HEAD" >&2; exit 1;
}
gh auth status
REMOTE_TAG=$(git ls-remote origin "refs/tags/$TAG" "refs/tags/$TAG^{}")
printf '%s\n' "$REMOTE_TAG" | grep -q "^$(git rev-parse HEAD)[[:space:]]" || {
  echo "error: push $TAG to origin at this commit first" >&2; exit 1;
}
Scripts/package.sh release
ARCH=$(lipo -archs build/Capt.app/Contents/MacOS/Capt | tr ' ' '-')
NAME="Capt-$VERSION-$ARCH"
gh release create "$TAG" --repo vznh/capt --verify-tag --draft --title "Capt $VERSION" \
  --generate-notes "build/packages/$NAME.dmg" "build/packages/$NAME.zip" "build/packages/$NAME.sha256"

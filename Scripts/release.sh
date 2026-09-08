#!/usr/bin/env bash
# Tag the already-pushed version and let GitHub Actions package and publish it.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'error: version must be X.Y.Z' >&2; exit 1; }
TAG="v$VERSION"
[ -z "$(git status --porcelain)" ] || { echo 'error: commit your release changes first' >&2; exit 1; }
HEAD_SHA=$(git rev-parse HEAD)
REMOTE_SHA=$(git ls-remote origin refs/heads/master | cut -f1)
[ "$HEAD_SHA" = "$REMOTE_SHA" ] || {
  echo 'error: push this commit to origin/master before releasing' >&2; exit 1;
}
if git show-ref --verify --quiet "refs/tags/$TAG"; then
  [ "$(git rev-parse "$TAG^{commit}")" = "$HEAD_SHA" ] || {
    echo "error: $TAG already points to another commit; bump the version" >&2; exit 1;
  }
else
  git tag "$TAG" "$HEAD_SHA"
fi
git push origin "refs/tags/$TAG"
echo "Release tag: $TAG"
echo 'Watch packaging: https://github.com/vznh/capt/actions/workflows/package.yml'
echo 'If the tag was already pushed, re-run its existing Actions run to retry packaging.'

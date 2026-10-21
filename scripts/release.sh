#!/bin/zsh
# Builds scro.app, zips it, and publishes a GitHub release.
# Usage: ./scripts/release.sh [version]      (defaults to Info.plist version)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(plutil -extract CFBundleShortVersionString raw Info.plist)}"
TAG="v$VERSION"
ZIP="scro-$VERSION.zip"

./scripts/bundle.sh

mkdir -p dist
rm -f "dist/$ZIP" "dist/$ZIP.sha256"
ditto -c -k --keepParent "scro.app" "dist/$ZIP"
shasum -a 256 "dist/$ZIP" > "dist/$ZIP.sha256"

echo "✅ dist/$ZIP"
echo "   $(cat "dist/$ZIP.sha256")"

if ! gh auth status >/dev/null 2>&1; then
    echo "⚠️  gh is not authenticated — run 'gh auth login', then re-run this script." >&2
    echo "    The zip is ready in dist/ either way." >&2
    exit 1
fi

NOTES="## Install

1. Unzip and move \`scro.app\` to \`/Applications\`
2. First launch: **right-click → Open** (ad-hoc signed, not notarized by Apple)
   — if macOS reports *\"damaged\"*, run:
   \`xattr -dr com.apple.quarantine /Applications/scro.app\`
3. Optional CLI (one command):
   \`/Applications/scro.app/Contents/MacOS/scro-cli install-cli\`

Verify the download with \`$ZIP.sha256\`.

## Captures

Screenshots land in \`~/Library/Application Support/scro/captures/\`
(last 50 kept). Originals stay wherever macOS saves them."

if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" "dist/$ZIP" "dist/$ZIP.sha256" --clobber
    echo "✅ Uploaded assets to existing release $TAG"
else
    gh release create "$TAG" "dist/$ZIP" "dist/$ZIP.sha256" \
        --title "scro $TAG" --notes "$NOTES"
    echo "✅ Created release $TAG"
fi

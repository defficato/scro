#!/bin/zsh
# Builds scro.app, packages a DMG (primary) + zip (fallback), and publishes a
# GitHub release. Usage: ./scripts/release.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(plutil -extract CFBundleShortVersionString raw Info.plist)}"
TAG="v$VERSION"
APP="scro.app"
DMG="scro-$VERSION.dmg"
ZIP="scro-$VERSION.zip"

./scripts/bundle.sh

mkdir -p dist
rm -f "dist/$DMG" "dist/$DMG.sha256" "dist/$ZIP" "dist/$ZIP.sha256"

# DMG: app + /Applications symlink → drag-to-install.
STAGING="dist/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/$APP"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "scro $VERSION" -srcfolder "$STAGING" -ov -format UDZO "dist/$DMG" >/dev/null
rm -rf "$STAGING"
shasum -a 256 "dist/$DMG" > "dist/$DMG.sha256"

# Zip fallback for scripted installs.
ditto -c -k --keepParent "$APP" "dist/$ZIP"
shasum -a 256 "dist/$ZIP" > "dist/$ZIP.sha256"

echo "✅ dist/$DMG"
echo "✅ dist/$ZIP"

if ! gh auth status >/dev/null 2>&1; then
    echo "⚠️  gh is not authenticated — run 'gh auth login', then re-run this script." >&2
    echo "    The packages are ready in dist/ either way." >&2
    exit 1
fi

NOTES="## Install (DMG)

1. Open \`$DMG\`
2. Drag **scro** into **Applications**
3. First launch: **right-click → Open** (ad-hoc signed, not notarized by Apple)
   — if macOS reports *\"damaged\"*, run:
   \`xattr -dr com.apple.quarantine /Applications/scro.app\`
4. Optional CLI (one command):
   \`/Applications/scro.app/Contents/MacOS/scro-cli install-cli\`

A \`$ZIP\` is attached too for scripted installs. Verify downloads with the
\`.sha256\` files.

## Captures

Screenshots land in \`~/Library/Application Support/scro/captures/\`
(last 50 kept). Originals stay wherever macOS saves them."

if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" "dist/$DMG" "dist/$DMG.sha256" "dist/$ZIP" "dist/$ZIP.sha256" --clobber
    gh release edit "$TAG" --title "scro $TAG" --notes "$NOTES"
    echo "✅ Updated release $TAG"
else
    gh release create "$TAG" "dist/$DMG" "dist/$DMG.sha256" "dist/$ZIP" "dist/$ZIP.sha256" \
        --title "scro $TAG" --notes "$NOTES"
    echo "✅ Created release $TAG"
fi

#!/bin/zsh
# Builds scro and installs/upgrades it in /Applications (one command).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="scro.app"
DEST="/Applications/$APP"

./scripts/bundle.sh

if [ ! -w "/Applications" ]; then
    echo "❌ /Applications is not writable by this user." >&2
    exit 1
fi

# Stop a running copy before replacing the bundle.
pkill -f "$DEST/Contents/MacOS/SCRO" 2>/dev/null || true
sleep 1

rm -rf "$DEST"
ditto "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
codesign --verify --deep --strict "$DEST"

# Keep the CLI symlink pointing at the installed bundle.
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
ln -sf "$DEST/Contents/MacOS/scro-cli" "$BIN_DIR/scro"

open "$DEST"

echo "✅ Installed $(plutil -extract CFBundleShortVersionString raw Info.plist) → $DEST"
echo "   CLI: $BIN_DIR/scro"

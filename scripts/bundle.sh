#!/bin/zsh
# Builds scro (app + CLI) and wraps it into a runnable scro.app (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product SCRO
swift build -c release --product scro-cli

# Icons are generated, not committed — build them on demand.
if [ ! -f "AppIcon.icns" ]; then
    ./scripts/make-icon.sh
fi

APP="scro.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/SCRO" "$APP/Contents/MacOS/SCRO"
cp ".build/release/scro-cli" "$APP/Contents/MacOS/scro-cli"
cp "Info.plist" "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc sign so it launches on Apple Silicon.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✅ Built $APP (app + scro-cli in Contents/MacOS)"
echo "Run app:  open $APP"
echo "CLI:      ./scripts/install-cli.sh, then use \`scro\`"

#!/bin/zsh
# Symlinks the scro CLI (bundled inside scro.app) into ~/.local/bin as `scro`.
set -euo pipefail
cd "$(dirname "$0")/.."

CLI="$PWD/scro.app/Contents/MacOS/scro-cli"
if [ ! -x "$CLI" ]; then
    echo "scro.app not built yet — run ./scripts/bundle.sh first" >&2
    exit 1
fi

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
ln -sf "$CLI" "$BIN_DIR/scro"
echo "✅ scro CLI → $BIN_DIR/scro"

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo "⚠️  $BIN_DIR is not on your PATH — add this to ~/.zshrc:"
        echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

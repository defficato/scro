#!/bin/zsh
# Regenerates AppIcon.icns from scripts/IconGen.swift (Core Graphics, no design tools).
set -euo pipefail
cd "$(dirname "$0")/.."

swift scripts/IconGen.swift
iconutil -c icns build/AppIcon.iconset -o AppIcon.icns

echo "✅ AppIcon.icns"

#!/bin/bash
# VA-11 Hall-A 64-bit runner uninstaller (macOS)
# Restores the original 32-bit Mac_Runner as the app entry point.
set -euo pipefail

DEFAULT_APP="$HOME/Library/Application Support/Steam/steamapps/common/VA-11 HALL-A/VA-11 Hall-A Cyberpunk Bartender Action.app"
APP="${1:-$DEFAULT_APP}"

if [ ! -f "$APP/Contents/Info.plist.va11-orig" ]; then
    echo "error: no backup found (Info.plist.va11-orig); nothing to restore." >&2
    exit 1
fi

cp "$APP/Contents/Info.plist.va11-orig" "$APP/Contents/Info.plist"
rm -f "$APP/Contents/MacOS/butterscotch"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1

echo "Restored the original runner. The game launches as the stock 32-bit build again."
echo "Save files in ~/Library/Application Support/VA_11_Hall_A/saves/ were left untouched."

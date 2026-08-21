#!/bin/bash
# VA-11 Hall-A 64-bit runner installer (macOS)
# Replaces the 32-bit GMS1.4 Mac_Runner in the Steam app with the Butterscotch-based
# 64-bit runner. Game data stays untouched; your copy of the game is required.
set -euo pipefail

DEFAULT_APP="$HOME/Library/Application Support/Steam/steamapps/common/VA-11 HALL-A/VA-11 Hall-A Cyberpunk Bartender Action.app"
APP="${1:-$DEFAULT_APP}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "VA-11 Hall-A 64-bit runner installer"
echo "Target app: $APP"

if [ ! -d "$APP" ]; then
    echo "error: app not found. Pass the path to 'VA-11 Hall-A Cyberpunk Bartender Action.app' as the first argument." >&2
    exit 1
fi
if [ ! -f "$APP/Contents/Resources/game.ios" ]; then
    echo "error: game.ios not found inside the app; is this the Steam release of VA-11 Hall-A?" >&2
    exit 1
fi
if [ ! -f "$SCRIPT_DIR/butterscotch" ]; then
    echo "error: butterscotch binary missing next to install.sh; re-extract the downloaded archive." >&2
    exit 1
fi

# One-time backups so uninstall.sh can restore the original state.
if [ ! -f "$APP/Contents/Info.plist.va11-orig" ]; then
    cp "$APP/Contents/Info.plist" "$APP/Contents/Info.plist.va11-orig"
    echo "backed up Info.plist"
fi

cp "$SCRIPT_DIR/butterscotch" "$APP/Contents/MacOS/butterscotch"
chmod +x "$APP/Contents/MacOS/butterscotch"
/usr/libexec/PlistBuddy -c "Set CFBundleExecutable butterscotch" "$APP/Contents/Info.plist"
echo "installed runner (CFBundleExecutable=butterscotch)"

# The original Mac_Runner is left in place; uninstall.sh restores the entry point.

# Ad-hoc re-sign the bundle (required after modifying an app on macOS).
codesign --force --deep --sign - "$APP" >/dev/null 2>&1
echo "re-signed (ad-hoc)"

# Save files live in the Steam AutoCloud directory so Steam Cloud can sync them.
# Migrate any existing saves written by the original runner (inside the app bundle).
CLOUD_SAVES="$HOME/Library/Application Support/VA_11_Hall_A/saves"
mkdir -p "$CLOUD_SAVES"
if [ -d "$APP/Contents/Resources/saves" ]; then
    for f in "$APP/Contents/Resources/saves/"*; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        if [ ! -f "$CLOUD_SAVES/$base" ]; then
            cp "$f" "$CLOUD_SAVES/$base"
            echo "migrated save: $base"
        fi
    done
fi

echo ""
echo "Done. Launch the game from Steam as usual - it now runs natively on 64-bit macOS."
echo "Saves: $CLOUD_SAVES (synced by Steam Cloud when the game is launched through Steam)."

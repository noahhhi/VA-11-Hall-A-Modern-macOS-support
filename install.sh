#!/bin/bash
# VA-11 Hall-A 64-bit runner installer (macOS)
# Replaces the 32-bit GMS1.4 Mac_Runner in the Steam app with the Butterscotch-based
# 64-bit runner. The bundled binary is universal (arm64 + x86_64); macOS picks the
# right slice automatically. Game data stays untouched; your copy of the game is required.
set -euo pipefail

APP_NAME="VA-11 Hall-A Cyberpunk Bartender Action.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "VA-11 Hall-A 64-bit runner installer"
echo ""

# --- Locate the game: explicit arg > every Steam library > default path ---
find_app() {
    local candidate
    # All Steam library folders (main library + any additional ones, e.g. external drives)
    local vdf="$HOME/Library/Application Support/Steam/config/libraryfolders.vdf"
    if [ -f "$vdf" ]; then
        while IFS= read -r lib; do
            candidate="$lib/steamapps/common/VA-11 HALL-A/$APP_NAME"
            [ -d "$candidate" ] && { echo "$candidate"; return 0; }
        done < <(sed -n 's/.*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$vdf")
    fi
    candidate="$HOME/Library/Application Support/Steam/steamapps/common/VA-11 HALL-A/$APP_NAME"
    [ -d "$candidate" ] && { echo "$candidate"; return 0; }
    return 1
}

if [ $# -ge 1 ]; then
    APP="$1"
else
    APP="$(find_app || true)"
fi

if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
    echo "error: could not find '$APP_NAME' in any Steam library." >&2
    echo "If your game is installed elsewhere, drag the .app onto this script," >&2
    echo "or run: ./install.sh \"/path/to/$APP_NAME\"" >&2
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

echo "Target app: $APP"

# --- Sanity check: the binary must contain a slice for this machine ---
ARCH="$(uname -m)"
if ! lipo -info "$SCRIPT_DIR/butterscotch" 2>/dev/null | grep -q "$ARCH"; then
    echo "error: the bundled runner has no $ARCH slice; re-download the universal package." >&2
    exit 1
fi

# One-time backup so uninstall.sh can restore the original state. Never back up an
# already-patched plist (that would make uninstall.sh "restore" the patched state).
CURRENT_EXEC="$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "$APP/Contents/Info.plist" 2>/dev/null || echo "")"
if [ ! -f "$APP/Contents/Info.plist.va11-orig" ]; then
    if [ "$CURRENT_EXEC" != "butterscotch" ]; then
        cp "$APP/Contents/Info.plist" "$APP/Contents/Info.plist.va11-orig"
        echo "backed up Info.plist"
    else
        echo "note: app is already patched and no original backup exists; skipping backup"
    fi
fi

cp "$SCRIPT_DIR/butterscotch" "$APP/Contents/MacOS/butterscotch"
chmod +x "$APP/Contents/MacOS/butterscotch"
/usr/libexec/PlistBuddy -c "Set CFBundleExecutable butterscotch" "$APP/Contents/Info.plist"
echo "installed runner (CFBundleExecutable=butterscotch)"

# The original Mac_Runner is left in place; uninstall.sh restores the entry point.

# Strip the quarantine flag from the file we just installed (the archive came from
# a browser download), then ad-hoc re-sign the bundle as macOS requires after edits.
xattr -d com.apple.quarantine "$APP/Contents/MacOS/butterscotch" 2>/dev/null || true
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

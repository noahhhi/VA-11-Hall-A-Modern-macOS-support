#!/bin/bash
# Restores the Steam app state saved by install.sh. Save files are retained.
set -euo pipefail

APP_NAME="VA-11 Hall-A Cyberpunk Bartender Action.app"
TARGET_HOME="${VA11_TARGET_HOME:-$HOME}"

find_app() {
    local candidate lib vdf
    vdf="$TARGET_HOME/Library/Application Support/Steam/config/libraryfolders.vdf"
    if [ -f "$vdf" ]; then
        while IFS= read -r lib; do
            candidate="$lib/steamapps/common/VA-11 HALL-A/$APP_NAME"
            [ -d "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
        done < <(sed -n 's/.*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$vdf")
    fi
    candidate="$TARGET_HOME/Library/Application Support/Steam/steamapps/common/VA-11 HALL-A/$APP_NAME"
    [ -d "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
    return 1
}

APP="${1:-$(find_app || true)}"
[ -n "$APP" ] && [ -d "$APP" ] || { echo "error: VA-11 Hall-A Steam app not found" >&2; exit 1; }
BACKUP_DIR="$APP.va11-64bit-backup"

if [ -d "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/Info.plist" ]; then
    cp -p "$BACKUP_DIR/Info.plist" "$APP/Contents/Info.plist"
    if [ -d "$BACKUP_DIR/files" ]; then
        while IFS= read -r -d '' saved; do
            relative="${saved#"$BACKUP_DIR/files/"}"
            destination="$APP/$relative"
            mkdir -p "$(dirname "$destination")"
            cp -p "$saved" "$destination"
        done < <(find "$BACKUP_DIR/files" -type f -print0)
    fi
    rm -f "$APP/Contents/MacOS/butterscotch" "$APP/Contents/Info.plist.va11-orig"
    if [ -d "$BACKUP_DIR/_CodeSignature" ]; then
        rm -rf "$APP/Contents/_CodeSignature"
        cp -Rp "$BACKUP_DIR/_CodeSignature" "$APP/Contents/_CodeSignature"
        if codesign --verify --deep --strict "$APP" 2>/dev/null; then
            echo "Restored the byte-preserved Steam runner and signature."
        else
            echo "warning: original files were restored, but signature verification failed; use Steam 'Verify integrity of game files' if needed." >&2
        fi
    else
        codesign --force --deep --sign - "$APP" >/dev/null
        codesign --verify --deep --strict "$APP"
        echo "Restored the legacy Steam entry point and applied an ad-hoc signature."
    fi
elif [ -f "$APP/Contents/Info.plist.va11-orig" ]; then
    # Compatibility fallback for v1 packages that saved only Info.plist.
    cp -p "$APP/Contents/Info.plist.va11-orig" "$APP/Contents/Info.plist"
    rm -f "$APP/Contents/MacOS/butterscotch"
    codesign --force --deep --sign - "$APP" >/dev/null
    echo "Restored the original entry point from the legacy backup."
else
    echo "error: no VA-11 Hall-A 64-bit backup was found; nothing was changed." >&2
    exit 1
fi

echo "Save files in $TARGET_HOME/Library/Application Support/VA_11_Hall_A/saves were left untouched."

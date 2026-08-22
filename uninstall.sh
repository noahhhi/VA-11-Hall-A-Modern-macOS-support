#!/bin/bash
# Restores the Steam app state saved by install.sh. Save files are retained.
set -euo pipefail

APP_NAME="VA-11 Hall-A Cyberpunk Bartender Action.app"
TARGET_HOME="${VA11_TARGET_HOME:-$HOME}"

detect_language() {
    local preferred="${VA11_LANGUAGE:-}"
    if [ -z "$preferred" ] && [ -f "$TARGET_HOME/Library/Preferences/.GlobalPreferences.plist" ]; then
        preferred="$(plutil -extract AppleLanguages.0 raw "$TARGET_HOME/Library/Preferences/.GlobalPreferences.plist" 2>/dev/null || true)"
    fi
    if [ -z "$preferred" ]; then
        preferred="${LANG:-en}"
    fi
    case "$preferred" in
        zh*|ZH*) printf '%s\n' "zh" ;;
        *) printf '%s\n' "en" ;;
    esac
}

LANGUAGE_CODE="$(detect_language)"

msg() {
    if [ "$LANGUAGE_CODE" = "zh" ]; then
        printf '%s\n' "$2"
    else
        printf '%s\n' "$1"
    fi
}

device_architecture() {
    local translated="0"
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = "1" ]; then
        translated="$(sysctl -in sysctl.proc_translated 2>/dev/null || true)"
        if [ "$translated" = "1" ]; then
            msg "Apple Silicon (arm64; uninstaller running through Rosetta)" "Apple Silicon（arm64；卸载器当前通过 Rosetta 运行）"
        else
            msg "Apple Silicon (arm64)" "Apple Silicon（arm64）"
        fi
    else
        case "$(uname -m)" in
            x86_64) msg "Intel (x86_64)" "Intel（x86_64）" ;;
            *) msg "$(uname -m)" "$(uname -m)" ;;
        esac
    fi
}

fail() {
    if [ "$LANGUAGE_CODE" = "zh" ]; then
        printf '错误：%s\n' "$2" >&2
    else
        printf 'error: %s\n' "$1" >&2
    fi
    exit 1
}

msg "Device processor architecture: $(device_architecture)" "当前设备处理器架构：$(device_architecture)"

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
[ -n "$APP" ] && [ -d "$APP" ] || fail "VA-11 Hall-A Steam app not found" "未找到 Steam 版 VA-11 Hall-A"
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
            msg "Restored the byte-preserved Steam runner and signature." "已恢复逐字节留存的 Steam runner 与签名。"
        else
            msg "Warning: original files were restored, but signature verification failed; use Steam 'Verify integrity of game files' if needed." "警告：原始文件已恢复，但签名验证失败；如有需要，请在 Steam 中验证游戏文件完整性。" >&2
        fi
    else
        codesign --force --deep --sign - "$APP" >/dev/null
        codesign --verify --deep --strict "$APP"
        msg "Restored the legacy Steam entry point and applied an ad-hoc signature." "已恢复旧版 Steam 入口并应用 ad-hoc 签名。"
    fi
elif [ -f "$APP/Contents/Info.plist.va11-orig" ]; then
    # Compatibility fallback for v1 packages that saved only Info.plist.
    cp -p "$APP/Contents/Info.plist.va11-orig" "$APP/Contents/Info.plist"
    rm -f "$APP/Contents/MacOS/butterscotch"
    codesign --force --deep --sign - "$APP" >/dev/null
    msg "Restored the original entry point from the legacy backup." "已从旧版备份恢复原始入口。"
else
    fail "no VA-11 Hall-A 64-bit backup was found; nothing was changed" "未找到 VA-11 Hall-A 64 位备份；未进行任何更改"
fi

msg "Save files in $TARGET_HOME/Library/Application Support/VA_11_Hall_A/saves were left untouched." "未更改 $TARGET_HOME/Library/Application Support/VA_11_Hall_A/saves 中的存档。"

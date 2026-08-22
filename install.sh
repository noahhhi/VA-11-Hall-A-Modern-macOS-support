#!/bin/bash
# VA-11 Hall-A 64-bit runner installer (macOS). Game data is never modified.
# App-bundle mutations are transactional and reversible.
set -euo pipefail

APP_NAME="VA-11 Hall-A Cyberpunk Bartender Action.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER_SOURCE="$SCRIPT_DIR/butterscotch"
TARGET_HOME="${VA11_TARGET_HOME:-$HOME}"
MIN_MACOS_MAJOR=11

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
            msg "Apple Silicon (arm64; installer running through Rosetta)" "Apple Silicon（arm64；安装器当前通过 Rosetta 运行）"
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

msg "VA-11 Hall-A 64-bit runner installer" "VA-11 Hall-A 64 位 runner 安装程序"
echo ""

find_app() {
    local candidate lib vdf
    vdf="$TARGET_HOME/Library/Application Support/Steam/config/libraryfolders.vdf"
    if [ -f "$vdf" ]; then
        while IFS= read -r lib; do
            [ -n "$lib" ] || continue
            candidate="$lib/steamapps/common/VA-11 HALL-A/$APP_NAME"
            if [ -d "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done < <(sed -n 's/.*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$vdf")
    fi

    candidate="$TARGET_HOME/Library/Application Support/Steam/steamapps/common/VA-11 HALL-A/$APP_NAME"
    if [ -d "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    return 1
}

[ "$(uname -s)" = "Darwin" ] || fail "this installer supports macOS only" "此安装程序仅支持 macOS"
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
[ "$MACOS_MAJOR" -ge "$MIN_MACOS_MAJOR" ] || fail "macOS $MIN_MACOS_MAJOR or newer is required (found $MACOS_VERSION)" "需要 macOS $MIN_MACOS_MAJOR 或更高版本（当前为 ${MACOS_VERSION}）"
echo "macOS: $MACOS_VERSION"
msg "Device processor architecture: $(device_architecture)" "当前设备处理器架构：$(device_architecture)"

if [ $# -ge 1 ]; then
    APP="${1%/}"
else
    APP="$(find_app || true)"
fi

if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
    fail "could not find '$APP_NAME' in any Steam library. Drag the game app onto the .command file, or reinstall it in Steam." "未在任何 Steam 库中找到 '$APP_NAME'。请把游戏 app 拖到 .command 文件上，或通过 Steam 重新安装游戏。"
fi
[ -f "$APP/Contents/Info.plist" ] || fail "Info.plist is missing from the selected app" "所选 app 中缺少 Info.plist"
[ -f "$APP/Contents/Resources/game.ios" ] || fail "game.ios is missing; select the Steam release of VA-11 Hall-A" "缺少 game.ios；请选择 Steam 版 VA-11 Hall-A"
[ -f "$RUNNER_SOURCE" ] || fail "butterscotch is missing next to install.sh; download the complete package" "install.sh 旁缺少 butterscotch；请下载完整发布包"

msg "Target: $APP" "目标：$APP"

RUNNER_ARCHS="$(lipo -archs "$RUNNER_SOURCE" 2>/dev/null || true)"
case " $RUNNER_ARCHS " in *" arm64 "*) ;; *) fail "bundled runner is missing the arm64 slice" "随附 runner 缺少 arm64 切片" ;; esac
case " $RUNNER_ARCHS " in *" x86_64 "*) ;; *) fail "bundled runner is missing the x86_64 slice" "随附 runner 缺少 x86_64 切片" ;; esac
msg "Runner architectures: $RUNNER_ARCHS" "Runner 架构：$RUNNER_ARCHS"

# A normal Steam library is user-writable. Protected or external libraries get
# one standard macOS administrator dialog; no credential is stored or logged.
if [ ! -w "$APP/Contents/MacOS" ] || [ ! -w "$APP/Contents/Info.plist" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        msg "Administrator permission is required for this Steam library." "此 Steam 库需要管理员权限。"
        osascript - "$SCRIPT_DIR/install.sh" "$APP" "$TARGET_HOME" "$LANGUAGE_CODE" <<'APPLESCRIPT'
on run argv
    set installerPath to item 1 of argv
    set appPath to item 2 of argv
    set targetHome to item 3 of argv
    set languageCode to item 4 of argv
    set commandText to "env VA11_TARGET_HOME=" & quoted form of targetHome & " VA11_LANGUAGE=" & quoted form of languageCode & " " & quoted form of installerPath & " " & quoted form of appPath
    do shell script commandText with administrator privileges
end run
APPLESCRIPT
        exit 0
    fi
fi

APP_UID="$(stat -f '%u' "$APP")"
APP_GID="$(stat -f '%g' "$APP")"
TARGET_UID="$(stat -f '%u' "$TARGET_HOME")"
TARGET_GID="$(stat -f '%g' "$TARGET_HOME")"
BACKUP_DIR="$APP.va11-64bit-backup"
TXN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/va11-install.XXXXXX")"
TXN_ACTIVE=1

copy_with_parents() {
    local source="$1" root="$2" destination="$3" relative
    relative="${source#"$root"/}"
    mkdir -p "$destination/$(dirname "$relative")"
    cp -p "$source" "$destination/$relative"
}

restore_transaction() {
    set +e
    msg "Installation failed; restoring the previous app state..." "安装失败，正在恢复之前的 app 状态……" >&2
    cp -p "$TXN_DIR/Info.plist" "$APP/Contents/Info.plist"
    if [ -f "$TXN_DIR/butterscotch" ]; then
        cp -p "$TXN_DIR/butterscotch" "$APP/Contents/MacOS/butterscotch"
    else
        rm -f "$APP/Contents/MacOS/butterscotch"
    fi
    if [ -d "$TXN_DIR/code" ]; then
        while IFS= read -r -d '' saved; do
            relative="${saved#"$TXN_DIR/code/"}"
            destination="$APP/$relative"
            mkdir -p "$(dirname "$destination")"
            cp -p "$saved" "$destination"
        done < <(find "$TXN_DIR/code" -type f -print0)
    fi
    if [ -d "$TXN_DIR/_CodeSignature" ]; then
        rm -rf "$APP/Contents/_CodeSignature"
        cp -Rp "$TXN_DIR/_CodeSignature" "$APP/Contents/_CodeSignature"
    fi
    if [ -f "$TXN_DIR/Info.plist.va11-orig" ]; then
        cp -p "$TXN_DIR/Info.plist.va11-orig" "$APP/Contents/Info.plist.va11-orig"
    fi
    chown -R "$APP_UID:$APP_GID" "$APP" 2>/dev/null || true
}

finish() {
    local status=$?
    if [ "$status" -ne 0 ] && [ "$TXN_ACTIVE" -eq 1 ]; then
        restore_transaction
    fi
    rm -rf "$TXN_DIR"
    exit "$status"
}
trap finish EXIT INT TERM

cp -p "$APP/Contents/Info.plist" "$TXN_DIR/Info.plist"
if [ -d "$APP/Contents/_CodeSignature" ]; then
    cp -Rp "$APP/Contents/_CodeSignature" "$TXN_DIR/_CodeSignature"
fi
if [ -f "$APP/Contents/Info.plist.va11-orig" ]; then
    cp -p "$APP/Contents/Info.plist.va11-orig" "$TXN_DIR/Info.plist.va11-orig"
fi
if [ -f "$APP/Contents/MacOS/butterscotch" ]; then
    cp -p "$APP/Contents/MacOS/butterscotch" "$TXN_DIR/butterscotch"
fi
mkdir -p "$TXN_DIR/code"
while IFS= read -r -d '' code; do
    copy_with_parents "$code" "$APP" "$TXN_DIR/code"
done < <(find "$APP/Contents" -type f \( -name '*.dylib' -o -name 'Mac_Runner' \) -print0)

CURRENT_EXEC="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$APP/Contents/Info.plist" 2>/dev/null || true)"

# Preserve the pristine Steam state once, outside the signed app bundle. This
# includes nested code and the original outer signature for byte-exact restore.
if [ "$CURRENT_EXEC" != "butterscotch" ] && [ ! -d "$BACKUP_DIR" ]; then
    BACKUP_TMP="$BACKUP_DIR.tmp.$$"
    mkdir -p "$BACKUP_TMP/files"
    cp -p "$APP/Contents/Info.plist" "$BACKUP_TMP/Info.plist"
    if [ -d "$APP/Contents/_CodeSignature" ]; then
        cp -Rp "$APP/Contents/_CodeSignature" "$BACKUP_TMP/_CodeSignature"
    fi
    while IFS= read -r -d '' code; do
        copy_with_parents "$code" "$APP" "$BACKUP_TMP/files"
    done < <(find "$APP/Contents" -type f \( -name '*.dylib' -o -name 'Mac_Runner' \) -print0)
    mv "$BACKUP_TMP" "$BACKUP_DIR"
    chown -R "$APP_UID:$APP_GID" "$BACKUP_DIR" 2>/dev/null || true
    msg "Created reversible backup" "已创建可回滚备份"
elif [ -f "$APP/Contents/Info.plist.va11-orig" ] && [ ! -d "$BACKUP_DIR" ]; then
    # Upgrade an older project install: migrate its in-bundle plist backup out
    # of the signed app. The nested files are preserved, then ad-hoc signed on
    # uninstall because older packages did not retain the original signature.
    BACKUP_TMP="$BACKUP_DIR.tmp.$$"
    mkdir -p "$BACKUP_TMP/files"
    cp -p "$APP/Contents/Info.plist.va11-orig" "$BACKUP_TMP/Info.plist"
    while IFS= read -r -d '' code; do
        copy_with_parents "$code" "$APP" "$BACKUP_TMP/files"
    done < <(find "$APP/Contents" -type f \( -name '*.dylib' -o -name 'Mac_Runner' \) -print0)
    mv "$BACKUP_TMP" "$BACKUP_DIR"
    chown -R "$APP_UID:$APP_GID" "$BACKUP_DIR" 2>/dev/null || true
    msg "Migrated the legacy backup outside the app bundle" "已将旧版备份迁移到 app 包外"
fi

# Extra plist files inside Contents can be interpreted as unsigned nested code
# by strict codesign verification. The reversible backup now lives beside the
# app, so remove the obsolete in-bundle copy before signing.
rm -f "$APP/Contents/Info.plist.va11-orig"

RUNNER_TMP="$APP/Contents/MacOS/.butterscotch.new.$$"
install -m 755 "$RUNNER_SOURCE" "$RUNNER_TMP"
mv -f "$RUNNER_TMP" "$APP/Contents/MacOS/butterscotch"
/usr/libexec/PlistBuddy -c 'Set CFBundleExecutable butterscotch' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set NSHighResolutionCapable true' "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c 'Add NSHighResolutionCapable bool true' "$APP/Contents/Info.plist"
msg "Installed the universal runner" "已安装通用 runner"

xattr -d com.apple.quarantine "$APP/Contents/MacOS/butterscotch" 2>/dev/null || true

# Replace invalid pre-2016 nested signatures before signing the outer bundle.
while IFS= read -r -d '' code; do
    codesign --force --sign - "$code" >/dev/null
done < <(find "$APP/Contents" -type f \( -name '*.dylib' -o -name 'Mac_Runner' \) -print0)
codesign --force --sign - "$APP/Contents/MacOS/butterscotch" >/dev/null
codesign --force --deep --sign - "$APP" >/dev/null
codesign --verify --deep --strict "$APP"
msg "Verified the ad-hoc code signature" "已验证 ad-hoc 代码签名"

# Migrate only missing files; existing AutoCloud saves always win.
CLOUD_SAVES="$TARGET_HOME/Library/Application Support/VA_11_Hall_A/saves"
mkdir -p "$CLOUD_SAVES"
if [ -d "$APP/Contents/Resources/saves" ]; then
    while IFS= read -r -d '' save; do
        destination="$CLOUD_SAVES/$(basename "$save")"
        if [ ! -e "$destination" ]; then
            cp -p "$save" "$destination"
            msg "Migrated save: $(basename "$save")" "已迁移存档：$(basename "$save")"
        fi
    done < <(find "$APP/Contents/Resources/saves" -maxdepth 1 -type f -print0)
fi

chown "$APP_UID:$APP_GID" "$APP/Contents/MacOS/butterscotch" "$APP/Contents/Info.plist" 2>/dev/null || true
chown -R "$TARGET_UID:$TARGET_GID" "$CLOUD_SAVES" 2>/dev/null || true
TXN_ACTIVE=0

echo ""
msg "Done. Launch VA-11 Hall-A from Steam." "完成。现在可从 Steam 启动 VA-11 Hall-A。"
msg "Saves: $CLOUD_SAVES" "存档：$CLOUD_SAVES"

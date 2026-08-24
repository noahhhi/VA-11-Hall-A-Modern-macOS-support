#!/bin/bash
# Build a flat, double-clickable macOS installer package.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${1:-1.1.0-preview}"
RUNNER="${2:-$REPO_DIR/dist-bin/butterscotch-universal}"
STEAM_API="${3:-$REPO_DIR/vendor/steamworks/redistributable_bin/osx/libsteam_api.dylib}"
OUTPUT_DIR="$REPO_DIR/dist-bin"
OUTPUT="$OUTPUT_DIR/VA-11-Hall-A-64bit-universal.pkg"
PACKAGE_ID="io.github.noahhhi.va11-hall-a-64bit"

fail() {
    echo "error: $*" >&2
    exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "pkgbuild requires macOS"
[ -x "$RUNNER" ] || fail "universal runner not found: $RUNNER"
[ -f "$STEAM_API" ] || fail "official Steamworks runtime not found: $STEAM_API"

RUNNER_ARCHS="$(lipo -archs "$RUNNER" 2>/dev/null || true)"
case " $RUNNER_ARCHS " in *" arm64 "*) ;; *) fail "runner is missing arm64" ;; esac
case " $RUNNER_ARCHS " in *" x86_64 "*) ;; *) fail "runner is missing x86_64" ;; esac
for arch in arm64 x86_64; do
    MINOS="$(otool -arch "$arch" -l "$RUNNER" | awk '/cmd LC_BUILD_VERSION/{found=1; next} found && $1=="minos"{print $2; exit}')"
    [ "$MINOS" = "11.0" ] || fail "runner $arch deployment target is ${MINOS:-unknown}; expected 11.0"
done

STEAM_API_ARCHS="$(lipo -archs "$STEAM_API" 2>/dev/null || true)"
case " $STEAM_API_ARCHS " in *" arm64 "*) ;; *) fail "Steamworks runtime is missing arm64" ;; esac
case " $STEAM_API_ARCHS " in *" x86_64 "*) ;; *) fail "Steamworks runtime is missing x86_64" ;; esac
for symbol in SteamAPI_InitFlat SteamAPI_RunCallbacks SteamAPI_SteamUserStats_v013 SteamAPI_ISteamUserStats_SetAchievement SteamAPI_ISteamUserStats_StoreStats; do
    nm -gU "$STEAM_API" 2>/dev/null | grep " _$symbol$" >/dev/null \
        || fail "Steamworks runtime is missing required symbol: $symbol"
done

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/va11-pkg.XXXXXX")"
cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT INT TERM

PAYLOAD="$STAGE/payload"
SUPPORT="$PAYLOAD/Library/Application Support/VA-11-Hall-A-64bit"
mkdir -p "$SUPPORT" "$OUTPUT_DIR"

COPYFILE_DISABLE=1 install -m 755 "$RUNNER" "$SUPPORT/butterscotch"
COPYFILE_DISABLE=1 install -m 755 "$STEAM_API" "$SUPPORT/libsteam_api.dylib"
COPYFILE_DISABLE=1 install -m 755 "$REPO_DIR/install.sh" "$SUPPORT/install.sh"
COPYFILE_DISABLE=1 install -m 644 "$REPO_DIR/RELEASE_NOTES.md" "$SUPPORT/RELEASE_NOTES.md"
COPYFILE_DISABLE=1 install -m 644 "$REPO_DIR/LICENSE" "$SUPPORT/LICENSE"

# pkgbuild serializes extended attributes as AppleDouble companions. Strip
# download provenance and other local metadata so no ._* files enter the PKG.
xattr -cr "$PAYLOAD"
if find "$PAYLOAD" -name '._*' -print -quit | grep -q .; then
    fail "AppleDouble file found in staged payload"
fi

UNSIGNED="$STAGE/unsigned.pkg"
pkgbuild \
    --root "$PAYLOAD" \
    --scripts "$SCRIPT_DIR/pkg-scripts" \
    --identifier "$PACKAGE_ID" \
    --version "$VERSION" \
    --install-location / \
    "$UNSIGNED"

if pkgutil --payload-files "$UNSIGNED" | grep -Eq '(^|/)\._'; then
    fail "AppleDouble file found in built package"
fi

if [ -n "${PKG_SIGN_IDENTITY:-}" ]; then
    productsign --sign "$PKG_SIGN_IDENTITY" "$UNSIGNED" "$OUTPUT"
else
    cp "$UNSIGNED" "$OUTPUT"
fi
chmod 644 "$OUTPUT"

pkgutil --check-signature "$OUTPUT" || true
echo "Built: $OUTPUT"
echo "Runner architectures: $RUNNER_ARCHS"
echo "Steamworks architectures: $STEAM_API_ARCHS"
if [ -z "${PKG_SIGN_IDENTITY:-}" ]; then
    echo "warning: package is unsigned; set PKG_SIGN_IDENTITY to a Developer ID Installer identity for distribution" >&2
fi

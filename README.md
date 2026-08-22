# VA-11 Hall-A 64-bit Runner for macOS

[![macOS builds](https://github.com/noahhhi/VA-11-Hall-A-64bit/actions/workflows/build-macos.yml/badge.svg)](https://github.com/noahhhi/VA-11-Hall-A-64bit/actions/workflows/build-macos.yml)

<p align="center">
  <a href="README.md">English</a> |
  <a href="README.zh-CN.md">简体中文</a>
</p>

A native 64-bit runner for the macOS Steam release of *VA-11 Hall-A: Cyberpunk Bartender Action*, built on the open-source [Butterscotch](https://github.com/ButterscotchRunner/Butterscotch) GameMaker Studio 1.4 runtime. It replaces the game's original 32-bit `Mac_Runner`, which no longer launches on macOS 10.15 Catalina or later.

Current reference test: Apple Silicon Mac running macOS 27.0, Steam release of VA-11 Hall-A (AppID 447530, `game.ios` bytecode v15). Boot, language select, main menu, settings panel (volume / scanlines / fullscreen), and save files are covered by local testing.

> **Preview:** This package contains only the replacement runner. You must own VA-11 Hall-A on Steam; no game data is included or distributed.

## Requirements

- macOS on Apple Silicon (arm64) or 64-bit Intel (x86_64)
- VA-11 Hall-A installed via Steam (default location: `~/Library/Application Support/Steam/steamapps/common/VA-11 HALL-A/`)

## One-click install

Download `VA-11-Hall-A-64bit-universal.pkg` from [GitHub Releases](https://github.com/noahhhi/VA-11-Hall-A-64bit/releases) and double-click it. The package finds VA-11 Hall-A in all configured Steam libraries, installs the universal arm64/x86_64 runner, preserves a restorable copy of the original runner and signature, repairs the app signature, and migrates only missing saves. No extraction or Terminal commands are required.

The `.command` installer remains as a portable fallback for preview builds: extract `VA-11-Hall-A-64bit-universal.zip`, then double-click `Install VA-11 Hall-A 64bit.command`, or run:

```sh
cd VA-11-Hall-A-64bit-universal
./install.sh
```

The installer reports unsupported macOS versions, missing Steam libraries, malformed app bundles, missing binary architectures, and permission failures without leaving a half-installed runner. Launch the game from Steam as usual after it succeeds.

### Architecture selection

The Release runner is Universal. macOS automatically uses `arm64` on Apple Silicon and `x86_64` on Intel. On Apple Silicon, you can manually test the Intel slice by quitting the game, selecting the game app in Finder, choosing **File → Get Info**, and enabling **Open using Rosetta**. Disable that option to return to native arm64. Native arm64 is recommended for normal play; this choice does not change the Auto rendering policy.

> [!IMPORTANT]
> The runner is ad-hoc signed (re-signed on your machine by `install.sh`). If macOS blocks the first launch, open **System Settings → Privacy & Security** and click **Open Anyway**. You do not need to disable Gatekeeper or reduce system security.

If auto-detection fails (a very unusual install location), drag the game app onto `install.sh`, or pass the path yourself: `./install.sh "/path/to/VA-11 Hall-A Cyberpunk Bartender Action.app"`.

## Saves and Steam Cloud

Save files are written to `~/Library/Application Support/VA_11_Hall_A/saves/` — the directory the game's Steam AutoCloud configuration actually monitors. The original 32-bit runner never used it (it wrote inside the app bundle instead, so Steam Cloud never synced anything). This runner implements the game's `FS_set_gm_save_area` / `FS_set_working_directory` calls, so saves land where Steam expects them:

- Existing saves inside the app bundle are migrated automatically by `install.sh`.
- Launching the game through Steam uploads/downloads this directory as configured by the publisher.

## Uninstall

`uninstall.sh` is included in every Release ZIP and inside the PKG payload. From an extracted ZIP, run:

```sh
./uninstall.sh
```

After installing the PKG, the same script is available at:

```sh
"/Library/Application Support/VA-11-Hall-A-64bit/uninstall.sh"
```

This restores the original `Mac_Runner` entry point from the backup made during installation and re-signs the bundle. Your save files are left untouched.

## What was fixed beyond 64-bit

The upstream Butterscotch runtime needed VA-11-specific fixes, all included in this package:

- GMS1.4 automatic sprite bounding boxes (`bboxMode=0`) computed from texture alpha — fixes broken menu hitboxes (volume buttons, sliders) and click crosstalk.
- HiDPI mouse coordinate translation in the AppKit backend.
- `FS_set_gm_save_area` / `FS_set_working_directory` (used by the game's `_gmfilesystem_initialize`) with `%appdata%` placeholder mapping — enables the save behavior described above.
- Lazy texture loading by default in bundled mode, cutting the GPU memory footprint from ~1.3GB to ~540MB (comparable to the original runner's ~650MB).
- `ds_list_set` and Steam achievement stubs required by this game.
- Automatic HiDPI presentation with no mode selector: exact integer application-surface ratios use bit-exact nearest-neighbor; non-integer magnification uses a single-pass t3ssel8r/SDL-style pixel-art UV remap with an at-most-one-device-pixel boundary transition; minification uses linear filtering. AppKit supplies actual backing-pixel dimensions, and the 16:9 letterbox rectangle is quantized so horizontal and vertical scale match exactly.

## Known limitations

- VA-11 Hall-A composites into a 1280x720 application surface whose artwork is mostly a doubled 640x360 pixel grid. A 2880x1620 16:9 viewport is therefore 2.25x the application surface (4.5x the authored grid), so mathematically hard and perfectly equal source-pixel widths cannot both fill it. Auto limits the compromise to one destination pixel at source boundaries instead of blurring whole texel interiors.
- The scanlines toggle label in the settings panel displays "Off" even when enabled. This is a bug in the game's own logic — the original 32-bit runner behaves identically — and is not a regression of this port.
- Steam achievements are stubbed; gameplay is unaffected.
- Steam Cloud syncs saves between Macs only. The publisher's AutoCloud config keeps Windows, macOS, and Linux saves in separate namespaces, so saves never travel to or from a Steam Deck / Windows PC. The original game behaves the same way; no runner change can alter it.
- Testing cloud sync on a single machine looks like "nothing changed": the cloud copy was uploaded from this machine, so downloading restores identical files. To see it work, delete a file in `~/Library/Application Support/VA_11_Hall_A/saves/` and relaunch — Steam restores it before the game starts.

## Building from source

```sh
# Apple Silicon
make BACKEND=appkit -j4

# Intel 64-bit (cross-compile from Apple Silicon)
make BACKEND=appkit CFLAGS="-arch x86_64" LDFLAGS="-arch x86_64" -j4
```

See [README.upstream.md](README.upstream.md) for the full Butterscotch build documentation.
The full diagnosis, screenshots, and pixel metrics are in [HIDPI_RENDERING_REPORT.md](HIDPI_RENDERING_REPORT.md).

## License and credits

This project is a modified build of [Butterscotch](https://github.com/ButterscotchRunner/Butterscotch), licensed under the [GNU Affero General Public License v3](LICENSE), which this distribution retains. *VA-11 Hall-A* is a game by Sukeban Games; this project is an unofficial compatibility effort and distributes no game assets.

# VA-11 Hall-A 64-bit Runner for macOS

[![macOS builds](https://github.com/noahhhi/VA-11-Hall-A-64bit/actions/workflows/build-macos.yml/badge.svg)](https://github.com/noahhhi/VA-11-Hall-A-64bit/actions/workflows/build-macos.yml)

<p align="center">
  <a href="README.md">English</a> |
  <a href="README.zh-CN.md">简体中文</a>
</p>

A native 64-bit runner for the macOS Steam release of *VA-11 Hall-A: Cyberpunk Bartender Action*, built on the open-source GameMaker Studio 1.4 runner [Butterscotch](https://github.com/ButterscotchRunner/Butterscotch). It replaces the game's original 32-bit `Mac_Runner`, which cannot launch on macOS 10.15 Catalina or later.

Current reference test: Apple Silicon Mac running macOS 27.0, Steam release of VA-11 Hall-A (AppID 447530, `game.ios` bytecode v15). Boot, bartending, the settings panel (volume / scanlines / fullscreen), and save files are covered by local testing.

> **Note:** The installer contains fixes only. You must own VA-11 Hall-A on Steam; this repository does not include or distribute the game.

## Requirements

- macOS on Apple Silicon (arm64) or 64-bit Intel (x86_64)
- VA-11 Hall-A installed via Steam (default location: `~/Library/Application Support/Steam/steamapps/common/VA-11 HALL-A/`)

## One-click install

Download `VA-11-Hall-A-64bit-universal.pkg` from [GitHub Releases](https://github.com/noahhhi/VA-11-Hall-A-64bit/releases) and double-click it. The package searches every configured Steam library, installs the universal arm64/x86_64 runner and Valve's official Steamworks runtime, updates the app entry point, and re-signs the bundle. A restorable copy of the original runner and signature is kept outside the app.

The `.command` installer remains as a portable fallback for preview builds: extract `VA-11-Hall-A-64bit-universal.zip`, then double-click `Install VA-11 Hall-A 64bit.command`, or run:

```sh
cd VA-11-Hall-A-64bit-universal
./install.sh
```

The installer reports unsupported macOS versions, missing Steam libraries, malformed app bundles, missing component architectures, and permission failures. If installation fails, it rolls back automatically instead of leaving the app in an invalid state. Launch the game from Steam as usual after it succeeds.

> [!IMPORTANT]
> The runner is ad-hoc signed (re-signed on your machine by `install.sh`). If macOS blocks the first launch, open **System Settings → Privacy & Security** and click **Open Anyway**. You do not need to disable Gatekeeper or reduce system security.

If auto-detection fails because the game is installed in an unusual location, pass its path in Terminal: `./install.sh "/path/to/VA-11 Hall-A Cyberpunk Bartender Action.app"`.

## Saves and Steam Cloud

Save files remain compatible with the original game and are written to `~/Library/Application Support/VA_11_Hall_A/saves/`. The installer only migrates old saves that are missing from that destination, so existing progress is never overwritten. When the game is launched through Steam, the publisher's AutoCloud configuration handles uploads and downloads.

## Uninstall

`uninstall.sh` is included in the Release ZIP and is also available as a standalone Release asset. Run it from the extracted ZIP, or download it separately and run:

```sh
bash ~/Downloads/uninstall.sh
```

This restores the original `Mac_Runner` entry point from the backup made during installation and re-signs the bundle. Your save files are left untouched.

## What was fixed beyond 64-bit

The upstream Butterscotch runtime needed VA-11-specific fixes, all included in this package:

- GMS1.4 automatic sprite bounding boxes (`bboxMode=0`) computed from texture alpha — fixes broken menu hitboxes (volume buttons, sliders) and click crosstalk.
- `FS_set_gm_save_area` / `FS_set_working_directory` (used by the game's `_gmfilesystem_initialize`) with `%appdata%` placeholder mapping — enables the save behavior described above.
- Lazy texture loading by default in bundled mode, cutting the GPU memory footprint from ~1.3GB to ~540MB (comparable to the original runner's ~650MB).
- Achievement reads and unlocks through Valve's official Steamworks API, with Steam callbacks processed every frame.

## Known limitations

- The scanlines toggle label in the settings panel always displays "Off". This is a bug in the game's own logic.
- Steam Cloud syncs directly between Macs only. The publisher's AutoCloud configuration places Windows, macOS, and Linux saves in separate namespaces, so they do not sync across platforms automatically. Use Steam's cloud-file page for manual transfer when needed.

## Building from source

```sh
# Apple Silicon
make BACKEND=appkit -j4

# Intel 64-bit (cross-compile from Apple Silicon)
make BACKEND=appkit CFLAGS="-arch x86_64" LDFLAGS="-arch x86_64" -j4
```

See [README.upstream.md](README.upstream.md) for the full Butterscotch build documentation.

## License and credits

This project is a modified build of [Butterscotch](https://github.com/ButterscotchRunner/Butterscotch), licensed under the [GNU Affero General Public License v3](LICENSE), which this distribution retains. *VA-11 Hall-A* is a game by Sukeban Games; the Steamworks runtime is provided by Valve. This is an unofficial compatibility tool and distributes no game assets.

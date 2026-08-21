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

## Install

1. Download `VA-11-Hall-A-64bit-universal.zip` from [GitHub Releases](https://github.com/noahhhi/VA-11-Hall-A-64bit/releases). One package fits every Mac — the runner is a universal binary, and macOS automatically picks the arm64 (Apple Silicon) or x86_64 (Intel) slice.
2. Extract it, then either:
   - **Double-click** `Install VA-11 Hall-A 64bit.command` (if macOS blocks it, right-click → Open), or
   - run in Terminal:

```sh
cd VA-11-Hall-A-64bit-universal
./install.sh
```

The installer finds the game on its own: it scans every Steam library folder (including external drives) for the app — no arguments, no developer tools, everything it uses ships with macOS.

3. Launch the game from Steam as usual. It now runs natively in 64-bit.

> [!IMPORTANT]
> The runner is ad-hoc signed (re-signed on your machine by `install.sh`). If macOS blocks the first launch, open **System Settings → Privacy & Security** and click **Open Anyway**. You do not need to disable Gatekeeper or reduce system security.

If auto-detection fails (a very unusual install location), drag the game app onto `install.sh`, or pass the path yourself: `./install.sh "/path/to/VA-11 Hall-A Cyberpunk Bartender Action.app"`.

## Saves and Steam Cloud

Save files are written to `~/Library/Application Support/VA_11_Hall_A/saves/` — the directory the game's Steam AutoCloud configuration actually monitors. The original 32-bit runner never used it (it wrote inside the app bundle instead, so Steam Cloud never synced anything). This runner implements the game's `FS_set_gm_save_area` / `FS_set_working_directory` calls, so saves land where Steam expects them:

- Existing saves inside the app bundle are migrated automatically by `install.sh`.
- Launching the game through Steam uploads/downloads this directory as configured by the publisher.

## Uninstall

```sh
./uninstall.sh
```

This restores the original `Mac_Runner` entry point from the backup made during installation and re-signs the bundle. Your save files are left untouched.

## What was fixed beyond 64-bit

The upstream Butterscotch runtime needed VA-11-specific fixes, all included in this package:

- GMS1.4 automatic sprite bounding boxes (`bboxMode=0`) computed from texture alpha — fixes broken menu hitboxes (volume buttons, sliders) and click crosstalk.
- HiDPI mouse coordinate translation in the AppKit backend.
- `FS_set_gm_save_area` / `FS_set_working_directory` (used by the game's `_gmfilesystem_initialize`) with `%appdata%` placeholder mapping — enables the save behavior described above.
- Lazy texture loading by default in bundled mode, cutting the GPU memory footprint from ~1.3GB to ~540MB (comparable to the original runner's ~650MB).
- `ds_list_set` and Steam achievement stubs required by this game.

## Known limitations

- The scanlines toggle label in the settings panel displays "Off" even when enabled. This is a bug in the game's own logic — the original 32-bit runner behaves identically — and is not a regression of this port.
- Steam achievements are stubbed; gameplay is unaffected.

## Building from source

```sh
# Apple Silicon
make BACKEND=appkit -j8

# Intel 64-bit (cross-compile from Apple Silicon)
make BACKEND=appkit CFLAGS="-arch x86_64" LDFLAGS="-arch x86_64" -j8
```

See [README.upstream.md](README.upstream.md) for the full Butterscotch build documentation.

## License and credits

This project is a modified build of [Butterscotch](https://github.com/ButterscotchRunner/Butterscotch), licensed under the [GNU Affero General Public License v3](LICENSE), which this distribution retains. *VA-11 Hall-A* is a game by Sukeban Games; this project is an unofficial compatibility effort and distributes no game assets.

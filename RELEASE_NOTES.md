# Release usage notes / Release 使用说明

## Universal architecture / 通用架构

The runner contains both `arm64` and `x86_64`. macOS selects the native slice automatically. On Apple Silicon, quit the game and use Finder **Get Info → Open using Rosetta** to test `x86_64`; disable it to return to native `arm64`. Native mode is recommended.

Runner 同时包含 `arm64` 与 `x86_64`。macOS 默认自动选择原生架构。在 Apple Silicon 上，如需测试 `x86_64`，退出游戏后在 Finder 的 **显示简介 → 使用 Rosetta 打开** 中切换；取消勾选恢复原生 `arm64`。日常使用推荐原生模式。

## Uninstall / 卸载

The Release ZIP includes `uninstall.sh`, and the GitHub Release also provides it as a standalone asset. Run it with `bash ~/Downloads/uninstall.sh`. It restores the preserved Steam runner and signature while leaving saves untouched.

Release ZIP 中包含 `uninstall.sh`，GitHub Release 同时提供独立脚本资产。运行 `bash ~/Downloads/uninstall.sh` 即可恢复留存的 Steam runner 与签名，且不会删除存档。

# Release usage notes / Release 使用说明

## Universal architecture / 通用架构

The runner contains both `arm64` and `x86_64`. macOS selects the native slice automatically. On Apple Silicon, quit the game and use Finder **Get Info → Open using Rosetta** to test `x86_64`; disable it to return to native `arm64`. Native mode is recommended.

Runner 同时包含 `arm64` 与 `x86_64`。macOS 默认自动选择原生架构。在 Apple Silicon 上，如需测试 `x86_64`，退出游戏后在 Finder 的 **显示简介 → 使用 Rosetta 打开** 中切换；取消勾选恢复原生 `arm64`。日常使用推荐原生模式。

## Uninstall / 卸载

The Release ZIP includes executable `uninstall.sh`. The PKG installs the same script at `/Library/Application Support/VA-11-Hall-A-64bit/uninstall.sh`. It restores the preserved Steam runner and signature while leaving saves untouched.

Release ZIP 中包含可执行的 `uninstall.sh`；PKG 会把同一脚本安装到 `/Library/Application Support/VA-11-Hall-A-64bit/uninstall.sh`。脚本恢复留存的 Steam runner 与签名，不删除存档。

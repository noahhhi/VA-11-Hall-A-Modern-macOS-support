## English

Native Universal (`arm64` + `x86_64`) macOS runner for the Steam release of
*VA-11 Hall-A: Cyberpunk Bartender Action* (AppID 447530). You must own the
game on Steam; no game data is included.

### Downloads

- **`VA-11-Hall-A-64bit-universal.pkg`**: one-click installer; no extraction required.
- **`VA-11-Hall-A-64bit-universal.zip`**: portable fallback containing the double-click installer, `install.sh`, and `uninstall.sh`.
- **`uninstall.sh`**: standalone uninstaller for either installation method.

The PKG and ZIP now include Valve's official Universal Steamworks runtime.
Steam achievements use the public Steamworks API and work in both native
Apple Silicon and Intel/Rosetta modes.

Double-click the PKG, or extract the ZIP and double-click
**`Install VA-11 Hall-A 64bit.command`**. The installer scans all Steam
libraries, preserves a reversible copy of the original runner and signature,
installs the compatibility components, re-signs the app, and migrates only
missing saves.

The PKG is currently unsigned because no Developer ID Installer identity is
available. If Gatekeeper blocks it, right-click the package and choose
**Open**, or allow it under **System Settings → Privacy & Security**. Do not
disable Gatekeeper.

If the PKG reports that installation failed, run this command in Terminal. It
creates `VA11-install-log.txt` on the Desktop; attach that file to a
[GitHub issue](https://github.com/noahhhi/VA-11-Hall-A-Modern-macOS-support/issues):

```sh
/usr/bin/grep -iE 'VA-11|io.github.noahhhi|postinstall|xcrun|lipo|nm|codesign|error' /var/log/install.log | /usr/bin/tail -n 200 > "$HOME/Desktop/VA11-install-log.txt"
```

The runner contains both architectures. macOS selects `arm64` on Apple Silicon
and `x86_64` on Intel automatically. To test `x86_64` on Apple Silicon, quit
the game and enable **Finder → Get Info → Open using Rosetta**; disable it to
return to native `arm64`.

To uninstall, use `uninstall.sh` from the ZIP or download the standalone asset:

```sh
bash ~/Downloads/uninstall.sh
```

The original Steam runner is restored and saves are retained.

---

## 简体中文

适用于 Steam 版《VA-11 Hall-A：赛博朋克酒保行动》（AppID 447530）的
macOS Universal（`arm64` + `x86_64`）runner。你需要在 Steam 上拥有本游戏；
本发布不包含任何游戏数据。

### 下载

- **`VA-11-Hall-A-64bit-universal.pkg`**：无需解压的一键安装包。
- **`VA-11-Hall-A-64bit-universal.zip`**：包含双击安装器、`install.sh` 与 `uninstall.sh` 的便携备用包。
- **`uninstall.sh`**：适用于两种安装方式的独立卸载脚本。

PKG 与 ZIP 现已包含 Valve 官方 Universal Steamworks 运行库。Steam 成就通过
公开 Steamworks API 工作，原生 Apple Silicon 与 Intel/Rosetta 模式均受支持。

双击 PKG；或解压 ZIP 后双击 **`Install VA-11 Hall-A 64bit.command`**。
安装器会扫描全部 Steam 库，在 app 外保留原 runner 与签名用于恢复，安装兼容性
组件并重新签名，同时只迁移缺失的存档。

由于当前没有 Developer ID Installer 证书，PKG 尚未签名。如被 Gatekeeper
拦截，请右键安装包选择 **打开**，或前往 **系统设置 → 隐私与安全性** 允许打开；
无需关闭 Gatekeeper。

如果 PKG 提示安装失败，请在终端运行以下命令。命令会在桌面生成
`VA11-install-log.txt`；前往
[GitHub Issues](https://github.com/noahhhi/VA-11-Hall-A-Modern-macOS-support/issues)
反馈时请附上该文件：

```sh
/usr/bin/grep -iE 'VA-11|io.github.noahhhi|postinstall|xcrun|lipo|nm|codesign|error' /var/log/install.log | /usr/bin/tail -n 200 > "$HOME/Desktop/VA11-install-log.txt"
```

runner 同时包含两种架构，macOS 会在 Apple Silicon 上自动选择 `arm64`，在
Intel Mac 上自动选择 `x86_64`。如需在 Apple Silicon 上测试 `x86_64`，请先
退出游戏，再勾选 **Finder → 显示简介 → 使用 Rosetta 打开**；取消勾选即可恢复
原生 `arm64`。

卸载时可使用 ZIP 内或单独下载的 `uninstall.sh`：

```sh
bash ~/Downloads/uninstall.sh
```

脚本会恢复原版 Steam runner，并保留存档。

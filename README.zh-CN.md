# VA-11 Hall-A macOS 64 位 Runner

[![macOS builds](https://github.com/noahhhi/VA-11-Hall-A-64bit/actions/workflows/build-macos.yml/badge.svg)](https://github.com/noahhhi/VA-11-Hall-A-64bit/actions/workflows/build-macos.yml)

<p align="center">
  <a href="README.md">English</a> |
  <a href="README.zh-CN.md">简体中文</a>
</p>

为 macOS Steam 版《VA-11 Hall-A：赛博朋克酒保行动》提供的原生 64 位 runner，基于开源的 GameMaker Studio 1.4 运行时 [Butterscotch](https://github.com/ButterscotchRunner/Butterscotch) 构建。它替换游戏自带的 32 位 `Mac_Runner`——后者在 macOS 10.15 Catalina 及以后的系统上已无法启动。

当前参考测试环境：Apple Silicon Mac，macOS 27.0，Steam 版 VA-11 Hall-A（AppID 447530，`game.ios` 字节码 v15）。启动、语言选择、主菜单、设置面板（音量 / 扫描线 / 全屏）与存档读写均已通过本机测试。

> **预览说明：** 本包只包含替换用 runner。你需要在 Steam 上拥有 VA-11 Hall-A；本仓库不包含也不分发任何游戏数据。

## 系统要求

- macOS，Apple Silicon（arm64）或 64 位 Intel（x86_64）
- 已通过 Steam 安装 VA-11 Hall-A（默认位置：`~/Library/Application Support/Steam/steamapps/common/VA-11 HALL-A/`）

## 一键安装

从 [GitHub Releases](https://github.com/noahhhi/VA-11-Hall-A-64bit/releases) 下载 `VA-11-Hall-A-64bit-universal.pkg` 并双击。安装包会扫描所有 Steam 库，安装 arm64/x86_64 通用 runner，在 app 外保留可恢复的原 runner 与签名，修复 app 签名，并且只迁移缺失的存档。无需解压，也无需打开终端。

预览构建仍提供 `.command` 备用流程：解压 `VA-11-Hall-A-64bit-universal.zip`，双击 `Install VA-11 Hall-A 64bit.command`，或运行：

```sh
cd VA-11-Hall-A-64bit-universal
./install.sh
```

安装器会明确报告 macOS 版本不支持、Steam 库缺失、app 包结构异常、runner 缺少架构或权限不足等错误，并在失败时回滚，避免留下半安装状态。成功后照常从 Steam 启动游戏。

> [!IMPORTANT]
> runner 使用 ad-hoc 签名（由 `install.sh` 在你本机完成重签）。如果 macOS 阻止首次启动，打开 **系统设置 → 隐私与安全性**，点击 **仍要打开**。无需关闭 Gatekeeper 或降低系统安全性。

如果自动定位失败（极为少见的安装位置），把游戏 app 拖到 `install.sh` 上，或手动传路径：`./install.sh "/路径/VA-11 Hall-A Cyberpunk Bartender Action.app"`。

## 存档与 Steam 云同步

存档写入 `~/Library/Application Support/VA_11_Hall_A/saves/`——这正是该游戏 Steam AutoCloud 配置实际监控的目录。原版 32 位 runner 从未使用它（存档写在 app 包内，Steam 云从未同步过任何内容）。本 runner 实现了游戏调用的 `FS_set_gm_save_area` / `FS_set_working_directory`，让存档落到 Steam 预期的位置：

- `install.sh` 会自动迁移 app 包内的已有存档。
- 通过 Steam 启动游戏时，该目录会按发行商配置进行上传/下载同步。

## 卸载

```sh
./uninstall.sh
```

会从安装时创建的备份恢复原版 `Mac_Runner` 入口并重新签名，存档不受影响。

## 除 64 位化之外修复的问题

上游 Butterscotch 运行时需要的 VA-11 专属修复，均已包含在本包中：

- 按纹理 alpha 计算 GMS1.4 自动精灵包围盒（`bboxMode=0`）——修复设置菜单中失灵的按钮判定（音量按钮、滑块）与点击串扰。
- AppKit 后端的 HiDPI 鼠标坐标换算。
- `FS_set_gm_save_area` / `FS_set_working_directory`（游戏 `_gmfilesystem_initialize` 调用）及 `%appdata%` 占位符映射——实现上文所述的存档行为。
- 打包模式默认启用纹理懒加载，GPU 内存占用从约 1.3GB 降到约 540MB（与原版 runner 约 650MB 相当）。
- 补全该游戏需要的 `ds_list_set` 与 Steam 成就 stub。
- 唯一且自动的 HiDPI 上屏策略：应用表面为整数倍率时使用逐像素一致的最近邻；非整数放大时使用单 pass 的 t3ssel8r/SDL 风格像素艺术 UV 重映射，将过渡限制在源像素边界处最多一个设备像素；缩小时使用线性过滤。AppKit 提供真实 backing 像素尺寸，16:9 letterbox 内容区按等比例整数化，保证横纵倍率完全一致。没有模式选择器，也不读取旧偏好文件或环境变量。

## 已知限制

- VA-11 Hall-A 先合成到 1280x720 应用表面，其中绝大多数美术又来自放大两倍的 640x360 像素网格。2880x1620 的 16:9 内容区相对应用表面是 2.25 倍（相对原始网格是 4.5 倍），因此不可能同时做到完全硬边、每个源像素等宽并铺满画面。Auto 把不可避免的分数边界限制为一个目标像素，而不会模糊整个源像素内部。
- 设置面板中扫描线开关的标签恒显示"Off"。这是游戏自身逻辑的 bug——原版 32 位 runner 表现完全相同——并非本移植的回归。
- Steam 成就为 stub（不影响游玩）。
- Steam 云存档仅在 Mac 之间同步。发行商的 AutoCloud 配置将 Windows、macOS、Linux 的存档隔离在三个独立命名空间，存档不会与 Steam Deck / Windows PC 互通。原版游戏行为相同，runner 无法改变。
- 在同一台机器上测试云同步看起来会像"没反应"：云端内容就是本机刚上传的，拉回来自然一模一样。想直观验证，可删除 `~/Library/Application Support/VA_11_Hall_A/saves/` 里的某个存档再启动游戏——Steam 会在游戏启动前把它从云端还原。

## 从源码构建

```sh
# Apple Silicon
make BACKEND=appkit -j4

# Intel 64 位（从 Apple Silicon 交叉编译）
make BACKEND=appkit CFLAGS="-arch x86_64" LDFLAGS="-arch x86_64" -j4
```

完整的 Butterscotch 构建文档见 [README.upstream.md](README.upstream.md)。
完整根因、对比截图与像素量化结果见 [HIDPI_RENDERING_REPORT.md](HIDPI_RENDERING_REPORT.md)。

## 许可证与致谢

本项目是 [Butterscotch](https://github.com/ButterscotchRunner/Butterscotch) 的修改版本，依照其 [GNU Affero General Public License v3](LICENSE) 发布并保留该许可证。《VA-11 Hall-A》为 Sukeban Games 的作品；本项目是非官方兼容性工具，不分发任何游戏资源。

# HiDPI rendering repair report / HiDPI 渲染修复报告

## Conclusion / 结论

The final product exposes one policy only: **Auto**. Integer application-surface magnification uses nearest-neighbor, non-integer magnification uses a single-pass boundary-aware pixel-art shader, and minification uses linear filtering. Comparison-only launchers, preferences, environment overrides, intermediate surfaces, and alternate shaders were removed after evaluation.

最终产品只保留 **Auto**：应用表面整数倍放大使用最近邻，非整数倍放大使用单 pass 边界感知像素艺术 shader，缩小时使用线性过滤。完成选择后，比较启动器、偏好文件、环境变量覆盖、中间表面和其他 shader 均已移除。

## Root cause / 根因

The game does not present the authored 640x360 grid directly. It composites into a 1280x720 application surface; screenshot analysis found 99.769% of its 2x2 blocks still correspond to the 640x360 authored grid. A 1440x900 HiDPI desktop provides a 2880x1800 drawable, whose 16:9 game rectangle is 2880x1620. That is 2.25x the application surface or 4.5x the authored grid.

游戏并非直接输出 640x360 原始网格，而是先合成到 1280x720 应用表面；截图分析显示其中 99.769% 的 2x2 块仍对应 640x360 原始网格。1440x900 HiDPI 桌面的 drawable 为 2880x1800，游戏的 16:9 内容区为 2880x1620，即应用表面的 2.25 倍、原始网格的 4.5 倍。

Nearest-neighbor cannot divide 4.5 destination pixels into equal hard integer-width runs: widths must alternate between four and five pixels. Linear and sharp-bilinear distribute interpolation farther into texel interiors, which is perceived as general softness. Integer letterboxing is hard but reduces the image to 2560x1440 and still cannot reconstruct vector-like text from the already rasterized game surface. This is a sampling constraint, not a physical-panel or screenshot issue.

最近邻无法把 4.5 个目标像素分成等宽且完全硬边的整数游程，只能让宽度在 4 和 5 像素之间交替。线性与 sharp-bilinear 会把插值扩散到更多源像素内部，看起来整体偏软。整数 letterbox 虽然硬，但只能降为 2560x1440，而且无法把已经栅格化的游戏文字恢复成矢量文字。这是采样约束，不是物理面板或截图造成的问题。

## Implementation / 实现

- AppKit reports the `NSOpenGLView` backing-pixel size using `convertRectToBacking`, with `wantsBestResolutionOpenGLSurface` enabled.
- The content rectangle is quantized to a whole 16:9 aspect unit, preventing unequal horizontal and vertical scale caused by independent rounding.
- Exact integer 1280x720 ratios use the existing nearest framebuffer blit.
- Non-integer magnification executes one fragment-shader pass from the application-surface texture to the host drawable. Texel interiors sample their centers; `smoothstep` represents a fractional source boundary in at most one destination pixel.
- Minification uses linear sampling. Shader compilation failure falls back safely to nearest-neighbor.
- Every frame clears the complete host drawable with scissoring disabled, preventing stale letterbox pixels after resizing.

“Single pass / 单 pass” means the final application-surface texture is drawn directly to the window once. There is no higher-scale intermediate framebuffer and no second downsampling pass, reducing memory use and avoiding extra filtering.

## Quantitative validation / 量化验证

The checked-in `tests/analyze_scaling.py` reconstructs the logical grid, compares screenshots with a nearest prediction, measures palette changes, and records boundary-transition and isolated-run histograms.

| Drawable / viewport | Evaluated result | Relevant measurement |
|---|---|---|
| 2880x1800 / 2880x1620 (4.5x logical) | Nearest baseline | 2,409 measured boundaries had 0 blended pixels; isolated details alternated between 4px (2,974) and 5px (3,053) |
| 2880x1800 / 2880x1620 (4.5x logical) | Auto non-integer shader | 2,395 of 2,409 boundaries used exactly 1 transition pixel; isolated solid interiors were predominantly 4px (6,040 of 6,052); new-palette pixels 2.8697%, MAE 0.838 |
| 2560x1600 / 2560x1440 (4x logical) | Auto integer branch | Output was byte-identical to nearest; nearest prediction 100% |
| 2200x1238 / 2192x1233 (3.425x logical) | Auto non-integer shader | 2,255 measured boundaries were one-pixel transitions; nearest baseline alternated 3px (3,453) and 4px (2,593) runs |

The three overview comparisons are stored in [`artifacts/hidpi-comparison`](artifacts/hidpi-comparison). They preserve rejected modes only as test evidence; those modes are not compiled into or selectable in the delivered runner.

## Installer validation / 安装器验证

The installer scans Steam's default library and every path in `libraryfolders.vdf`, accepts a dragged app path, checks macOS and both runner architectures, stages replacement transactionally, keeps the original runner/signature in an external backup, repairs nested and outer signatures, and migrates only missing saves. A synthetic app-bundle install/uninstall round trip restored the original entry point byte-for-byte and passed strict signature verification.

The flat package contains no game assets. It installs the runner and helper scripts under `/Library/Application Support/VA-11-Hall-A-64bit`, then runs the same installer for the logged-in desktop user. Local packages are unsigned when no `Developer ID Installer` identity is available; release signing can be enabled with `PKG_SIGN_IDENTITY`.

## Remaining limitation / 剩余限制

Raster text drawn by the original GMS1.4 game is already part of the 1280x720 application surface. Re-rendering it at display resolution would require reliably intercepting and replaying the game's font/layout logic, including localization and effects. That was audited and deliberately abandoned as disproportionate and regression-prone. Auto improves final sampling but cannot create detail absent from the source surface.

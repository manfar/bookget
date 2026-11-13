# Bookget macOS Universal GUI

SwiftUI 原生 macOS 应用，最低支持 macOS 14。下载功能复用仓库现有 Go CLI，不修改 Windows GUI。

## 支持架构

- Intel Mac：x86_64
- Apple Silicon：arm64
- Go 下载核心与 SwiftUI GUI 均打包为 Universal Binary。

## 构建

在 macOS 上安装 Go、Swift（Xcode Command Line Tools）和 Make 后，在仓库根目录运行：

```bash
make macos-app
```

输出：`dist/darwin-universal/Bookget.app`

如果目标 App 已存在，脚本默认拒绝覆盖。确认后执行：

```bash
FORCE=1 make macos-app
```

脚本会分别构建 x86_64 与 arm64 的 Go 下载核心和 SwiftUI GUI，再合并成 Universal Binary。只有新应用完整构建并通过架构检查后，才会替换旧的构建产物。

## 第一版功能

- 单个 HTTP/HTTPS URL 下载
- 保存目录选择
- 可选 Cookies、Headers 文件
- 页码范围、册数范围、每任务线程数
- stdout/stderr 运行日志
- 终止下载进程、打开保存目录

CLI 当前没有稳定的结构化进度协议，因此 GUI 显示运行状态与日志，不显示虚构的百分比。终止进程不保证优雅取消，可能留下部分文件。

## 应用图标

当前临时图标来自仓库已有资源：`bookget-gui/gui/controls_ui/img/favicon.png`。构建脚本将其转换为 `AppIcon.icns`。后续替换 `macos/Resources/bookget-icon.png` 即可，不需要改 SwiftUI 代码。

## 签名

构建脚本使用 ad-hoc 签名，仅用于本地测试。正式对外分发还需 Developer ID 签名和 Apple 公证。

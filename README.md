# 簡介

bookget 数字古籍图书下载工具，已支持约 50+ 个数字图书馆。 

### 使用説明
1. 打开 [https://github.com/deweizhu/bookget/releases](https://github.com/deweizhu/bookget/releases/latest) 下载最新版。
1. [必读]使用手册wiki https://github.com/deweizhu/bookget/wiki 
1. 此项目代码仅供学习研究使用，欢迎有能力的朋友git clone 代码二次开发维护您自己的版本。

#### 源碼編譯
从源码构建，仅对计算机程序员参考。普通用户可直接跳过阅读。   
阅读 [golang 官方文档](https://golang.google.cn/doc/install) ，给您的电脑安装 golang 开发环境。
```shell
git clone https://github.com/deweizhu/bookget.git
cd bookget

# 本地开发时可直接运行
make linux-amd64    # 编译Linux版本
make windows-amd64  # 编译Windows版本
make release        # 编译所有平台
```

### macOS Intel 原生 GUI（macOS 14+）

在 Intel Mac 上安装 Go、Swift（Xcode Command Line Tools）和 Make 后，在项目根目录执行：

```shell
make macos-app
```

构建产物：`dist/darwin-amd64/Bookget.app`。如果需要重新构建并替换这个由脚本生成的 App，先确认目标路径后执行 `FORCE=1 make macos-app`。

此 GUI 使用 SwiftUI，并调用随 App 打包的 `darwin/amd64` Go 下载核心；原有 Windows `bookget-gui/` 工程保持不变。第一版支持单个 HTTP/HTTPS URL、保存目录、Cookies、Headers、页码范围、册数范围和线程数。当前 CLI 没有结构化下载进度接口，因此界面显示运行状态与日志，不显示虚构的百分比。终止按钮会结束子进程，不能保证优雅取消，可能留下部分文件。批量 URL 文件和交互式图片模板模式暂时仍使用 CLI。

构建为本机 ad-hoc 签名，不包含 Apple Developer ID 公证。

- For Win可用环境：windows 10 x64 / windows 11 （自2024/01/12日起，引入bookget-gui只适用于Win10/11 x64系统）。

# 新書推薦

本書即以清代避諱為例，試探如何運用融合數位與傳統的e考據之法，重新定義避諱學2.0該有的研究模式。這將是治清代的文史工作者案頭不可或缺的一本專著。[^1]
-  [清代避諱研究](https://gpi.culture.tw/books/1011300273)
- 作者: 黃一農 / 黄一农
- 出版社: 台灣清華大學出版社
- 副标题: e考據的學術實踐
- 出版年: 2024-4
- ISBN: 9786269724987
[^1]:[https://gpi.culture.tw/books/1011300273](https://gpi.culture.tw/books/1011300273)

### 第三方社區/網站
- 书格 https://www.shuge.org
### Arch Linux AUR 可选包
以下是热心网友维护的 Linux 软件仓库，便于 Arch Linux 用户安装使用。
-  https://aur.archlinux.org/packages/bookget
-  https://aur.archlinux.org/packages/bookget-bin
-  https://aur.archlinux.org/packages/bookget-git
-  [bookget -  Arch Linux 中文维基](https://wiki.archlinuxcn.org/wiki/Bookget)



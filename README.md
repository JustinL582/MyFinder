# 自建 Finder (MyFinder)

一个 macOS 14+ 的原生 SwiftUI 文件浏览器，长得像 Finder，并且**对每个文件夹显示递归计算出的总体积**。

## 功能

- Finder 风格：侧边栏（主目录/桌面/文稿/下载）、工具栏前进后退、四种视图（图标 / 列表 / 分栏 / 画廊）。
- 文件夹递归体积：进入某目录后，该层各文件夹的总体积在后台并发计算、算好逐个填入；带磁盘缓存，再次打开更快。
- 浏览：双击文件夹进入、双击文件用默认程序打开、列头排序、按名称搜索。
- 文件操作（右键）：新建文件夹、重命名、移到废纸篓、拷贝路径、在 Finder 中显示。
- QuickLook：选中后按**空格**预览。

## 运行

```bash
cd "MyFinderTool2.fresh"
swift build
swift run MyFinder
```

也可用 Xcode 打开 `MyFinderTool2.fresh/Package.swift` 后点 Run。

## 要求

- macOS 14 或更高
- Xcode / Swift 5.9+ 工具链

## 说明

- 当前以可执行程序（非沙盒）运行，可直接读取所选目录。
- 如需打包成沙盒 `.app` 分发，需要补 security-scoped bookmark（见 `Project Context.md` 的"后续"）。

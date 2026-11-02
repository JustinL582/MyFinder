# CLAUDE.md — 自建 Finder

本文件为 AI 在本项目工作时的上下文。进入本项目前先读它。

## 项目一句话

一个 macOS 14+ 的原生 SwiftUI 文件浏览器，外观与交互模仿 macOS Finder，并额外对**每个文件夹显示递归计算出的总体积**（真 Finder 列表视图这一列对文件夹是空的）。

## 位置与运行

- 代码在子目录 `MyFinderTool2.fresh/`（一个 Swift Package 可执行程序，产物名 `MyFinder`）。
- 启动：
  ```bash
  cd "MyFinderTool2.fresh" && swift build && swift run MyFinder
  ```
- 需要 Xcode 的 Swift 工具链（macOS 14+，Swift 5.9+）。

## 技术栈

- SwiftUI + Observation（`@Observable`），`NavigationSplitView` + `Table` + `LazyVGrid`。
- AppKit 桥接：`NSWorkspace`（打开/图标/在 Finder 中显示）、`NSPasteboard`、`FileManager.trashItem`。
- QuickLook：SwiftUI `.quickLookPreview(_:)`。
- 并发：`actor FolderScanner` + `TaskGroup`。

## 架构（`MyFinderTool2.fresh/`）

| 文件 | 职责 |
|---|---|
| `MyFinderApp.swift` | `@main` 入口、窗口样式 |
| `ContentView.swift` | 侧边栏 + 工具栏 + 四视图切换 + 重命名/错误 alert + QuickLook |
| `FileItem.swift` | `@Observable final class`：一个文件/文件夹（引用类型，体积结果就地更新 UI） |
| `FolderScanner.swift` | `actor`：列目录 + 递归求体积（可取消）+ 缓存读写 |
| `SizeCache.swift` | 体积缓存持久化（Application Support/MyFinder/cache.json） |
| `FileOps.swift` | 新建/重命名/移动/拷贝/废纸篓/拷贝路径/显示于 Finder |
| `BrowserViewModel.swift` | `@MainActor @Observable`：导航、排序、搜索、按层后台算体积、文件操作 |
| `FileViews.swift` | 列表(Table)/图标/分栏(Miller)/画廊 四个视图 + 右键菜单 |
| `RowView.swift` | 单元格与图标 tile（真实系统图标 + 计算中转圈） |
| `Localization.swift` | `L()`：非 SwiftUI 字面量的本地化（中文源文案作 key） |

资源在仓库根 `Resources/`（`en.lproj` / `zh-Hans.lproj`），由 `打包App.command` 拷进 `.app`。新增界面文案时：SwiftUI 字面量直接写中文，同时在 `en.lproj/Localizable.strings` 补译文；`String` 变量/三元表达式/错误信息用 `L()`。

## 关键约定（为什么这样做见 `Memory/`）

- **模型必须是引用类型**：`FileItem` 是 class。曾经是 struct，导致选中快照、详情永不刷新的 bug。
- **体积"进入哪层算哪层"**：只算当前显示层，后台并发、算好逐个填入；离开目录 `sizeTask?.cancel()`。不要预先递归整棵树。
- **跨线程只读不写 FileItem**：体积在 actor/后台算，结果一律 `await MainActor.run { ... }` 再写回 `FileItem`。
- **缓存访问只在 `FolderScanner` actor 内**，避免数据竞争。

## 不在当前范围

标签系统、多标签页/多窗口、全局递归搜索、列表视图内联展开三角（当前用双击进入导航）、沙盒 `.app` 打包。

# 调试记录与关键决策 — 自建 Finder

## 2026-11-01 重构

### 为什么模型必须是引用类型
原 `FolderItem` 是 `struct`。`selectedFolder` 存的是拷贝，`loadChildren` 更新 `rootFolders` 后拷贝不变，导致展开后详情永不刷新；整棵树还要靠递归查找+替换维护，脆弱。改为 `@Observable final class FileItem` 后，属性变化直接驱动 UI，问题消失。

### 为什么体积计算要"进入哪层算哪层"
对大目录（如主目录）预先递归整棵树会卡很久。改为只算当前显示层的文件夹体积，`TaskGroup` 有界并发（6），结果 `await MainActor.run` 写回 `FileItem`；离开目录 `sizeTask?.cancel()`，`computeSizeUncached` 内每 512 项 `Task.checkCancellation()`。

### 为什么缓存访问收敛到 actor
原代码在 `withTaskGroup` 子任务里跨线程并发读写 `@MainActor` 的 `sizeCache` 字典，是数据竞争。现在缓存只在 `FolderScanner`（actor）内访问；`listContents` 与 `computeSizeUncached` 是 `nonisolated`，可并发在 actor 外运行，不碰缓存。

### QuickLook 的实现
用 SwiftUI 的 `.quickLookPreview($url)`（需 `import QuickLook`），比自己桥接 `QLPreviewPanel` 简单可靠。空格键通过 `.onKeyPress(.space)` 切换。

### 列表视图为什么用双击进入而非内联三角
`Table` 的 `children:` 懒加载与"未扫描的文件夹要显示展开三角"配合不好（nil 子节点=无三角）。配合"进入哪层算哪层"，改用双击进入导航作为列表视图的主交互；内联三角列为后续。

### 构建/运行
`cd MyFinderTool2.fresh && swift build && swift run MyFinder`。非沙盒可执行程序，直接读所选目录。`swift build` 实测通过（Swift 6.4.2 工具链，-swift-version 5）。

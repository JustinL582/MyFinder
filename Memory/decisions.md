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

## 2026-11-02 增补

### 分栏视图为什么要按路径建多列
初版分栏只渲染当前目录一列，不符合 Finder「各级目录并排」的核心体验。改为 `rebuildFromPath`：从根（主目录或 `/`）沿当前路径算出目录链，每级一列并标记选中的子项，进入深层自动滚到最右。

### 分栏为什么要单独触发体积扫描
主列表 `vm.items` 由 `startSizeScan` 自动算体积，但分栏其它列是 `sortedChildren` 现做的 `FileItem`，不走那条路径，所以会一直显示 `--`。新增 `scanColumnSizes(_:)`：分栏每开一列就对该列文件夹跑一次有界并发扫描；扫描逻辑抽成 `makeSizeScan(for:)` 复用。离开目录时连同列扫描任务一起取消。

### 排序模型
`SortKey`（名称/种类/修改日期/大小）封装 `comparator(ascending:)` 与 `keyPath`；`setSort` 写回 `sortComparators`（列表 Table 也绑它，保持同步），点同一键切换升降序。右键菜单 `SortByMenu` 四视图通用，分栏用 `.onChange(of: sortComparators)` 重建列。

### 关窗即退出
SwiftUI 默认关最后一个窗口不退出、进程驻留后台占内存。加 `AppDelegate` 实现 `applicationShouldTerminateAfterLastWindowClosed → true`，经 `@NSApplicationDelegateAdaptor` 接入。

### 打包与隐私
`打包App.command`：release 编译 → 组装 `MyFinder.app`（`MacOS/` 二进制、`Resources/MyFinder.icns`、`Info.plist`）→ ad-hoc 签名。图标由 AppKit 矢量脚本渲染各尺寸 + `iconutil` 生成 `.icns`。仓库公开，提交统一用匿名 `255309524+JustinL582@users.noreply.github.com`（全局 git 邮箱也已改），Bundle ID 去掉个人名改为 `com.myfinder.app`。

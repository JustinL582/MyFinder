# Project Context — 自建 Finder

## 背景

原始版本 `MyFinderTool2.fresh` 是一个"选文件夹 → 列出子文件夹体积"的 SwiftUI 小工具，但**无法编译**（`NavigationSplitView ... columnVisibility: .visible` 语法错误），且有一系列架构缺陷：`List(selection:)` 绑错类型、`FolderItem` 为值类型导致详情永不刷新、`withTaskGroup` 跨线程并发读写 `@MainActor` 字典（数据竞争）、缓存目录从未创建且启动从不读取、错误被静默吞掉。

## 目标

重构成一个外观与交互都像 **macOS 原生 Finder** 的文件浏览器，保留 Finder 的常用能力，并提供 Finder 没有的"文件夹递归体积"。

## 需求（2026-11 重构范围）

**浏览导航**：进出文件夹、前进/后退、侧边栏快速位置（主目录/桌面/文稿/下载）、列头排序、双击用默认程序打开、在 Finder 中显示、当前目录名称过滤搜索。

**四种视图**：列表（`Table`）、图标（`LazyVGrid`）、分栏（Miller columns）、画廊（大预览 + 底部缩略图条）。

**文件操作**（右键菜单）：新建文件夹、重命名、移到废纸篓、拷贝路径、在 Finder 中显示。

**QuickLook**：选中后按空格预览。

**文件夹递归体积**："进入哪层算哪层"，后台并发计算、算好逐个填入，带持久化缓存。

## 明确不做（后续可选）

标签系统、多标签页/多窗口、全局递归搜索、列表内联展开三角、拖拽移动的完整实现、按修改时间精确失效缓存、沙盒 `.app` 打包（security-scoped bookmark）、体积占比横条。

## 设计原型

交互原型（Claude Artifact，示例数据）：https://claude.ai/artifact/R9PJGKqE3DsBz2tij29F4K

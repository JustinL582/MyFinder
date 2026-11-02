# CHANGELOG — 自建 Finder

## 2026-11-02 — 英文版

### 新增
- 界面本地化：英文 / 简体中文。中文源文案作 key，英文翻译在 `Resources/en.lproj/Localizable.strings`；打包后的 App 跟随系统语言。非 SwiftUI 字面量（枚举标签、错误信息、默认文件名）统一走 `Localization.swift` 的 `L()`。
- App 显示名本地化（英文 `MyFinder` / 中文 `自建 Finder`）。
- `启动英文版.command`：不受系统语言影响，以英文界面启动。
- 英文文档 `README.en.md`。

### 其他
- `打包App.command` 现会拷入 `*.lproj` 并写入 `CFBundleLocalizations`。
- 提交继续使用匿名 noreply 邮箱。

## 2026-11-02 — 排序、图标与打包

### 新增
- 右键「排序方式」菜单：名称 / 种类 / 修改日期 / 大小，再点当前项切换升/降序；右键项目或空白处均可，四视图通用。
- 应用图标（矢量绘制 → `MyFinder.icns`）与可双击启动的 `MyFinder.app`；根目录 `打包App.command` 一键重新打包（release 编译 + 图标 + `Info.plist` + ad-hoc 签名）。

### 改进
- 分栏视图（Miller columns）改为沿当前路径逐级展开的多列并排，进入深层目录自动滚到最右。
- 分栏每开一列即自动后台测算该列所有子文件夹体积，无需双击钻取；分栏行也显示文件夹大小。
- 界面配色：半透明侧边栏、内容区文稿白底、分栏选中项主题色高亮，减轻发灰。
- 关闭窗口即退出进程，不再驻留后台占内存（`AppDelegate.applicationShouldTerminateAfterLastWindowClosed`）。

### 其他
- 清理体积扫描的 Sendable 并发警告，现零警告编译。
- Bundle ID 设为 `com.myfinder.app`（移除个人名）。
- 初始化 git 仓库并推送到 GitHub（提交使用匿名 noreply 邮箱）：https://github.com/JustinL582/MyFinder

## 2026-11-01 — 重构为 Finder 风格文件浏览器

### 修复
- 修复无法编译的问题（`NavigationSplitView ... columnVisibility: .visible` 语法错误）。
- 修复选中失效（`List(selection:)` 绑定类型错误）。
- 修复展开后详情永不刷新（模型由值类型 `struct FolderItem` 改为引用类型 `@Observable class FileItem`）。
- 修复体积计算的跨线程数据竞争（缓存访问收敛到 `actor FolderScanner`，`FileItem` 只在主线程写回）。
- 修复缓存读写：创建 Application Support 目录、启动时加载、退出时保存、开关真正生效。
- 错误不再被静默吞掉，改为 `.alert` 提示。

### 新增
- Finder 风格界面：侧边栏 + 工具栏（前进/后退、视图切换、新建文件夹、搜索）。
- 四种视图：图标 / 列表（`Table`）/ 分栏（Miller columns）/ 画廊。
- 文件操作（右键）：新建文件夹、重命名、移到废纸篓、拷贝路径、在 Finder 中显示。
- QuickLook 预览（空格）。
- 文件夹递归体积"进入哪层算哪层"，后台并发 + 可取消 + 持久化缓存。
- 真实系统图标（`NSWorkspace.icon`）。

### 文档
- 按工作区规范补齐 `CLAUDE.md` / `Project Context.md` / `README.md` / `CHANGELOG.md` / `Memory/`。
- 删除过时的 `项目概述.md`（描述的是旧的双栏设计）。

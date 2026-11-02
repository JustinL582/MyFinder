# CHANGELOG — 自建 Finder

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

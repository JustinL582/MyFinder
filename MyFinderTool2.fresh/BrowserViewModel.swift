import Foundation
import AppKit
import Observation

struct SidebarLocation: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let symbol: String   // SF Symbol name
    let url: URL
}

@MainActor
@Observable
final class BrowserViewModel {
    /// Finder-style sort criteria, offered through the right-click "排序方式" menu.
    enum SortKey: String, CaseIterable, Identifiable {
        case name, kind, date, size
        var id: String { rawValue }
        var label: String {
            switch self {
            case .name: return L("名称"); case .kind: return L("种类")
            case .date: return L("修改日期"); case .size: return L("大小")
            }
        }
        /// Finder's defaults: names/kinds ascending, dates & sizes descending.
        var defaultAscending: Bool {
            switch self { case .name, .kind: return true; case .date, .size: return false }
        }
        func comparator(ascending: Bool) -> KeyPathComparator<FileItem> {
            let order: SortOrder = ascending ? .forward : .reverse
            switch self {
            case .name: return KeyPathComparator(\FileItem.name, order: order)
            case .kind: return KeyPathComparator(\FileItem.kind, order: order)
            case .date: return KeyPathComparator(\FileItem.dateForSort, order: order)
            case .size: return KeyPathComparator(\FileItem.sizeForSort, order: order)
            }
        }
        var keyPath: PartialKeyPath<FileItem> {
            switch self {
            case .name: return \FileItem.name
            case .kind: return \FileItem.kind
            case .date: return \FileItem.dateForSort
            case .size: return \FileItem.sizeForSort
            }
        }
    }

    enum ViewMode: String, CaseIterable, Identifiable {
        case icons, list, columns, gallery
        var id: String { rawValue }
        var label: String {
            switch self {
            case .icons: return L("图标"); case .list: return L("列表")
            case .columns: return L("分栏"); case .gallery: return L("画廊")
            }
        }
        var symbol: String {
            switch self {
            case .icons: return "square.grid.2x2"; case .list: return "list.bullet"
            case .columns: return "rectangle.split.3x1"; case .gallery: return "square.on.square"
            }
        }
    }

    // Displayed state
    var items: [FileItem] = []
    var currentURL: URL?
    var selection: FileItem.ID?
    var viewMode: ViewMode = .list
    var searchText = ""
    var sortComparators: [KeyPathComparator<FileItem>] =
        [KeyPathComparator(\FileItem.sizeForSort, order: .reverse)]
    var errorMessage: String?
    var quickLookURL: URL?

    // Rename is presented as an alert driven by these.
    var renamingItem: FileItem?
    var renameText = ""

    var cacheEnabled = true {
        didSet { Task { await scanner.setCacheEnabled(cacheEnabled) } }
    }

    let sidebarLocations: [SidebarLocation]

    // Navigation history
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []

    private let scanner: FolderScanner
    private var sizeTask: Task<Void, Never>?
    private var columnScanTasks: [Task<Void, Never>] = []

    init() {
        scanner = FolderScanner(cache: SizeCache())

        let fm = FileManager.default
        func loc(_ dir: FileManager.SearchPathDirectory, _ label: String, _ symbol: String) -> SidebarLocation? {
            guard let url = fm.urls(for: dir, in: .userDomainMask).first else { return nil }
            return SidebarLocation(label: label, symbol: symbol, url: url)
        }
        var locs: [SidebarLocation] = []
        let home = fm.homeDirectoryForCurrentUser
        locs.append(SidebarLocation(label: NSUserName(), symbol: "house", url: home))
        if let l = loc(.desktopDirectory, L("桌面"), "menubar.dock.rectangle") { locs.append(l) }
        if let l = loc(.documentDirectory, L("文稿"), "doc") { locs.append(l) }
        if let l = loc(.downloadsDirectory, L("下载"), "arrow.down.circle") { locs.append(l) }
        sidebarLocations = locs

        navigate(to: home, pushHistory: false)
    }

    // MARK: Derived

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var title: String { currentURL?.lastPathComponent ?? "MyFinder" }

    func item(_ id: FileItem.ID?) -> FileItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    var selectedItem: FileItem? { item(selection) }

    var filteredItems: [FileItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var totalSize: UInt64 { items.reduce(0) { $0 + ($1.size ?? 0) } }

    // MARK: Navigation

    func open(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else {
            FileOps.open(item.url)
        }
    }

    func navigate(to url: URL, pushHistory: Bool = true) {
        if pushHistory, let current = currentURL {
            backStack.append(current)
            forwardStack.removeAll()
        }
        load(url)
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        if let current = currentURL { forwardStack.append(current) }
        load(previous)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        if let current = currentURL { backStack.append(current) }
        load(next)
    }

    private func load(_ url: URL) {
        sizeTask?.cancel()
        columnScanTasks.forEach { $0.cancel() }
        columnScanTasks.removeAll()
        currentURL = url
        selection = nil
        do {
            items = try scanner.listContents(of: url, showHidden: false)
            applySort()
            startSizeScan()
        } catch {
            items = []
            errorMessage = L("无法打开「%@」：%@", url.lastPathComponent, error.localizedDescription)
        }
    }

    func reload() {
        if let url = currentURL { load(url) }
    }

    // MARK: Sorting

    func applySort() {
        items.sort(using: sortComparators)
    }

    /// The sort key currently in effect (matched back from `sortComparators`).
    var currentSortKey: SortKey? {
        guard let kp = sortComparators.first?.keyPath else { return nil }
        return SortKey.allCases.first { $0.keyPath == kp }
    }

    var sortAscending: Bool { sortComparators.first?.order == .forward }

    /// Pick a sort key from the menu; clicking the active key flips direction.
    func setSort(_ key: SortKey) {
        if currentSortKey == key {
            toggleSortOrder()
        } else {
            sortComparators = [key.comparator(ascending: key.defaultAscending)]
            applySort()
        }
    }

    func toggleSortOrder() {
        guard let key = currentSortKey else { return }
        sortComparators = [key.comparator(ascending: !sortAscending)]
        applySort()
    }

    // MARK: Background size scan (current level only)

    private func startSizeScan() {
        sizeTask = makeSizeScan(for: items.filter { $0.isDirectory })
    }

    /// Kick off recursive size computation for one freshly listed column of a
    /// Miller-columns view. Lets every displayed subfolder fill its size in
    /// automatically, without the user drilling into it first.
    func scanColumnSizes(_ listing: [FileItem]) {
        let directories = listing.filter { $0.isDirectory && $0.sizeState != .done }
        guard !directories.isEmpty else { return }
        if let task = makeSizeScan(for: directories) {
            columnScanTasks.append(task)
        }
    }

    /// Shared bounded-concurrency size scan. Results are written back on the
    /// main actor; the cache is touched only inside the `FolderScanner` actor.
    private func makeSizeScan(for directories: [FileItem]) -> Task<Void, Never>? {
        guard !directories.isEmpty else { return nil }
        for dir in directories { dir.sizeState = .pending }

        let maxConcurrent = 6
        return Task { [scanner] in
            await withTaskGroup(of: Void.self) { group in
                var iterator = directories.makeIterator()

                func addNext() {
                    guard let dir = iterator.next() else { return }
                    dir.sizeState = .computing
                    let url = dir.url
                    let mtime = dir.modDate
                    group.addTask {
                        if Task.isCancelled { return }
                        let size: UInt64?
                        if let cached = await scanner.cachedSize(for: url, mtime: mtime) {
                            size = cached
                        } else if let computed = try? scanner.computeSizeUncached(of: url) {
                            await scanner.store(url.path, size: computed, mtime: mtime)
                            size = computed
                        } else {
                            size = nil
                        }
                        if Task.isCancelled { return }
                        let resolved = size
                        await MainActor.run {
                            dir.size = resolved
                            dir.sizeState = .done
                        }
                    }
                }

                for _ in 0..<min(maxConcurrent, directories.count) { addNext() }
                for await _ in group {
                    if Task.isCancelled { break }
                    addNext()
                }
            }
        }
    }

    // MARK: File operations

    func newFolder() {
        guard let parent = currentURL else { return }
        do {
            let url = try FileOps.newFolder(in: parent)
            reload()
            selection = items.first { $0.url == url }?.id
        } catch {
            errorMessage = L("新建文件夹失败：%@", error.localizedDescription)
        }
    }

    func beginRename(_ item: FileItem) {
        renameText = item.name
        renamingItem = item
    }

    func commitRename() {
        guard let item = renamingItem else { return }
        rename(item, to: renameText)
        renamingItem = nil
    }

    func rename(_ item: FileItem, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        do {
            _ = try FileOps.rename(item.url, to: trimmed)
            reload()
        } catch {
            errorMessage = L("重命名失败：%@", error.localizedDescription)
        }
    }

    func trash(_ item: FileItem) {
        do {
            try FileOps.trash(item.url)
            Task { await scanner.invalidate(item.url.path) }
            reload()
        } catch {
            errorMessage = L("移到废纸篓失败：%@", error.localizedDescription)
        }
    }

    func copyPath(_ item: FileItem) { FileOps.copyPath(item.url) }
    func revealInFinder(_ item: FileItem) { FileOps.revealInFinder(item.url) }

    // MARK: QuickLook

    func toggleQuickLook() {
        if quickLookURL != nil {
            quickLookURL = nil
        } else if let item = selectedItem {
            quickLookURL = item.url
        }
    }

    // MARK: Lifecycle

    func saveOnQuit() {
        sizeTask?.cancel()
        Task { await scanner.save() }
    }
}

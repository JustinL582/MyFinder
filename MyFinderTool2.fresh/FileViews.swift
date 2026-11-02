import SwiftUI

// MARK: - Shared context menu

extension View {
    /// The right-click / context menu shown for a single item across all views.
    @ViewBuilder
    func itemContextMenu(for item: FileItem, vm: BrowserViewModel) -> some View {
        self.contextMenu {
            Button(item.isDirectory ? "打开" : "用默认程序打开") { vm.open(item) }
            Button("快速查看") { vm.quickLookURL = item.url }
            Divider()
            Button("重命名…") { vm.beginRename(item) }
            Button("拷贝路径") { vm.copyPath(item) }
            Button("在 Finder 中显示") { vm.revealInFinder(item) }
            Divider()
            Button("新建文件夹") { vm.newFolder() }
            SortByMenu(vm: vm)
            Divider()
            Button("移到废纸篓", role: .destructive) { vm.trash(item) }
        }
    }

    /// Right-clicking empty space in a view gives the Finder-style sort + new-folder menu.
    @ViewBuilder
    func backgroundContextMenu(vm: BrowserViewModel) -> some View {
        self.contextMenu {
            Button("新建文件夹") { vm.newFolder() }
            SortByMenu(vm: vm)
        }
    }
}

/// Finder's "排序方式" submenu: pick a criterion, re-pick it to flip direction.
struct SortByMenu: View {
    @Bindable var vm: BrowserViewModel

    var body: some View {
        Menu("排序方式") {
            ForEach(BrowserViewModel.SortKey.allCases) { key in
                Button {
                    vm.setSort(key)
                } label: {
                    if vm.currentSortKey == key {
                        Label(key.label, systemImage: "checkmark")
                    } else {
                        Text(key.label)
                    }
                }
            }
            Divider()
            Button(vm.sortAscending ? "改为降序" : "改为升序") { vm.toggleSortOrder() }
                .disabled(vm.currentSortKey == nil)
        }
    }
}

// MARK: - List view (native Table)

struct FileListView: View {
    @Bindable var vm: BrowserViewModel

    var body: some View {
        Table(vm.filteredItems, selection: $vm.selection, sortOrder: $vm.sortComparators) {
            TableColumn("名称", value: \.name) { item in
                NameCell(item: item)
                    .itemContextMenu(for: item, vm: vm)
            }
            .width(min: 200, ideal: 320)

            TableColumn("大小", value: \.sizeForSort) { item in
                Text(ItemFormat.size(item))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(90)

            TableColumn("种类", value: \.kind) { item in
                Text(item.kind).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 90, ideal: 140)

            TableColumn("修改日期", value: \.dateForSort) { item in
                Text(ItemFormat.date(item)).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 120, ideal: 160)
        }
        .contextMenu(forSelectionType: FileItem.ID.self) { ids in
            if let item = vm.item(ids.first) {
                Button(item.isDirectory ? "打开" : "用默认程序打开") { vm.open(item) }
                Button("快速查看") { vm.quickLookURL = item.url }
                Divider()
                Button("重命名…") { vm.beginRename(item) }
                Button("拷贝路径") { vm.copyPath(item) }
                Button("在 Finder 中显示") { vm.revealInFinder(item) }
                Divider()
                Button("新建文件夹") { vm.newFolder() }
                SortByMenu(vm: vm)
                Divider()
                Button("移到废纸篓", role: .destructive) { vm.trash(item) }
            } else {
                Button("新建文件夹") { vm.newFolder() }
                SortByMenu(vm: vm)
            }
        } primaryAction: { ids in
            if let item = vm.item(ids.first) { vm.open(item) }
        }
        .onChange(of: vm.sortComparators) { vm.applySort() }
    }
}

// MARK: - Icon view

struct FileIconView: View {
    @Bindable var vm: BrowserViewModel
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(vm.filteredItems) { item in
                    IconTile(item: item)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(vm.selection == item.id ? Color.accentColor.opacity(0.85) : .clear)
                        )
                        .foregroundStyle(vm.selection == item.id ? Color.white : Color.primary)
                        .contentShape(Rectangle())
                        .onTapGesture { vm.selection = item.id }
                        .simultaneousGesture(TapGesture(count: 2).onEnded { vm.open(item) })
                        .itemContextMenu(for: item, vm: vm)
                }
            }
            .padding(14)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .backgroundContextMenu(vm: vm)
    }
}

// MARK: - Columns view (Miller columns)

struct FileColumnsView: View {
    @Bindable var vm: BrowserViewModel
    // One listing per visible column; picked[i] is the chosen item's id in column i.
    @State private var columns: [[FileItem]] = []
    @State private var picked: [FileItem.ID] = []

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { index, listing in
                        column(listing, level: index)
                            .id(index)
                        Divider()
                    }
                    if let last = pickedItem(at: columns.count - 1), !last.isDirectory {
                        preview(last)
                            .id(columns.count)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .backgroundContextMenu(vm: vm)
            .onAppear { rebuildFromPath(); scrollToEnd(proxy) }
            .onChange(of: vm.currentURL) { rebuildFromPath(); scrollToEnd(proxy) }
            .onChange(of: vm.sortComparators) { rebuildFromPath() }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(columns.count, anchor: .trailing) }
        }
    }

    /// Build the Miller-column chain from a sensible root down to the current
    /// directory, so every ancestor level is shown as its own column — the
    /// signature Finder column-view behaviour.
    private func rebuildFromPath() {
        guard let current = vm.currentURL else {
            columns = [vm.items]; picked = []; return
        }
        let chain = directoryChain(to: current)   // [root, …, current]

        var cols: [[FileItem]] = []
        var sel: [FileItem.ID] = []
        for (i, dir) in chain.enumerated() {
            // Reuse the already-loaded listing for the current directory; other
            // columns get their folder sizes computed automatically too.
            let isCurrent = (dir == current)
            let listing = isCurrent ? vm.items : (try? sortedChildren(of: dir)) ?? []
            if !isCurrent { vm.scanColumnSizes(listing) }
            cols.append(listing)
            if i < chain.count - 1 {
                let next = chain[i + 1]
                if let child = listing.first(where: { $0.url.standardizedFileURL == next.standardizedFileURL }) {
                    sel.append(child.id)
                }
            }
        }
        columns = cols
        picked = sel
    }

    /// Directory URLs from a root (home when under home, else "/") down to `url`.
    private func directoryChain(to url: URL) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        var chain: [URL] = []
        var u = url.standardizedFileURL
        while true {
            chain.insert(u, at: 0)
            if u.path == home.path || u.path == "/" { break }
            let parent = u.deletingLastPathComponent().standardizedFileURL
            if parent.path == u.path { break }
            u = parent
        }
        return chain
    }

    private func pickedItem(at level: Int) -> FileItem? {
        guard level >= 0, level < picked.count, level < columns.count else { return nil }
        return columns[level].first { $0.id == picked[level] }
    }

    @ViewBuilder
    private func column(_ listing: [FileItem], level: Int) -> some View {
        List {
            ForEach(listing) { item in
                let isPicked = level < picked.count && picked[level] == item.id
                HStack(spacing: 6) {
                    Image(nsImage: item.icon).resizable().frame(width: 16, height: 16)
                    Text(item.name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    if item.isDirectory && item.sizeState == .computing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text(ItemFormat.size(item))
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(isPicked ? Color.white.opacity(0.9) : Color.secondary)
                    }
                    if item.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isPicked ? Color.white.opacity(0.9) : Color.secondary)
                    }
                }
                .foregroundStyle(isPicked ? Color.white : Color.primary)
                .contentShape(Rectangle())
                .listRowBackground(isPicked ? Color.accentColor : Color.clear)
                .onTapGesture { pick(item, level: level) }
                .simultaneousGesture(TapGesture(count: 2).onEnded { vm.open(item) })
                .itemContextMenu(for: item, vm: vm)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(width: 230)
    }

    private func pick(_ item: FileItem, level: Int) {
        vm.selection = item.id
        picked = Array(picked.prefix(level))
        picked.append(item.id)
        columns = Array(columns.prefix(level + 1))
        if item.isDirectory {
            let children = (try? sortedChildren(of: item.url)) ?? []
            vm.scanColumnSizes(children)   // auto-compute sizes for the opened column
            columns.append(children)
        }
    }

    private func sortedChildren(of url: URL) throws -> [FileItem] {
        var list = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .localizedNameKey],
            options: [.skipsHiddenFiles]
        ).map { FileItem(url: $0) }
        list.sort(using: vm.sortComparators)
        return list
    }

    @ViewBuilder
    private func preview(_ item: FileItem) -> some View {
        VStack(spacing: 10) {
            Image(nsImage: item.icon)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
            Text(item.name).font(.headline).multilineTextAlignment(.center).lineLimit(3)
            VStack(spacing: 3) {
                Text(item.kind)
                Text(ItemFormat.size(item))
                if let d = item.modDate { Text(d, style: .date) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Button("快速查看") { vm.quickLookURL = item.url }
                .controlSize(.small)
        }
        .padding(20)
        .frame(width: 240)
    }
}

// MARK: - Gallery view

struct FileGalleryView: View {
    @Bindable var vm: BrowserViewModel

    private var current: FileItem? {
        vm.selectedItem ?? vm.filteredItems.first
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let item = current {
                VStack(spacing: 14) {
                    Image(nsImage: item.icon)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 220, maxHeight: 220)
                    Text(item.name).font(.title3.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
                    Text("\(item.kind) · \(ItemFormat.size(item))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
            } else {
                Text("空文件夹").foregroundStyle(.secondary)
            }
            Spacer()
            Divider()
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(vm.filteredItems) { item in
                        VStack(spacing: 2) {
                            Image(nsImage: item.icon).resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40)
                            Text(item.name).font(.system(size: 9)).lineLimit(1).frame(maxWidth: 58)
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(vm.selection == item.id ? Color.accentColor : .clear, lineWidth: 2.5)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { vm.selection = item.id }
                        .simultaneousGesture(TapGesture(count: 2).onEnded { vm.open(item) })
                        .itemContextMenu(for: item, vm: vm)
                    }
                }
                .padding(12)
            }
            .frame(height: 92)
            .background(.bar)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .backgroundContextMenu(vm: vm)
    }
}

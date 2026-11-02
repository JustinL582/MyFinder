import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct ContentView: View {
    @State private var vm = BrowserViewModel()
    @State private var showingPicker = false

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { vm.sidebarLocations.first { $0.url == vm.currentURL }?.id },
                set: { id in
                    if let loc = vm.sidebarLocations.first(where: { $0.id == id }) {
                        vm.navigate(to: loc.url)
                    }
                }
            )) {
                Section("个人收藏") {
                    ForEach(vm.sidebarLocations) { loc in
                        Label(loc.label, systemImage: loc.symbol)
                            .foregroundStyle(Color.accentColor, Color.primary)
                            .tag(loc.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 280)
        } detail: {
            detail
                .navigationTitle(vm.title)
                .toolbar { toolbarContent }
        }
        .frame(minWidth: 820, minHeight: 520)
        .quickLookPreview($vm.quickLookURL)
        .onKeyPress(.space) {
            vm.toggleQuickLook()
            return .handled
        }
        .fileImporter(isPresented: $showingPicker,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                vm.navigate(to: url)
            }
        }
        .alert("重命名", isPresented: Binding(
            get: { vm.renamingItem != nil },
            set: { if !$0 { vm.renamingItem = nil } }
        )) {
            TextField("名称", text: $vm.renameText)
            Button("取消", role: .cancel) { vm.renamingItem = nil }
            Button("重命名") { vm.commitRename() }
        }
        .alert("出错了", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onDisappear { vm.saveOnQuit() }
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch vm.viewMode {
            case .icons: FileIconView(vm: vm)
            case .list: FileListView(vm: vm)
            case .columns: FileColumnsView(vm: vm)
            case .gallery: FileGalleryView(vm: vm)
            }
        }
        .safeAreaInset(edge: .bottom) { statusBar }
    }

    private var statusBar: some View {
        HStack {
            Text("\(vm.items.count) 个项目")
            Text("·")
            Text("合计 \(ByteCountFormatter.string(fromByteCount: Int64(vm.totalSize), countStyle: .file))")
            Spacer()
            Toggle("缓存大小", isOn: $vm.cacheEnabled)
                .toggleStyle(.checkbox)
                .controlSize(.small)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { vm.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!vm.canGoBack)
            Button { vm.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!vm.canGoForward)
        }
        ToolbarItemGroup {
            Picker("视图", selection: $vm.viewMode) {
                ForEach(BrowserViewModel.ViewMode.allCases) { mode in
                    Image(systemName: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("切换视图")

            Button { vm.newFolder() } label: { Image(systemName: "folder.badge.plus") }
                .help("新建文件夹")

            Button { showingPicker = true } label: { Image(systemName: "folder") }
                .help("选择文件夹")
        }
        ToolbarItem {
            TextField("搜索", text: $vm.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
        }
    }
}

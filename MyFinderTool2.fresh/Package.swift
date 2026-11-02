// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MyFinder",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MyFinder", targets: ["MyFinder"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MyFinder",
            path: ".",
            sources: ["MyFinderApp.swift",
                      "ContentView.swift",
                      "FileItem.swift",
                      "FolderScanner.swift",
                      "SizeCache.swift",
                      "FileOps.swift",
                      "BrowserViewModel.swift",
                      "FileViews.swift",
                      "RowView.swift",
                      "Localization.swift"]
        )
    ]
)

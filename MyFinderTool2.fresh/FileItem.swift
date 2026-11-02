import Foundation
import AppKit
import Observation

/// One entry (file or folder) shown in the browser.
/// Reference type so background size results update the UI in place —
/// no value-type snapshots, no recursive find-and-replace.
@Observable
final class FileItem: Identifiable {
    enum SizeState { case pending, computing, done }

    let id = UUID()
    let url: URL
    let isDirectory: Bool

    var name: String
    var kind: String
    var modDate: Date?

    /// Files know their size immediately; folders start nil and are filled in
    /// by the background size scan ("进入哪层算哪层").
    var size: UInt64?
    var sizeState: SizeState

    /// nil = not loaded yet (used by column view to drill in); never used for files.
    var children: [FileItem]?

    init(url: URL) {
        self.url = url
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            .localizedTypeDescriptionKey, .localizedNameKey
        ]
        let rv = try? url.resourceValues(forKeys: keys)
        let isDir = rv?.isDirectory ?? false
        self.isDirectory = isDir
        self.name = rv?.localizedName ?? url.lastPathComponent
        self.kind = rv?.localizedTypeDescription ?? (isDir ? "文件夹" : "文稿")
        self.modDate = rv?.contentModificationDate
        if isDir {
            self.size = nil
            self.sizeState = .pending
        } else {
            self.size = UInt64(rv?.fileSize ?? 0)
            self.sizeState = .done
        }
    }

    /// Real system icon, so the list looks like Finder.
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    // Non-optional keys so `Table`'s KeyPathComparator can sort on them.
    var sizeForSort: UInt64 { size ?? 0 }
    var dateForSort: Date { modDate ?? .distantPast }
}

import Foundation
import AppKit

/// Thin wrappers over the file-system operations the browser exposes.
/// Each returns the resulting URL (or throws) so the caller can refresh.
enum FileOps {
    static func newFolder(in parent: URL, name: String = L("未命名文件夹")) throws -> URL {
        var url = parent.appendingPathComponent(name, isDirectory: true)
        var i = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = parent.appendingPathComponent("\(name) \(i)", isDirectory: true)
            i += 1
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    static func rename(_ url: URL, to newName: String) throws -> URL {
        let dest = url.deletingLastPathComponent().appendingPathComponent(newName)
        guard dest != url else { return url }
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    }

    static func move(_ url: URL, into directory: URL) throws -> URL {
        let dest = directory.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    }

    static func copy(_ url: URL, into directory: URL) throws -> URL {
        var dest = directory.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            let base = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let suffix = L("副本")
            let copyName = ext.isEmpty ? "\(base) \(suffix)" : "\(base) \(suffix).\(ext)"
            dest = directory.appendingPathComponent(copyName)
        }
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    @discardableResult
    static func trash(_ url: URL) throws -> URL? {
        var resulting: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
        return resulting as URL?
    }

    static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

import Foundation

/// Persistent folder-size cache in Application Support.
/// Only ever touched from inside `FolderScanner` (the actor), so it needs no
/// locking of its own. Keyed by path, with a modification-date hint for staleness.
final class SizeCache {
    struct Entry: Codable {
        var size: UInt64
        var mtime: Date?
    }

    private var map: [String: Entry] = [:]
    private let fileURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        fileURL = base
            .appendingPathComponent("MyFinder", isDirectory: true)
            .appendingPathComponent("cache.json")
        load()
    }

    func get(_ path: String, mtime: Date?) -> UInt64? {
        guard let entry = map[path] else { return nil }
        // If both sides have a modification date and they differ, treat as stale.
        if let m = mtime, let em = entry.mtime, abs(m.timeIntervalSince(em)) > 1 {
            return nil
        }
        return entry.size
    }

    func set(_ path: String, size: UInt64, mtime: Date?) {
        map[path] = Entry(size: size, mtime: mtime)
    }

    func remove(_ path: String) {
        map[path] = nil
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return }
        map = decoded
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(map)
            try data.write(to: fileURL)
        } catch {
            NSLog("MyFinder cache save failed: \(error.localizedDescription)")
        }
    }
}

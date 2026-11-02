import Foundation

/// Serializes cache access and owns the recursive size computation.
/// `listContents` and `computeSizeUncached` are `nonisolated` so many scans
/// run concurrently off the actor; only the cache read/write is isolated.
actor FolderScanner {
    private let cache: SizeCache
    private var cacheEnabled = true

    init(cache: SizeCache) {
        self.cache = cache
    }

    // MARK: Listing (no recursive size)

    nonisolated func listContents(of url: URL, showHidden: Bool) throws -> [FileItem] {
        var options: FileManager.DirectoryEnumerationOptions = []
        if !showHidden { options.insert(.skipsHiddenFiles) }
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            .localizedTypeDescriptionKey, .localizedNameKey
        ]
        let urls = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: options)
        return urls.map { FileItem(url: $0) }
    }

    // MARK: Recursive size

    /// Walks the whole subtree and sums on-disk allocated size.
    /// Checks for cancellation periodically so leaving a folder stops work.
    nonisolated func computeSizeUncached(of url: URL) throws -> UInt64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey]
        var total: UInt64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var seen = 0
        for case let fileURL as URL in enumerator {
            seen += 1
            if seen % 512 == 0 { try Task.checkCancellation() }
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += UInt64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    // MARK: Cache (isolated)

    func cachedSize(for url: URL, mtime: Date?) -> UInt64? {
        guard cacheEnabled else { return nil }
        return cache.get(url.path, mtime: mtime)
    }

    func store(_ path: String, size: UInt64, mtime: Date?) {
        guard cacheEnabled else { return }
        cache.set(path, size: size, mtime: mtime)
    }

    func invalidate(_ path: String) {
        cache.remove(path)
    }

    func setCacheEnabled(_ enabled: Bool) {
        cacheEnabled = enabled
    }

    func save() {
        cache.save()
    }
}

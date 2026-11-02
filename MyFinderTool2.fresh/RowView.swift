import SwiftUI

/// Shared helpers for presenting a FileItem.
enum ItemFormat {
    static func size(_ item: FileItem) -> String {
        if item.isDirectory && item.sizeState != .done { return "--" }
        guard let bytes = item.size else { return "--" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    static func date(_ item: FileItem) -> String {
        guard let d = item.modDate else { return "--" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

/// Name cell with the real system icon; shows a tiny spinner while a folder's
/// size is still being computed.
struct NameCell: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 16, height: 16)
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
            if item.isDirectory && item.sizeState == .computing {
                ProgressView()
                    .controlSize(.mini)
                    .padding(.leading, 2)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A large icon tile used by icon / gallery / column views.
struct IconTile: View {
    let item: FileItem
    var size: CGFloat = 48

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
            Text(ItemFormat.size(item))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

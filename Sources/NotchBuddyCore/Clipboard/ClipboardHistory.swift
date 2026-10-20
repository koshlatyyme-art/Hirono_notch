import Foundation

/// The session's last few copies, newest first.
public struct ClipboardHistory: Sendable {
    public static let capacity = 10

    public private(set) var items: [ClipboardItem] = []

    public init() {}

    /// Adds a copy; copying the same content again moves the existing item to the top (same id).
    @discardableResult
    public mutating func add(_ content: ClipboardItem.Content, at date: Date) -> ClipboardItem {
        var item = ClipboardItem(content: content, copiedAt: date)
        if let index = items.firstIndex(where: { $0.dedupKey == item.dedupKey }) {
            item = items.remove(at: index)
            item.copiedAt = date
        }
        items.insert(item, at: 0)
        if items.count > Self.capacity { items.removeLast(items.count - Self.capacity) }
        return item
    }

    public mutating func promote(id: UUID, at date: Date) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.copiedAt = date
        items.insert(item, at: 0)
    }

    public mutating func clear() {
        items.removeAll()
    }
}

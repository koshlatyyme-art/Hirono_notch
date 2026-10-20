/// Tells external copies apart from our own writes, using only the pasteboard's change count
/// (reading the count never needs clipboard access permission).
public struct PasteboardChangeTracker: Sendable {
    private var lastSeen: Int

    public init(initialCount: Int) {
        lastSeen = initialCount
    }

    /// True when the count moved since the last look and the move wasn't ours.
    public mutating func observe(_ count: Int) -> Bool {
        defer { lastSeen = count }
        return count != lastSeen
    }

    public mutating func markOwnWrite(_ count: Int) {
        lastSeen = count
    }
}

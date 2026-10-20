import CryptoKit
import Foundation

/// One thing the user copied during this session.
public struct ClipboardItem: Identifiable, Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case text(String)
        case link(URL)
        case image(Data, uti: String)
    }

    public static let previewLimit = 300

    public let id: UUID
    public let content: Content
    public var copiedAt: Date
    /// Same key = same content; computed once because hashing a large image is not free.
    public let dedupKey: String

    public init(id: UUID = UUID(), content: Content, copiedAt: Date) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        switch content {
        case .text(let text): dedupKey = "t:" + text
        case .link(let url): dedupKey = "l:" + url.absoluteString
        case .image(let data, _): dedupKey = "i:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }

    public var previewText: String? {
        switch content {
        case .text(let text): Self.preview(of: text)
        case .link(let url): url.absoluteString
        case .image: nil
        }
    }

    /// Whitespace runs become one space; at most `previewLimit` characters, then "…".
    /// Walks only as far as needed, so a multi-megabyte paste stays cheap.
    static func preview(of text: String) -> String {
        var out = ""
        var count = 0
        var pendingSpace = false
        for ch in text {
            if ch.isWhitespace {
                pendingSpace = count > 0
                continue
            }
            for next in pendingSpace ? [" ", ch] : [ch] {
                if count == previewLimit { return out + "…" }
                out.append(next)
                count += 1
            }
            pendingSpace = false
        }
        return out
    }
}

import Foundation

/// What the pasteboard held at one moment, as plain values (filled in by the app from NSPasteboard).
public struct PasteboardSnapshot: Equatable, Sendable {
    /// Password managers mark secrets as concealed/transient; Finder files are out of scope.
    static let ignoredTypes: Set<String> = [
        "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "public.file-url",
    ]

    public var types: [String]
    public var string: String?
    public var urlString: String?
    public var png: Data?
    public var tiff: Data?

    public init(types: [String], string: String? = nil, urlString: String? = nil, png: Data? = nil, tiff: Data? = nil) {
        self.types = types
        self.string = string
        self.urlString = urlString
        self.png = png
        self.tiff = tiff
    }

    /// Decided from the types alone, so a password is never read at all.
    public var isIgnored: Bool { types.contains(where: Self.ignoredTypes.contains) }

    public func classify() -> ClipboardItem.Content? {
        if isIgnored { return nil }
        if let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let url = Self.webURL(string) else { return .text(string) }
            return image ?? .link(url)  // a copied image may carry its own address as text: keep the picture
        }
        if let image { return image }
        if let urlString, let url = Self.webURL(urlString) { return .link(url) }
        return nil
    }

    private var image: ClipboardItem.Content? {
        if let png { return .image(png, uti: "public.png") }
        if let tiff { return .image(tiff, uti: "public.tiff") }
        return nil
    }

    /// Longer than any link worth keeping; also keeps a multi-megabyte paste from being scanned.
    static let maxURLLength = 8192

    /// A single http(s) URL with a host and no whitespace inside.
    static func webURL(_ string: String) -> URL? {
        guard string.utf8.count <= maxURLLength else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.prefix(4).lowercased() == "http",
              !trimmed.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host() != nil
        else { return nil }
        return url
    }
}

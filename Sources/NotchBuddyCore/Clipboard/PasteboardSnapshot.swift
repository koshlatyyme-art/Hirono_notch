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

    public func classify() -> ClipboardItem.Content? {
        if types.contains(where: Self.ignoredTypes.contains) { return nil }
        if let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Self.webURL(string).map(ClipboardItem.Content.link) ?? .text(string)
        }
        if let png { return .image(png, uti: "public.png") }
        if let tiff { return .image(tiff, uti: "public.tiff") }
        if let urlString, let url = Self.webURL(urlString) { return .link(url) }
        return nil
    }

    /// A single http(s) URL with a host and no whitespace inside.
    static func webURL(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host() != nil
        else { return nil }
        return url
    }
}

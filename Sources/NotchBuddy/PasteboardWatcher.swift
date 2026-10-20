import AppKit
import NotchBuddyCore

/// Polls the general pasteboard and reports copies made by other apps.
@MainActor
final class PasteboardWatcher {
    private let pasteboard: NSPasteboard
    private let onExternalChange: (ClipboardItem.Content?) -> Void
    private var tracker: PasteboardChangeTracker
    private var timer: Timer?

    /// `onExternalChange` gets nil when the copy can't be read (access denied, password, unsupported type).
    init(pasteboard: NSPasteboard = .general, onExternalChange: @escaping (ClipboardItem.Content?) -> Void) {
        self.pasteboard = pasteboard
        self.onExternalChange = onExternalChange
        tracker = PasteboardChangeTracker(initialCount: pasteboard.changeCount)
    }

    var isAccessDenied: Bool {
        if #available(macOS 15.4, *) {
            return pasteboard.accessBehavior == .alwaysDeny
        }
        return false
    }

    func start() {
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func write(_ item: ClipboardItem) {
        pasteboard.clearContents()
        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .link(let url):
            pasteboard.writeObjects([url as NSURL])
            pasteboard.setString(url.absoluteString, forType: .string)
        case .image(let data, let uti):
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(uti))
        }
        tracker.markOwnWrite(pasteboard.changeCount)
    }

    private func poll() {
        guard tracker.observe(pasteboard.changeCount) else { return }
        onExternalChange(isAccessDenied ? nil : snapshot()?.classify())
    }

    /// Reads only the representations the classifier can use, and nothing at all for ignored copies.
    private func snapshot() -> PasteboardSnapshot? {
        let types = pasteboard.types ?? []
        var snapshot = PasteboardSnapshot(types: types.map(\.rawValue))
        guard !snapshot.isIgnored else { return nil }
        if types.contains(.string) { snapshot.string = pasteboard.string(forType: .string) }
        if types.contains(.URL) { snapshot.urlString = pasteboard.string(forType: .URL) }
        if types.contains(.png) {
            snapshot.png = pasteboard.data(forType: .png)
        } else if types.contains(.tiff) {
            snapshot.tiff = pasteboard.data(forType: .tiff)
        }
        return snapshot
    }
}

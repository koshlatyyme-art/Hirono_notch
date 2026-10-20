import AppKit
import NotchBuddyCore
import Observation

@Observable @MainActor
final class AppModel {
    var geometry = NotchGeometry(screenFrame: .zero, safeAreaTop: 0, auxiliaryTopLeft: nil, auxiliaryTopRight: nil)
    var isExpanded = false
    var isDragging = false

    var history = ClipboardHistory()
    var thumbnails: [UUID: NSImage] = [:]
    var imageSizes: [UUID: CGSize] = [:]
    var accessDenied = false
    var justCopiedID: UUID?

    /// Called when a drag that started in the panel is over (the mouse button is up).
    @ObservationIgnored var onDragEnded: (() -> Void)?
    @ObservationIgnored private var watcher: PasteboardWatcher?
    @ObservationIgnored private var dragTimer: Timer?

    var showsRightEar: Bool { !history.items.isEmpty }

    /// The black shape currently drawn, in screen coordinates.
    var shapeRect: CGRect {
        isExpanded ? geometry.expandedRect : geometry.collapsedRect(showsRightEar: showsRightEar)
    }

    func startWatchingPasteboard() {
        let watcher = PasteboardWatcher { [weak self] content in self?.record(content) }
        watcher.start()
        accessDenied = watcher.isAccessDenied
        self.watcher = watcher
    }

    func copy(_ item: ClipboardItem) {
        watcher?.write(item)
        history.promote(id: item.id, at: .now)
        justCopiedID = item.id
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if justCopiedID == item.id { justCopiedID = nil }
        }
    }

    func clearHistory() {
        history.clear()
        thumbnails.removeAll()
        imageSizes.removeAll()
    }

    func beginDrag() {
        isDragging = true
        dragTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkDragEnded() }
        }
        RunLoop.main.add(timer, forMode: .common)
        dragTimer = timer
    }

    private func checkDragEnded() {
        guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
        dragTimer?.invalidate()
        dragTimer = nil
        isDragging = false
        onDragEnded?()
    }

    func itemProvider(for item: ClipboardItem) -> NSItemProvider {
        switch item.content {
        case .text(let text): NSItemProvider(object: text as NSString)
        case .link(let url): NSItemProvider(object: url as NSURL)
        case .image(let data, _): NSImage(data: data).map { NSItemProvider(object: $0) } ?? NSItemProvider()
        }
    }

    private func record(_ content: ClipboardItem.Content?) {
        accessDenied = watcher?.isAccessDenied ?? false
        guard let content else { return }
        let item = history.add(content, at: .now)
        let alive = Set(history.items.map(\.id))
        thumbnails = thumbnails.filter { alive.contains($0.key) }
        imageSizes = imageSizes.filter { alive.contains($0.key) }
        if case .image(let data, _) = content, thumbnails[item.id] == nil {
            Task {
                guard let (thumb, size) = await Self.thumbnail(of: data) else { return }
                thumbnails[item.id] = NSImage(cgImage: thumb, size: .zero)
                imageSizes[item.id] = size
            }
        }
    }

    /// Decodes only a small thumbnail, off the main thread, so a 50 MB screenshot never blocks the UI.
    private nonisolated static func thumbnail(of data: Data) async -> (CGImage, CGSize)? {
        await Task.detached(priority: .userInitiated) { () -> (CGImage, CGSize)? in
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 128,
            ]
            guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = props?[kCGImagePropertyPixelWidth] as? Int ?? thumb.width
            let height = props?[kCGImagePropertyPixelHeight] as? Int ?? thumb.height
            return (thumb, CGSize(width: width, height: height))
        }.value
    }
}

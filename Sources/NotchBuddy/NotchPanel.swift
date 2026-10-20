import AppKit
import SwiftUI

/// A borderless, never-key panel that sits over the menu bar on every Space.
final class NotchPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        acceptsMouseMovedEvents = true
        let host = FirstMouseHostingView(rootView: rootView)
        host.sizingOptions = []
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Clicks land on the first try, without activating the app.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

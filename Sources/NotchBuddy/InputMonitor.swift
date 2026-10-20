import AppKit
import NotchBuddyCore

/// Watches the mouse everywhere and the system idle time, for the character's brain.
/// Mouse monitors don't need Accessibility permission; keyboard ones would.
@MainActor
final class InputMonitor {
    private let onEvent: (BrainEvent) -> Void
    private let onTick: (TimeInterval) -> Void
    private var monitors: [Any] = []
    private var timer: Timer?

    init(onEvent: @escaping (BrainEvent) -> Void, onTick: @escaping (TimeInterval) -> Void) {
        self.onEvent = onEvent
        self.onTick = onTick
    }

    func start() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.forward(type) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.forward(event.type) }
            return event
        }) {
            monitors.append(local)
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func forward(_ type: NSEvent.EventType) {
        let point = NSEvent.mouseLocation
        switch type {
        case .leftMouseDown, .rightMouseDown: onEvent(.click(point))
        default: onEvent(.cursorMoved(point))
        }
    }

    private func tick() {
        let anyInput = CGEventType(rawValue: ~0)!
        onTick(CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput))
    }
}

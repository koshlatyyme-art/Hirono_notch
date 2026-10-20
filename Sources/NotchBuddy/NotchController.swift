import AppKit
import NotchBuddyCore

/// Places the panel over the notch, lets clicks outside the black shape pass through,
/// and expands the shape while the cursor rests on it.
@MainActor
final class NotchController {
    private static let expandDelay: TimeInterval = 0.2
    private static let collapseDelay: TimeInterval = 0.3

    private let model: AppModel
    private let panel: NotchPanel
    private var monitors: [Any] = []
    private var hoverTimer: Timer?
    /// Debug: `-NotchBuddyForceExpanded YES` keeps the panel open for screenshots.
    private let forceExpanded = UserDefaults.standard.bool(forKey: "NotchBuddyForceExpanded")

    init(model: AppModel) {
        self.model = model
        panel = NotchPanel(rootView: NotchView(model: model))
        model.isExpanded = forceExpanded
        layout()
        panel.orderFrontRegardless()
        model.onDragEnded = { [weak self] in self?.mouseMoved() }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func layout() {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
        guard let screen else { return }
        model.geometry = NotchGeometry(
            screenFrame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeft: screen.auxiliaryTopLeftArea, auxiliaryTopRight: screen.auxiliaryTopRightArea
        )
        NSLog("NotchBuddy screen=%@ safeTop=%.1f left=%@ right=%@ notch=%@",
              NSStringFromRect(screen.frame), screen.safeAreaInsets.top,
              screen.auxiliaryTopLeftArea.map(NSStringFromRect) ?? "nil",
              screen.auxiliaryTopRightArea.map(NSStringFromRect) ?? "nil",
              NSStringFromRect(model.geometry.notchRect))
        panel.setFrame(model.geometry.panelFrame, display: true)
        mouseMoved()
    }

    private func mouseMoved() {
        let inside = model.shapeRect.contains(NSEvent.mouseLocation)
        if !model.isDragging { panel.ignoresMouseEvents = !inside }
        guard !forceExpanded else { return }
        if inside != model.isExpanded {
            scheduleHoverChange(after: inside ? Self.expandDelay : Self.collapseDelay)
        } else {
            hoverTimer?.invalidate()
            hoverTimer = nil
        }
    }

    private func scheduleHoverChange(after delay: TimeInterval) {
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hoverTimerFired() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func hoverTimerFired() {
        hoverTimer = nil
        let inside = model.shapeRect.contains(NSEvent.mouseLocation)
        if inside && !model.isExpanded {
            model.isExpanded = true
        } else if !inside && model.isExpanded && !model.isDragging {
            model.isExpanded = false
        }
        mouseMoved()
    }
}

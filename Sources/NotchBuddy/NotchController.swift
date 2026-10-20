import AppKit
import NotchBuddyCore

/// Places the panel over the notch and lets clicks outside the black shape pass through.
@MainActor
final class NotchController {
    private let model: AppModel
    private let panel: NotchPanel
    private var monitors: [Any] = []

    init(model: AppModel) {
        self.model = model
        panel = NotchPanel(rootView: NotchView(model: model))
        layout()
        panel.orderFrontRegardless()

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
        guard !model.isDragging else { return }
        panel.ignoresMouseEvents = !model.shapeRect.contains(NSEvent.mouseLocation)
    }
}

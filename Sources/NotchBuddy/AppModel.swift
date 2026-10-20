import CoreGraphics
import NotchBuddyCore
import Observation

@Observable @MainActor
final class AppModel {
    var geometry = NotchGeometry(screenFrame: .zero, safeAreaTop: 0, auxiliaryTopLeft: nil, auxiliaryTopRight: nil)
    var isExpanded = false
    var isDragging = false

    /// The black shape currently drawn, in screen coordinates.
    var shapeRect: CGRect {
        isExpanded ? geometry.expandedRect : geometry.collapsedRect(showsRightEar: false)
    }
}

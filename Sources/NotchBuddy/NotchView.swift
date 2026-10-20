import NotchBuddyCore
import SwiftUI

/// The black shape that extends the hardware notch: ears when collapsed, a panel when expanded.
struct NotchView: View {
    let model: AppModel

    var body: some View {
        let panel = model.geometry.panelFrame
        let shape = model.shapeRect
        let radius: CGFloat = model.isExpanded ? 18 : 10
        UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
            .fill(.black)
            .frame(width: shape.width, height: shape.height)
            .offset(x: shape.minX - panel.minX, y: panel.maxY - shape.maxY)
            .frame(width: panel.width, height: panel.height, alignment: .topLeading)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isExpanded)
    }
}

import NotchBuddyCore
import SwiftUI

/// The black shape that extends the hardware notch: ears when collapsed, a panel when expanded.
struct NotchView: View {
    let model: AppModel

    var body: some View {
        let panel = model.geometry.panelFrame
        let notch = model.geometry.notchRect
        let shape = model.shapeRect
        let radius: CGFloat = model.isExpanded ? 18 : 10
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
                .fill(.black)
                .frame(width: shape.width, height: shape.height)
                .offset(x: shape.minX - panel.minX, y: panel.maxY - shape.maxY)

            if model.isExpanded {
                HStack(spacing: 8) {
                    Color.clear.frame(width: 120)  // the character's seat
                    ClipboardListView(model: model)
                }
                .padding(EdgeInsets(top: notch.height + 6, leading: 12, bottom: 12, trailing: 12))
                .frame(width: shape.width, height: shape.height)
                .offset(x: shape.minX - panel.minX, y: panel.maxY - shape.maxY)
                .transition(.opacity)
            } else if model.showsRightEar {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.clipboard")
                    Text("\(model.history.items.count)")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: NotchGeometry.earWidth, height: notch.height)
                .offset(x: notch.maxX - panel.minX, y: panel.maxY - notch.maxY)
                .transition(.opacity)
            }
        }
        .frame(width: panel.width, height: panel.height, alignment: .topLeading)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isExpanded)
        .animation(.easeOut(duration: 0.2), value: model.showsRightEar)
    }
}

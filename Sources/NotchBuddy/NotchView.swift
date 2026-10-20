import NotchBuddyCore
import SwiftUI

/// The black shape that extends the hardware notch: ears when collapsed, a panel when expanded.
struct NotchView: View {
    static let portraitHeight: CGFloat = 30
    static let fullHeight: CGFloat = 100

    let model: AppModel
    let character: CharacterModel
    let assets: CharacterAssets?

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
                    Group {
                        if let assets {
                            CharacterView(assets: assets, pose: character.pose, frame: "full", height: Self.fullHeight)
                        }
                    }
                    .frame(width: 120)
                    ClipboardListView(model: model)
                }
                .padding(EdgeInsets(top: notch.height + 6, leading: 12, bottom: 12, trailing: 12))
                .frame(width: shape.width, height: shape.height)
                .offset(x: shape.minX - panel.minX, y: panel.maxY - shape.maxY)
                .transition(.opacity)
            } else {
                if let assets {
                    CharacterView(assets: assets, pose: character.pose, frame: "portrait", height: Self.portraitHeight)
                        .frame(width: NotchGeometry.earWidth, height: notch.height)
                        .offset(x: notch.minX - NotchGeometry.earWidth - panel.minX, y: panel.maxY - notch.maxY)
                        .transition(.opacity)
                }
            }
            if !model.isExpanded && model.showsRightEar {
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
        .onChange(of: model.isExpanded, initial: true) { _, expanded in
            character.setFrameRate(expanded ? 60 : 30)
        }
    }
}

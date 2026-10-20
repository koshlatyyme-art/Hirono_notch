import NotchBuddyCore
import SwiftUI

/// The black shape that extends the hardware notch: ears when collapsed, a panel when expanded.
struct NotchView: View {
    static let portraitHeight: CGFloat = 30
    static let fullHeight: CGFloat = 120
    static let seatWidth: CGFloat = 128
    static let topGap: CGFloat = 6
    static let inset: CGFloat = 8

    let model: AppModel
    let character: CharacterModel
    let assets: CharacterAssets?

    var body: some View {
        let panel = model.geometry.panelFrame
        let notch = model.geometry.notchRect
        let expanded = model.geometry.expandedRect
        let shape = model.shapeRect
        let radius: CGFloat = model.isExpanded ? 18 : 10
        ZStack(alignment: .topLeading) {
            // The panel's content keeps its place on screen; the animated shape only reveals or hides it.
            ZStack(alignment: .topLeading) {
                Color.black
                if model.isExpanded {
                    expandedContent(notchHeight: notch.height)
                        .frame(width: expanded.width, height: expanded.height)
                        .offset(x: expanded.minX - shape.minX)
                        .transition(.opacity)
                }
            }
            .frame(width: shape.width, height: shape.height, alignment: .topLeading)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous))
            .offset(x: shape.minX - panel.minX, y: panel.maxY - shape.maxY)

            if !model.isExpanded {
                if let assets {
                    LiveCharacter(character: character, assets: assets, frame: "portrait", height: Self.portraitHeight)
                        .frame(width: NotchGeometry.earWidth, height: notch.height)
                        .contentShape(Rectangle())
                        .contextMenu { menu }
                        .offset(x: notch.minX - NotchGeometry.earWidth - panel.minX, y: panel.maxY - notch.maxY)
                        .transition(.opacity)
                }
                if model.showsRightEar {
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
        }
        .frame(width: panel.width, height: panel.height, alignment: .topLeading)
        // Opening may bounce a little; closing settles without overshoot so the edge doesn't jerk.
        .animation(model.isExpanded ? .spring(response: 0.35, dampingFraction: 0.8) : .smooth(duration: 0.25),
                   value: model.isExpanded)
        .animation(.easeOut(duration: 0.2), value: model.showsRightEar)
        .onChange(of: model.isExpanded, initial: true) { _, expanded in
            character.isExpanded = expanded
        }
    }

    private func expandedContent(notchHeight: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Group {
                if let assets {
                    LiveCharacter(character: character, assets: assets, frame: "full", height: Self.fullHeight)
                        .contextMenu { menu }
                }
            }
            .frame(width: Self.seatWidth)
            ClipboardListView(model: model)
        }
        .padding(EdgeInsets(top: notchHeight + Self.topGap, leading: Self.inset, bottom: Self.inset, trailing: 12))
    }

    @ViewBuilder private var menu: some View {
        Button("Очистить историю") { model.clearHistory() }
        Divider()
        Button("Выйти") { NSApp.terminate(nil) }
    }
}

/// Reads the per-frame pose in its own body, so only the character redraws each frame, not the whole notch.
private struct LiveCharacter: View {
    let character: CharacterModel
    let assets: CharacterAssets
    let frame: String
    let height: CGFloat

    var body: some View {
        CharacterView(assets: assets, pose: character.pose, time: character.time, frame: frame, height: height)
    }
}

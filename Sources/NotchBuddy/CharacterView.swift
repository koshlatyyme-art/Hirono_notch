import NotchBuddyCore
import SwiftUI

/// The layered character in one pose, cropped to a rig frame ("portrait" or "full") and scaled to `height`.
struct CharacterView: View {
    static let nightTint = (red: 0x4D / 255.0, green: 0x55 / 255.0, blue: 0x73 / 255.0)

    let assets: CharacterAssets
    let pose: Pose
    let frame: String
    let height: CGFloat

    var body: some View {
        let rig = assets.rig
        let crop = rig.frame(frame) ?? CGRect(origin: .zero, size: rig.canvasSize)
        let scale = height / crop.height
        let canvas = CGSize(width: rig.canvasSize.width * scale, height: rig.canvasSize.height * scale)
        let world = worldTransforms(for: pose, rig: rig)
        ZStack(alignment: .topLeading) {
            ForEach(rig.layers, id: \.name) { layer in
                if let image = assets.images[layer.name] {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: canvas.width, height: canvas.height)
                        .colorMultiply(tint)
                        .transformEffect(Self.inView(world[layer.name] ?? .identity, scale: scale))
                }
            }
            ForEach(rig.glows, id: \.name) { glow in
                glowView(glow, world: world, scale: scale)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .offset(x: -crop.minX * scale, y: -crop.minY * scale)
        .frame(width: crop.width * scale, height: crop.height * scale, alignment: .topLeading)
        .clipped()
    }

    private var tint: Color {
        let n = pose.night, t = Self.nightTint
        return Color(red: 1 - n * (1 - t.red), green: 1 - n * (1 - t.green), blue: 1 - n * (1 - t.blue))
    }

    @ViewBuilder
    private func glowView(_ glow: Rig.Glow, world: [String: CGAffineTransform], scale: CGFloat) -> some View {
        let flash = switch glow.name {
        case "heart": pose.heartGlow
        case "antenna": pose.antennaGlow
        default: 0.0
        }
        let strength = max(pose.night * glow.night, flash)
        if strength > 0.01 {
            let center = CGPoint(x: glow.center[0], y: glow.center[1]).applying(world[glow.parent] ?? .identity)
            let radius = glow.radius * scale
            let color = Color(hex: glow.color)
            Circle()
                .fill(RadialGradient(stops: [  // ≈ (1 − d)², like the preview sheet
                    .init(color: color.opacity(strength), location: 0),
                    .init(color: color.opacity(strength * 0.56), location: 0.25),
                    .init(color: color.opacity(strength * 0.25), location: 0.5),
                    .init(color: color.opacity(strength * 0.06), location: 0.75),
                    .init(color: color.opacity(0), location: 1),
                ], center: .center, startRadius: 0, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .position(x: center.x * scale, y: center.y * scale)
                .blendMode(.plusLighter)
        }
    }

    /// A canvas-pixel transform, re-expressed for a view drawn at `scale`.
    static func inView(_ t: CGAffineTransform, scale: CGFloat) -> CGAffineTransform {
        CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)
            .concatenating(t)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
    }
}

extension Color {
    /// "#RRGGBB"
    init(hex: String) {
        let value = Int(hex.dropFirst(), radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

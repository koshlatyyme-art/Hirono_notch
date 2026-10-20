import CoreGraphics
import Foundation

/// Everything the character's body is doing right now, normalized.
public struct Pose: Equatable, Sendable {
    /// −1…1
    public var lean = 0.0, headTilt = 0.0, headTurn = 0.0, arm = 0.0, antenna = 0.0
    /// 0…1
    public var bounce = 0.0, breath = 0.0, sleep = 0.0, night = 0.0
    /// 0…1
    public var heartGlow = 0.0, antennaGlow = 0.0

    public static let rest = Pose()
}

/// Where the behavior wants the body to go; springs get it there.
public struct PoseTargets: Equatable, Sendable {
    public var lean = 0.0, headTilt = 0.0, headTurn = 0.0, sleep = 0.0
    public var wiggle = false

    public init(lean: Double = 0, headTilt: Double = 0, headTurn: Double = 0, sleep: Double = 0, wiggle: Bool = false) {
        self.lean = lean
        self.headTilt = headTilt
        self.headTurn = headTurn
        self.sleep = sleep
        self.wiggle = wiggle
    }
}

/// A layer's own motion relative to its parent, about its pivot.
public struct LayerTransform: Equatable, Sendable {
    /// Degrees, clockwise on screen.
    public var rotation = 0.0
    /// Degrees about the vertical axis, drawn as horizontal foreshortening.
    public var turn = 0.0
    /// Canvas pixels.
    public var offset = CGVector.zero
    public var scaleY = 1.0
    /// Uniform, about the pivot.
    public var scale = 1.0

    public static let identity = LayerTransform()
}

func clamp(_ value: Double, _ low: Double = -1, _ high: Double = 1) -> Double {
    min(max(value, low), high)
}

public func transforms(for pose: Pose, rig: Rig) -> [String: LayerTransform] {
    var out = Dictionary(uniqueKeysWithValues: rig.layers.map { ($0.name, LayerTransform.identity) })
    let height = rig.canvasSize.height
    func set(_ name: String, _ transform: LayerTransform) {
        if out[name] != nil { out[name] = transform }
    }
    set("body", LayerTransform(rotation: clamp(pose.lean) * rig.limit("body"),
                               offset: CGVector(dx: 0, dy: -pose.bounce * 0.08 * height),
                               scaleY: 1 + 0.015 * pose.breath))
    set("head", LayerTransform(rotation: clamp(pose.headTilt) * rig.limit("head") + pose.sleep * 0.8 * rig.limit("head"),
                               turn: clamp(pose.headTurn) * rig.limit("headTurn"),
                               offset: CGVector(dx: clamp(pose.headTurn) * 0.015 * rig.canvasSize.width,
                                                dy: pose.sleep * 0.03 * height)))
    set("arm", LayerTransform(rotation: clamp(pose.arm) * rig.limit("arm")))
    set("antenna", LayerTransform(rotation: clamp(pose.antenna) * rig.limit("antenna")))
    set("heart", LayerTransform(scale: 1 + 0.3 * clamp(pose.heartGlow, 0, 1)))  // pops when it flashes
    return out
}

/// How visible a layer is: overlays fade in with the pose value they follow.
public func opacity(of layer: Rig.Layer, in pose: Pose) -> Double {
    switch layer.opacityFrom {
    case "sleep": clamp(pose.sleep, 0, 1)
    default: 1
    }
}

/// Canvas → canvas transform of every layer, its ancestors' motion included (same math as tools/rig/riglib.py).
public func worldTransforms(for pose: Pose, rig: Rig) -> [String: CGAffineTransform] {
    let local = transforms(for: pose, rig: rig)
    func matrix(_ layer: Rig.Layer) -> CGAffineTransform {
        let t = local[layer.name] ?? .identity
        let px = layer.pivot[0], py = layer.pivot[1]
        return CGAffineTransform(translationX: -px, y: -py)
            .concatenating(CGAffineTransform(scaleX: t.scale * cos(t.turn * .pi / 180), y: t.scale * t.scaleY))
            .concatenating(CGAffineTransform(rotationAngle: t.rotation * .pi / 180))
            .concatenating(CGAffineTransform(translationX: px + t.offset.dx, y: py + t.offset.dy))
    }
    var out: [String: CGAffineTransform] = [:]
    for layer in rig.layers {
        out[layer.name] = rig.chain(to: layer.name).reversed().reduce(.identity) { $0.concatenating(matrix($1)) }
    }
    return out
}

import Foundation

/// Turns behavior targets into a smooth, slightly springy pose, one frame at a time.
public struct PoseAnimator: Sendable {
    public static let breathPeriod = 4.0
    /// How hard the antenna swings against the head's acceleration.
    static let antennaInertia = 0.4

    public private(set) var pose = Pose.rest

    private struct Track: Sendable {
        let reaction: Reaction
        var elapsed = 0.0
    }

    private var tracks: [Track] = []

    var lean = Spring(stiffness: 40, damping: 12)
    var headTilt = Spring(stiffness: 60, damping: 11)
    var headTurn = Spring(stiffness: 60, damping: 11)
    var arm = Spring(stiffness: 90, damping: 9)
    var antenna = Spring(stiffness: 70, damping: 3.5)
    var bounce = Spring(stiffness: 140, damping: 10)
    var sleep = Spring(stiffness: 12, damping: 7)
    var night = Spring(stiffness: 4, damping: 4)
    var heartGlow = Spring(stiffness: 9, damping: 6)  // flashes linger ~half a second
    var antennaGlow = Spring(stiffness: 16, damping: 8)

    public init() {}

    private static var allSprings: [WritableKeyPath<Self, Spring>] {
        [\.lean, \.headTilt, \.headTurn, \.arm, \.antenna, \.bounce, \.sleep, \.night, \.heartGlow, \.antennaGlow]
    }

    /// Nothing is moving except the breath: the renderer can slow down.
    public var isSettled: Bool {
        tracks.isEmpty && Self.allSprings.allSatisfy {
            abs(self[keyPath: $0].velocity) < 0.001 && abs(self[keyPath: $0].value - self[keyPath: $0].target) < 0.002
        }
    }

    /// Starts a reaction: kicks (bounce, glow flashes) land now, sways play out over its duration.
    public mutating func play(_ reaction: Reaction) {
        switch reaction {
        case .flinch:
            bounce.impulse(1.5)
            antennaGlow.value = 1
        case .jump:
            bounce.impulse(12)
            heartGlow.value = 1
        case .catchCopy:
            heartGlow.value = max(heartGlow.value, 0.7)
            antennaGlow.value = 1
        case .wake:
            bounce.impulse(2.5)
            antennaGlow.value = 1
        case .stretch, .shakeHead, .alienWiggle:
            break
        }
        tracks.append(Track(reaction: reaction))
    }

    /// What the running reactions add to the targets this frame.
    private func sway(time: Double, wiggle: Bool) -> (tilt: Double, turn: Double, arm: Double) {
        var tilt = 0.0, turn = 0.0, arm = 0.0
        for track in tracks {
            let p = track.elapsed / track.reaction.duration
            switch track.reaction {
            case .jump: arm += -0.6 * sin(2 * .pi * 2 * p)
            case .catchCopy: arm += -0.8 * sin(.pi * p)
            case .stretch: tilt += -0.6 * sin(2 * .pi * p)
            case .shakeHead: turn += 0.8 * sin(2 * .pi * 3 * p)
            case .alienWiggle: arm += 0.4 * sin(2 * .pi * 4 * p)
            case .flinch, .wake: break
            }
        }
        if wiggle {  // slow enough for the springs to follow
            arm += 0.35 * sin(2 * .pi * 2.5 * time)
            tilt += 0.4 * sin(2 * .pi * 2 * time)
        }
        return (tilt, turn, arm)
    }

    public mutating func step(dt: Double, time: Double, targets: PoseTargets, night isNight: Bool) -> Pose {
        let sway = sway(time: time, wiggle: targets.wiggle)
        lean.target = targets.lean
        headTilt.target = targets.headTilt + sway.tilt
        headTurn.target = targets.headTurn + sway.turn
        arm.target = sway.arm
        sleep.target = targets.sleep
        night.target = isNight ? 1 : 0
        for i in tracks.indices { tracks[i].elapsed += dt }
        tracks.removeAll { $0.elapsed >= $0.reaction.duration }

        let headVelocity = headTilt.velocity + lean.velocity
        for keyPath in Self.allSprings {
            self[keyPath: keyPath].step(dt: dt)
        }
        antenna.impulse(-Self.antennaInertia * (headTilt.velocity + lean.velocity - headVelocity))

        pose = Pose(lean: lean.value, headTilt: headTilt.value, headTurn: headTurn.value, arm: arm.value,
                    antenna: antenna.value, bounce: max(0, bounce.value),
                    breath: 0.5 + 0.5 * sin(2 * .pi * time / Self.breathPeriod),
                    sleep: clamp(sleep.value, 0, 1), night: clamp(night.value, 0, 1),
                    heartGlow: clamp(heartGlow.value, 0, 1), antennaGlow: clamp(antennaGlow.value, 0, 1))
        return pose
    }
}

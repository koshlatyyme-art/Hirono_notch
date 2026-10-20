import Foundation

/// Turns behavior targets into a smooth, slightly springy pose, one frame at a time.
public struct PoseAnimator: Sendable {
    public static let breathPeriod = 4.0
    /// How hard the antenna swings against the head's acceleration.
    static let antennaInertia = 0.4

    public private(set) var pose = Pose.rest

    var lean = Spring(stiffness: 40, damping: 12)
    var headTilt = Spring(stiffness: 60, damping: 11)
    var headTurn = Spring(stiffness: 60, damping: 11)
    var arm = Spring(stiffness: 90, damping: 9)
    var antenna = Spring(stiffness: 70, damping: 3.5)
    var bounce = Spring(stiffness: 140, damping: 10)
    var sleep = Spring(stiffness: 12, damping: 7)
    var night = Spring(stiffness: 4, damping: 4)
    var heartGlow = Spring(stiffness: 30, damping: 11)
    var antennaGlow = Spring(stiffness: 40, damping: 13)

    public init() {}

    public mutating func step(dt: Double, time: Double, targets: PoseTargets, night isNight: Bool) -> Pose {
        lean.target = targets.lean
        headTilt.target = targets.headTilt
        headTurn.target = targets.headTurn
        sleep.target = targets.sleep
        night.target = isNight ? 1 : 0

        let headVelocity = headTilt.velocity + lean.velocity
        for keyPath in [\Self.lean, \.headTilt, \.headTurn, \.arm, \.antenna, \.bounce, \.sleep, \.night,
                        \.heartGlow, \.antennaGlow] as [WritableKeyPath<Self, Spring>] {
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

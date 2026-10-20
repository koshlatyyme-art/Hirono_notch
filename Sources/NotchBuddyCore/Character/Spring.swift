/// A damped spring for one animated value.
public struct Spring: Sendable {
    /// Longer frames (a Mac waking from sleep) are cut short so the spring can't blow up.
    public static let maxStep = 1.0 / 20

    public var value: Double
    public var velocity = 0.0
    public var target: Double
    public var stiffness: Double
    public var damping: Double

    public init(value: Double = 0, stiffness: Double = 120, damping: Double = 14) {
        self.value = value
        self.target = value
        self.stiffness = stiffness
        self.damping = damping
    }

    /// Semi-implicit Euler.
    public mutating func step(dt: Double) {
        let h = min(max(dt, 0), Self.maxStep)
        velocity += (stiffness * (target - value) - damping * velocity) * h
        value += velocity * h
    }

    public mutating func impulse(_ dv: Double) {
        velocity += dv
    }
}

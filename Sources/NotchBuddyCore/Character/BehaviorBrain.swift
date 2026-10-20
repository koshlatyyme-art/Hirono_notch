import CoreGraphics
import Foundation

public enum BehaviorState: Equatable, Sendable {
    case idle, attentive, tickled, sleeping
}

/// Something that happened, in screen coordinates.
public enum BrainEvent: Equatable, Sendable {
    case cursorMoved(CGPoint)
    case click(CGPoint)
    case copied
}

/// Decides what the character pays attention to and when it acts on its own.
public struct BehaviorBrain: Sendable {
    public static let sleepAfter: TimeInterval = 300
    public static let attentionRadius: Double = 200
    public static let idleActionInterval: ClosedRange<TimeInterval> = 15...40
    static let idleActions: [Reaction] = [.stretch, .shakeHead, .alienWiggle]

    /// Where the visible character is on screen.
    public var characterRect: CGRect = .zero
    public private(set) var state: BehaviorState = .idle

    private var cursor: CGPoint?
    private var random: SeededRandom
    private var nextIdleAction: Date

    public init(now: Date, seed: UInt64) {
        random = SeededRandom(seed: seed)
        nextIdleAction = now
        scheduleIdleAction(after: now)
    }

    public var targets: PoseTargets {
        guard state != .sleeping else { return PoseTargets(sleep: 1) }
        guard let cursor else { return PoseTargets() }
        let dx = Double(cursor.x - characterRect.midX)
        let attention = clamp(1 - distance(to: cursor) / Self.attentionRadius, 0, 1)
        return PoseTargets(lean: clamp(dx / 600), headTilt: clamp(dx / 500) * 0.5 * (1 - attention),
                           headTurn: clamp(dx / 300), wiggle: state == .tickled)
    }

    public mutating func handle(_ event: BrainEvent, now: Date) -> Reaction? {
        let wasAsleep = state == .sleeping
        switch event {
        case .cursorMoved(let point):
            cursor = point
            state = mood(for: point)
            return wasAsleep ? react(.wake, now) : nil
        case .click(let point):
            if wasAsleep {
                state = mood(for: cursor ?? point)
                return react(.wake, now)
            }
            return react(characterRect.contains(point) ? .jump : .flinch, now)
        case .copied:
            if wasAsleep { state = cursor.map(mood(for:)) ?? .idle }
            return react(.catchCopy, now)
        }
    }

    public mutating func tick(now: Date, systemIdle: TimeInterval) -> Reaction? {
        if systemIdle >= Self.sleepAfter {
            state = .sleeping
            return nil
        }
        if state == .sleeping {
            guard systemIdle < 1 else { return nil }  // typing counts as activity too
            state = cursor.map(mood(for:)) ?? .idle
            return react(.wake, now)
        }
        guard now >= nextIdleAction else { return nil }
        return react(Self.idleActions.randomElement(using: &random)!, now)
    }

    private func mood(for point: CGPoint) -> BehaviorState {
        if characterRect.contains(point) { return .tickled }
        return distance(to: point) < Self.attentionRadius ? .attentive : .idle
    }

    private func distance(to point: CGPoint) -> Double {
        Double(hypot(point.x - characterRect.midX, point.y - characterRect.midY))
    }

    private mutating func react(_ reaction: Reaction, _ now: Date) -> Reaction {
        scheduleIdleAction(after: now)
        return reaction
    }

    private mutating func scheduleIdleAction(after now: Date) {
        nextIdleAction = now.addingTimeInterval(.random(in: Self.idleActionInterval, using: &random))
    }
}

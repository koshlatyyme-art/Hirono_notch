import AppKit
import NotchBuddyCore
import QuartzCore

/// Feeds events to the brain, steps the springs on every display frame, and publishes the pose.
@Observable @MainActor
final class CharacterModel {
    private(set) var pose = Pose.rest
    @ObservationIgnored private var brain = BehaviorBrain(now: .now, seed: .random(in: 0...UInt64.max))
    @ObservationIgnored private var animator = PoseAnimator()
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastTimestamp: CFTimeInterval?
    /// Debug: `-NotchBuddyForceNight YES`.
    @ObservationIgnored private let forceNight = UserDefaults.standard.bool(forKey: "NotchBuddyForceNight")

    func start(on screen: NSScreen) {
        link?.invalidate()
        let target = DisplayLinkTarget { [weak self] timestamp in self?.tick(at: timestamp) }
        let link = screen.displayLink(target: target, selector: #selector(DisplayLinkTarget.fire(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        setFrameRate(30)
    }

    /// `characterRect`: where the character is visible right now, in screen coordinates.
    func handle(_ event: BrainEvent, characterRect: CGRect) {
        brain.characterRect = characterRect
        if let reaction = brain.handle(event, now: .now) { animator.play(reaction) }
    }

    func tick(systemIdle: TimeInterval) {
        if let reaction = brain.tick(now: .now, systemIdle: systemIdle) { animator.play(reaction) }
    }

    func setFrameRate(_ fps: Float) {
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: min(15, fps), maximum: fps, preferred: fps)
    }

    private func tick(at timestamp: CFTimeInterval) {
        let dt = lastTimestamp.map { timestamp - $0 } ?? 1.0 / 60
        lastTimestamp = timestamp
        pose = animator.step(dt: dt, time: timestamp, targets: brain.targets, night: forceNight)
    }
}

/// CADisplayLink needs an Objective-C target; this one forwards to a closure.
/// The link is added to the main run loop, so it always fires on the main thread.
@MainActor
final class DisplayLinkTarget: NSObject {
    private let handler: (CFTimeInterval) -> Void

    init(_ handler: @escaping (CFTimeInterval) -> Void) {
        self.handler = handler
    }

    @objc func fire(_ link: CADisplayLink) {
        handler(link.targetTimestamp)
    }
}

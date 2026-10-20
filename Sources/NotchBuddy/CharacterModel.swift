import AppKit
import NotchBuddyCore
import QuartzCore

/// Feeds events to the brain, steps the springs on every display frame, and publishes the pose.
/// Draws only as often as the motion needs: 60 fps open, 30 while moving, 15 at rest, 10 asleep.
@Observable @MainActor
final class CharacterModel {
    private(set) var pose = Pose.rest
    /// Seconds on the display clock, for things that loop (the sleeping "z").
    private(set) var time: CFTimeInterval = 0
    @ObservationIgnored var isExpanded = false
    @ObservationIgnored private var brain = BehaviorBrain(now: .now, seed: .random(in: 0...UInt64.max))
    @ObservationIgnored private var animator = PoseAnimator()
    @ObservationIgnored private var isNight = false
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var frameRate: Float = 0
    @ObservationIgnored private var lastTimestamp: CFTimeInterval?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    /// Debug: `-NotchBuddyForceNight YES`.
    @ObservationIgnored private let forceNight = UserDefaults.standard.bool(forKey: "NotchBuddyForceNight")

    func start(on screen: NSScreen) {
        link?.invalidate()
        let target = DisplayLinkTarget { [weak self] timestamp in self?.tick(at: timestamp) }
        let link = screen.displayLink(target: target, selector: #selector(DisplayLinkTarget.fire(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        frameRate = 0
        updateNight()
        if observers.isEmpty { observeDisplaySleep() }
    }

    /// `characterRect`: where the character is visible right now, in screen coordinates.
    func handle(_ event: BrainEvent, characterRect: CGRect) {
        brain.characterRect = characterRect
        if let reaction = brain.handle(event, now: .now) { animator.play(reaction) }
    }

    /// Once a second. Idle acts are skipped while nothing is drawn, so they don't all play at once later.
    func tick(systemIdle: TimeInterval) {
        if let reaction = brain.tick(now: .now, systemIdle: systemIdle), link?.isPaused != true {
            animator.play(reaction)
        }
        updateNight()
    }

    private func tick(at timestamp: CFTimeInterval) {
        let dt = lastTimestamp.map { timestamp - $0 } ?? 1.0 / 60
        lastTimestamp = timestamp
        time = timestamp
        pose = animator.step(dt: dt, time: timestamp, targets: brain.targets, night: isNight)
        let settled = animator.isSettled
        setFrameRate(isExpanded ? 60 : !settled ? 30 : brain.state == .sleeping ? 10 : 15)
    }

    private func setFrameRate(_ fps: Float) {
        guard fps != frameRate else { return }
        frameRate = fps
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
    }

    private func updateNight() {
        isNight = forceNight || NightSchedule.isNight(.now)
    }

    /// No frames at all while the displays are off.
    private func observeDisplaySleep() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) {
            [weak self] _ in MainActor.assumeIsolated { self?.link?.isPaused = true }
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated {
                self?.lastTimestamp = nil
                self?.link?.isPaused = false
            }
        })
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

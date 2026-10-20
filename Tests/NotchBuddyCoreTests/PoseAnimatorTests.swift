import Testing
@testable import NotchBuddyCore

@Suite struct PoseAnimatorTests {
    let dt = 1.0 / 60

    /// Runs the animator for `seconds`, returning every pose.
    func run(_ a: inout PoseAnimator, seconds: Double, from start: Double = 0,
             targets: PoseTargets = PoseTargets(), night: Bool = false) -> [Pose] {
        (0..<Int(seconds / dt)).map { i in a.step(dt: dt, time: start + Double(i) * dt, targets: targets, night: night) }
    }

    @Test func followsLeanTarget() {
        var a = PoseAnimator()
        let poses = run(&a, seconds: 2, targets: PoseTargets(lean: 1))
        #expect(poses.last!.lean > 0.95)
    }

    @Test func breathesEveryFourSeconds() {
        var a = PoseAnimator()
        let breath = run(&a, seconds: 4).map(\.breath)
        #expect(breath.min()! < 0.1)
        #expect(breath.max()! > 0.9)
    }

    @Test func antennaLagsBehindHeadThenSettles() {
        var a = PoseAnimator()
        _ = run(&a, seconds: 1)
        let swing = run(&a, seconds: 0.5, from: 1, targets: PoseTargets(headTilt: 1)).map { abs($0.antenna) }
        #expect(swing.max()! > 0.05)
        let after = run(&a, seconds: 3, from: 1.5, targets: PoseTargets(headTilt: 1))
        #expect(abs(after.last!.antenna) < 0.02)
    }

    @Test func nightFadesIn() {
        var a = PoseAnimator()
        let poses = run(&a, seconds: 5, night: true)
        #expect(poses.last!.night > 0.95)
    }
}

@Suite struct PoseAnimatorSettlingTests {
    let dt = 1.0 / 60

    @Test func settlesWhenLeftAlone() {
        var a = PoseAnimator()
        for i in 0..<Int(3 / dt) { _ = a.step(dt: dt, time: Double(i) * dt, targets: PoseTargets(), night: false) }
        #expect(a.isSettled)
    }

    @Test func notSettledWhileReacting() {
        var a = PoseAnimator()
        a.play(.jump)
        _ = a.step(dt: dt, time: 0, targets: PoseTargets(), night: false)
        #expect(!a.isSettled)
    }

    @Test func notSettledWhileTickled() {
        var a = PoseAnimator()
        for i in 0..<Int(3 / dt) { _ = a.step(dt: dt, time: Double(i) * dt, targets: PoseTargets(wiggle: true), night: false) }
        #expect(!a.isSettled)
    }
}

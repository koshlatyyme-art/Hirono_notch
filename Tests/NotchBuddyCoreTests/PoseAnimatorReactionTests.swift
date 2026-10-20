import Testing
@testable import NotchBuddyCore

@Suite struct PoseAnimatorReactionTests {
    let dt = 1.0 / 60

    func steps(_ seconds: Double) -> Int { Int(seconds / dt) }

    @Test(arguments: Reaction.allCases)
    func reactionEndsAndSettles(reaction: Reaction) {
        var calm = PoseAnimator(), lively = PoseAnimator()
        lively.play(reaction)
        var a = Pose.rest, b = Pose.rest
        for i in 0..<steps(reaction.duration + 2) {
            let time = Double(i) * dt
            a = calm.step(dt: dt, time: time, targets: PoseTargets(), night: false)
            b = lively.step(dt: dt, time: time, targets: PoseTargets(), night: false)
        }
        for key in [\Pose.lean, \Pose.headTilt, \Pose.headTurn, \Pose.arm, \Pose.antenna, \Pose.bounce, \Pose.heartGlow, \Pose.antennaGlow] {
            #expect(abs(a[keyPath: key] - b[keyPath: key]) < 0.05)
        }
    }

    func run(_ reaction: Reaction, seconds: Double) -> [Pose] {
        var animator = PoseAnimator()
        animator.play(reaction)
        return (0..<steps(seconds)).map { animator.step(dt: dt, time: Double($0) * dt, targets: PoseTargets(), night: false) }
    }

    @Test func jumpLeavesTheGround() {
        #expect(run(.jump, seconds: 1).map(\.bounce).max()! > 0.5)
    }

    @Test func catchLightsTheHeart() {
        #expect(run(.catchCopy, seconds: 0.1).map(\.heartGlow).max()! > 0.5)
    }

    @Test func flinchBlinksTheAntenna() {
        #expect(run(.flinch, seconds: 0.1).map(\.antennaGlow).max()! > 0.5)
    }

    @Test func wiggleKeepsMoving() {
        var animator = PoseAnimator()
        let arms = (0..<steps(2)).map {
            animator.step(dt: dt, time: Double($0) * dt, targets: PoseTargets(wiggle: true), night: false).arm
        }
        #expect(arms.max()! - arms.min()! > 0.1)
    }
}

@Suite struct PoseAnimatorQueueTests {
    let dt = 1.0 / 60

    func poses(playing reaction: Reaction, times: Int) -> [Pose] {
        var animator = PoseAnimator()
        for _ in 0..<times { animator.play(reaction) }
        return (0..<Int(1.2 / dt)).map { animator.step(dt: dt, time: Double($0) * dt, targets: PoseTargets(), night: false) }
    }

    @Test(arguments: [Reaction.stretch, .shakeHead, .alienWiggle])
    func repeatedIdleActionsDoNotStack(reaction: Reaction) {  // e.g. queued while the display slept
        #expect(poses(playing: reaction, times: 10) == poses(playing: reaction, times: 1))
    }
}

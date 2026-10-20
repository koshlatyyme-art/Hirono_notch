import CoreGraphics
import Foundation
import Testing
@testable import NotchBuddyCore

@Suite struct BehaviorBrainTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    let rect = CGRect(x: 700, y: 1085, width: 40, height: 32)

    func brain() -> BehaviorBrain {
        var b = BehaviorBrain(now: t0, seed: 42)
        b.characterRect = rect
        return b
    }

    func asleep() -> BehaviorBrain {
        var b = brain()
        _ = b.tick(now: t0, systemIdle: 300)
        return b
    }

    @Test func startsIdle() {
        #expect(brain().state == .idle)
        #expect(brain().targets == PoseTargets())
    }

    @Test func cursorFarRightTurnsRight() {
        var b = brain()
        #expect(b.handle(.cursorMoved(CGPoint(x: 1700, y: 1101)), now: t0) == nil)
        #expect(b.targets.headTurn == 1)
        #expect(b.targets.lean > 0)
        #expect(b.state == .idle)
    }

    @Test func cursorFarLeftTurnsLeft() {
        var b = brain()
        _ = b.handle(.cursorMoved(CGPoint(x: 0, y: 1101)), now: t0)
        #expect(b.targets.headTurn == -1)
    }

    @Test func cursorOnCharacterTickles() {
        var b = brain()
        _ = b.handle(.cursorMoved(CGPoint(x: 720, y: 1101)), now: t0)
        #expect(b.state == .tickled)
        #expect(b.targets.wiggle)
    }

    @Test func cursorNearbyGetsAttention() {
        var b = brain()
        _ = b.handle(.cursorMoved(CGPoint(x: 820, y: 1101)), now: t0)
        #expect(b.state == .attentive)
    }

    @Test func attentionStraightensTheHead() {
        var near = brain(), far = brain()
        _ = near.handle(.cursorMoved(CGPoint(x: 820, y: 1101)), now: t0)
        _ = far.handle(.cursorMoved(CGPoint(x: 1020, y: 1101)), now: t0)
        #expect(abs(near.targets.headTilt) < abs(far.targets.headTilt))
    }

    @Test func clickInsideJumps() {
        var b = brain()
        #expect(b.handle(.click(CGPoint(x: 710, y: 1090)), now: t0) == .jump)
    }

    @Test func clickOutsideFlinches() {
        var b = brain()
        #expect(b.handle(.click(CGPoint(x: 100, y: 500)), now: t0) == .flinch)
    }

    @Test func copiedCatches() {
        var b = brain()
        #expect(b.handle(.copied, now: t0) == .catchCopy)
    }

    @Test func sleepsAfter300s() {
        var b = brain()
        #expect(b.tick(now: t0, systemIdle: 299) == nil)
        #expect(b.state != .sleeping)
        #expect(b.tick(now: t0, systemIdle: 300) == nil)
        #expect(b.state == .sleeping)
        #expect(b.targets.sleep == 1)
        #expect(b.targets.lean == 0 && b.targets.headTurn == 0 && b.targets.headTilt == 0)
    }

    @Test func cursorWakes() {
        var b = asleep()
        #expect(b.handle(.cursorMoved(CGPoint(x: 1000, y: 900)), now: t0) == .wake)
        #expect(b.state != .sleeping)
    }

    @Test func clickWakesWithoutJumping() {
        var b = asleep()
        #expect(b.handle(.click(CGPoint(x: 710, y: 1090)), now: t0) == .wake)
        #expect(b.state != .sleeping)
    }

    @Test func copiedWakesAndCatches() {
        var b = asleep()
        #expect(b.handle(.copied, now: t0) == .catchCopy)
        #expect(b.state != .sleeping)
    }

    @Test func typingWakes() {  // keyboard activity resets the system idle time
        var b = asleep()
        #expect(b.tick(now: t0, systemIdle: 0.5) == .wake)
        #expect(b.state != .sleeping)
    }

    @Test func idleActionsEvery15to40s() {
        var b = brain()
        var fired: [(Double, Reaction)] = []
        for second in 1...200 {
            if let r = b.tick(now: t0.addingTimeInterval(Double(second)), systemIdle: 0) {
                fired.append((Double(second), r))
            }
        }
        #expect(!fired.isEmpty)
        #expect((15...40).contains(fired[0].0))
        for (a, b) in zip(fired, fired.dropFirst()) { #expect((15...40).contains(b.0 - a.0)) }
        #expect(fired.allSatisfy { [.stretch, .shakeHead, .alienWiggle].contains($0.1) })
    }

    @Test func noIdleActionsWhileSleeping() {
        var b = asleep()
        for second in 1...200 {
            #expect(b.tick(now: t0.addingTimeInterval(Double(second)), systemIdle: 300 + Double(second)) == nil)
        }
    }

    @Test func seededRandomIsDeterministic() {
        var a = SeededRandom(seed: 7), c = SeededRandom(seed: 7)
        #expect((0..<5).map { _ in a.next() } == (0..<5).map { _ in c.next() })
    }
}

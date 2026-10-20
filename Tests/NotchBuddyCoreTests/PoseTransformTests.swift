import CoreGraphics
import Testing
@testable import NotchBuddyCore

@Suite struct PoseTransformTests {
    let rig = RigFixture.rig

    @Test func restIsStill() {
        let t = transforms(for: .rest, rig: rig)
        #expect(Set(t.keys) == ["arm", "body", "head", "heart", "antenna"])
        for (_, layer) in t {
            #expect(layer.rotation == 0)
            #expect(layer.turn == 0)
            #expect(layer.offset == .zero)
            #expect((1...1.015).contains(layer.scaleY))
        }
    }

    @Test func leanTiltsBody() {
        #expect(transforms(for: Pose(lean: 1), rig: rig)["body"]?.rotation == rig.limits["body"])
    }

    @Test func headTiltIsClamped() {
        #expect(transforms(for: Pose(headTilt: 3), rig: rig)["head"]?.rotation == rig.limits["head"])
    }

    @Test func sleepDropsHead() {
        let head = transforms(for: Pose(sleep: 1), rig: rig)["head"]!
        #expect(head.offset.dy > 0)
        #expect(head.rotation > 0)
    }

    @Test func armFollowsSign() {
        #expect(transforms(for: Pose(arm: -1), rig: rig)["arm"]?.rotation == -rig.limits["arm"]!)
    }

    @Test func headTurnFollowsLimit() {
        #expect(transforms(for: Pose(headTurn: -1), rig: rig)["head"]?.turn == -rig.limits["headTurn"]!)
    }

    @Test func heartPopsWhenItFlashes() {
        #expect(transforms(for: .rest, rig: rig)["heart"]?.scale == 1)
        #expect(transforms(for: Pose(heartGlow: 1), rig: rig)["heart"]!.scale > 1.2)
    }

    @Test func headTurnShiftsTowardTheTurn() {  // foreshortening alone looks the same both ways
        #expect(transforms(for: Pose(headTurn: -1), rig: rig)["head"]!.offset.dx < 0)
        #expect(transforms(for: Pose(headTurn: 1), rig: rig)["head"]!.offset.dx > 0)
    }
}

@Suite struct WorldTransformTests {
    let rig = RigFixture.rig

    func pivot(_ name: String) -> CGPoint {
        let p = rig.layers.first { $0.name == name }!.pivot
        return CGPoint(x: p[0], y: p[1])
    }

    func close(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.x - b.x) < 1e-6 && abs(a.y - b.y) < 1e-6 }

    @Test func restIsIdentity() {
        for (_, t) in worldTransforms(for: .rest, rig: rig) { #expect(t.isIdentity) }
    }

    @Test func childrenFollowTheBody() {
        let w = worldTransforms(for: Pose(lean: 1), rig: rig)
        #expect(close(pivot("body").applying(w["body"]!), pivot("body")))
        let p = pivot("head")
        #expect(!close(p.applying(w["body"]!), p))
        #expect(close(p.applying(w["head"]!), p.applying(w["body"]!)))
    }

    @Test func antennaRidesTheHead() {
        let w = worldTransforms(for: Pose(headTilt: 1), rig: rig)
        let p = pivot("antenna")
        #expect(close(p.applying(w["antenna"]!), p.applying(w["head"]!)))
    }

    @Test func heartPopKeepsItsPivot() {
        let w = worldTransforms(for: Pose(heartGlow: 1), rig: rig)
        let p = pivot("heart")
        #expect(close(p.applying(w["heart"]!), p))
        #expect(!close(CGPoint(x: p.x + 10, y: p.y).applying(w["heart"]!), CGPoint(x: p.x + 10, y: p.y)))
    }

    @Test func positiveTiltIsClockwiseOnScreen() {
        let w = worldTransforms(for: Pose(headTilt: 1), rig: rig)
        let right = CGPoint(x: pivot("head").x + 100, y: pivot("head").y)
        #expect(right.applying(w["head"]!).y > pivot("head").y)  // y grows downward
    }
}

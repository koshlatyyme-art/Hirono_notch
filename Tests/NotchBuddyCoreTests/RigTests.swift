import CoreGraphics
import Foundation
import Testing
@testable import NotchBuddyCore

@Suite struct RigTests {
    let rig = RigFixture.rig

    @Test func decodesCutOutput() {
        #expect(rig.layers.map(\.name) == ["arm", "alienSleep", "body", "head", "heart", "antenna"])
        #expect(rig.layer(named: "alienSleep")?.opacityFrom == "sleep")
        #expect(rig.layer(named: "arm")?.opacityFrom == nil)
        #expect(rig.limits["head"] == 10)
        #expect(rig.frames["portrait"] == [45, 130, 495, 350])
        #expect(rig.glows.first?.color == "#FF7A2E")
    }

    @Test func chainRunsFromRoot() {
        #expect(rig.chain(to: "antenna").map(\.name) == ["body", "head", "antenna"])
        #expect(rig.chain(to: "body").map(\.name) == ["body"])
    }

    @Test func unitPivotIsRelativeToCanvas() {
        #expect(rig.unitPivot(of: "head") == CGPoint(x: 292.5 / 586, y: 470.0 / 774))
    }

    @Test func alienClosesItsEyesAsTheCharacterFallsAsleep() {
        let lids = rig.layer(named: "alienSleep")!
        #expect(opacity(of: lids, in: Pose(sleep: 0)) == 0)
        #expect(opacity(of: lids, in: Pose(sleep: 0.5)) == 0.5)
        #expect(opacity(of: lids, in: Pose(sleep: 1)) == 1)
        #expect(opacity(of: rig.layer(named: "arm")!, in: Pose(sleep: 1)) == 1)
    }
}

import CoreGraphics
import Foundation
import Testing
@testable import NotchBuddyCore

@Suite struct RigTests {
    let rig = RigFixture.rig

    @Test func decodesCutOutput() {
        #expect(rig.layers.map(\.name) == ["arm", "body", "head", "heart", "antenna"])
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
}

import Testing
@testable import NotchBuddyCore

@Suite struct SpringTests {
    @Test func settlesOnTarget() {
        var s = Spring()
        s.target = 1
        for _ in 0..<120 { s.step(dt: 1.0 / 60) }
        #expect(abs(s.value - 1) < 0.01)
    }

    @Test func hugeStepAfterSleepStaysSane() {
        var s = Spring()
        s.target = 1
        s.step(dt: 5)
        #expect(s.value.isFinite)
        #expect(abs(s.value) <= 2)
    }

    @Test func impulseSwingsAndSettles() {
        var s = Spring()
        s.impulse(5)
        s.step(dt: 1.0 / 60)
        #expect(s.value > 0)
        for _ in 0..<180 { s.step(dt: 1.0 / 60) }
        #expect(abs(s.value) < 0.01)
    }
}

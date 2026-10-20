import Testing
@testable import NotchBuddyCore

@Suite struct PasteboardChangeTrackerTests {
    @Test func externalChangeReportedOnce() {
        var t = PasteboardChangeTracker(initialCount: 1)
        #expect(t.observe(1) == false)
        #expect(t.observe(2) == true)
        #expect(t.observe(2) == false)
    }

    @Test func ownWriteNotReported() {
        var t = PasteboardChangeTracker(initialCount: 1)
        t.markOwnWrite(3)
        #expect(t.observe(3) == false)
        #expect(t.observe(4) == true)
    }
}

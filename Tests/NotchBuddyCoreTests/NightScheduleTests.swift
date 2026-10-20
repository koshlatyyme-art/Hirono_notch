import Foundation
import Testing
@testable import NotchBuddyCore

@Suite struct NightScheduleTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return c
    }

    func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: hour, minute: minute))!
    }

    @Test(arguments: [(20, 59, false), (21, 0, true), (3, 0, true), (6, 59, true), (7, 0, false), (12, 0, false)])
    func nightIsNineToSeven(hour: Int, minute: Int, night: Bool) {
        #expect(NightSchedule.isNight(at(hour, minute), calendar: calendar) == night)
    }
}

import Foundation

/// When the character switches to its night look.
public enum NightSchedule {
    public static let start = 21
    public static let end = 7

    /// 21:00 ≤ t < 07:00, local time.
    public static func isNight(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= start || hour < end
    }
}

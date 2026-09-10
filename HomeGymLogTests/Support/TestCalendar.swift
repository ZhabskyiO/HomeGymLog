import Foundation
@testable import HomeGymLog

/// A fixed calendar so date tests never depend on the machine. Sunday is deliberately the first
/// weekday: the app's Monday-based helpers must not rely on the calendar's setting.
enum TestCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }()

    /// Start of the given local day.
    static func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
    }

    /// Example A's twelve dates (1 month, Mon/Wed/Fri from Mon 2026-09-07), as slots.
    static func exampleASlots(status: (Int) -> SessionStatus = { _ in .pending }) -> [SessionSlot] {
        let days: [(Int, Int)] = [(9, 7), (9, 9), (9, 11), (9, 14), (9, 16), (9, 18), (9, 21), (9, 23), (9, 25), (9, 28), (9, 30), (10, 2)]
        return days.enumerated().map { index, md in
            SessionSlot(index: index, scheduledDate: day(2026, md.0, md.1), status: status(index))
        }
    }
}

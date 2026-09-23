import Foundation
@testable import HomeGymLog

/// Plain values for the reminder suites. Session days come from the spec 5.1 formulas (`MissedDayFixtures` slots, the typed
/// `freshProgram` formula) and expected ids from `weekdayIDs`, a calendar walk that never calls `ReminderPlan`, so an
/// expected list cannot be computed by the code under test.
enum ReminderFixtures {
    /// Gregorian weekday numbers (Sunday = 1): Monday through Friday.
    static let monToFri: Set<Int> = [2, 3, 4, 5, 6]
    /// Mon Tue Thu Fri, `SplitPlans.defaultWeekdays(4)` in Gregorian numbering.
    static let freshWeekdays: Set<Int> = [2, 3, 5, 6]

    /// The pending days of the `midProgram` program (120 sessions, Mon–Fri from Mon 08-31), with `dates` overriding slots.
    static func midProgramDays(completed: [Int], dates: [Int: Date] = [:]) -> [Date] {
        MissedDayFixtures.slots(completed: completed, dates: dates)
            .filter { $0.status == .pending }
            .map(\.scheduledDate)
    }

    /// `freshProgram`'s 16 session days: Mon 08-31 + 7·(i / 4) + [0, 1, 3, 4][i % 4], nothing completed.
    static func freshProgramDays() -> [Date] {
        let offsets = [0, 1, 3, 4]
        return (0..<16).map { index in
            TestCalendar.calendar.date(byAdding: .day, value: 7 * (index / 4) + offsets[index % 4], to: TestCalendar.day(2026, 8, 31))!
        }
    }

    /// A 2026 local instant in `TestCalendar`.
    static func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        TestCalendar.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    /// "reminder-YYYY-MM-DD" for every calendar day from `start` through `end` (inclusive) whose weekday is in `weekdays`.
    static func weekdayIDs(from start: Date, through end: Date, weekdays: Set<Int> = monToFri) -> [String] {
        let calendar = TestCalendar.calendar
        var ids: [String] = []
        var day = calendar.startOfDay(for: start)
        while day <= end {
            let c = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
            if weekdays.contains(c.weekday!) {
                ids.append(String(format: "reminder-%04d-%02d-%02d", c.year!, c.month!, c.day!))
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return ids
    }
}

import Foundation
@testable import HomeGymLog

/// Plain values for the missed-day suites. Dates come from the spec 5.3 formula (session i of the `missed` program is on
/// Mon 2026-08-31 + 7·(i / 5) + i % 5 days), never from the generator or `Reslot`, so an expected map cannot be computed by
/// the code under test.
enum MissedDayFixtures {
    /// The `midProgram` / `missed` completed sessions.
    static let midProgramCompleted = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]
    /// The `restDay` completed sessions: 0…14 minus 7.
    static let restDayCompleted = Array(0...14).filter { $0 != 7 }

    /// 12:00 local on a 2026 day.
    static func noon(_ month: Int, _ day: Int) -> Date {
        TestCalendar.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    /// Session i's generated date by calendar arithmetic (valid past 119: `originalDate(120)` is Mon 2027-02-15).
    static func originalDate(_ index: Int) -> Date {
        TestCalendar.calendar.date(byAdding: .day, value: 7 * (index / 5) + index % 5, to: TestCalendar.day(2026, 8, 31))!
    }

    /// The program's 120 slots: completed and skipped by index, the rest pending; `dates` overrides a slot's date.
    static func slots(completed: [Int], skipped: [Int] = [], dates: [Int: Date] = [:]) -> [SessionSlot] {
        (0..<120).map { index in
            let status: SessionStatus = completed.contains(index) ? .completed : (skipped.contains(index) ? .skipped : .pending)
            return SessionSlot(index: index, scheduledDate: dates[index] ?? originalDate(index), status: status)
        }
    }

    /// A typed shift map: the first entry, plus k → `originalDate(k + offset)` for every k in `range`.
    static func map(first: (Int, Date), range: ClosedRange<Int>, offset: Int) -> [Int: Date] {
        var result: [Int: Date] = [first.0: first.1]
        for index in range { result[index] = originalDate(index + offset) }
        return result
    }

    /// `HomeFixtures.midProgramInput`'s sessions with `dates` applied; logs unchanged.
    static func input(completed: [Int], skipped: [Int] = [], dates: [Int: Date] = [:]) throws -> HomeStatsInput {
        let base = try HomeFixtures.midProgramInput(completedIndexes: completed, skippedIndexes: skipped)
        let sessions = base.sessions.map { s in
            SessionSummary(index: s.index, week: s.week, phase: s.phase, name: s.name, scheduledDate: dates[s.index] ?? s.scheduledDate,
                           status: s.status, sets: s.sets, reps: s.reps, exercises: s.exercises)
        }
        return try HomeStatsInput(sessions: sessions, logs: base.logs)
    }
}

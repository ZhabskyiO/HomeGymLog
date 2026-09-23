import Foundation
import Testing
@testable import HomeGymLog

/// AC-10 edges: `ReminderPlan.desired` is total over order, duplicates and empty input; the fire-time and window
/// boundaries; days before today; year boundaries; `validMinutes`; the constants and `canSchedule` against typed literals.
@Suite struct ReminderPlanEdgeTests {
    private typealias F = ReminderFixtures
    private let cal = TestCalendar.calendar

    private func ids(_ days: [Date], now: Date, minutes: Int = 420, workoutInProgress: Bool = false) -> [String] {
        ReminderPlan.desired(sessionDays: days, enabled: true, status: .authorized, minutes: minutes, now: now, calendar: cal,
                             workoutInProgress: workoutInProgress).map(\.identifier)
    }

    /// Fixed permutations (no randomness): reversed, and interleaved odd/even.
    private static let shuffles: [(([Date]) -> [Date])] = [
        { $0.reversed() },
        { days in days.enumerated().filter { $0.offset % 2 == 1 }.map(\.element) + days.enumerated().filter { $0.offset % 2 == 0 }.map(\.element) },
    ]

    @Test("shuffled input gives the same ids")
    func orderIndependent() {
        let days = F.midProgramDays(completed: MissedDayFixtures.midProgramCompleted)
        let expected = ids(days, now: F.at(9, 15, 12))
        #expect(expected.count == 30)
        for shuffle in Self.shuffles {
            #expect(ids(shuffle(days), now: F.at(9, 15, 12)) == expected)
        }
    }

    @Test("duplicated days, and several times on one day, give one id per day")
    func duplicates() {
        let days = [F.at(9, 16, 9), F.at(9, 16, 18), TestCalendar.day(2026, 9, 16), F.at(9, 17, 8), F.at(9, 17, 8)]
        #expect(ids(days, now: F.at(9, 15, 12)) == ["reminder-2026-09-16", "reminder-2026-09-17"])
    }

    @Test("empty input gives nothing")
    func empty() {
        #expect(ids([], now: F.at(9, 15, 12)) == [])
    }

    @Test("days before today never become requests, even with the time still ahead on the clock")
    func pastDays() {
        let days = [TestCalendar.day(2026, 9, 14), TestCalendar.day(2026, 9, 1), TestCalendar.day(2025, 12, 31)]
        #expect(ids(days, now: F.at(9, 15, 6)) == [])
        #expect(ids(days + [TestCalendar.day(2026, 9, 15)], now: F.at(9, 15, 6)) == ["reminder-2026-09-15"])
    }

    @Test("now exactly at 07:00 drops today; one second earlier keeps it")
    func fireBoundary() {
        let days = [TestCalendar.day(2026, 9, 15), TestCalendar.day(2026, 9, 16)]
        #expect(ids(days, now: F.at(9, 15, 7)) == ["reminder-2026-09-16"])
        #expect(ids(days, now: F.at(9, 15, 7).addingTimeInterval(-1)) == ["reminder-2026-09-15", "reminder-2026-09-16"])
    }

    @Test("a workout in progress drops only today")
    func workoutDropsToday() {
        let days = [TestCalendar.day(2026, 9, 15), TestCalendar.day(2026, 9, 16)]
        #expect(ids(days, now: F.at(9, 15, 6), workoutInProgress: true) == ["reminder-2026-09-16"])
    }

    @Test("31 candidates give the first 30")
    func window() {
        let days = (0..<31).map { cal.date(byAdding: .day, value: $0, to: TestCalendar.day(2026, 9, 16))! }
        let result = ids(days, now: F.at(9, 15, 12))
        #expect(result.count == 30)
        #expect(result.first == "reminder-2026-09-16")
        #expect(result.last == "reminder-2026-10-15")
        #expect(result.contains("reminder-2026-10-16") == false)
    }

    @Test("year boundary: 2026-12-31 then 2027-01-01, from calendar components")
    func yearBoundary() throws {
        let days = [TestCalendar.day(2027, 1, 1), TestCalendar.day(2026, 12, 31)]
        let now = cal.date(from: DateComponents(year: 2026, month: 12, day: 30, hour: 12))!
        let requests = ReminderPlan.desired(sessionDays: days, enabled: true, status: .authorized, minutes: 420, now: now,
                                            calendar: cal, workoutInProgress: false)
        #expect(requests.map(\.identifier) == ["reminder-2026-12-31", "reminder-2027-01-01"])
        let last = try #require(requests.last)
        #expect(last.dateComponents.year == 2027)
        #expect(last.dateComponents.month == 1)
        #expect(last.dateComponents.day == 1)
    }

    @Test("every id is prefix + dayKey of its day")
    func idShape() {
        let days = F.midProgramDays(completed: MissedDayFixtures.midProgramCompleted)
        let requests = ReminderPlan.desired(sessionDays: days, enabled: true, status: .authorized, minutes: 420, now: F.at(9, 15, 12),
                                            calendar: cal, workoutInProgress: false)
        #expect(requests.count == 30)
        for request in requests {
            let c = request.dateComponents
            let day = TestCalendar.day(c.year!, c.month!, c.day!)
            #expect(request.identifier == "reminder-" + ReminderPlan.dayKey(day, calendar: cal))
        }
        #expect(ReminderPlan.dayKey(TestCalendar.day(2026, 9, 6), calendar: cal) == "2026-09-06")
        #expect(ReminderPlan.dayKey(F.at(9, 16, 23, 59), calendar: cal) == "2026-09-16")
    }

    @Test("validMinutes keeps 0…1439 and rejects the rest",
          arguments: [(0, Optional(0)), (1439, Optional(1439)), (420, Optional(420)), (1440, nil), (-1, nil), (Int.max, nil)])
    func validMinutes(input: Int, expected: Int?) {
        #expect(ReminderPlan.validMinutes(input) == expected)
    }

    @Test("the five constants equal the spec's literals")
    func constants() {
        #expect(ReminderPlan.prefix == "reminder-")
        #expect(ReminderPlan.window == 30)
        #expect(ReminderPlan.defaultMinutes == 420)
        #expect(ReminderPlan.enabledKey == "reminderEnabled")
        #expect(ReminderPlan.minutesKey == "reminderMinutes")
    }

    @Test("canSchedule is true for authorized and provisional only",
          arguments: [(ReminderAuthorization.authorized, true), (.provisional, true), (.denied, false), (.notDetermined, false)])
    func canSchedule(status: ReminderAuthorization, expected: Bool) {
        #expect(status.canSchedule == expected)
    }
}

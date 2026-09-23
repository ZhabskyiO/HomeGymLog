import Foundation
import Testing
@testable import HomeGymLog

/// AC-10: `ReminderPlan.desired` over the rows of spec 5.1. Session days come from the typed formulas in `ReminderFixtures`
/// and `MissedDayFixtures` (never the generator or `Reslot`); expected ids from a calendar walk plus typed literals.
@Suite struct ReminderPlanTests {
    private typealias F = ReminderFixtures
    private let cal = TestCalendar.calendar

    private func ids(_ days: [Date], now: Date, minutes: Int = 420, status: ReminderAuthorization = .authorized,
                     enabled: Bool = true, workoutInProgress: Bool = false) -> [String] {
        requests(days, now: now, minutes: minutes, status: status, enabled: enabled, workoutInProgress: workoutInProgress)
            .map(\.identifier)
    }

    private func requests(_ days: [Date], now: Date, minutes: Int = 420, status: ReminderAuthorization = .authorized,
                          enabled: Bool = true, workoutInProgress: Bool = false) -> [ReminderRequest] {
        ReminderPlan.desired(sessionDays: days, enabled: enabled, status: status, minutes: minutes, now: now, calendar: cal,
                             workoutInProgress: workoutInProgress)
    }

    private var midDays: [Date] { F.midProgramDays(completed: MissedDayFixtures.midProgramCompleted) }

    @Test("A: midProgram, Tue 09-15 12:00, 420 → 30 ids 09-16 … 10-27, today's 07:00 already passed")
    func rowA() {
        let result = ids(midDays, now: F.at(9, 15, 12))
        #expect(result.count == 30)
        #expect(result.first == "reminder-2026-09-16")
        #expect(result.last == "reminder-2026-10-27")
        #expect(result == F.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27)))
    }

    @Test("A: the first request is 2026-09-16 07:00 with no time zone, compared field by field")
    func rowAComponents() throws {
        let first = try #require(requests(midDays, now: F.at(9, 15, 12)).first)
        #expect(first.dateComponents.year == 2026)
        #expect(first.dateComponents.month == 9)
        #expect(first.dateComponents.day == 16)
        #expect(first.dateComponents.hour == 7)
        #expect(first.dateComponents.minute == 0)
        #expect(first.dateComponents.timeZone == nil)
        #expect(first.dateComponents.calendar == nil)
    }

    @Test("A′: as A at 06:00 → today kept, 30 ids 09-15 … 10-26")
    func rowAPrime() {
        let result = ids(midDays, now: F.at(9, 15, 6))
        #expect(result.count == 30)
        #expect(result.first == "reminder-2026-09-15")
        #expect(result.last == "reminder-2026-10-26")
        #expect(result == F.weekdayIDs(from: TestCalendar.day(2026, 9, 15), through: TestCalendar.day(2026, 10, 26)))
    }

    @Test("B: missed-shifted rows give the same 30 ids as A")
    func rowB() {
        let shifted = MissedDayFixtures.map(first: (7, TestCalendar.day(2026, 9, 15)), range: 11...119, offset: 1)
        let days = F.midProgramDays(completed: MissedDayFixtures.midProgramCompleted, dates: shifted)
        let result = ids(days, now: F.at(9, 15, 12))
        #expect(result == F.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27)))
        #expect(result == ids(midDays, now: F.at(9, 15, 12)))
    }

    @Test("C: missed-several, Thu 09-17 12:00 → 30 ids 09-18 … 10-29")
    func rowC() {
        let result = ids(midDays, now: F.at(9, 17, 12))
        #expect(result.count == 30)
        #expect(result.first == "reminder-2026-09-18")
        #expect(result.last == "reminder-2026-10-29")
        #expect(result.prefix(2) == ["reminder-2026-09-18", "reminder-2026-09-21"])
        #expect(result == F.weekdayIDs(from: TestCalendar.day(2026, 9, 18), through: TestCalendar.day(2026, 10, 29)))
    }

    @Test("D: restDay, Sat 09-19 12:00 → 30 ids 09-21 … 10-30")
    func rowD() {
        let days = F.midProgramDays(completed: MissedDayFixtures.restDayCompleted)
        let result = ids(days, now: F.at(9, 19, 12))
        #expect(result.count == 30)
        #expect(result.first == "reminder-2026-09-21")
        #expect(result.last == "reminder-2026-10-30")
        #expect(result == F.weekdayIDs(from: TestCalendar.day(2026, 9, 21), through: TestCalendar.day(2026, 10, 30)))
    }

    @Test("E: freshProgram, Mon 08-31 12:00 → 15 ids 09-01 … 09-25 (fewer than the window)")
    func rowE() {
        let result = ids(F.freshProgramDays(), now: F.at(8, 31, 12))
        #expect(result.count == 15)
        #expect(result.first == "reminder-2026-09-01")
        #expect(result.last == "reminder-2026-09-25")
        #expect(result == F.weekdayIDs(from: TestCalendar.day(2026, 9, 1), through: TestCalendar.day(2026, 9, 25),
                                       weekdays: F.freshWeekdays))
    }

    @Test("E′: freshProgram at 18:30 → 16 ids 08-31 … 09-25, each at 18:30")
    func rowEPrime() {
        let result = requests(F.freshProgramDays(), now: F.at(8, 31, 12), minutes: 1110)
        #expect(result.count == 16)
        #expect(result.first?.identifier == "reminder-2026-08-31")
        #expect(result.last?.identifier == "reminder-2026-09-25")
        #expect(result.map(\.identifier) == F.weekdayIDs(from: TestCalendar.day(2026, 8, 31), through: TestCalendar.day(2026, 9, 25),
                                                         weekdays: F.freshWeekdays))
        #expect(result.allSatisfy { $0.dateComponents.hour == 18 && $0.dateComponents.minute == 30 })
    }

    @Test("F: enabled false → nothing")
    func rowF() {
        #expect(ids(midDays, now: F.at(9, 15, 12), enabled: false) == [])
        #expect(ids(midDays, now: F.at(9, 15, 6), status: .provisional, enabled: false) == [])
    }

    @Test("G: denied or not determined → nothing", arguments: [ReminderAuthorization.denied, .notDetermined])
    func rowG(status: ReminderAuthorization) {
        #expect(ids(midDays, now: F.at(9, 15, 12), status: status) == [])
    }

    @Test("H: every session completed, or no rows → nothing")
    func rowH() {
        #expect(ids(F.midProgramDays(completed: Array(0..<120)), now: F.at(9, 15, 12)) == [])
        #expect(ids([], now: F.at(9, 15, 12)) == [])
    }

    @Test("I: minutes 1440 or −1 normalise to 420: the same requests as A", arguments: [1440, -1])
    func rowI(minutes: Int) {
        let result = requests(midDays, now: F.at(9, 15, 12), minutes: minutes)
        #expect(result == requests(midDays, now: F.at(9, 15, 12)))
        #expect(result.count == 30)
        #expect(result.allSatisfy { $0.dateComponents.hour == 7 && $0.dateComponents.minute == 0 })
    }

    @Test("J: provisional schedules like authorized")
    func rowJ() {
        #expect(ids(midDays, now: F.at(9, 15, 12), status: .provisional)
                == F.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27)))
    }

    @Test("K: A′ with a workout in progress drops today → A's ids, not A′'s")
    func rowK() {
        let result = ids(midDays, now: F.at(9, 15, 6), workoutInProgress: true)
        #expect(result.first == "reminder-2026-09-16")
        #expect(result == F.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27)))
        #expect(result != ids(midDays, now: F.at(9, 15, 6)))
    }
}

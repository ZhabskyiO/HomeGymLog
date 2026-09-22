import Foundation
import Testing
@testable import HomeGymLog

/// Boundary cases for the Program tab's selectors that the spec's tables (§5.1–5.5, §6) imply but do not
/// tabulate: the fall-back and year-boundary windows, the exact edges of the `/ 7 + 1` window arithmetic,
/// a Sunday default day, a status-mixed tie on one day, and negative selection values.
/// Every expectation is a literal date or number, never the output of another `ProgramTabStats` call.
@Suite struct ProgramTabStatsEdgeTests {
    private let cal = TestCalendar.calendar
    /// The `midProgram` schedule: 6 months, 5 days, generated Mon 2026-08-31; sessions Mon–Fri, index i on
    /// anchor + 7·(i / 5) + i % 5.
    private let mid = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]

    private func midSessions() throws -> [SessionSummary] {
        try HomeFixtures.midProgramInput(completedIndexes: mid).sessions
    }

    /// A bare session value: only index, date and status matter to these tests.
    private func session(_ index: Int, on date: Date, status: SessionStatus = .pending) -> SessionSummary {
        SessionSummary(index: index, week: index / 5 + 1, phase: .foundation, name: "S\(index)",
                       scheduledDate: date, status: status, sets: 3, reps: 12, exercises: [])
    }

    // MARK: - 5.1 window arithmetic at its edges

    @Test("the anchor is the Monday before a Sunday-dated first session, not the fixed calendar's Sunday")
    func anchorFromASundaySession() {
        let sessions = [session(0, on: TestCalendar.day(2026, 9, 6))]   // Sunday; TestCalendar.firstWeekday == Sunday
        #expect(ProgramTabStats.weekAnchor(sessions: sessions, calendar: cal) == TestCalendar.day(2026, 8, 31))
        #expect(ProgramTabStats.weekCount(sessions: sessions, calendar: cal) == 1)
    }

    @Test("a Sunday-dated last session closes its window; the Monday after opens the next")
    func weekCountAtTheSundayBoundary() {
        let anchor = TestCalendar.day(2026, 8, 31)
        let throughSunday = [session(0, on: anchor), session(1, on: TestCalendar.day(2026, 9, 6))]
        #expect(ProgramTabStats.weekCount(sessions: throughSunday, calendar: cal) == 1)
        let intoMonday = throughSunday + [session(2, on: TestCalendar.day(2026, 9, 7))]
        #expect(ProgramTabStats.weekCount(sessions: intoMonday, calendar: cal) == 2)
    }

    // MARK: - 5.3 initial week at its edges

    @Test("the window flips on the Monday after the anchor's Sunday, not before")
    func initialWeekAtTheFirstSundayBoundary() throws {
        let sessions = try midSessions()
        #expect(ProgramTabStats.initialWeek(sessions: sessions, today: TestCalendar.day(2026, 8, 31), calendar: cal) == 1)
        #expect(ProgramTabStats.initialWeek(sessions: sessions, today: TestCalendar.day(2026, 9, 6), calendar: cal) == 1)
        #expect(ProgramTabStats.initialWeek(sessions: sessions, today: TestCalendar.day(2026, 9, 7), calendar: cal) == 2)
    }

    @Test("the last window ends on its Sunday; the Monday after is bounded back to it")
    func initialWeekAtTheLastSundayBoundary() throws {
        let sessions = try midSessions()
        #expect(ProgramTabStats.initialWeek(sessions: sessions, today: TestCalendar.day(2027, 2, 14), calendar: cal) == 24)
        #expect(ProgramTabStats.initialWeek(sessions: sessions, today: TestCalendar.day(2027, 2, 15), calendar: cal) == 24)
    }

    @Test("the fall-back day 2026-11-01 is still window 9 and the Monday after is window 10")
    func initialWeekAcrossTheFallBack() throws {
        let sessions = try midSessions()
        #expect(ProgramTabStats.initialWeek(sessions: sessions, today: TestCalendar.day(2026, 11, 1), calendar: cal) == 9)
        #expect(ProgramTabStats.initialWeek(sessions: sessions, today: TestCalendar.day(2026, 11, 2), calendar: cal) == 10)
    }

    // MARK: - 5.4 default day

    @Test("today's weekday wins even when today is a Sunday with no session")
    func defaultDayOnASundayInsideTheWindow() throws {
        let sessions = try midSessions()
        // Sun 2026-09-20 is the last day of window 3 (days 20 from the anchor).
        #expect(ProgramTabStats.defaultDay(sessions: sessions, week: 3, today: TestCalendar.day(2026, 9, 20), calendar: cal) == 6)
    }

    @Test("a Sunday default day lands on an empty cell, so the rest card shows")
    func sundayDefaultDayHasNoSession() throws {
        let cells = ProgramTabStats.dayCells(sessions: try midSessions(), week: 3, calendar: cal)
        #expect(cells[6].date == TestCalendar.day(2026, 9, 20))
        #expect(cells[6].session == nil)
    }

    // MARK: - 5.5 day cells across the awkward weeks

    @Test("the fall-back week 9 holds sessions 40–44 Monday to Friday")
    func fallBackWeekSessions() throws {
        let cells = ProgramTabStats.dayCells(sessions: try midSessions(), week: 9, calendar: cal)
        #expect(cells.map { $0.session?.index } == [40, 41, 42, 43, 44, nil, nil])
        #expect(cells.last?.date == TestCalendar.day(2026, 11, 1))
    }

    @Test("the week after the fall-back starts on Mon 2026-11-02")
    func weekAfterTheFallBack() throws {
        let cells = ProgramTabStats.dayCells(sessions: try midSessions(), week: 10, calendar: cal)
        #expect(cells.map(\.date) == [2, 3, 4, 5, 6, 7, 8].map { TestCalendar.day(2026, 11, $0) })
        #expect(cells.map(\.dayNumber) == [2, 3, 4, 5, 6, 7, 8])
        #expect(cells.map { $0.session?.index } == [45, 46, 47, 48, 49, nil, nil])
    }

    @Test("week 18 spans the year boundary: Dec 28 2026 to Jan 3 2027")
    func yearBoundaryWeek() throws {
        let cells = ProgramTabStats.dayCells(sessions: try midSessions(), week: 18, calendar: cal)
        #expect(cells.map(\.date) == [TestCalendar.day(2026, 12, 28), TestCalendar.day(2026, 12, 29),
                                      TestCalendar.day(2026, 12, 30), TestCalendar.day(2026, 12, 31),
                                      TestCalendar.day(2027, 1, 1), TestCalendar.day(2027, 1, 2),
                                      TestCalendar.day(2027, 1, 3)])
        #expect(cells.map(\.dayNumber) == [28, 29, 30, 31, 1, 2, 3])
        #expect(cells.map { $0.session?.index } == [85, 86, 87, 88, 89, nil, nil])
    }

    @Test("the last window is Feb 8–14 2027 and ends with session 119 on the Friday")
    func lastWindowCells() throws {
        let cells = ProgramTabStats.dayCells(sessions: try midSessions(), week: 24, calendar: cal)
        #expect(cells.map(\.date) == (8...14).map { TestCalendar.day(2027, 2, $0) })
        #expect(cells.map { $0.session?.index } == [115, 116, 117, 118, 119, nil, nil])
    }

    @Test("chips 18 and 24 carry the phases their year-boundary windows recorded")
    func yearBoundaryChipPhases() throws {
        let chips = ProgramTabStats.weekChips(sessions: try midSessions(), calendar: cal)
        #expect(chips.count == 24)
        #expect(chips[17] == WeekChip(week: 18, phase: .peak))
        #expect(chips[23] == WeekChip(week: 24, phase: .deload))
    }

    /// Changed in m4-progress (spec 4.3, NB1): the shared day rule lets a completed session win a same-day tie.
    @Test("a completed session wins a same-day tie, else the lowest index")
    func completedSessionWinsTheDay() {
        let day = TestCalendar.day(2026, 9, 15)
        let lowerCompleted = [session(7, on: day, status: .pending), session(3, on: day, status: .completed)]
        #expect(ProgramTabStats.dayCells(sessions: lowerCompleted, week: 1, calendar: cal)[1].session?.index == 3)
        let lowerPending = [session(7, on: day, status: .completed), session(3, on: day, status: .pending)]
        #expect(ProgramTabStats.dayCells(sessions: lowerPending, week: 1, calendar: cal)[1].session?.index == 7)
    }

    // MARK: - selection and focus with raw negatives

    @Test("negative debug values are resolved raw, never clamped or dropped")
    func selectionKeepsNegatives() {
        #expect(ProgramSelection.from(preselectedWeek: -1, preselectedDay: nil, initialWeek: 3) == .week(-1))
        #expect(ProgramSelection.from(preselectedWeek: 0, preselectedDay: -1, initialWeek: 3) == .day(week: 0, day: -1))
        #expect(ProgramSelection.from(preselectedWeek: nil, preselectedDay: -1, initialWeek: 3) == .day(week: 3, day: -1))
    }

    @Test("a negative week or day behaves as follow-today")
    func focusRejectsNegatives() throws {
        let sessions = try midSessions()
        let today = HomeFixtures.midProgramDay
        func focus(_ selection: ProgramSelection) -> ProgramFocus? {
            ProgramTabStats.focus(selection: selection, sessions: sessions, today: today, calendar: cal)
        }
        #expect(focus(.week(0)) == ProgramFocus(week: 3, day: 1))
        #expect(focus(.week(-1)) == ProgramFocus(week: 3, day: 1))
        #expect(focus(.day(week: 3, day: -1)) == ProgramFocus(week: 3, day: 1))
        #expect(focus(.day(week: -1, day: 0)) == ProgramFocus(week: 3, day: 1))
    }

    @Test("the valid ranges are inclusive: weeks 1 and 24, days 0 and 6")
    func focusRangesAreInclusive() throws {
        let sessions = try midSessions()
        let today = HomeFixtures.midProgramDay
        func focus(_ selection: ProgramSelection) -> ProgramFocus? {
            ProgramTabStats.focus(selection: selection, sessions: sessions, today: today, calendar: cal)
        }
        #expect(focus(.week(1)) == ProgramFocus(week: 1, day: 0))
        #expect(focus(.week(24)) == ProgramFocus(week: 24, day: 0))
        #expect(focus(.day(week: 3, day: 0)) == ProgramFocus(week: 3, day: 0))
        #expect(focus(.day(week: 3, day: 6)) == ProgramFocus(week: 3, day: 6))
    }
}

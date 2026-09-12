import Foundation
import Testing
@testable import HomeGymLog

/// AC-13 … AC-17 and AC-22's resolution list. Every expectation is a literal from the spec's tables
/// (§5.1–5.5, §6), never the output of another Engine call.
@Suite struct ProgramTabStatsTests {
    private let cal = TestCalendar.calendar
    /// The `midProgram` / `restDay` / `missed` schedule: 6 months, 5 days, generated Mon 2026-08-31.
    private let mid = [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]

    private func midSessions() throws -> [SessionSummary] {
        try HomeFixtures.midProgramInput(completedIndexes: mid).sessions
    }

    private func freshSessions() throws -> [SessionSummary] {
        try HomeFixtures.freshProgramInput().sessions
    }

    // MARK: - 5.1 anchor and count (AC-13)

    @Test("week anchor and count for each seed")
    func anchorAndCount() throws {
        let midProgram = try midSessions()
        #expect(ProgramTabStats.weekAnchor(sessions: midProgram, calendar: cal) == TestCalendar.day(2026, 8, 31))
        #expect(ProgramTabStats.weekCount(sessions: midProgram, calendar: cal) == 24)

        let fresh = try freshSessions()
        #expect(ProgramTabStats.weekAnchor(sessions: fresh, calendar: cal) == TestCalendar.day(2026, 8, 31))
        #expect(ProgramTabStats.weekCount(sessions: fresh, calendar: cal) == 4)

        let exampleE = try HomeFixtures.exampleESessions()
        #expect(ProgramTabStats.weekAnchor(sessions: exampleE, calendar: cal) == TestCalendar.day(2026, 9, 7))
        #expect(ProgramTabStats.weekCount(sessions: exampleE, calendar: cal) == 5)
    }

    @Test("an empty program has no anchor and no weeks")
    func emptyAnchorAndCount() {
        #expect(ProgramTabStats.weekAnchor(sessions: [], calendar: cal) == nil)
        #expect(ProgramTabStats.weekCount(sessions: [], calendar: cal) == 0)
    }

    // MARK: - 5.2 chips (AC-14)

    @Test("midProgram chips are 9 Foundation, 8 Build, 6 Peak, 1 Deload")
    func midProgramChips() throws {
        let chips = ProgramTabStats.weekChips(sessions: try midSessions(), calendar: cal)
        #expect(chips.map(\.week) == Array(1...24))
        let expected: [Phase?] = Array(repeating: .foundation, count: 9)
            + Array(repeating: .build, count: 8)
            + Array(repeating: .peak, count: 6)
            + [.deload]
        #expect(chips.map(\.phase) == expected)
    }

    @Test("freshProgram has four chips: Foundation, Foundation, Peak, Deload")
    func freshProgramChips() throws {
        let chips = ProgramTabStats.weekChips(sessions: try freshSessions(), calendar: cal)
        #expect(chips.map(\.phase) == [.foundation, .foundation, .peak, .deload])
    }

    @Test("Example E spills into a fifth chip taking the highest-index session's phase")
    func exampleEChips() throws {
        let chips = ProgramTabStats.weekChips(sessions: try HomeFixtures.exampleESessions(), calendar: cal)
        #expect(chips.map(\.phase) == [.foundation, .foundation, .peak, .deload, .deload])
    }

    @Test("a window with no session gets a nil phase and still counts")
    func emptyWindowChip() throws {
        let emptied = try HomeFixtures.exampleESessions().filter { session in
            let date = session.scheduledDate
            return date < TestCalendar.day(2026, 9, 14) || date > TestCalendar.day(2026, 9, 18)
        }
        let chips = ProgramTabStats.weekChips(sessions: emptied, calendar: cal)
        #expect(chips.count == 5)
        #expect(chips[1].phase == nil)
        #expect(chips[0].phase == .foundation)
    }

    @Test("no sessions, no chips")
    func emptyChips() {
        #expect(ProgramTabStats.weekChips(sessions: [], calendar: cal) == [])
    }

    // MARK: - 5.3 initial week (AC-15)

    @Test("initial week is the window containing today, bounded to the program")
    func initialWeek() throws {
        let midProgram = try midSessions()
        #expect(ProgramTabStats.initialWeek(sessions: midProgram, today: HomeFixtures.midProgramDay, calendar: cal) == 3)
        // restDay: Sat 2026-09-19 — still window 3, not the stored week 4 of Monday's next session.
        #expect(ProgramTabStats.initialWeek(sessions: midProgram, today: TestCalendar.day(2026, 9, 19), calendar: cal) == 3)
        #expect(ProgramTabStats.initialWeek(sessions: try freshSessions(), today: TestCalendar.day(2026, 8, 31), calendar: cal) == 1)
        // Before the anchor and after the last window are both bounded.
        #expect(ProgramTabStats.initialWeek(sessions: midProgram, today: TestCalendar.day(2026, 8, 30), calendar: cal) == 1)
        #expect(ProgramTabStats.initialWeek(sessions: midProgram, today: TestCalendar.day(2027, 3, 1), calendar: cal) == 24)
        #expect(ProgramTabStats.initialWeek(sessions: try HomeFixtures.exampleESessions(), today: TestCalendar.day(2026, 9, 23), calendar: cal) == 3)
        #expect(ProgramTabStats.initialWeek(sessions: [], today: HomeFixtures.midProgramDay, calendar: cal) == nil)
    }

    @Test("a weekend generation: today before the anchor opens week 1 on the first session's weekday")
    func todayBeforeTheAnchor() throws {
        // Generated Sat 2026-09-12 with Mon/Wed/Fri training: every week-1 session re-slots past the weekend,
        // so the anchor is Mon 09-14 and Sat/Sun sit six and one days *before* it. Swift's truncating `/`
        // used to put them in window 1, which made "today lies in this window" true and selected Sat/Sun.
        let program = try ProgramGenerator.generate(TestCalendar.exampleAInputs(generatedOn: TestCalendar.day(2026, 9, 12)),
                                                    calendar: cal)
        let sessions = HomeFixtures.summaries(program, completed: [], skipped: [])
        let earliest = try #require(sessions.map(\.scheduledDate).min())
        #expect(earliest == TestCalendar.day(2026, 9, 14))
        #expect(ProgramTabStats.weekAnchor(sessions: sessions, calendar: cal) == TestCalendar.day(2026, 9, 14))

        for day in [12, 13] {
            let today = TestCalendar.day(2026, 9, day).addingTimeInterval(12 * 3600)
            #expect(ProgramTabStats.initialWeek(sessions: sessions, today: today, calendar: cal) == 1)
            #expect(ProgramTabStats.defaultDay(sessions: sessions, week: 1, today: today, calendar: cal) == 0)
        }
        let saturday = TestCalendar.day(2026, 9, 12).addingTimeInterval(12 * 3600)
        #expect(ProgramTabStats.focus(selection: .followToday, sessions: sessions, today: saturday, calendar: cal)
                == ProgramFocus(week: 1, day: 0))
    }

    // MARK: - 5.4 default day (AC-16)

    @Test("default day is today's weekday in today's window, else the window's earliest session")
    func defaultDay() throws {
        let midProgram = try midSessions()
        #expect(ProgramTabStats.defaultDay(sessions: midProgram, week: 3, today: HomeFixtures.midProgramDay, calendar: cal) == 1)
        #expect(ProgramTabStats.defaultDay(sessions: midProgram, week: 3, today: TestCalendar.day(2026, 9, 19), calendar: cal) == 5)
        #expect(ProgramTabStats.defaultDay(sessions: try freshSessions(), week: 1, today: TestCalendar.day(2026, 8, 31), calendar: cal) == 0)
        // Week 2 is not today's window: session 5 on Mon 2026-09-07.
        #expect(ProgramTabStats.defaultDay(sessions: midProgram, week: 2, today: HomeFixtures.midProgramDay, calendar: cal) == 0)
        // A window beyond the program holds no session and is not today's: Monday.
        #expect(ProgramTabStats.defaultDay(sessions: midProgram, week: 99, today: HomeFixtures.midProgramDay, calendar: cal) == 0)
    }

    // MARK: - 5.5 day cells (AC-17)

    @Test("midProgram week 3 is Mon 14 … Sun 20 with sessions 10–14")
    func midProgramWeek3Cells() throws {
        let cells = ProgramTabStats.dayCells(sessions: try midSessions(), week: 3, calendar: cal)
        #expect(cells.count == 7)
        #expect(cells.map(\.dayNumber) == [14, 15, 16, 17, 18, 19, 20])
        #expect(cells.map { $0.date } == (14...20).map { TestCalendar.day(2026, 9, $0) })
        #expect(cells.map { $0.session?.index } == [10, 11, 12, 13, 14, nil, nil])
    }

    @Test("the missed seed's week 2 is Mon 7 … Sun 13 with sessions 5–9")
    func week2Cells() throws {
        let cells = ProgramTabStats.dayCells(sessions: try midSessions(), week: 2, calendar: cal)
        #expect(cells.map(\.dayNumber) == [7, 8, 9, 10, 11, 12, 13])
        #expect(cells.map { $0.session?.index } == [5, 6, 7, 8, 9, nil, nil])
    }

    @Test("freshProgram week 1 trains Mon, Tue, Thu, Fri and starts on Aug 31")
    func freshProgramWeek1Cells() throws {
        let cells = ProgramTabStats.dayCells(sessions: try freshSessions(), week: 1, calendar: cal)
        #expect(cells.map(\.dayNumber) == [31, 1, 2, 3, 4, 5, 6])
        #expect(cells.map { $0.session?.index } == [0, 1, nil, 2, 3, nil, nil])
    }

    @Test("Example E week 2 holds the re-slotted session 2 under a later window")
    func exampleEWeek2Cells() throws {
        let cells = ProgramTabStats.dayCells(sessions: try HomeFixtures.exampleESessions(), week: 2, calendar: cal)
        #expect(cells.map(\.dayNumber) == [14, 15, 16, 17, 18, 19, 20])
        #expect(cells.map { $0.session?.index } == [2, nil, 3, nil, 4, nil, nil])
        #expect(cells[0].session?.week == 1)   // stored week 1, shown under window 2 (decision 1)
    }

    @Test("a week outside the program still gives seven dated, empty cells")
    func outOfRangeCells() throws {
        let midProgram = try midSessions()
        let before = ProgramTabStats.dayCells(sessions: midProgram, week: 0, calendar: cal)
        #expect(before.count == 7)
        #expect(before.first?.date == TestCalendar.day(2026, 8, 24))
        #expect(before.allSatisfy { $0.session == nil })
        let after = ProgramTabStats.dayCells(sessions: midProgram, week: 99, calendar: cal)
        #expect(after.count == 7)
        #expect(after.first?.date == TestCalendar.day(2028, 7, 17))
        #expect(after.allSatisfy { $0.session == nil })
    }

    @Test("two sessions on one day: the cell takes the lower index")
    func tiedCells() {
        let sessions = [
            SessionSummary(index: 4, week: 3, phase: .foundation, name: "Later", scheduledDate: TestCalendar.day(2026, 9, 15),
                           status: .pending, sets: 3, reps: 12, exercises: []),
            SessionSummary(index: 3, week: 3, phase: .foundation, name: "Earlier", scheduledDate: TestCalendar.day(2026, 9, 15),
                           status: .pending, sets: 3, reps: 12, exercises: []),
        ]
        let cells = ProgramTabStats.dayCells(sessions: sessions, week: 1, calendar: cal)
        #expect(cells[1].session?.index == 3)
        #expect(cells[1].session?.name == "Earlier")
    }

    @Test("no sessions, no cells")
    func emptyCells() {
        #expect(ProgramTabStats.dayCells(sessions: [], week: 1, calendar: cal) == [])
    }

    @Test("the fall-back week stays at local midnight on every day")
    func dstWeekCells() throws {
        let cells = ProgramTabStats.dayCells(sessions: try midSessions(), week: 9, calendar: cal)
        let expected = [26, 27, 28, 29, 30, 31].map { TestCalendar.day(2026, 10, $0) } + [TestCalendar.day(2026, 11, 1)]
        #expect(cells.map(\.date) == expected)
        #expect(cells.map(\.dayNumber) == [26, 27, 28, 29, 30, 31, 1])
    }

    // MARK: - selection and focus (AC-22 resolution)

    @Test("preselection resolves to a selection without any range check")
    func selectionFrom() {
        #expect(ProgramSelection.from(preselectedWeek: 2, preselectedDay: 2, initialWeek: 3) == .day(week: 2, day: 2))
        #expect(ProgramSelection.from(preselectedWeek: 24, preselectedDay: nil, initialWeek: 3) == .week(24))
        #expect(ProgramSelection.from(preselectedWeek: nil, preselectedDay: 5, initialWeek: 3) == .day(week: 3, day: 5))
        #expect(ProgramSelection.from(preselectedWeek: nil, preselectedDay: nil, initialWeek: 3) == .followToday)
        #expect(ProgramSelection.from(preselectedWeek: nil, preselectedDay: 5, initialWeek: nil) == .followToday)
    }

    @Test("focus applies the one validity rule: out of range behaves as follow-today")
    func focus() throws {
        let sessions = try midSessions()
        let today = HomeFixtures.midProgramDay
        func focus(_ selection: ProgramSelection) -> ProgramFocus? {
            ProgramTabStats.focus(selection: selection, sessions: sessions, today: today, calendar: cal)
        }
        #expect(focus(.followToday) == ProgramFocus(week: 3, day: 1))
        #expect(focus(.week(2)) == ProgramFocus(week: 2, day: 0))
        #expect(focus(.day(week: 2, day: 2)) == ProgramFocus(week: 2, day: 2))
        #expect(focus(.day(week: 24, day: 4)) == ProgramFocus(week: 24, day: 4))
        for invalid: ProgramSelection in [.week(99), .day(week: 2, day: 7), .day(week: 0, day: 1), .day(week: 25, day: 0)] {
            #expect(focus(invalid) == ProgramFocus(week: 3, day: 1))
        }
        #expect(ProgramTabStats.focus(selection: .followToday, sessions: [], today: today, calendar: cal) == nil)
    }
}

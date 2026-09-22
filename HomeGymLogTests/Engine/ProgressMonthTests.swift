import Foundation
import Testing
@testable import HomeGymLog

/// AC-19: `ProgressStats.month` over the rows of spec 5.5 (open questions 1 and 2 of the plan: Sep 9 missed; Feb 2027 states).
@Suite struct ProgressMonthTests {
    private let cal = TestCalendar.calendar
    private let created = ProgressFixtures.at(8, 31, hour: 6)

    private func sessions(_ input: HomeStatsInput) -> [ProgressSession] {
        ProgressFixtures.sessions(input, programID: ProgressFixtures.currentID, createdAt: created, archived: false)
    }

    private func shiftedDates() -> [Int: Date] {
        MissedDayFixtures.map(first: (7, TestCalendar.day(2026, 9, 15)), range: 11...119, offset: 1)
    }

    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TestCalendar.day(year, month, day).addingTimeInterval(12 * 3600)
    }

    /// Expected states for days 1…n from a sparse map; unlisted days are `.rest`.
    private func states(_ n: Int, _ map: [ClosedRange<Int>: WeekStripState]) -> [WeekStripState] {
        (1...n).map { day in map.first { $0.key.contains(day) }?.value ?? .rest }
    }

    private let septemberMid: [ClosedRange<Int>: WeekStripState] = [
        1...4: .completed, 7...8: .completed, 9...9: .missed, 10...11: .completed, 14...14: .completed, 15...15: .today,
        16...18: .scheduled, 21...25: .scheduled, 28...30: .scheduled,
    ]

    @Test("midProgram, Tue 09-15: lead 1, 30 cells, Sep 9 missed, today 15, 9 completed; Aug 31 is not a cell")
    func midProgram() throws {
        let month = ProgressStats.month(sessions: sessions(try MissedDayFixtures.input(completed: MissedDayFixtures.midProgramCompleted)),
                                        today: noon(2026, 9, 15), calendar: cal)
        #expect(month.year == 2026 && month.month == 9)
        #expect(month.leadingBlanks == 1)
        #expect(month.cells.count == 30)
        #expect(month.cells.map(\.dayNumber) == Array(1...30))
        #expect(month.cells.map(\.state) == states(30, septemberMid))
        #expect(month.cells.filter(\.isToday).map(\.dayNumber) == [15])
        #expect(month.completedCount == 9)
        #expect(month.cells.first?.date == TestCalendar.day(2026, 9, 1))
        #expect(!month.cells.contains { $0.date == TestCalendar.day(2026, 8, 31) })
    }

    @Test("missed-skipped: Sep 9 skipped, 9 completed")
    func skipped() throws {
        let input = try MissedDayFixtures.input(completed: MissedDayFixtures.midProgramCompleted, skipped: [7])
        let month = ProgressStats.month(sessions: sessions(input), today: noon(2026, 9, 15), calendar: cal)
        #expect(month.cells[8].state == .skipped)
        #expect(month.completedCount == 9)
    }

    @Test("missed-shifted: Sep 9 rest, 15 today, the pending set still fills 16–18, 21–25, 28–30")
    func shifted() throws {
        let input = try MissedDayFixtures.input(completed: MissedDayFixtures.midProgramCompleted, dates: shiftedDates())
        let month = ProgressStats.month(sessions: sessions(input), today: noon(2026, 9, 15), calendar: cal)
        var expected = septemberMid
        expected[9...9] = nil
        #expect(month.cells.map(\.state) == states(30, expected))
        #expect(month.completedCount == 9)
    }

    @Test("freshProgram, Mon 08-31: lead 5, 31 cells, only 31 today, 0 completed")
    func fresh() throws {
        let month = ProgressStats.month(sessions: sessions(try HomeFixtures.freshProgramInput()), today: noon(2026, 8, 31), calendar: cal)
        #expect(month.year == 2026 && month.month == 8)
        #expect(month.leadingBlanks == 5)
        #expect(month.cells.count == 31)
        #expect(month.cells.map(\.state) == states(31, [31...31: .today]))
        #expect(month.cells.filter(\.isToday).map(\.dayNumber) == [31])
        #expect(month.completedCount == 0)
    }

    @Test("restDay data, Sat 09-19: 9 missed, 19 a rest day that is today, 13 completed")
    func restDay() throws {
        let month = ProgressStats.month(sessions: sessions(try MissedDayFixtures.input(completed: MissedDayFixtures.restDayCompleted)),
                                        today: noon(2026, 9, 19), calendar: cal)
        #expect(month.leadingBlanks == 1)
        #expect(month.cells[8].state == .missed)
        #expect(month.cells[18].state == .rest && month.cells[18].isToday)
        #expect(month.cells.map(\.state) == states(30, [1...4: .completed, 7...8: .completed, 9...9: .missed, 10...11: .completed,
                                                        14...18: .completed, 21...25: .scheduled, 28...30: .scheduled]))
        #expect(month.completedCount == 13)
    }

    @Test("Nov 2026: starts on a Sunday (6 blanks), 30 cells at local midnight across the DST change")
    func november() throws {
        let month = ProgressStats.month(sessions: sessions(try MissedDayFixtures.input(completed: MissedDayFixtures.midProgramCompleted)),
                                        today: noon(2026, 11, 10), calendar: cal)
        #expect(month.leadingBlanks == 6)
        #expect(month.cells.count == 30)
        #expect(month.cells[0].state == .rest)
        #expect(month.cells.map(\.date) == (1...30).map { TestCalendar.day(2026, 11, $0) })
    }

    @Test("Feb 2027, today Mon 02-01: lead 0, 28 cells; the program ends on the 12th, a shift moves its last session to the 15th")
    func february() throws {
        let plain = ProgressStats.month(sessions: sessions(try MissedDayFixtures.input(completed: MissedDayFixtures.midProgramCompleted)),
                                        today: noon(2027, 2, 1), calendar: cal)
        #expect(plain.year == 2027 && plain.month == 2)
        #expect(plain.leadingBlanks == 0)
        #expect(plain.cells.count == 28)
        let base: [ClosedRange<Int>: WeekStripState] = [1...1: .today, 2...5: .scheduled, 8...12: .scheduled]
        #expect(plain.cells.map(\.state) == states(28, base))
        #expect(plain.completedCount == 0)
        let shifted = ProgressStats.month(sessions: sessions(try MissedDayFixtures.input(completed: MissedDayFixtures.midProgramCompleted,
                                                                                         dates: shiftedDates())),
                                          today: noon(2027, 2, 1), calendar: cal)
        var expected = base
        expected[15...15] = .scheduled
        #expect(shifted.cells.map(\.state) == states(28, expected))
    }

    @Test("an archived completed session beats a current pending one on the same day (D2)")
    func archivedCompletedWins() {
        func s(_ index: Int, _ status: SessionStatus) -> SessionSummary {
            SessionSummary(index: index, week: 1, phase: .foundation, name: "S", scheduledDate: TestCalendar.day(2026, 9, 1),
                           status: status, sets: 3, reps: 12, exercises: [])
        }
        let archived = ProgressSession(programID: ProgressFixtures.archivedID, programCreatedAt: ProgressFixtures.at(8, 3, hour: 6),
                                       isArchived: true, summary: s(11, .completed))
        let current = ProgressSession(programID: ProgressFixtures.currentID, programCreatedAt: created, isArchived: false, summary: s(1, .pending))
        for input in [[current, archived], [archived, current]] {
            let month = ProgressStats.month(sessions: input, today: noon(2026, 9, 15), calendar: cal)
            #expect(month.cells[0].state == .completed)
            #expect(month.completedCount == 1)
        }
    }
}

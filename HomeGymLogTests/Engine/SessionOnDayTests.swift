import Foundation
import Testing
@testable import HomeGymLog

/// `HomeStats.session(on:in:calendar:)`: the one day rule shared by the week strip, the Program day cells and the
/// Progress calendar (m4-progress spec 4.3, NB1): completed wins, else lowest index.
@Suite struct SessionOnDayTests {
    private let cal = TestCalendar.calendar
    private let day = TestCalendar.day(2026, 9, 15)

    private func s(_ index: Int, _ status: SessionStatus, on date: Date = TestCalendar.day(2026, 9, 15)) -> SessionSummary {
        SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: date,
                       status: status, sets: 3, reps: 12, exercises: [])
    }

    @Test("a completed session beats a lower-index pending one, in either order")
    func completedWins() {
        let pair = [s(3, .pending), s(4, .completed)]
        #expect(HomeStats.session(on: day, in: pair, calendar: cal)?.index == 4)
        #expect(HomeStats.session(on: day, in: pair.reversed(), calendar: cal)?.index == 4)
    }

    @Test("two pending sessions: lowest index, in either order")
    func pendingLowestIndex() {
        let pair = [s(4, .pending), s(3, .pending)]
        #expect(HomeStats.session(on: day, in: pair, calendar: cal)?.index == 3)
        #expect(HomeStats.session(on: day, in: pair.reversed(), calendar: cal)?.index == 3)
    }

    @Test("two completed sessions: lowest index, in either order")
    func completedLowestIndex() {
        let pair = [s(5, .completed), s(2, .completed)]
        #expect(HomeStats.session(on: day, in: pair, calendar: cal)?.index == 2)
        #expect(HomeStats.session(on: day, in: pair.reversed(), calendar: cal)?.index == 2)
    }

    @Test("no session on the day, or no sessions at all → nil")
    func none() {
        let other = [s(1, .pending, on: TestCalendar.day(2026, 9, 16)), s(2, .completed, on: TestCalendar.day(2026, 9, 14))]
        #expect(HomeStats.session(on: day, in: other, calendar: cal) == nil)
        #expect(HomeStats.session(on: day, in: other.reversed(), calendar: cal) == nil)
        #expect(HomeStats.session(on: day, in: [], calendar: cal) == nil)
    }

    @Test("a time later in the day still counts as that day")
    func noonCounts() {
        #expect(HomeStats.session(on: day.addingTimeInterval(12 * 3600), in: [s(7, .skipped)], calendar: cal)?.index == 7)
    }

    @Test("weekStrip and dayCells follow the rule")
    func callersFollow() {
        let pair = [s(3, .pending), s(4, .completed)]
        let strip = HomeStats.weekStrip(sessions: pair, today: day.addingTimeInterval(12 * 3600), calendar: cal)
        #expect(strip[1].state == .completed, "Tuesday 09-15")
        let cells = ProgramTabStats.dayCells(sessions: pair, week: 1, calendar: cal)
        #expect(cells[1].session?.index == 4)
        let reversed = ProgramTabStats.dayCells(sessions: pair.reversed(), week: 1, calendar: cal)
        #expect(reversed[1].session?.index == 4)
    }
}

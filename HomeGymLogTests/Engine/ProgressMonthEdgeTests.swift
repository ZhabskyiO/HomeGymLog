import Foundation
import Testing
@testable import HomeGymLog

/// `ProgressStats.month` edges beyond `ProgressMonthTests` (spec 5.5, §6): sessions just outside the month, `today` on the first
/// and last instant of a month, a 6-row 31-day month starting on Sunday that holds the spring DST day, the fall-back day's
/// repeated hour, a leap February, and archived + current sessions sharing a day. TestCalendar is America/New_York.
@Suite struct ProgressMonthEdgeTests {
    private let cal = TestCalendar.calendar

    private func s(_ index: Int, _ status: SessionStatus, _ date: Date, archived: Bool = false) -> ProgressSession {
        let summary = SessionSummary(index: index, week: 1, phase: .foundation, name: "S\(index)", scheduledDate: date,
                                     status: status, sets: 3, reps: 12, exercises: [])
        return ProgressSession(programID: archived ? ProgressFixtures.archivedID : ProgressFixtures.currentID,
                               programCreatedAt: archived ? ProgressFixtures.at(8, 3, hour: 6) : ProgressFixtures.at(8, 31, hour: 6),
                               isArchived: archived, summary: summary)
    }

    private func local(_ y: Int, _ m: Int, _ d: Int, hour: Int, minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    @Test("sessions one minute before the 1st and at midnight after the last day are not counted")
    func sessionsOutsideTheMonth() {
        let sessions = [s(0, .completed, local(2026, 8, 31, hour: 23, minute: 59)),
                        s(1, .completed, TestCalendar.day(2026, 9, 1)),
                        s(2, .completed, local(2026, 9, 30, hour: 23, minute: 59)),
                        s(3, .completed, TestCalendar.day(2026, 10, 1))]
        let month = ProgressStats.month(sessions: sessions, today: local(2026, 9, 15, hour: 12), calendar: cal)
        #expect(month.completedCount == 2)
        #expect(month.cells.first?.state == .completed)
        #expect(month.cells.last?.state == .completed)
        #expect(month.cells.count == 30)
    }

    @Test("today on a month's edge instants picks that month",
          arguments: [(0.0, 11, 30, 1), (-1, 10, 31, 31), (30 * 86_400 - 1 + 3600, 11, 30, 30)])
    func todayOnEdges(offset: Double, month expectedMonth: Int, cells: Int, todayDay: Int) {
        // Offsets from local midnight Nov 1 2026: 0 = the first instant of November; −1 s = the last of October;
        // 30 days − 1 s + 1 h = Nov 30 23:59:59 EST (November gains the hour back on the 1st).
        let today = TestCalendar.day(2026, 11, 1).addingTimeInterval(offset)
        let month = ProgressStats.month(sessions: [], today: today, calendar: cal)
        #expect(month.month == expectedMonth)
        #expect(month.cells.count == cells)
        #expect(month.cells.filter(\.isToday).map(\.dayNumber) == [todayDay])
    }

    @Test("March 2026: starts Sunday (6 blanks, 37 slots = 6 rows), 31 local-midnight cells across the spring DST day")
    func marchSpringForward() {
        let sessions = [s(0, .completed, TestCalendar.day(2026, 3, 8)),
                        s(1, .pending, TestCalendar.day(2026, 3, 9)),
                        s(2, .pending, TestCalendar.day(2026, 3, 31))]
        let month = ProgressStats.month(sessions: sessions, today: local(2026, 3, 8, hour: 12), calendar: cal)
        #expect(month.year == 2026 && month.month == 3)
        #expect(month.leadingBlanks == 6)
        #expect(month.cells.count == 31)
        #expect(month.cells.map(\.date) == (1...31).map { TestCalendar.day(2026, 3, $0) })
        #expect(month.cells.map(\.dayNumber) == Array(1...31))
        #expect(month.cells[7].state == .completed && month.cells[7].isToday)
        #expect(month.cells[8].state == .scheduled)
        #expect(month.cells[30].state == .scheduled)
        #expect(month.cells.filter(\.isToday).count == 1)
        #expect(month.completedCount == 1)
    }

    @Test("Nov 1 2026, the fall-back day: 01:30 EST (the repeated hour) and 23:30 are both today on cell 1",
          arguments: [2.5 * 3600, 24.5 * 3600])
    func fallBackDay(secondsAfterMidnight: Double) throws {
        let today = TestCalendar.day(2026, 11, 1).addingTimeInterval(secondsAfterMidnight)
        try #require(cal.component(.day, from: today) == 1)
        let sessions = [s(0, .pending, TestCalendar.day(2026, 10, 31)),
                        s(1, .pending, TestCalendar.day(2026, 11, 1)),
                        s(2, .pending, TestCalendar.day(2026, 11, 2))]
        let month = ProgressStats.month(sessions: sessions, today: today, calendar: cal)
        #expect(month.month == 11)
        #expect(month.leadingBlanks == 6)
        #expect(month.cells[0].state == .today && month.cells[0].isToday)
        #expect(month.cells[1].date == TestCalendar.day(2026, 11, 2), "a 25-hour day must not put cell 2 at 23:00 on Nov 1")
        #expect(month.cells[1].state == .scheduled)
        #expect(month.cells.filter(\.isToday).count == 1)
    }

    @Test("leap February 2028: Tue the 1st (lead 1), 29 cells, the 29th today")
    func leapFebruary() {
        let month = ProgressStats.month(sessions: [s(0, .pending, TestCalendar.day(2028, 2, 29))],
                                        today: cal.date(from: DateComponents(year: 2028, month: 2, day: 29, hour: 12))!, calendar: cal)
        #expect(month.year == 2028 && month.month == 2)
        #expect(month.leadingBlanks == 1)
        #expect(month.cells.count == 29)
        #expect(month.cells[28].state == .today && month.cells[28].isToday)
    }

    @Test("an archived and a current session both completed on one day make one completed cell")
    func bothCompletedCountOnce() {
        let day = TestCalendar.day(2026, 9, 1)
        let month = ProgressStats.month(sessions: [s(11, .completed, day, archived: true), s(1, .completed, day)],
                                        today: local(2026, 9, 15, hour: 12), calendar: cal)
        #expect(month.cells[0].state == .completed)
        #expect(month.completedCount == 1)
    }

    @Test("an archived completed session on today beats a current pending one: completed, still marked today")
    func archivedCompletedOnToday() {
        let day = TestCalendar.day(2026, 9, 15)
        let month = ProgressStats.month(sessions: [s(0, .pending, day), s(11, .completed, day, archived: true)],
                                        today: local(2026, 9, 15, hour: 12), calendar: cal)
        #expect(month.cells[14].state == .completed)
        #expect(month.cells[14].isToday)
        #expect(month.completedCount == 1)
    }

    @Test("an archived completed session beats a current missed one on the same past day")
    func archivedCompletedBeatsMissed() {
        let day = TestCalendar.day(2026, 9, 9)
        let month = ProgressStats.month(sessions: [s(7, .pending, day), s(3, .completed, day, archived: true)],
                                        today: local(2026, 9, 15, hour: 12), calendar: cal)
        #expect(month.cells[8].state == .completed)
    }
}

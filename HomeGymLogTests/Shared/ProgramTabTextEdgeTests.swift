import Foundation
import Testing
@testable import HomeGymLog

/// The corners of the Program tab's text helpers: the `.rest` case that never reaches a card, and the
/// scheduled-date string at a month and a year boundary.
@MainActor
@Suite struct ProgramTabTextEdgeTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    @Test("the rest state has no status text and a muted tone")
    func restState() {
        let date = TestCalendar.day(2026, 9, 20)
        #expect(ProgramTabText.status(.rest, date: date, calendar: cal).isEmpty)
        #expect(ProgramTabText.tone(for: .rest) == .muted)
    }

    @Test("a scheduled status shows the short date across month and year boundaries")
    func scheduledDatesAcrossBoundaries() {
        #expect(ProgramTabText.status(.scheduled, date: TestCalendar.day(2026, 11, 1), calendar: cal) == "Nov 1")
        #expect(ProgramTabText.status(.scheduled, date: TestCalendar.day(2026, 12, 31), calendar: cal) == "Dec 31")
        #expect(ProgramTabText.status(.scheduled, date: TestCalendar.day(2027, 1, 1), calendar: cal) == "Jan 1")
        #expect(ProgramTabText.status(.scheduled, date: TestCalendar.day(2027, 2, 8), calendar: cal) == "Feb 8")
    }

    @Test("only Deload carries the load note")
    func onlyDeloadHasTheLoadNote() {
        #expect(!ProgramTabText.phaseScheme(.foundation).contains("30%"))
        #expect(!ProgramTabText.phaseScheme(.build).contains("30%"))
        #expect(!ProgramTabText.phaseScheme(.peak).contains("30%"))
        #expect(ProgramTabText.phaseScheme(.deload) == "2 × 12 · \u{2212}30% load")
    }
}

import Foundation
import Testing
@testable import HomeGymLog

/// One title input (spec 5.2) with its verbatim text.
struct MissedEdgeTitleCase: Sendable, CustomTestStringConvertible {
    let name: String
    let scheduled: Date
    let today: Date
    let expected: String
    var testDescription: String { expected }
}

private func titleAt(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    TestCalendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private let titleEdgeTable: [MissedEdgeTitleCase] = [
    MissedEdgeTitleCase(name: "Lower", scheduled: TestCalendar.day(2026, 12, 28), today: titleAt(2027, 1, 3),
                        expected: "You skipped Lower on Mon"),
    MissedEdgeTitleCase(name: "Upper", scheduled: TestCalendar.day(2026, 12, 27), today: titleAt(2027, 1, 3),
                        expected: "You skipped Upper on Sun, Dec 27"),
    MissedEdgeTitleCase(name: "Legs", scheduled: TestCalendar.day(2026, 10, 28), today: titleAt(2026, 11, 3),
                        expected: "You skipped Legs on Wed"),
    MissedEdgeTitleCase(name: "Pull", scheduled: TestCalendar.day(2026, 10, 27), today: titleAt(2026, 11, 3),
                        expected: "You skipped Pull on Tue, Oct 27"),
    MissedEdgeTitleCase(name: "Push", scheduled: TestCalendar.day(2027, 3, 8), today: titleAt(2027, 3, 14),
                        expected: "You skipped Push on Mon"),
    MissedEdgeTitleCase(name: "Lower", scheduled: TestCalendar.day(2027, 3, 7), today: titleAt(2027, 3, 14, 0),
                        expected: "You skipped Lower on Sun, Mar 7"),
    MissedEdgeTitleCase(name: "Legs", scheduled: TestCalendar.day(2025, 9, 10), today: titleAt(2026, 9, 15),
                        expected: "You skipped Legs on Wed, Sep 10"),
    MissedEdgeTitleCase(name: "Legs", scheduled: TestCalendar.day(2026, 9, 15), today: titleAt(2026, 9, 16),
                        expected: "You skipped Legs on Tue"),
    MissedEdgeTitleCase(name: "Push", scheduled: TestCalendar.day(2026, 9, 8), today: titleAt(2026, 9, 14, 23, 59),
                        expected: "You skipped Push on Tue"),
]

/// Gaps beside `MissedDayTextTests` (spec 5.2): the title across the year end, both DST changes and a year back, for a
/// shifted session a day later, and in calendar locales other than English (the weekday and the full date follow the
/// calendar's locale, not the process's).
@MainActor
@Suite struct MissedDayTextEdgeTests {
    private func calendar(_ localeID: String) -> Calendar {
        var calendar = TestCalendar.calendar
        calendar.locale = Locale(identifier: localeID)
        return calendar
    }

    @Test("title across the year end, the fall-back and spring-forward weeks, a year back, and the shifted s7 a day later",
          arguments: titleEdgeTable)
    func titles(_ edge: MissedEdgeTitleCase) {
        let text = MissedDayText.title(name: edge.name, scheduledDate: edge.scheduled, today: edge.today, calendar: calendar("en_US"))
        #expect(text == edge.expected)
    }

    @Test("within six days the weekday is the calendar locale's standalone short weekday, not \"Wed\"", arguments: ["fr_FR", "de_DE", "ja_JP"])
    func weekdayFollowsCalendarLocale(localeID: String) {
        let localized = calendar(localeID)
        let scheduled = TestCalendar.day(2026, 9, 9)   // a Wednesday
        let weekday = localized.shortStandaloneWeekdaySymbols[localized.component(.weekday, from: scheduled) - 1]
        #expect(weekday != "Wed")
        let text = MissedDayText.title(name: "Legs", scheduledDate: scheduled, today: titleAt(2026, 9, 15), calendar: localized)
        #expect(text == "You skipped Legs on \(weekday)")
    }

    @Test("from seven days the full date follows the calendar locale too: fr_FR names no English weekday or month")
    func fullDateFollowsCalendarLocale() {
        let scheduled = TestCalendar.day(2026, 9, 9)
        let today = titleAt(2026, 9, 17)
        let english = MissedDayText.title(name: "Legs", scheduledDate: scheduled, today: today, calendar: calendar("en_US"))
        let french = MissedDayText.title(name: "Legs", scheduledDate: scheduled, today: today, calendar: calendar("fr_FR"))
        #expect(english == "You skipped Legs on Wed, Sep 9")
        #expect(french.hasPrefix("You skipped Legs on "))
        #expect(french != english)
        #expect(!french.contains("Wed"))
        #expect(!french.contains("Sep"))
    }
}

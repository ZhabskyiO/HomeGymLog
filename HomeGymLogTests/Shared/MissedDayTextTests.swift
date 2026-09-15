import Foundation
import Testing
@testable import HomeGymLog

/// AC-20 (text half): the prompt title's day text and the four fixed strings, verbatim from spec 2.1 / 4.3.
@MainActor
@Suite struct MissedDayTextTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test("title: weekday for 1–6 days back, full date from 7 days, across a year end")
    func titles() {
        let rows: [(name: String, scheduled: Date, today: Date, expected: String)] = [
            ("Legs", TestCalendar.day(2026, 9, 9), noon(2026, 9, 15), "You skipped Legs on Wed"),
            ("Pull", TestCalendar.day(2026, 9, 15), noon(2026, 9, 17), "You skipped Pull on Tue"),
            ("Legs", TestCalendar.day(2026, 9, 16), noon(2026, 9, 17), "You skipped Legs on Wed"),
            ("Pull", TestCalendar.day(2026, 9, 8), noon(2026, 9, 15), "You skipped Pull on Tue, Sep 8"),
            ("Legs", TestCalendar.day(2026, 9, 9), noon(2026, 9, 17), "You skipped Legs on Wed, Sep 9"),
            ("Lower", TestCalendar.day(2026, 12, 25), noon(2027, 1, 4), "You skipped Lower on Fri, Dec 25"),
        ]
        for row in rows {
            #expect(MissedDayText.title(name: row.name, scheduledDate: row.scheduled, today: row.today, calendar: cal) == row.expected)
        }
    }

    @Test("the four fixed strings, with U+00B7 in both button labels")
    func constants() {
        #expect(MissedDayText.kicker == "MISSED SESSION")
        #expect(MissedDayText.body == "Do it today and push the rest of the week back a day, or skip it and stay on schedule.")
        #expect(MissedDayText.shift == "Do it today \u{00B7} shift program")
        #expect(MissedDayText.skip == "Skip it \u{00B7} stay on schedule")
        #expect(Array(MissedDayText.shift.unicodeScalars).map(\.value)[12] == 0x00B7)
        #expect(Array(MissedDayText.skip.unicodeScalars).map(\.value)[8] == 0x00B7)
    }
}

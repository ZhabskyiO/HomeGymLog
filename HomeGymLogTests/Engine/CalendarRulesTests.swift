import Foundation
import Testing
@testable import HomeGymLog

@Suite struct CalendarRulesTests {
    private let cal = TestCalendar.calendar
    private let mwf = [0, 2, 4]

    @Test("app weekday is 0 = Monday, Sunday 2026-09-06 through Saturday 09-12 map to 6, 0…5")
    func appWeekday() {
        let expected = [6, 0, 1, 2, 3, 4, 5]
        for (offset, weekday) in expected.enumerated() {
            let date = TestCalendar.day(2026, 9, 6 + offset)
            #expect(CalendarRules.appWeekday(of: date, calendar: cal) == weekday, "2026-09-\(6 + offset)")
        }
    }

    @Test("monday of week containing each day of the week is Mon 2026-09-07")
    func mondayOfWeek() {
        let monday = TestCalendar.day(2026, 9, 7)
        for dayOfMonth in 7...13 {
            #expect(CalendarRules.monday(ofWeekContaining: TestCalendar.day(2026, 9, dayOfMonth), calendar: cal) == monday)
        }
        // Sunday 09-06 belongs to the previous Monday-based week
        #expect(CalendarRules.monday(ofWeekContaining: TestCalendar.day(2026, 9, 6), calendar: cal) == TestCalendar.day(2026, 8, 31))
    }

    @Test("adding 7 days across the DST change lands on midnight of Mon 2026-11-02")
    func dstSafeDayArithmetic() {
        let before = TestCalendar.day(2026, 10, 26)
        let result = CalendarRules.day(before, adding: 7, calendar: cal)
        #expect(result == TestCalendar.day(2026, 11, 2))
        #expect(result != before.addingTimeInterval(7 * 86_400))
    }

    @Test("training-day helpers")
    func trainingDays() {
        #expect(CalendarRules.nextTrainingDay(strictlyAfter: TestCalendar.day(2026, 9, 11), trainingWeekdays: mwf, calendar: cal) == TestCalendar.day(2026, 9, 14))
        #expect(CalendarRules.firstTrainingDay(onOrAfter: TestCalendar.day(2026, 9, 12), trainingWeekdays: mwf, calendar: cal) == TestCalendar.day(2026, 9, 14))
        #expect(CalendarRules.firstTrainingDay(onOrAfter: TestCalendar.day(2026, 9, 9), trainingWeekdays: mwf, calendar: cal) == TestCalendar.day(2026, 9, 9))
        #expect(CalendarRules.nextTrainingDay(strictlyAfter: TestCalendar.day(2026, 9, 9), trainingWeekdays: mwf, calendar: cal) == TestCalendar.day(2026, 9, 11))
        #expect(CalendarRules.isSameDay(TestCalendar.day(2026, 9, 9), TestCalendar.day(2026, 9, 9).addingTimeInterval(3600), calendar: cal))
    }

    @Test("days between calendar days is DST-safe and signed")
    func daysBetween() {
        #expect(CalendarRules.days(from: TestCalendar.day(2026, 8, 31), to: TestCalendar.day(2026, 9, 15), calendar: cal) == 15)
        #expect(CalendarRules.days(from: TestCalendar.day(2026, 8, 31), to: TestCalendar.day(2027, 2, 12), calendar: cal) == 165)
        #expect(CalendarRules.days(from: TestCalendar.day(2026, 9, 15), to: TestCalendar.day(2026, 9, 15), calendar: cal) == 0)
        #expect(CalendarRules.days(from: TestCalendar.day(2026, 9, 15), to: TestCalendar.day(2026, 9, 14), calendar: cal) == -1)
        // Spring forward 2027-03-14 (America/New_York): that day is 23 hours long, so `/ 86 400` gives 1 and 0.
        #expect(CalendarRules.days(from: TestCalendar.day(2027, 3, 13), to: TestCalendar.day(2027, 3, 15), calendar: cal) == 2)
        #expect(CalendarRules.days(from: TestCalendar.day(2027, 3, 14), to: TestCalendar.day(2027, 3, 15), calendar: cal) == 1)
        // Times of day inside the two days are ignored.
        #expect(CalendarRules.days(from: TestCalendar.day(2026, 8, 31).addingTimeInterval(12 * 3600),
                                   to: TestCalendar.day(2026, 9, 15).addingTimeInterval(8 * 3600), calendar: cal) == 15)
    }
}

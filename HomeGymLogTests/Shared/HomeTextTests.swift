import Foundation
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct HomeTextTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    @Test("dates, greeting, pill, meta")
    func texts() {
        #expect(HomeText.dayLabel(TestCalendar.day(2026, 9, 15), calendar: cal) == "Tue, Sep 15")
        #expect(HomeText.dayLabel(TestCalendar.day(2026, 9, 21), calendar: cal) == "Mon, Sep 21")
        #expect(HomeText.shortDate(TestCalendar.day(2026, 9, 14), calendar: cal) == "Sep 14")
        #expect(HomeText.greeting(.morning) == "Good morning" && HomeText.greeting(.afternoon) == "Good afternoon" && HomeText.greeting(.evening) == "Good evening")
        #expect(HomeText.weekPill(CurrentWeek(week: 3, phase: .foundation)) == "Week 3 · Foundation")
        #expect(HomeText.sessionMeta(exercises: 5, sets: 3, reps: 12, minutes: 45) == "5 exercises · 3 × 12 · ~45 min")
        #expect(HomeText.sessionMeta(exercises: 5, sets: 3, reps: 12, minutes: nil) == "5 exercises · 3 × 12")
    }

    @Test("week strip letters are Monday first even on a Sunday-first calendar")
    func letters() {
        #expect(HomeText.weekStripLetters(calendar: cal) == ["M", "T", "W", "T", "F", "S", "S"])
    }
}

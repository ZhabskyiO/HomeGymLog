import Foundation
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct ProgramSummaryTextTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    private func summary(months: Int, frequency: Int, days: [Int], on: Date) throws -> ProgramSummary {
        let inputs = ProgramInputs(months: months, frequency: frequency, trainingWeekdays: days, sessionLengthMinutes: 45,
                                   startingWeightsLb: [:], generatedOn: on)
        return ProgramSummary(generated: try ProgramGenerator.generate(inputs, calendar: cal))
    }

    @Test("title, week ranges, schemes")
    func fragments() throws {
        let s = try summary(months: 6, frequency: 5, days: [0, 1, 2, 3, 4], on: TestCalendar.day(2026, 8, 31))
        #expect(ProgramSummaryText.title(months: 6) == "6-month program")
        #expect(ProgramSummaryText.title(months: 1) == "1-month program")
        #expect(ProgramSummaryText.weekRange(s.phases[0]) == "Weeks 1–9")
        #expect(ProgramSummaryText.weekRange(s.phases[3]) == "Week 24")
        #expect(ProgramSummaryText.scheme(.deload) == "2 × 12")
        #expect(ProgramSummaryText.scheme(.foundation) == "3 × 12")
    }

    @Test("first session line for the three spec rows")
    func firstSession() throws {
        #expect(ProgramSummaryText.firstSession(try summary(months: 6, frequency: 5, days: [0, 1, 2, 3, 4], on: TestCalendar.day(2026, 8, 31)), calendar: cal) == "Push · Mon, Aug 31")
        #expect(ProgramSummaryText.firstSession(try summary(months: 1, frequency: 4, days: [0, 1, 3, 4], on: TestCalendar.day(2026, 8, 31)), calendar: cal) == "Upper A · Mon, Aug 31")
        #expect(ProgramSummaryText.firstSession(try summary(months: 2, frequency: 3, days: [0, 2, 4], on: TestCalendar.day(2026, 9, 9)), calendar: cal) == "Full Body A · Wed, Sep 9")
    }
}

import Foundation
import Testing
@testable import HomeGymLog

@Suite struct ProgramSummaryTests {
    private let cal = TestCalendar.calendar

    private func summary(months: Int, frequency: Int, days: [Int], minutes: Int, on: Date) throws -> ProgramSummary {
        let inputs = ProgramInputs(months: months, frequency: frequency, trainingWeekdays: days, sessionLengthMinutes: minutes,
                                   startingWeightsLb: [:], generatedOn: on)
        return ProgramSummary(generated: try ProgramGenerator.generate(inputs, calendar: cal))
    }

    @Test("ob5 seed: 6 months, 5 days, 45 min, generated Mon 2026-08-31")
    func ob5() throws {
        let s = try summary(months: 6, frequency: 5, days: [0, 1, 2, 3, 4], minutes: 45, on: TestCalendar.day(2026, 8, 31))
        #expect(s.months == 6 && s.weeks == 24 && s.totalSessions == 120 && s.frequency == 5 && s.sessionLengthMinutes == 45)
        #expect(s.phases == [
            PhaseRange(phase: .foundation, firstWeek: 1, lastWeek: 9), PhaseRange(phase: .build, firstWeek: 10, lastWeek: 17),
            PhaseRange(phase: .peak, firstWeek: 18, lastWeek: 23), PhaseRange(phase: .deload, firstWeek: 24, lastWeek: 24),
        ])
        #expect(s.phases.map { ($0.phase.sets, $0.phase.reps) }.map { "\($0.0)x\($0.1)" } == ["3x12", "4x10", "4x8", "2x12"])
        #expect(s.splitName == "Push / Pull / Legs + Upper / Lower")
        #expect(s.firstSessionName == "Push" && s.firstSessionDate == TestCalendar.day(2026, 8, 31))
    }

    @Test("defaults: 1 month, 4 days, 45 min")
    func defaults() throws {
        let s = try summary(months: 1, frequency: 4, days: [0, 1, 3, 4], minutes: 45, on: TestCalendar.day(2026, 8, 31))
        #expect(s.totalSessions == 16)
        #expect(s.phases == [
            PhaseRange(phase: .foundation, firstWeek: 1, lastWeek: 2), PhaseRange(phase: .peak, firstWeek: 3, lastWeek: 3),
            PhaseRange(phase: .deload, firstWeek: 4, lastWeek: 4),
        ])
        #expect(s.splitName == "Upper / Lower")
        #expect(s.firstSessionName == "Upper A" && s.firstSessionDate == TestCalendar.day(2026, 8, 31))
    }

    @Test("2 months, Mon/Wed/Fri, generated Wed 2026-09-09: mid-week start")
    func midWeek() throws {
        let s = try summary(months: 2, frequency: 3, days: [0, 2, 4], minutes: 45, on: TestCalendar.day(2026, 9, 9))
        #expect(s.totalSessions == 24)
        #expect(s.phases.map { ($0.firstWeek, $0.lastWeek) }.map { "\($0.0)-\($0.1)" } == ["1-3", "4-5", "6-7", "8-8"])
        #expect(s.firstSessionName == "Full Body A" && s.firstSessionDate == TestCalendar.day(2026, 9, 9))
    }
}

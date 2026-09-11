import Foundation
import Testing
@testable import HomeGymLog

/// The 5.2 table cells the existing summary tests skip: the full text of the 2-month row and the
/// defaults row, every phase's scheme, the tiles, and a weekend generation with Mo–Fr.
@MainActor
@Suite struct ProgramSummaryRowsTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    private func summary(months: Int, frequency: Int, days: [Int], minutes: Int = 45, on: Date) throws -> ProgramSummary {
        let inputs = ProgramInputs(months: months, frequency: frequency, trainingWeekdays: days, sessionLengthMinutes: minutes,
                                   startingWeightsLb: [:], generatedOn: on)
        return ProgramSummary(generated: try ProgramGenerator.generate(inputs, calendar: cal))
    }

    @Test("2-month row: title, four week ranges with schemes, 24 sessions, 3/wk Full body, mid-week first session")
    func twoMonthRow() throws {
        let s = try summary(months: 2, frequency: 3, days: [0, 2, 4], on: TestCalendar.day(2026, 9, 9))
        #expect(ProgramSummaryText.title(months: s.months) == "2-month program")
        #expect(s.weeks == 8)
        #expect(s.phases.map(ProgramSummaryText.weekRange) == ["Weeks 1–3", "Weeks 4–5", "Weeks 6–7", "Week 8"])
        #expect(s.phases.map { ProgramSummaryText.scheme($0.phase) } == ["3 × 12", "4 × 10", "4 × 8", "2 × 12"])
        #expect(s.totalSessions == 24 && s.frequency == 3 && s.sessionLengthMinutes == 45)
        #expect(s.splitName == "Full body A / B / C")
        #expect(ProgramSummaryText.firstSession(s, calendar: cal) == "Full Body A · Wed, Sep 9")
    }

    @Test("defaults row: three ranges without Build, 4/wk Upper / Lower, 45 min")
    func defaultsRow() throws {
        let s = try summary(months: 1, frequency: 4, days: [0, 1, 3, 4], on: TestCalendar.day(2026, 8, 31))
        #expect(ProgramSummaryText.title(months: s.months) == "1-month program")
        #expect(s.weeks == 4)
        #expect(s.phases.map(ProgramSummaryText.weekRange) == ["Weeks 1–2", "Week 3", "Week 4"])
        #expect(s.phases.map { ProgramSummaryText.scheme($0.phase) } == ["3 × 12", "4 × 8", "2 × 12"])
        #expect(s.totalSessions == 16 && s.frequency == 4 && s.sessionLengthMinutes == 45)
        #expect(s.splitName == "Upper / Lower")
    }

    @Test("ob5 row tiles: 120 sessions, 5/wk, 45 min, and the bar's flex weights 9/8/6/1")
    func ob5Tiles() throws {
        let s = try summary(months: 6, frequency: 5, days: [0, 1, 2, 3, 4], on: TestCalendar.day(2026, 8, 31))
        #expect(s.totalSessions == 120 && s.frequency == 5 && s.sessionLengthMinutes == 45)
        #expect(s.phases.map { $0.lastWeek - $0.firstWeek + 1 } == [9, 8, 6, 1])
        #expect(s.phases.map(ProgramSummaryText.weekRange) == ["Weeks 1–9", "Weeks 10–17", "Weeks 18–23", "Week 24"])
    }

    @Test("phase-bar flex weights per program length", arguments: [(1, [2, 1, 1]), (2, [3, 2, 2, 1]), (3, [4, 4, 3, 1]), (6, [9, 8, 6, 1])])
    func barWeights(months: Int, weights: [Int]) {
        let ranges = PhaseSplit.phaseRanges(weeks: PhaseSplit.weeks(months: months))
        #expect(ranges.map { $0.lastWeek - $0.firstWeek + 1 } == weights)
        #expect(ranges.last?.phase == .deload)
    }

    @Test("scheme text per phase", arguments: [(Phase.foundation, "3 × 12"), (.build, "4 × 10"), (.peak, "4 × 8"), (.deload, "2 × 12")])
    func schemes(phase: Phase, expected: String) {
        #expect(ProgramSummaryText.scheme(phase) == expected)
    }

    @Test("session length tile reflects the chosen length", arguments: [20, 30, 45, 60])
    func lengthTile(minutes: Int) throws {
        let s = try summary(months: 1, frequency: 4, days: [0, 1, 3, 4], minutes: minutes, on: TestCalendar.day(2026, 8, 31))
        #expect(s.sessionLengthMinutes == minutes)
    }

    @Test("generated on a weekend with Mo–Fr: first session is next Monday", arguments: [(9, 5), (9, 6)])
    func weekendStart(month: Int, day: Int) throws {
        let s = try summary(months: 6, frequency: 5, days: [0, 1, 2, 3, 4], on: TestCalendar.day(2026, month, day))
        #expect(s.firstSessionName == "Push" && s.firstSessionDate == TestCalendar.day(2026, 9, 7))
        #expect(ProgramSummaryText.firstSession(s, calendar: cal) == "Push · Mon, Sep 7")
        #expect(s.totalSessions == 120)
    }
}

import Foundation
import Testing
@testable import HomeGymLog

/// Spec 6 edge cases for the draft that `OnboardingDraftTests` does not already cover.
@MainActor
@Suite struct OnboardingDraftEdgeTests {
    private let cal = TestCalendar.calendar

    @Test("with frequency 5 and five days picked, each extra tap swaps out the earliest selected day")
    func extraDaySwapsEarliest() {
        let d = OnboardingDraft()
        d.step = 2
        d.selectFrequency(5)
        d.toggleDay(5)
        #expect(d.days == [1, 2, 3, 4, 5])
        d.toggleDay(6)
        #expect(d.days == [2, 3, 4, 5, 6])
        #expect(d.canContinue)
    }

    @Test("reducing frequency from 5 to 3 resets to Mo We Fr, never keeping a 5-day set")
    func fiveToThreeResets() {
        let d = OnboardingDraft()
        d.selectFrequency(5)
        d.toggleDay(0)
        d.toggleDay(5)
        #expect(d.days == [1, 2, 3, 4, 5])
        d.selectFrequency(3)
        #expect(d.frequency == 3 && d.days == [0, 2, 4])
    }

    @Test("days stay sorted when a lower weekday is re-added")
    func daysStaySorted() {
        let d = OnboardingDraft()
        d.toggleDay(0)
        d.toggleDay(2)
        #expect(d.days == [1, 2, 3, 4])
        d.toggleDay(1)
        d.toggleDay(0)
        #expect(d.days == [0, 2, 3, 4])
    }

    @Test("weekdays outside 0…6 are ignored")
    func outOfRangeDay() {
        let d = OnboardingDraft()
        d.toggleDay(0)
        d.toggleDay(7)
        d.toggleDay(-1)
        #expect(d.days == [1, 3, 4])
    }

    @Test("advance stays blocked after a frequency change until the day count matches again")
    func gateAfterFrequencyChange() {
        let d = OnboardingDraft()
        d.step = 2
        d.selectFrequency(5)
        d.toggleDay(4)
        #expect(!d.canContinue)
        d.advance(now: TestCalendar.day(2026, 8, 31), calendar: cal)
        #expect(d.step == 2)
        d.selectFrequency(3)
        #expect(d.canContinue, "a frequency change restores the default days")
        d.toggleDay(2)
        d.advance(now: TestCalendar.day(2026, 8, 31), calendar: cal)
        #expect(d.step == 2 && !d.canContinue)
        d.toggleDay(6)
        #expect(d.days == [0, 4, 6])
        d.advance(now: TestCalendar.day(2026, 8, 31), calendar: cal)
        #expect(d.step == 3)
        #expect(d.inputs(generatedOn: TestCalendar.day(2026, 8, 31)).trainingWeekdays == [0, 4, 6])
    }

    @Test("a value for a row hidden by a shorter session is kept, not shown, and not generated")
    func hiddenRowKeepsValue() throws {
        let d = OnboardingDraft()
        d.selectFrequency(5)
        d.adjustStartingWeight(key: "latRaise", steps: 1)
        #expect(d.startingWeightRows.first { $0.key == "latRaise" }?.weightLb == 17.5)

        d.sessionLengthMinutes = 20
        #expect(d.startingWeightRows.count == 12)
        #expect(!d.startingWeightRows.contains { $0.key == "latRaise" })
        #expect(d.startingWeightsLb["latRaise"] == 17.5, "the draft keeps it")
        let inputs = d.inputs(generatedOn: TestCalendar.day(2026, 8, 31))
        #expect(inputs.startingWeightsLb["latRaise"] == 17.5, "the inputs still carry it")
        let generated = try ProgramGenerator.generate(inputs, calendar: cal)
        #expect(generated.startingWeightsLb["latRaise"] == nil, "the generator resolves only used keys")
        #expect(!generated.sessions.contains { $0.exercises.contains { $0.exerciseKey == "latRaise" } })
        d.adjustStartingWeight(key: "latRaise", steps: 1)
        #expect(d.startingWeightsLb["latRaise"] == 17.5, "a hidden row cannot be stepped")

        d.sessionLengthMinutes = 45
        #expect(d.startingWeightRows.first { $0.key == "latRaise" }?.weightLb == 17.5, "back to 45 min shows the kept value")
    }

    @Test("the unit toggle changes no row value and no body weight; lb text is exact after a kg detour")
    func unitToggleRoundTrip() {
        let d = OnboardingDraft()
        d.selectFrequency(5)
        d.adjustStartingWeight(key: "dbBench", steps: 1)
        d.adjustStartingWeight(key: "latPull", steps: 2)
        let rowsLb = d.startingWeightRows.map(\.weightLb)
        d.units = .kg
        #expect(d.startingWeightRows.map(\.weightLb) == rowsLb)
        #expect(WeightDisplay.text(lb: d.startingWeightRows[0].weightLb, unit: .kg) == "19.3")
        #expect(WeightDisplay.wholeText(lb: d.bodyWeightLb, unit: .kg) == "82")
        d.units = .lb
        #expect(d.startingWeightRows.map(\.weightLb) == rowsLb)
        #expect(WeightDisplay.text(lb: d.startingWeightRows[0].weightLb, unit: .lb) == "42.5")
        #expect(WeightDisplay.text(lb: d.startingWeightsLb["latPull"]!, unit: .lb) == "120")
        #expect(WeightDisplay.wholeText(lb: d.bodyWeightLb, unit: .lb) == "180")
    }

    @Test("the draft opens in the stored unit; an unknown preference string is not a unit")
    func initialUnits() {
        #expect(OnboardingDraft(units: .kg).units == .kg)
        #expect(OnboardingDraft().units == .lb)
        #expect(WeightUnit(rawValue: "stone") == nil)
    }

    @Test("body weight reaches both bounds by stepping and stops there")
    func bodyWeightBoundsByStepping() {
        let d = OnboardingDraft()
        for _ in 0..<26 { d.adjustBodyWeight(by: -5) }
        #expect(d.bodyWeightLb == 50)
        d.adjustBodyWeight(by: -5)
        #expect(d.bodyWeightLb == 50)
        for _ in 0..<90 { d.adjustBodyWeight(by: 5) }
        #expect(d.bodyWeightLb == 500)
        d.adjustBodyWeight(by: 5)
        #expect(d.bodyWeightLb == 500)
        #expect(d.bodyWeightLb.truncatingRemainder(dividingBy: 5) == 0)
    }

    @Test("the A4 caption count follows the session length", arguments: [(20, 3), (30, 4), (45, 5), (60, 6)])
    func exerciseCountCaption(minutes: Int, expected: Int) {
        let d = OnboardingDraft()
        d.sessionLengthMinutes = minutes
        #expect(d.exerciseCount == expected)
        #expect(d.startingWeightRows.count == SplitPlans.exerciseKeys(frequency: 4, sessionLengthMinutes: minutes)?.count)
    }

    @Test("months is one of the four cards and the preview reflects it", arguments: [(1, 16), (2, 32), (3, 48), (6, 96)])
    func monthsDrivePreview(months: Int, sessions: Int) throws {
        let d = OnboardingDraft(months: months)
        d.step = 4
        d.advance(now: TestCalendar.day(2026, 8, 31).addingTimeInterval(12 * 3600), calendar: cal)
        let preview = try #require(d.preview)
        #expect(preview.months == months && preview.weeks == months * 4 && preview.totalSessions == sessions)
        #expect(preview.phases.count == (months == 1 ? 3 : 4), "1 month omits Build")
    }
}

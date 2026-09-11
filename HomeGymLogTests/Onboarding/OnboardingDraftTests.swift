import Foundation
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct OnboardingDraftTests {
    private let cal = TestCalendar.calendar

    @Test("defaults match the spec")
    func defaults() {
        let d = OnboardingDraft()
        #expect(d.step == 0 && d.units == .lb && d.months == 1 && d.frequency == 4 && d.days == [0, 1, 3, 4])
        #expect(d.bodyWeightLb == 180 && d.experience == .intermediate && d.sessionLengthMinutes == 45)
        #expect(d.startingWeightsLb.isEmpty && d.preview == nil && d.exerciseCount == 5)
        #expect(d.canContinue)
    }

    @Test("selecting a frequency resets the days to the split default")
    func frequency() {
        let d = OnboardingDraft()
        d.selectFrequency(3)
        #expect(d.frequency == 3 && d.days == [0, 2, 4])
        d.selectFrequency(5)
        #expect(d.frequency == 5 && d.days == [0, 1, 2, 3, 4])
        d.selectFrequency(9)
        #expect(d.frequency == 5)
    }

    @Test("day toggling gates Continue on step 2 and caps at frequency")
    func days() {
        let d = OnboardingDraft()
        d.step = 2
        d.toggleDay(0)
        #expect(d.days == [1, 3, 4] && !d.canContinue)
        d.toggleDay(6)
        #expect(d.days == [1, 3, 4, 6] && d.canContinue)
        d.toggleDay(2)
        #expect(d.days == [2, 3, 4, 6], "a fifth day replaces the earliest selected day")
        #expect(d.canContinue)
        d.step = 3
        d.toggleDay(6)
        #expect(!d.days.contains(6) && d.canContinue, "only step 2 gates Continue")
    }

    @Test("body weight steps by 5 within 50…500")
    func bodyWeight() {
        let d = OnboardingDraft()
        d.adjustBodyWeight(by: 5)
        #expect(d.bodyWeightLb == 185)
        d.bodyWeightLb = 50
        d.adjustBodyWeight(by: -5)
        #expect(d.bodyWeightLb == 50)
        d.bodyWeightLb = 500
        d.adjustBodyWeight(by: 5)
        #expect(d.bodyWeightLb == 500)
    }

    @Test("starting weights step by equipment and stop at bounds; overrides survive a hidden row")
    func startingWeights() {
        let d = OnboardingDraft()
        d.selectFrequency(5)
        d.adjustStartingWeight(key: "dbBench", steps: 1)
        #expect(d.startingWeightsLb["dbBench"] == 42.5)
        #expect(d.startingWeightRows.first?.weightLb == 42.5)
        d.adjustStartingWeight(key: "dbBench", steps: 4)
        #expect(d.startingWeightsLb["dbBench"] == 52.5)
        d.adjustStartingWeight(key: "dbBench", steps: 1)
        #expect(d.startingWeightsLb["dbBench"] == 52.5, "+1 from the max is a no-op")
        d.adjustStartingWeight(key: "legCurl", steps: -4)
        #expect(d.startingWeightsLb["legCurl"] == 10)
        d.adjustStartingWeight(key: "legCurl", steps: -1)
        #expect(d.startingWeightsLb["legCurl"] == 10, "-1 from the min is a no-op")
        d.sessionLengthMinutes = 20
        // (5, 20) has 12 rows and no latRaise; the dbBench override survives the change
        #expect(d.startingWeightRows.count == 12)
        #expect(!d.startingWeightRows.contains { $0.key == "latRaise" })
        #expect(d.startingWeightsLb["dbBench"] == 52.5 && d.inputs(generatedOn: TestCalendar.day(2026, 8, 31)).startingWeightsLb["dbBench"] == 52.5)
    }

    @Test("advance from step 4 computes the ob5 preview; goBack clears it")
    func preview() {
        let d = OnboardingDraft(months: 6, frequency: 5)
        d.step = 4
        d.advance(now: TestCalendar.day(2026, 8, 31).addingTimeInterval(12 * 3600), calendar: cal)
        #expect(d.step == 5)
        let p = d.preview
        #expect(p?.months == 6 && p?.totalSessions == 120 && p?.firstSessionName == "Push")
        #expect(p?.firstSessionDate == TestCalendar.day(2026, 8, 31))
        #expect(p?.phases.count == 4)
        d.advance(now: TestCalendar.day(2026, 8, 31), calendar: cal)
        #expect(d.step == 5, "cannot advance past the summary")
        d.goBack()
        #expect(d.step == 4 && d.preview == nil)
        d.step = 0
        d.goBack()
        #expect(d.step == 0)
    }

    @Test("advance is blocked on step 2 until the days are complete")
    func advanceGate() {
        let d = OnboardingDraft()
        d.step = 2
        d.toggleDay(0)
        d.advance(now: TestCalendar.day(2026, 8, 31), calendar: cal)
        #expect(d.step == 2)
        d.toggleDay(0)
        d.advance(now: TestCalendar.day(2026, 8, 31), calendar: cal)
        #expect(d.step == 3)
    }

    @Test("CTA labels per step")
    func ctaLabels() {
        let d = OnboardingDraft()
        var labels: [String] = []
        for step in 0...5 { d.step = step; labels.append(d.ctaLabel) }
        #expect(labels == ["Set up my program", "Continue", "Continue", "Continue", "Generate program", "Start program"])
    }

    @Test("body weight unit follows the app unit until chosen separately")
    func bodyWeightUnit() {
        let d = OnboardingDraft()
        #expect(d.bodyWeightUnit == .lb)
        d.units = .kg
        #expect(d.bodyWeightUnit == .kg, "follows the welcome-step unit while untouched")
        d.bodyWeightUnit = .lb
        d.units = .kg
        #expect(d.bodyWeightUnit == .lb, "an explicit choice sticks")
        d.adjustBodyWeight(by: 5)
        #expect(d.bodyWeightLb == 185, "stepper stays in pounds whatever the display unit")
        #expect(WeightDisplay.wholeText(lb: d.bodyWeightLb, unit: .kg) == "84")
    }

    @Test("changing the unit never changes stored values (AC-10)")
    func unitToggle() {
        let d = OnboardingDraft()
        d.adjustStartingWeight(key: "dbBench", steps: 1)
        d.units = .kg
        #expect(d.bodyWeightLb == 180 && d.startingWeightsLb == ["dbBench": 42.5])
        d.units = .lb
        #expect(d.bodyWeightLb == 180 && d.startingWeightsLb == ["dbBench": 42.5])
    }
}

import Foundation
import Testing
@testable import HomeGymLog

/// One weekday row: the archived program's stored frequency and weekdays, and what spec 5.2's per-field fallback must
/// return. Explicitly typed at file scope, never an inline `arguments:` literal (gotchas Swift 2026-09-14).
private struct WeekdayCase: Sendable, CustomStringConvertible {
    let frequency: Int
    let stored: [Int]
    let expected: [Int]
    let why: String

    var description: String { "frequency \(frequency), \(stored) → \(expected) (\(why))" }
}

private let weekdayCases: [WeekdayCase] = [
    WeekdayCase(frequency: 3, stored: [0, 2, 4], expected: [0, 2, 4], why: "valid, already sorted"),
    WeekdayCase(frequency: 3, stored: [4, 2, 0], expected: [0, 2, 4], why: "valid, sorted on the way out"),
    WeekdayCase(frequency: 3, stored: [0, 1, 6], expected: [0, 1, 6], why: "6 (Sunday) is inside 0…6"),
    WeekdayCase(frequency: 3, stored: [4, 5, 6], expected: [4, 5, 6], why: "the last three weekdays"),
    WeekdayCase(frequency: 5, stored: [2, 3, 4, 5, 6], expected: [2, 3, 4, 5, 6], why: "a valid non-default week"),
    WeekdayCase(frequency: 3, stored: [0, 0, 2], expected: [0, 2, 4], why: "one duplicate, right count"),
    WeekdayCase(frequency: 3, stored: [2, 2, 2], expected: [0, 2, 4], why: "all three the same day"),
    WeekdayCase(frequency: 4, stored: [0, 1, 1, 3], expected: [0, 1, 3, 4], why: "duplicate at frequency 4"),
    WeekdayCase(frequency: 5, stored: [0, 1, 2, 3, 3], expected: [0, 1, 2, 3, 4], why: "duplicate at frequency 5"),
    WeekdayCase(frequency: 3, stored: [0, 2, 7], expected: [0, 2, 4], why: "7 is past the last weekday"),
    WeekdayCase(frequency: 3, stored: [0, 2, -1], expected: [0, 2, 4], why: "-1 is before the first weekday"),
    WeekdayCase(frequency: 3, stored: [-7, -2, -1], expected: [0, 2, 4], why: "every day before the first"),
    WeekdayCase(frequency: 3, stored: [7, 8, 9], expected: [0, 2, 4], why: "every day past the last"),
    WeekdayCase(frequency: 3, stored: [0, 1, 2, 3], expected: [0, 2, 4], why: "one too many"),
    WeekdayCase(frequency: 3, stored: [0, 1], expected: [0, 2, 4], why: "one too few"),
    WeekdayCase(frequency: 3, stored: [], expected: [0, 2, 4], why: "none stored"),
    WeekdayCase(frequency: 4, stored: [], expected: [0, 1, 3, 4], why: "none stored, frequency 4"),
    WeekdayCase(frequency: 5, stored: [], expected: [0, 1, 2, 3, 4], why: "none stored, frequency 5"),
    WeekdayCase(frequency: 6, stored: [1, 2, 3, 4], expected: [1, 2, 3, 4], why: "checked against the fallen-back frequency 4"),
    WeekdayCase(frequency: 6, stored: [0, 1, 2, 3, 4, 5], expected: [0, 1, 3, 4], why: "six days, frequency falls back to 4"),
    WeekdayCase(frequency: 0, stored: [0, 2, 4], expected: [0, 1, 3, 4], why: "frequency 0 → 4, so three days no longer fit"),
]

/// AC-19 edges: the weekday table the plan's hand cases only sample (duplicates, out-of-range values either side of
/// 0…6, wrong counts) and the boundary weights of the starting-weight filter. Expected values are spec 5.2's rules
/// typed here; the defaults are `SplitPlans.defaultWeekdays`' published table.
@Suite struct RestartPrefillEdgeTests {
    private func answers(frequency: Int = 5, weekdays: [Int] = [0, 1, 2, 3, 4], bodyWeightLb: Double = 180,
                         weights: [String: Double] = [:]) -> OnboardingAnswers {
        RestartPrefill.answers(months: 6, frequency: frequency, trainingWeekdays: weekdays, sessionLengthMinutes: 45,
                               bodyWeightLb: bodyWeightLb, experience: "Intermediate", startingWeightsLb: weights)
    }

    @Test("weekdays are kept only when they are exactly `frequency` distinct days in 0…6", arguments: weekdayCases)
    fileprivate func weekdayTable(row: WeekdayCase) {
        #expect(answers(frequency: row.frequency, weekdays: row.stored).trainingWeekdays == row.expected)
    }

    @Test("whatever is stored, the result is sorted and has one day per session of the week", arguments: weekdayCases)
    fileprivate func weekdayShape(row: WeekdayCase) {
        let result = answers(frequency: row.frequency, weekdays: row.stored)
        #expect(result.trainingWeekdays == result.trainingWeekdays.sorted())
        #expect(result.trainingWeekdays.count == result.frequency)
        #expect(Set(result.trainingWeekdays).count == result.frequency)
        #expect(result.trainingWeekdays.allSatisfy { (0...6).contains($0) })
    }

    @Test("body weight: the two bounds are kept, anything outside is pulled to them")
    func bodyWeightBounds() {
        #expect(answers(bodyWeightLb: 50).bodyWeightLb == 50)
        #expect(answers(bodyWeightLb: 500).bodyWeightLb == 500)
        #expect(answers(bodyWeightLb: 49.9).bodyWeightLb == 50)
        #expect(answers(bodyWeightLb: 500.1).bodyWeightLb == 500)
        #expect(answers(bodyWeightLb: 0).bodyWeightLb == 50)
        #expect(answers(bodyWeightLb: -180).bodyWeightLb == 50)
        #expect(answers(bodyWeightLb: .infinity).bodyWeightLb == 500)
        #expect(answers(bodyWeightLb: -.infinity).bodyWeightLb == 50)
    }

    @Test("a dumbbell weight is kept at 5 and 52.5 lb and dropped one step outside either bound")
    func dumbbellGridBounds() {
        #expect(answers(weights: ["dbBench": 5]).startingWeightsLb == ["dbBench": 5])
        #expect(answers(weights: ["dbBench": 52.5]).startingWeightsLb == ["dbBench": 52.5])
        #expect(answers(weights: ["dbBench": 2.5]).startingWeightsLb == [:])
        #expect(answers(weights: ["dbBench": 55]).startingWeightsLb == [:], "the prototype's 55 lb is off this rack")
        #expect(answers(weights: ["dbBench": 0]).startingWeightsLb == [:])
        #expect(answers(weights: ["dbBench": -40]).startingWeightsLb == [:])
    }

    @Test("a Marcy weight is kept at 10 and 150 lb and dropped off the 10 lb grid or past the stack")
    func marcyGridBounds() {
        #expect(answers(weights: ["latPull": 10]).startingWeightsLb == ["latPull": 10])
        #expect(answers(weights: ["latPull": 150]).startingWeightsLb == ["latPull": 150])
        #expect(answers(weights: ["latPull": 160]).startingWeightsLb == [:])
        #expect(answers(weights: ["latPull": 95]).startingWeightsLb == [:])
        #expect(answers(weights: ["latPull": 0]).startingWeightsLb == [:])
    }

    @Test("the filter drops only the bad keys and keeps every good one in a mixed map")
    func mixedMap() {
        let map: [String: Double] = ["dbBench": 42.5, "latPull": 110, "nope": 40, "curl": 41, "goblet": 50]
        #expect(answers(weights: map).startingWeightsLb == ["dbBench": 42.5, "latPull": 110, "goblet": 50])
    }
}

import Foundation
import Testing
@testable import HomeGymLog

/// AC-19: `RestartPrefill.answers` keeps every valid field and falls back per field (spec 5.2). The worked row is
/// `midProgram`'s program; the hand cases are separate tests rather than one nested-tuple argument table
/// (gotchas Swift 2026-09-14).
@Suite struct RestartPrefillTests {
    /// The `midProgram` program's stored fields, one per named argument.
    private func midProgram(months: Int = 6, frequency: Int = 5, weekdays: [Int] = [0, 1, 2, 3, 4], length: Int = 45,
                            bodyWeightLb: Double = 180, experience: String = "Intermediate",
                            weights: [String: Double] = [:]) -> OnboardingAnswers {
        RestartPrefill.answers(months: months, frequency: frequency, trainingWeekdays: weekdays,
                               sessionLengthMinutes: length, bodyWeightLb: bodyWeightLb, experience: experience,
                               startingWeightsLb: weights)
    }

    /// The 17 library defaults of spec 5.2, typed as literals. `lowRow` is 90, not the spec's 80: 80 is that key's first
    /// *chart point* in the archived `progress-history` program (m4-progress 5.2 line 225), while `ExerciseLibrary`'s
    /// default — the value `midProgram` stores and the prototype's Home shows progressed to 100 — is 90.
    private static let midProgramWeightsLb: [String: Double] = [
        "dbBench": 40, "inclineDb": 35, "shoulderPress": 30, "pecDeck": 70, "latRaise": 15, "latPull": 100,
        "lowRow": 90, "dbRow": 45, "rdl": 50, "curl": 25, "goblet": 50, "legExt": 70, "legCurl": 50, "split": 30,
        "chestPress": 90, "skull": 25, "lunge": 30,
    ]

    @Test("the midProgram row keeps all seven fields, including its 17 starting weights")
    func midProgramRow() {
        let rows = StartingWeights.rows(frequency: 5, sessionLengthMinutes: 45, overrides: [:])
        var stored: [String: Double] = [:]
        for row in rows { stored[row.key] = row.weightLb }
        #expect(stored.count == 17)
        #expect(stored == Self.midProgramWeightsLb)

        let answers = midProgram(weights: stored)
        #expect(answers == OnboardingAnswers(months: 6, frequency: 5, trainingWeekdays: [0, 1, 2, 3, 4],
                                             sessionLengthMinutes: 45, bodyWeightLb: 180, experience: .intermediate,
                                             startingWeightsLb: Self.midProgramWeightsLb))
    }

    @Test("an unsupported month count falls back to 1")
    func months() {
        #expect(midProgram(months: 5).months == 1)
        #expect(midProgram(months: 0).months == 1)
        #expect(midProgram(months: 3).months == 3)
    }

    @Test("an unsupported frequency falls back to 4 with the 4-day default weekdays")
    func frequency() {
        let answers = midProgram(frequency: 6)
        #expect(answers.frequency == 4)
        #expect(answers.trainingWeekdays == [0, 1, 3, 4])
    }

    @Test("weekdays that do not match the frequency fall back to the split's defaults")
    func weekdayCount() {
        #expect(midProgram(frequency: 5, weekdays: [0, 1, 2]).trainingWeekdays == [0, 1, 2, 3, 4])
        #expect(midProgram(frequency: 3, weekdays: [0, 1, 2, 3]).trainingWeekdays == [0, 2, 4])
        #expect(midProgram(frequency: 3, weekdays: [0, 2, 2]).trainingWeekdays == [0, 2, 4])
        #expect(midProgram(frequency: 3, weekdays: [0, 2, 9]).trainingWeekdays == [0, 2, 4])
    }

    @Test("valid weekdays are returned sorted")
    func weekdaysSorted() {
        #expect(midProgram(frequency: 3, weekdays: [4, 0, 2]).trainingWeekdays == [0, 2, 4])
    }

    @Test("an unsupported session length falls back to 45 minutes")
    func sessionLength() {
        #expect(midProgram(length: 25).sessionLengthMinutes == 45)
        #expect(midProgram(length: 20).sessionLengthMinutes == 20)
        #expect(midProgram(length: 60).sessionLengthMinutes == 60)
    }

    @Test("body weight is clamped into 50…500 lb")
    func bodyWeight() {
        #expect(midProgram(bodyWeightLb: 20).bodyWeightLb == 50)
        #expect(midProgram(bodyWeightLb: 900).bodyWeightLb == 500)
        #expect(midProgram(bodyWeightLb: 147.5).bodyWeightLb == 147.5)
    }

    @Test("an unknown experience falls back to Intermediate")
    func experience() {
        #expect(midProgram(experience: "Pro").experience == .intermediate)
        #expect(midProgram(experience: "").experience == .intermediate)
        #expect(midProgram(experience: "Beginner").experience == .beginner)
        #expect(midProgram(experience: "Advanced").experience == .advanced)
    }

    @Test("a starting weight is dropped when the key is unknown or the weight is off the equipment grid")
    func startingWeights() {
        #expect(midProgram(weights: ["dbBench": 41]).startingWeightsLb == [:])
        #expect(midProgram(weights: ["nope": 40]).startingWeightsLb == [:])
        #expect(midProgram(weights: ["latPull": 105]).startingWeightsLb == [:])
        #expect(midProgram(weights: ["dbBench": 42.5]).startingWeightsLb == ["dbBench": 42.5])
        #expect(midProgram(weights: ["dbBench": 42.5, "nope": 40]).startingWeightsLb == ["dbBench": 42.5])
        #expect(midProgram(weights: [:]).startingWeightsLb == [:])
    }

    @Test("a fully valid custom input passes through unchanged")
    func validCustomInput() {
        let answers = RestartPrefill.answers(months: 3, frequency: 3, trainingWeekdays: [1, 3, 5],
                                             sessionLengthMinutes: 60, bodyWeightLb: 165, experience: "Advanced",
                                             startingWeightsLb: ["goblet": 45, "latPull": 110])
        #expect(answers == OnboardingAnswers(months: 3, frequency: 3, trainingWeekdays: [1, 3, 5],
                                             sessionLengthMinutes: 60, bodyWeightLb: 165, experience: .advanced,
                                             startingWeightsLb: ["goblet": 45, "latPull": 110]))
    }
}

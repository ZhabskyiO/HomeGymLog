import Foundation
import Testing
@testable import HomeGymLog

@Suite struct ExerciseKeysTests {
    @Test("the five spec rows, in order", arguments: [
        (3, 20, ["dbBench", "latPull", "goblet", "chestPress", "dbRow", "rdl", "inclineDb", "lowRow", "split"]),
        (4, 45, ["dbBench", "latPull", "shoulderPress", "lowRow", "curl", "goblet", "rdl", "legExt", "legCurl", "lunge", "inclineDb", "dbRow", "pecDeck", "latRaise", "skull", "split"]),
        (5, 20, ["dbBench", "inclineDb", "shoulderPress", "latPull", "lowRow", "dbRow", "goblet", "rdl", "legExt", "chestPress", "split", "legCurl"]),
        (5, 45, ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise", "latPull", "lowRow", "dbRow", "rdl", "curl", "goblet", "legExt", "legCurl", "split", "chestPress", "skull", "lunge"]),
        (5, 60, ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise", "pushdown", "latPull", "lowRow", "dbRow", "rdl", "curl", "goblet", "legExt", "legCurl", "split", "lunge", "chestPress", "skull"]),
    ])
    func specRows(frequency: Int, minutes: Int, expected: [String]) {
        #expect(SplitPlans.exerciseKeys(frequency: frequency, sessionLengthMinutes: minutes) == expected)
    }

    @Test("invalid inputs give nil")
    func invalid() {
        #expect(SplitPlans.exerciseKeys(frequency: 2, sessionLengthMinutes: 45) == nil)
        #expect(SplitPlans.exerciseKeys(frequency: 3, sessionLengthMinutes: 25) == nil)
    }

    @Test("generator keys and session exercise lists agree with exerciseKeys for all 12 shapes")
    func generatorAgrees() throws {
        for frequency in [3, 4, 5] {
            for minutes in [20, 30, 45, 60] {
                let keys = Set(try #require(SplitPlans.exerciseKeys(frequency: frequency, sessionLengthMinutes: minutes)))
                let inputs = ProgramInputs(months: 1, frequency: frequency, trainingWeekdays: SplitPlans.defaultWeekdays(frequency: frequency)!,
                                           sessionLengthMinutes: minutes, startingWeightsLb: [:], generatedOn: TestCalendar.day(2026, 9, 7))
                let generated = try ProgramGenerator.generate(inputs, calendar: TestCalendar.calendar)
                #expect(Set(generated.startingWeightsLb.keys) == keys, "\(frequency)d \(minutes)min startingWeights")
                // session lists are built independently of exerciseKeys, so this ties the rule to them
                #expect(Set(generated.sessions.flatMap { $0.exercises.map(\.exerciseKey) }) == keys, "\(frequency)d \(minutes)min sessions")
            }
        }
    }

    @Test("starting-weight rows for the ob4 shape: 17 rows, defaults, override applied")
    func rows() throws {
        let rows = StartingWeights.rows(frequency: 5, sessionLengthMinutes: 45, overrides: [:])
        #expect(rows.count == 17)
        let first = try #require(rows.first)
        #expect(first.key == "dbBench" && first.name == "Dumbbell Bench Press" && first.equipment == "Dumbbells + bench")
        #expect(first.kind == .dumbbell && first.weightLb == 40)
        #expect(!rows.contains { $0.key == "pushdown" })
        let overridden = StartingWeights.rows(frequency: 5, sessionLengthMinutes: 45, overrides: ["dbBench": 30, "latPull": 120])
        #expect(overridden.first?.weightLb == 30)
        #expect(overridden.first { $0.key == "latPull" }?.weightLb == 120)
        #expect(overridden.first { $0.key == "goblet" }?.weightLb == 50)
    }

    @Test("stepping stops at the equipment bounds")
    func stepped() {
        #expect(EquipmentKind.dumbbell.stepped(lb: 40, by: 1) == 42.5)
        #expect(EquipmentKind.dumbbell.stepped(lb: 40, by: -1) == 37.5)
        #expect(EquipmentKind.dumbbell.stepped(lb: 52.5, by: 1) == nil)
        #expect(EquipmentKind.dumbbell.stepped(lb: 5, by: -1) == nil)
        #expect(EquipmentKind.marcy.stepped(lb: 10, by: -1) == nil)
        #expect(EquipmentKind.marcy.stepped(lb: 140, by: 1) == 150)
        #expect(EquipmentKind.marcy.stepped(lb: 150, by: 1) == nil)
        #expect(EquipmentKind.dumbbell.stepped(lb: 15.75, by: 1) == nil)
    }

    @Test("Experience raw values")
    func experience() {
        #expect(Experience.allCases.map(\.rawValue) == ["Beginner", "Intermediate", "Advanced"])
    }
}

import Foundation
import Testing
@testable import HomeGymLog

/// Exercise-tools text edges beyond AC-23: kg text of every small grid delta (the pound difference converted, one decimal,
/// a trailing ".0" dropped like every weight), large lb deltas, the AC-6 candidate weights in kg, the remaining muscle names,
/// and a long name. Expected strings are typed; kg values are 0.45359237 × lb rounded to tenths by hand.
@MainActor
@Suite struct ExerciseToolsTextEdgeTests {
    @Test("the pill in kg for small and large deltas", arguments: [
        (2.5, "+1.1 kg from your last Lat Pulldown"), (5.0, "+2.3 kg from your last Lat Pulldown"),
        (7.5, "+3.4 kg from your last Lat Pulldown"), (12.5, "+5.7 kg from your last Lat Pulldown"),
        (15.0, "+6.8 kg from your last Lat Pulldown"), (30.0, "+13.6 kg from your last Lat Pulldown"),
        (130.0, "+59 kg from your last Lat Pulldown"),
    ])
    func pillKg(deltaLb: Double, expected: String) {
        #expect(ExerciseToolsText.pill(deltaLb: deltaLb, unit: .kg, name: "Lat Pulldown") == expected)
    }

    @Test("the pill in lb never shows a trailing .0 and keeps a half step", arguments: [
        (47.5, "Dumbbell Romanian Deadlift", "+47.5 lb from your last Dumbbell Romanian Deadlift"),
        (140.0, "Lat Pulldown", "+140 lb from your last Lat Pulldown"),
        (5.0, "Goblet Squat", "+5 lb from your last Goblet Squat"),
    ])
    func pillLb(deltaLb: Double, name: String, expected: String) {
        #expect(ExerciseToolsText.pill(deltaLb: deltaLb, unit: .lb, name: name) == expected)
    }

    @Test("the spoken pill in kg for a small delta")
    func pillSpokenSmallKg() {
        #expect(ExerciseToolsText.pillSpoken(deltaLb: 5, unit: .kg, name: "Goblet Squat") == "Up 2.3 kg from your last Goblet Squat")
    }

    @Test("candidate weights of AC-6 and the grid ends in kg", arguments: [
        (60.0, "27.2 kg"), (32.5, "14.7 kg"), (27.5, "12.5 kg"), (70.0, "31.8 kg"), (150.0, "68 kg"), (5.0, "2.3 kg"),
    ])
    func candidateWeightKg(lb: Double, expected: String) {
        #expect(ExerciseToolsText.candidateWeight(lb: lb, unit: .kg) == expected)
    }

    @Test("the empty state names the other muscle groups", arguments: [
        (MuscleGroup.chest, "Every Chest exercise is already in this workout."),
        (.arms, "Every Arms exercise is already in this workout."),
        (.legs, "Every Legs exercise is already in this workout."),
    ])
    func emptySwapOtherMuscles(muscle: MuscleGroup, expected: String) {
        #expect(ExerciseToolsText.emptySwap(muscle: muscle) == expected)
    }

    @Test("a long name in the title, and a candidate label whose equipment holds a plus sign, in kg")
    func longNames() {
        #expect(ExerciseToolsText.swapTitle(name: "Dumbbell Romanian Deadlift") == "Swap Dumbbell Romanian Deadlift")
        #expect(ExerciseToolsText.candidateAccessibilityLabel(name: "Bulgarian Split Squat", equipment: "Dumbbells + bench", lb: 32.5, unit: .kg)
                == "Bulgarian Split Squat, Dumbbells + bench, 14.7 kg")
    }
}

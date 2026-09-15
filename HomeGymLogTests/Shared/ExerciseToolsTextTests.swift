import Foundation
import Testing
@testable import HomeGymLog

/// AC-23: every exercise-tools string, typed from the spec (2.1–2.4, 4.3, AC-16).
@MainActor
@Suite struct ExerciseToolsTextTests {
    @Test("pill text in lb and kg, kg converting the pound difference", arguments: [
        (10.0, WeightUnit.lb, "Lat Pulldown", "+10 lb from your last Lat Pulldown"),
        (2.5, WeightUnit.lb, "Dumbbell Romanian Deadlift", "+2.5 lb from your last Dumbbell Romanian Deadlift"),
        (10.0, WeightUnit.kg, "Lat Pulldown", "+4.5 kg from your last Lat Pulldown"),
        (2.5, WeightUnit.kg, "Dumbbell Curl", "+1.1 kg from your last Dumbbell Curl"),
        (20.0, WeightUnit.kg, "Lat Pulldown", "+9.1 kg from your last Lat Pulldown"),
    ])
    func pill(deltaLb: Double, unit: WeightUnit, name: String, expected: String) {
        #expect(ExerciseToolsText.pill(deltaLb: deltaLb, unit: unit, name: name) == expected)
    }

    @Test("the pill's spoken form")
    func pillSpoken() {
        #expect(ExerciseToolsText.pillSpoken(deltaLb: 10, unit: .lb, name: "Lat Pulldown") == "Up 10 lb from your last Lat Pulldown")
        #expect(ExerciseToolsText.pillSpoken(deltaLb: 2.5, unit: .kg, name: "Dumbbell Curl") == "Up 1.1 kg from your last Dumbbell Curl")
    }

    @Test("swap sheet title, subtitle and empty state")
    func swapSheet() {
        #expect(ExerciseToolsText.swapTitle(name: "Lat Pulldown") == "Swap Lat Pulldown")
        #expect(ExerciseToolsText.swapSubtitle == "Same muscle group, your equipment.")
        #expect(ExerciseToolsText.emptySwap(muscle: .back) == "Every Back exercise is already in this workout.")
        #expect(ExerciseToolsText.emptySwap(muscle: .shoulders) == "Every Shoulders exercise is already in this workout.")
    }

    @Test("bar label: \"Notes ·\" with a trailing U+00B7 or \"Add note\"; accessibility label without the dot")
    func noteLabels() {
        #expect(ExerciseToolsText.noteLabel(hasNote: false) == "Add note")
        let label = ExerciseToolsText.noteLabel(hasNote: true)
        #expect(label.unicodeScalars.map(\.value) == Array("Notes ".unicodeScalars.map(\.value)) + [0x00B7])
        #expect(ExerciseToolsText.noteAccessibilityLabel(hasNote: true) == "Notes")
        #expect(ExerciseToolsText.noteAccessibilityLabel(hasNote: false) == "Add note")
    }

    @Test("hint, name hint, notes title, placeholder and arrow")
    func constants() {
        #expect(ExerciseToolsText.noteAccessibilityHint == "Edit your note")
        #expect(ExerciseToolsText.nameHint == "Shows form cues and notes")
        #expect(ExerciseToolsText.notesTitle == "Notes")
        #expect(ExerciseToolsText.notePlaceholder == "e.g. bench at incline notch 2, grip slightly wider")
        #expect(ExerciseToolsText.pillArrow == "↑")
    }

    @Test("candidate weights", arguments: [
        (52.5, WeightUnit.lb, "52.5 lb"), (52.5, WeightUnit.kg, "23.8 kg"), (80.0, WeightUnit.lb, "80 lb"), (80.0, WeightUnit.kg, "36.3 kg"),
    ])
    func candidateWeight(lb: Double, unit: WeightUnit, expected: String) {
        #expect(ExerciseToolsText.candidateWeight(lb: lb, unit: unit) == expected)
    }

    @Test("a candidate row's accessibility label")
    func candidateAccessibilityLabel() {
        #expect(ExerciseToolsText.candidateAccessibilityLabel(name: "Goblet Squat", equipment: "Dumbbell", lb: 52.5, unit: .lb)
                == "Goblet Squat, Dumbbell, 52.5 lb")
        #expect(ExerciseToolsText.candidateAccessibilityLabel(name: "Leg Extension", equipment: "Marcy · leg developer", lb: 80, unit: .kg)
                == "Leg Extension, Marcy · leg developer, 36.3 kg")
    }
}

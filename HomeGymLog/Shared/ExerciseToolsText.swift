import Foundation

/// Strings for the exercise tools: the progression pill, the detail sheet's notes, the bar's note button and the swap
/// sheet. `ProgressionPill` and `SwapCandidates` return numbers; this turns them into text (the Engine stays text-free).
enum ExerciseToolsText {
    static let swapSubtitle = "Same muscle group, your equipment."
    static let notesTitle = "Notes"
    static let notePlaceholder = "e.g. bench at incline notch 2, grip slightly wider"
    /// The bar button's hint when a note exists.
    static let noteAccessibilityHint = "Edit your note"
    /// The exercise name button's hint.
    static let nameHint = "Shows form cues and notes"
    /// Drawn beside the pill text, not part of it.
    static let pillArrow = "↑"

    /// "+10 lb from your last Lat Pulldown"; kg converts the pound difference ("+4.5 kg").
    static func pill(deltaLb: Double, unit: WeightUnit, name: String) -> String {
        "+\(weight(lb: deltaLb, unit: unit)) from your last \(name)"
    }

    /// The pill's VoiceOver label: "Up 10 lb from your last Lat Pulldown".
    static func pillSpoken(deltaLb: Double, unit: WeightUnit, name: String) -> String {
        "Up \(weight(lb: deltaLb, unit: unit)) from your last \(name)"
    }

    /// "Swap Lat Pulldown"
    static func swapTitle(name: String) -> String {
        "Swap \(name)"
    }

    /// The swap sheet's empty state: "Every Back exercise is already in this workout."
    static func emptySwap(muscle: MuscleGroup) -> String {
        "Every \(muscle.rawValue) exercise is already in this workout."
    }

    /// The bar button's visible text: "Notes ·" (trailing U+00B7 middle dot, verbatim from the prototype) or "Add note".
    static func noteLabel(hasNote: Bool) -> String {
        hasNote ? "Notes \u{00B7}" : "Add note"
    }

    /// The bar button's accessibility label: the visible text without the decorative dot, so Voice Control's "Tap Notes"
    /// matches.
    static func noteAccessibilityLabel(hasNote: Bool) -> String {
        hasNote ? "Notes" : "Add note"
    }

    /// A candidate row's weight: "52.5 lb" / "23.8 kg".
    static func candidateWeight(lb: Double, unit: WeightUnit) -> String {
        weight(lb: lb, unit: unit)
    }

    /// A candidate row read as one button: "Goblet Squat, Dumbbell, 52.5 lb".
    static func candidateAccessibilityLabel(name: String, equipment: String, lb: Double, unit: WeightUnit) -> String {
        "\(name), \(equipment), \(candidateWeight(lb: lb, unit: unit))"
    }

    private static func weight(lb: Double, unit: WeightUnit) -> String {
        "\(WeightDisplay.text(lb: lb, unit: unit)) \(unit.rawValue)"
    }
}

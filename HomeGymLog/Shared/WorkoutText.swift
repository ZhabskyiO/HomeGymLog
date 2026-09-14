import Foundation

/// Strings for the workout and summary screens. The Engine returns numbers and states; this turns them into text.
enum WorkoutText {
    static let swipeHint = "Swipe right to log · swipe left to adjust"
    static let rpeTitle = "How hard was that set?"
    static let kicker = "SESSION COMPLETE"
    static let noRecords = "No new records today."
    static let discardTitle = "Discard workout?"
    static let discardMessage = "Logged sets will be deleted."

    /// "mm:ss" with minutes uncapped: 754 → "12:34", 4 503 → "75:03". Negative → "00:00".
    static func clock(seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    /// An integer with "," every three digits (12 270 → "12,270"). Manual, so the text never depends on the locale.
    static func grouped(_ value: Int) -> String {
        let digits = String(value.magnitude)
        var result = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append(",") }
            result.append(digit)
        }
        return value < 0 ? "-" + result : result
    }

    /// Summary volume tile: the whole number in the display unit, grouped ("12,270" lb, "5,566" kg).
    static func volume(lb: Double, unit: WeightUnit) -> String {
        grouped(WeightDisplay.whole(lb: lb, unit: unit))
    }

    /// "lb total volume" / "kg total volume"
    static func volumeCaption(unit: WeightUnit) -> String {
        "\(unit.rawValue) total volume"
    }

    /// Adjust sheet weight tile caption: "Weight · lb" / "Weight · kg".
    static func weightCaption(unit: WeightUnit) -> String {
        "Weight · \(unit.rawValue)"
    }

    /// The library name, or the key itself for an unknown key.
    static func exerciseName(key: String) -> String {
        ExerciseLibrary.exercise(for: key)?.name ?? key
    }

    /// "Exercise 1 of 5 · Back"; no muscle suffix for an unknown key.
    static func exerciseLine(number: Int, count: Int, key: String) -> String {
        let base = "Exercise \(number) of \(count)"
        guard let exercise = ExerciseLibrary.exercise(for: key) else { return base }
        return "\(base) · \(exercise.muscle.rawValue)"
    }

    /// "Marcy · high pulley"; "" for an unknown key.
    static func equipment(key: String) -> String {
        ExerciseLibrary.exercise(for: key)?.equipment ?? ""
    }

    /// Summary meta: "Tue, Sep 15 · Week 3 · Foundation" — the day the workout started, plus the stored week and phase.
    static func meta(startedAt: Date, info: WorkoutSessionInfo, calendar: Calendar) -> String {
        "\(HomeText.dayLabel(startedAt, calendar: calendar)) · Week \(info.week) · \(info.phase.rawValue)"
    }

    /// A set row's right-hand label.
    static func rowLabel(_ kind: SetRowKind) -> String {
        switch kind {
        case .done(let rpe):
            if let rpe { return "RPE \(rpe)" }
            return "logged"
        case .skipped: return "skipped"
        case .active: return "← →"
        case .waiting: return ""
        }
    }

    /// The word under an RPE button; "" outside 6…10.
    static func rpeLabel(_ rpe: Int) -> String {
        switch rpe {
        case 6: return "easy"
        case 7: return "solid"
        case 8: return "hard"
        case 9: return "grind"
        case 10: return "max"
        default: return ""
        }
    }

    /// A record row's previous best: "100 lb", or "—" when there was none.
    static func recordPrevious(_ lb: Double?, unit: WeightUnit) -> String {
        guard let lb else { return "—" }
        return recordNew(lb, unit: unit)
    }

    /// A record row's new best: "120 lb" / "54.4 kg".
    static func recordNew(_ lb: Double, unit: WeightUnit) -> String {
        "\(WeightDisplay.text(lb: lb, unit: unit)) \(unit.rawValue)"
    }

    /// VoiceOver label of the active set row: "Set 1, 110 lb × 12 reps".
    static func setAccessibilityLabel(number: Int, weightLb: Double, reps: Int, unit: WeightUnit) -> String {
        "Set \(number), \(WeightDisplay.text(lb: weightLb, unit: unit)) \(unit.rawValue) × \(reps) reps"
    }
}

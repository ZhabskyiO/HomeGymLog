import Foundation

/// Strings for the Progress tab (spec 4.3, 5.7). Engine returns pounds and states; this turns them into text in the
/// display unit. Every spoken string is one of these, verbatim.
enum ProgressText {
    static let title = "Progress"
    static let best = "Best"
    static let sinceStart = "Since start"
    /// Em dash (U+2014): no value.
    static let none = "\u{2014}"
    static let empty = "No sessions logged yet \u{2014} your first workout starts the line."

    /// The library name of a key; the raw key when the library does not know it.
    static func chipLabel(key: String) -> String {
        ExerciseLibrary.exercise(for: key)?.name ?? key
    }

    /// Number only: "42.5", or "19.3" in kg.
    static func weight(lb: Double, unit: WeightUnit) -> String {
        WeightDisplay.text(lb: lb, unit: unit)
    }

    /// "+5 lb", "0 lb", "−2.5 lb" (U+2212). The difference is converted as a difference, so 5 lb reads "+2.3 kg".
    static func delta(lb: Double, unit: WeightUnit) -> String {
        let sign = lb > 0 ? "+" : (lb < 0 ? "\u{2212}" : "")
        return "\(sign)\(WeightDisplay.text(lb: abs(lb), unit: unit)) \(unit.rawValue)"
    }

    /// Since-start colour: success when up, warning when down, muted for no change or no value.
    static func deltaTone(lb: Double?) -> StatusTone {
        guard let lb else { return .muted }
        if lb > 0 { return .success }
        return lb < 0 ? .warning : .muted
    }

    /// "September 2026"
    static func monthTitle(year: Int, month: Int, calendar: Calendar) -> String {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return "" }
        let style = Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
        return date.formatted(style.month(.wide).year())
    }

    /// "9 completed"
    static func completed(n: Int) -> String {
        "\(n) completed"
    }

    /// A calendar cell's spoken value (the Program card's words, plus "Scheduled"); nil for a day with no session.
    static func cellValue(state: WeekStripState) -> String? {
        switch state {
        case .completed: return "Completed"
        case .today: return "Today"
        case .missed: return "Missed"
        case .skipped: return "Skipped"
        case .scheduled: return "Scheduled"
        case .rest: return nil
        }
    }

    /// The chart container's label: "Dumbbell Bench Press, 3 sessions, 37.5 to 42.5 lb" (lowest to highest top).
    static func chartSummary(name: String, count: Int, minLb: Double, maxLb: Double, unit: WeightUnit) -> String {
        let sessions = count == 1 ? "1 session" : "\(count) sessions"
        return "\(name), \(sessions), \(weight(lb: minLb, unit: unit)) to \(weight(lb: maxLb, unit: unit)) \(unit.rawValue)"
    }

    /// The chart container's label with no points: "Dumbbell Bench Press, no sessions logged".
    static func chartEmptySummary(name: String) -> String {
        "\(name), no sessions logged"
    }

    /// A dot's label and the from/to captions: "Aug 31".
    static func pointLabel(date: Date, calendar: Calendar) -> String {
        HomeText.shortDate(date, calendar: calendar)
    }

    /// A dot's value: "37.5 lb".
    static func pointValue(lb: Double, unit: WeightUnit) -> String {
        "\(weight(lb: lb, unit: unit)) \(unit.rawValue)"
    }
}

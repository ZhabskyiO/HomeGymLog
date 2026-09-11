import Foundation

/// Strings for the program summary step. Kept out of Engine so Engine stays formatting-free.
enum ProgramSummaryText {
    /// "6-month program"
    static func title(months: Int) -> String {
        "\(months)-month program"
    }

    /// "Week 24" or "Weeks 1–9"
    static func weekRange(_ range: PhaseRange) -> String {
        range.firstWeek == range.lastWeek ? "Week \(range.firstWeek)" : "Weeks \(range.firstWeek)–\(range.lastWeek)"
    }

    /// "3 × 12"
    static func scheme(_ phase: Phase) -> String {
        "\(phase.sets) × \(phase.reps)"
    }

    /// "Push · Mon, Aug 31", using the calendar's time zone and locale so seeded and real dates read alike.
    static func firstSession(_ summary: ProgramSummary, calendar: Calendar) -> String {
        let style = Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).month(.abbreviated).day()
        return "\(summary.firstSessionName) · \(summary.firstSessionDate.formatted(style))"
    }
}

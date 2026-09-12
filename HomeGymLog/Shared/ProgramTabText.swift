import SwiftUI

/// The three color roles a session status can take. An enum rather than a `Color` so status colouring is
/// testable by equality (SwiftUI `Color`s from asset sets do not compare usefully).
enum StatusTone: Equatable {
    case success, muted, warning

    var color: Color {
        switch self {
        case .success: return Theme.success
        case .muted: return Theme.mu
        case .warning: return Theme.warning
        }
    }
}

/// Strings for the Program tab. Engine returns values; this turns them into text.
enum ProgramTabText {
    /// Verbatim prototype copy for a day with no session.
    static let restDay = "Rest day. Light walk, stretch, eat."
    /// The small caption above every week number.
    static let weekChipCaption = "WK"

    /// "6-month program · Push / Pull / Legs + Upper / Lower"
    static func subtitle(months: Int, splitName: String) -> String {
        "\(ProgramSummaryText.title(months: months)) · \(splitName)"
    }

    /// The phase line's scheme: "3 × 12", and for Deload "2 × 12 · −30% load" (U+2212 minus, as the prototype).
    static func phaseScheme(_ phase: Phase) -> String {
        let scheme = ProgramSummaryText.scheme(phase)
        return phase == .deload ? "\(scheme) · \u{2212}30% load" : scheme
    }

    /// The compact per-row scheme: "3×12" (no spaces, unlike the phase line).
    static func rowScheme(sets: Int, reps: Int) -> String {
        "\(sets)×\(reps)"
    }

    /// The card's status text. A future session shows its date ("Sep 16"); `.rest` has no card.
    static func status(_ state: WeekStripState, date: Date, calendar: Calendar) -> String {
        switch state {
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        case .today: return "Today"
        case .missed: return "Missed"
        case .scheduled: return HomeText.shortDate(date, calendar: calendar)
        case .rest: return ""
        }
    }

    static func tone(for state: WeekStripState) -> StatusTone {
        switch state {
        case .completed: return .success
        case .missed: return .warning
        case .skipped, .today, .scheduled, .rest: return .muted
        }
    }
}

import Foundation

/// Strings for the Home tab. Engine returns values; this turns them into text.
enum HomeText {
    private static func style(_ calendar: Calendar) -> Date.FormatStyle {
        Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
    }

    /// "Tue, Sep 15"
    static func dayLabel(_ date: Date, calendar: Calendar) -> String {
        date.formatted(style(calendar).weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "Sep 14"
    static func shortDate(_ date: Date, calendar: Calendar) -> String {
        date.formatted(style(calendar).month(.abbreviated).day())
    }

    static func greeting(_ greeting: Greeting) -> String {
        switch greeting {
        case .morning: return "Good morning"
        case .afternoon: return "Good afternoon"
        case .evening: return "Good evening"
        }
    }

    /// Single letters Monday first. `veryShortWeekdaySymbols` is Sunday-first, hence the shift.
    static func weekStripLetters(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { symbols[($0 + 1) % 7] }
    }

    /// "Week 3 · Foundation"
    static func weekPill(_ week: CurrentWeek) -> String {
        "Week \(week.week) · \(week.phase.rawValue)"
    }

    /// "5 exercises · 3 × 12" plus " · ~45 min" when minutes are given.
    static func sessionMeta(exercises: Int, sets: Int, reps: Int, minutes: Int?) -> String {
        var text = "\(exercises) exercises · \(sets) × \(reps)"
        if let minutes { text += " · ~\(minutes) min" }
        return text
    }
}

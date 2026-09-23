import Foundation

/// Strings for the missed-session prompt and the Program card's shift and skip buttons (spec 4.3). The spoken labels are
/// these exact strings on both surfaces, with no hints. Engine picks the day style; this turns it into text.
enum MissedDayText {
    static let kicker = "MISSED SESSION"
    static let body = "Do it today and push the rest of the week back a day, or skip it and stay on schedule."
    static let shift = "Do it today · shift program"
    static let skip = "Skip it · stay on schedule"

    /// "You skipped Legs on Wed" within six days, else "You skipped Legs on Wed, Sep 9" (spec 5.2).
    static func title(name: String, scheduledDate: Date, today: Date, calendar: Calendar) -> String {
        let dayText: String
        switch MissedDay.dayLabelStyle(scheduledDate: scheduledDate, today: today, calendar: calendar) {
        case .weekday:
            let style = Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
            dayText = scheduledDate.formatted(style.weekday(.abbreviated))
        case .fullDate:
            dayText = HomeText.dayLabel(scheduledDate, calendar: calendar)
        }
        return "You skipped \(name) on \(dayText)"
    }

    /// The banner after an automatic shift (m4-settings spec 2.7): "Shifted Legs to today" when the session landed on today,
    /// else "Shifted Legs to Mon, Sep 21". The Engine picks the style (`MissedDay.bannerDayStyle`); this writes the words.
    static func shiftedBanner(name: String, style: BannerDayStyle, newDate: Date, calendar: Calendar) -> String {
        switch style {
        case .today: return "Shifted \(name) to today"
        case .date: return "Shifted \(name) to \(HomeText.dayLabel(newDate, calendar: calendar))"
        }
    }

    /// The banner after an automatic skip pass (m4-settings spec 2.7), over the sessions the pass actually skipped:
    /// "Skipped Legs" for one, "Skipped 3 missed sessions" for several, and nil for none (no banner at all).
    static func skippedBanner(names: [String]) -> String? {
        if names.isEmpty { return nil }
        if names.count == 1 { return "Skipped \(names[0])" }
        return "Skipped \(names.count) missed sessions"
    }
}

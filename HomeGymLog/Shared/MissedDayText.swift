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
}

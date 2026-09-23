import Foundation

/// Every new string the daily reminder shows or speaks (spec 4.3): the Settings rows and the notification itself.
/// `SettingsText.reminder` ("Daily reminder") stays in `SettingsText`. Nothing here reads a model or the clock: the
/// calendar and locale come in as arguments.
enum ReminderText {
    static let off = "Off"
    static let deniedSubtitle = "Notifications are off in iOS Settings"
    static let unaskedSubtitle = "Notifications not allowed yet"
    static let timeLabel = "Reminder time"
    static let openSettings = "Open iOS Settings"
    static let allow = "Allow notifications"
    static let notificationTitle = "Training day"
    static let notificationBody = "Your workout is planned for today."

    /// "7:00 AM on training days" (prototype 704), the time in the locale's short style. Formatted on a fixed modern day
    /// (2001-01-01) in `calendar` and its zone, so the text never depends on the process zone (NB2). Invalid minutes read
    /// as 07:00.
    static func subtitle(minutes: Int, calendar: Calendar, locale: Locale) -> String {
        let minutes = ReminderPlan.validMinutes(minutes) ?? ReminderPlan.defaultMinutes
        let reference = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1,
                                                           hour: minutes / 60, minute: minutes % 60)) ?? .distantPast
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar,
                                     timeZone: calendar.timeZone)
        return "\(reference.formatted(style)) on training days"
    }

    /// The toggle's second line for each row state (spec 2.1).
    static func rowSubtitle(state: ReminderRowState, minutes: Int, calendar: Calendar, locale: Locale) -> String {
        switch state {
        case .off: return off
        case .scheduled: return subtitle(minutes: minutes, calendar: calendar, locale: locale)
        case .denied: return deniedSubtitle
        case .unasked: return unaskedSubtitle
        }
    }
}

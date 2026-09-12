import Foundation

/// Date helpers shared by the generator and the re-slot primitive. Every function takes the
/// calendar explicitly so tests can pin a time zone; nothing here reads `Calendar.current` or `Date()`.
/// Weekday convention everywhere in the app: 0 = Monday … 6 = Sunday.
nonisolated enum CalendarRules {
    /// App weekday (0 = Monday) of `date`. `Calendar.weekday` is 1 = Sunday, hence the shift.
    static func appWeekday(of date: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// Midnight at the start of `date`'s calendar day.
    static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Start of the day `days` after `date`'s day. Uses calendar arithmetic, never 86 400 × n,
    /// so daylight-saving transitions cannot move a session.
    static func day(_ date: Date, adding days: Int, calendar: Calendar) -> Date {
        let base = startOfDay(date, calendar: calendar)
        guard let result = calendar.date(byAdding: .day, value: days, to: base) else {
            preconditionFailure("calendar could not add \(days) days to \(base)")
        }
        return startOfDay(result, calendar: calendar)
    }

    /// Start of the Monday of the week containing `date`, regardless of the calendar's first weekday.
    static func monday(ofWeekContaining date: Date, calendar: Calendar) -> Date {
        day(date, adding: -appWeekday(of: date, calendar: calendar), calendar: calendar)
    }

    /// Start of the first training day on or after `date`'s day.
    static func firstTrainingDay(onOrAfter date: Date, trainingWeekdays: [Int], calendar: Calendar) -> Date {
        precondition(!trainingWeekdays.isEmpty, "trainingWeekdays must not be empty")
        var candidate = startOfDay(date, calendar: calendar)
        for _ in 0..<7 {
            if trainingWeekdays.contains(appWeekday(of: candidate, calendar: calendar)) { return candidate }
            candidate = day(candidate, adding: 1, calendar: calendar)
        }
        preconditionFailure("no training weekday within a week of \(date)")
    }

    /// Start of the first training day strictly after `date`'s day.
    static func nextTrainingDay(strictlyAfter date: Date, trainingWeekdays: [Int], calendar: Calendar) -> Date {
        firstTrainingDay(onOrAfter: day(date, adding: 1, calendar: calendar), trainingWeekdays: trainingWeekdays, calendar: calendar)
    }

    /// True when both dates fall on the same calendar day.
    static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Whole calendar days from `start`'s day to `end`'s day; negative when `end` precedes `start`.
    /// Counted with `dateComponents`, never `/ 86 400`: a daylight-saving day is 23 or 25 hours long and
    /// dividing by a fixed day length loses (or invents) a day across the transition.
    static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let from = startOfDay(start, calendar: calendar)
        let to = startOfDay(end, calendar: calendar)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

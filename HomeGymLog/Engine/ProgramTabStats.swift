import Foundation

/// One week chip: a calendar window, 1-based. `phase` is the recorded phase of the window's highest-index
/// session, or nil when the window holds no session (the view then draws no bar).
nonisolated struct WeekChip: Equatable, Sendable {
    let week: Int
    let phase: Phase?
}

/// One day button: its date (local midnight), the day of the month shown on it, and the session that falls
/// on it, if any.
nonisolated struct ProgramDayCell: Equatable, Sendable {
    let date: Date
    let dayNumber: Int
    let session: SessionSummary?
}

/// A resolved selection: week 1…weekCount, day 0 = Monday … 6 = Sunday.
nonisolated struct ProgramFocus: Equatable, Sendable {
    let week: Int
    let day: Int
}

/// What the Program tab is showing, as one value (the prototype's `selWeek` / `selDay` pair).
/// Analogy: a single reducer state instead of two `useState`s that can disagree.
nonisolated enum ProgramSelection: Equatable, Sendable {
    /// No tap and no DEBUG preselection: the week containing today, and that week's default day.
    case followToday
    /// A chip was tapped, or a debug week argument was given: the week's default day is used.
    case week(Int)
    /// A day was tapped, or a debug day argument was given.
    case day(week: Int, day: Int)

    /// Spec 4.1. Values are taken raw — validity is applied once, in `ProgramTabStats.focus`:
    /// (w, d) → `.day`, (w, nil) → `.week`, (nil, d) → `.day(initialWeek, d)` when a week exists,
    /// nothing → `.followToday`.
    static func from(preselectedWeek: Int?, preselectedDay: Int?, initialWeek: Int?) -> ProgramSelection {
        switch (preselectedWeek, preselectedDay) {
        case let (week?, day?): return .day(week: week, day: day)
        case let (week?, nil): return .week(week)
        case let (nil, day?):
            guard let initialWeek else { return .followToday }
            return .day(week: initialWeek, day: day)
        case (nil, nil): return .followToday
        }
    }
}

/// The Program tab's selectors over plain session values. Calendar windows Monday–Sunday, anchored on the
/// Monday of the earliest session's week, so a re-slotted program shows the week a session actually falls in.
/// Nothing here throws or traps: an empty program yields nil / 0 / empty, and an out-of-range week yields
/// dated cells with no sessions.
nonisolated enum ProgramTabStats {
    /// Monday of the week containing the earliest `scheduledDate`; nil for no sessions.
    static func weekAnchor(sessions: [SessionSummary], calendar: Calendar) -> Date? {
        guard let earliest = sessions.map(\.scheduledDate).min() else { return nil }
        return CalendarRules.monday(ofWeekContaining: earliest, calendar: calendar)
    }

    /// Windows spanned by the schedule: days(anchor → latest session) / 7 + 1. 0 for no sessions.
    static func weekCount(sessions: [SessionSummary], calendar: Calendar) -> Int {
        guard let anchor = weekAnchor(sessions: sessions, calendar: calendar),
              let latest = sessions.map(\.scheduledDate).max() else { return 0 }
        return CalendarRules.days(from: anchor, to: latest, calendar: calendar) / 7 + 1
    }

    /// 1-based window containing `date`; 0 for any day before the anchor. Swift's `/` truncates toward zero
    /// (like JS `Math.trunc`, not `Math.floor`), so a plain `days / 7 + 1` would put the six days before the
    /// anchor into window 1.
    private static func window(of date: Date, anchor: Date, calendar: Calendar) -> Int {
        let days = CalendarRules.days(from: anchor, to: date, calendar: calendar)
        guard days >= 0 else { return 0 }
        return days / 7 + 1
    }

    /// One chip per window, in order. Phase = the recorded phase of the highest-index session in the window
    /// (in a spilled window the later program week holds the majority); nil when the window is empty.
    static func weekChips(sessions: [SessionSummary], calendar: Calendar) -> [WeekChip] {
        guard let anchor = weekAnchor(sessions: sessions, calendar: calendar) else { return [] }
        var latestByWindow: [Int: SessionSummary] = [:]
        for session in sessions {
            let week = window(of: session.scheduledDate, anchor: anchor, calendar: calendar)
            if let current = latestByWindow[week], current.index >= session.index { continue }
            latestByWindow[week] = session
        }
        return (1...max(1, weekCount(sessions: sessions, calendar: calendar))).map { week in
            WeekChip(week: week, phase: latestByWindow[week]?.phase)
        }
    }

    /// The window containing today, bounded to 1…weekCount (the prototype's `curWeek`). nil for no sessions.
    /// Deliberately not `HomeStats.currentWeek`, which follows the next pending session's stored week.
    static func initialWeek(sessions: [SessionSummary], today: Date, calendar: Calendar) -> Int? {
        guard let anchor = weekAnchor(sessions: sessions, calendar: calendar) else { return nil }
        let count = weekCount(sessions: sessions, calendar: calendar)
        return min(max(window(of: today, anchor: anchor, calendar: calendar), 1), count)
    }

    /// Today's weekday when today lies in this window; else the weekday of the window's earliest session;
    /// else Monday.
    static func defaultDay(sessions: [SessionSummary], week: Int, today: Date, calendar: Calendar) -> Int {
        guard let anchor = weekAnchor(sessions: sessions, calendar: calendar) else { return 0 }
        if window(of: today, anchor: anchor, calendar: calendar) == week {
            return CalendarRules.appWeekday(of: today, calendar: calendar)
        }
        let inWindow = sessions.filter { window(of: $0.scheduledDate, anchor: anchor, calendar: calendar) == week }
        guard let earliest = HomeStats.ordered(inWindow).first else { return 0 }   // (scheduledDate, index) order
        return CalendarRules.appWeekday(of: earliest.scheduledDate, calendar: calendar)
    }

    /// Seven cells, Monday first, for any week number (out of range gives dated cells with no sessions).
    /// A day holding two sessions follows `HomeStats.session(on:in:calendar:)`: completed wins, else lowest index.
    /// Empty only for no sessions.
    static func dayCells(sessions: [SessionSummary], week: Int, calendar: Calendar) -> [ProgramDayCell] {
        guard let anchor = weekAnchor(sessions: sessions, calendar: calendar) else { return [] }
        let start = CalendarRules.day(anchor, adding: 7 * (week - 1), calendar: calendar)
        return (0..<7).map { offset in
            let date = CalendarRules.day(start, adding: offset, calendar: calendar)
            let session = HomeStats.session(on: date, in: sessions, calendar: calendar)
            return ProgramDayCell(date: date, dayNumber: calendar.component(.day, from: date), session: session)
        }
    }

    /// The one validity rule (spec §3): a week outside 1…weekCount or a day outside 0…6 — tapped, stale,
    /// or from a DEBUG argument — behaves as `.followToday`. Nothing is clamped. nil only for no sessions.
    static func focus(selection: ProgramSelection, sessions: [SessionSummary], today: Date, calendar: Calendar) -> ProgramFocus? {
        guard let initial = initialWeek(sessions: sessions, today: today, calendar: calendar) else { return nil }
        let count = weekCount(sessions: sessions, calendar: calendar)
        let followToday = ProgramFocus(week: initial, day: defaultDay(sessions: sessions, week: initial, today: today, calendar: calendar))
        switch selection {
        case .followToday:
            return followToday
        case .week(let week):
            guard (1...count).contains(week) else { return followToday }
            return ProgramFocus(week: week, day: defaultDay(sessions: sessions, week: week, today: today, calendar: calendar))
        case .day(let week, let day):
            guard (1...count).contains(week), (0...6).contains(day) else { return followToday }
            return ProgramFocus(week: week, day: day)
        }
    }
}

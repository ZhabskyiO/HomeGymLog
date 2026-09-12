import Foundation

/// Home tab statistics over plain values; `ordered` and `sessionState` are also the Program tab's. Every
/// function takes `today` and `calendar` explicitly and returns no text. Empty input yields zeros, nil, or
/// empty collections.
nonisolated enum HomeStats {
    /// 5–11 morning, 12–16 afternoon, otherwise evening.
    static func greeting(hour: Int) -> Greeting {
        switch hour {
        case 5...11: return .morning
        case 12...16: return .afternoon
        default: return .evening
        }
    }

    /// Sessions in (scheduledDate, index) order.
    static func ordered(_ sessions: [SessionSummary]) -> [SessionSummary] {
        sessions.sorted { ($0.scheduledDate, $0.index) < ($1.scheduledDate, $1.index) }
    }

    private static func isToday(_ session: SessionSummary, _ today: Date, _ calendar: Calendar) -> Bool {
        CalendarRules.isSameDay(session.scheduledDate, today, calendar: calendar)
    }

    private static func isBeforeToday(_ session: SessionSummary, _ today: Date, _ calendar: Calendar) -> Bool {
        CalendarRules.startOfDay(session.scheduledDate, calendar: calendar) < CalendarRules.startOfDay(today, calendar: calendar)
    }

    private static func isAfterToday(_ session: SessionSummary, _ today: Date, _ calendar: Calendar) -> Bool {
        CalendarRules.startOfDay(session.scheduledDate, calendar: calendar) > CalendarRules.startOfDay(today, calendar: calendar)
    }

    /// Week and phase of a session dated today (any status); else of the earliest pending session after
    /// today; else of the last session by index. nil only for no sessions.
    static func currentWeek(sessions: [SessionSummary], today: Date, calendar: Calendar) -> CurrentWeek? {
        let sorted = ordered(sessions)
        if let todays = sorted.first(where: { isToday($0, today, calendar) }) {
            return CurrentWeek(week: todays.week, phase: todays.phase)
        }
        if let next = sorted.first(where: { $0.status == .pending && isAfterToday($0, today, calendar) }) {
            return CurrentWeek(week: next.week, phase: next.phase)
        }
        guard let last = sessions.max(by: { $0.index < $1.index }) else { return nil }
        return CurrentWeek(week: last.week, phase: last.phase)
    }

    /// Consecutive completed sessions walking back from today. A pending or skipped session dated today is
    /// stepped over; a pending or skipped session dated before today stops the walk.
    static func streak(sessions: [SessionSummary], today: Date, calendar: Calendar) -> Int {
        let walk = ordered(sessions).reversed().filter { !isAfterToday($0, today, calendar) }
        var count = 0
        for session in walk {
            if session.status == .completed {
                count += 1
            } else if isToday(session, today, calendar) {
                continue
            } else {
                break
            }
        }
        return count
    }

    static func completedCount(sessions: [SessionSummary]) -> Int {
        sessions.filter { $0.status == .completed }.count
    }

    /// Heaviest done set, or nil when no set is done.
    static func topWeightLb(_ exercise: LoggedExerciseValue) -> Double? {
        exercise.sets.filter { $0.status == .done }.map(\.weightLb).max()
    }

    /// Σ weight × reps over done sets.
    static func volumeLb(_ log: FinishedLogValue) -> Double {
        log.exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter { $0.status == .done }.reduce(0) { $0 + $1.weightLb * Double($1.reps) }
        }
    }

    /// Monday of the calendar week containing `today`, and the day after its Sunday.
    private static func weekWindow(today: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let start = CalendarRules.monday(ofWeekContaining: today, calendar: calendar)
        return (start, CalendarRules.day(start, adding: 7, calendar: calendar))
    }

    /// Volume of finished logs whose completed session is scheduled in the calendar week containing `today`.
    static func weekVolumeLb(sessions: [SessionSummary], logs: [FinishedLogValue], today: Date, calendar: Calendar) -> Double {
        let window = weekWindow(today: today, calendar: calendar)
        let inWindow = Set(sessions.filter { session in
            let day = CalendarRules.startOfDay(session.scheduledDate, calendar: calendar)
            return session.status == .completed && day >= window.start && day < window.end
        }.map(\.index))
        return logs.filter { inWindow.contains($0.sessionIndex) }.reduce(0) { $0 + volumeLb($1) }
    }

    /// A session's state relative to `today`. The one derivation shared by the Home week strip and the
    /// Program tab's card status; `.rest` means "no session" and is never returned here.
    static func sessionState(_ session: SessionSummary, today: Date, calendar: Calendar) -> WeekStripState {
        switch session.status {
        case .completed: return .completed
        case .skipped: return .skipped
        case .pending:
            if isToday(session, today, calendar) { return .today }
            return isBeforeToday(session, today, calendar) ? .missed : .scheduled
        }
    }

    /// Seven entries, Monday first, for the calendar week containing `today`.
    static func weekStrip(sessions: [SessionSummary], today: Date, calendar: Calendar) -> [WeekStripDay] {
        let monday = CalendarRules.monday(ofWeekContaining: today, calendar: calendar)
        let sorted = ordered(sessions)
        return (0..<7).map { offset in
            let date = CalendarRules.day(monday, adding: offset, calendar: calendar)
            let isToday = CalendarRules.isSameDay(date, today, calendar: calendar)
            let session = sorted.first { CalendarRules.isSameDay($0.scheduledDate, date, calendar: calendar) }
            let state = session.map { sessionState($0, today: today, calendar: calendar) } ?? .rest
            return WeekStripDay(date: date, isToday: isToday, state: state, dayNumber: calendar.component(.day, from: date))
        }
    }

    /// The pending session dated today, lowest index.
    static func todaySession(sessions: [SessionSummary], today: Date, calendar: Calendar) -> SessionSummary? {
        ordered(sessions).first { $0.status == .pending && isToday($0, today, calendar) }
    }

    /// The earliest pending session strictly after today; if none, the last session by index.
    static func nextSession(sessions: [SessionSummary], today: Date, calendar: Calendar) -> SessionSummary? {
        let sorted = ordered(sessions)
        if let next = sorted.first(where: { $0.status == .pending && isAfterToday($0, today, calendar) }) {
            return next
        }
        return sessions.max { $0.index < $1.index }
    }

    /// One entry per exercise key: its best done weight and the session day it was first reached.
    /// Sorted by date desc, then session index desc, then exercise order asc.
    static func personalRecords(sessions: [SessionSummary], logs: [FinishedLogValue]) -> [PersonalRecord] {
        // Unique keys are guaranteed by HomeStatsInput; keep the first if a caller bypasses it rather than trap.
        let logsByIndex = Dictionary(logs.map { ($0.sessionIndex, $0) }, uniquingKeysWith: { first, _ in first })
        var best: [String: PersonalRecord] = [:]
        for session in ordered(sessions) where session.status == .completed {
            guard let log = logsByIndex[session.index] else { continue }
            for exercise in log.exercises.sorted(by: { $0.order < $1.order }) {
                guard let top = topWeightLb(exercise) else { continue }
                if let current = best[exercise.exerciseKey], current.weightLb >= top { continue }
                best[exercise.exerciseKey] = PersonalRecord(exerciseKey: exercise.exerciseKey, weightLb: top, date: session.scheduledDate,
                                                            sessionIndex: session.index, order: exercise.order)
            }
        }
        return best.values.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            if $0.sessionIndex != $1.sessionIndex { return $0.sessionIndex > $1.sessionIndex }
            return $0.order < $1.order
        }
    }

    /// The four most recent records.
    static func recentRecords(sessions: [SessionSummary], logs: [FinishedLogValue]) -> [PersonalRecord] {
        Array(personalRecords(sessions: sessions, logs: logs).prefix(4))
    }
}

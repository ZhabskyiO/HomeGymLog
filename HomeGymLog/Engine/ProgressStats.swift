import Foundation

/// A planned session as the Progress tab needs it: Home's `SessionSummary` plus the program it belongs to, so
/// sessions of the current and archived programs can sit in one list (spec 4.3, B1).
nonisolated struct ProgressSession: Equatable, Sendable {
    let programID: UUID
    let programCreatedAt: Date
    let isArchived: Bool
    let summary: SessionSummary
}

/// The top done weight of one finished log for one exercise key, dated by its session's `scheduledDate` (D4).
/// In the chart a top's identity is its position after `ProgressStats.points`, never `sessionIndex`: indexes
/// restart per program (B2).
nonisolated struct ProgressTop: Equatable, Sendable {
    let programID: UUID
    let programCreatedAt: Date
    let sessionIndex: Int
    let scheduledDate: Date
    let topWeightLb: Double
}

/// Progress tab numbers over plain values (spec 5.1–5.8). No SwiftUI, SwiftData or text; nothing throws or traps.
/// Analogy: a module of pure selectors the screen runs over its query results.
nonisolated enum ProgressStats {
    /// Chip keys, first-seen (5.1): the current program's sessions by index, each session's exercises in plan order;
    /// then archived programs' completed sessions, newest `programCreatedAt` first, index ascending.
    static func exerciseKeys(sessions: [ProgressSession]) -> [String] {
        let current = sessions.filter { !$0.isArchived }.sorted { $0.summary.index < $1.summary.index }
        let archived = sessions.filter { $0.isArchived && $0.summary.status == .completed }.sorted {
            if $0.programCreatedAt != $1.programCreatedAt { return $0.programCreatedAt > $1.programCreatedAt }
            return $0.summary.index < $1.summary.index
        }
        var seen: Set<String> = []
        var keys: [String] = []
        for session in current + archived {
            for exercise in session.summary.exercises.sorted(by: { $0.order < $1.order }) {
                if seen.insert(exercise.exerciseKey).inserted { keys.append(exercise.exerciseKey) }
            }
        }
        return keys
    }

    /// The top of one finished log for a key: the heaviest done set over the log's rows for that key (a key twice
    /// in one log gives the larger top). nil when no set is done.
    static func logTopLb(_ rows: [LoggedExerciseValue]) -> Double? {
        rows.compactMap { HomeStats.topWeightLb($0) }.max()
    }

    /// Chart order (5.2): `(scheduledDate, programCreatedAt, sessionIndex)` ascending, whatever the input order.
    static func points(tops: [ProgressTop]) -> [ProgressTop] {
        tops.sorted {
            ($0.scheduledDate, $0.programCreatedAt, $0.sessionIndex) < ($1.scheduledDate, $1.programCreatedAt, $1.sessionIndex)
        }
    }

    /// The heaviest top; nil for no points.
    static func bestLb(points: [ProgressTop]) -> Double? {
        points.map(\.topWeightLb).max()
    }

    /// Last point − first point (not best − first); 0 for one point, nil for none.
    static func sinceStartLb(points: [ProgressTop]) -> Double? {
        guard let first = points.first, let last = points.last else { return nil }
        return last.topWeightLb - first.topWeightLb
    }

    /// Empty-history Best (5.4): the planned target of the key in the current program's lowest-index session that
    /// plans it; nil when no current session does.
    static func plannedFallbackLb(key: String, sessions: [ProgressSession]) -> Double? {
        sessions
            .filter { !$0.isArchived }
            .sorted { $0.summary.index < $1.summary.index }
            .lazy
            .compactMap { $0.summary.exercises.first { $0.exerciseKey == key }?.targetWeightLb }
            .first
    }

    /// The chip the screen shows: `selected` when it is listed, else the first key; nil for no keys.
    static func effectiveKey(selected: String?, keys: [String]) -> String? {
        if let selected, keys.contains(selected) { return selected }
        return keys.first
    }

    /// The tops the chart may draw: the held tops only while they were fetched for the effective key (B3), so a
    /// fast chip change never shows the previous exercise's line.
    static func heldTops(heldKey: String?, tops: [ProgressTop], effectiveKey: String?) -> [ProgressTop] {
        guard let heldKey, heldKey == effectiveKey else { return [] }
        return tops
    }
}

/// One calendar cell: a day of the month, its session state (`.rest` when no session falls on it) and whether it is today.
nonisolated struct ProgressDayCell: Equatable, Sendable {
    let date: Date
    let dayNumber: Int
    let state: WeekStripState
    let isToday: Bool
}

/// The month containing today (spec 5.5): Monday-first leading blanks, one cell per day, no trailing blanks.
nonisolated struct ProgressMonth: Equatable, Sendable {
    let year: Int
    let month: Int
    let leadingBlanks: Int
    let cells: [ProgressDayCell]
    let completedCount: Int
}

/// The prototype's SVG geometry as chart scale domains and rule positions, in pounds (spec 5.8). Numbers only.
nonisolated struct ChartGeometry: Equatable, Sendable {
    let xDomain: ClosedRange<Double>
    let yDomain: ClosedRange<Double>
    let baselineLb: Double
    let midLb: Double
    let topLb: Double
}

extension ProgressStats {
    /// Spec 5.5. A cell's session follows `HomeStats.session(on:in:calendar:)` (completed wins, else lowest index), its
    /// state `HomeStats.sessionState`; `.rest` for no session.
    static func month(sessions: [ProgressSession], today: Date, calendar: Calendar) -> ProgressMonth {
        let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? CalendarRules.startOfDay(today, calendar: calendar)
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        let nextMonth = CalendarRules.day(monthStart, adding: dayCount, calendar: calendar)
        // Only this month's sessions are searched per day (≈ filtering once before a per-cell lookup).
        let inMonth = sessions.map(\.summary).filter { session in
            let day = CalendarRules.startOfDay(session.scheduledDate, calendar: calendar)
            return day >= monthStart && day < nextMonth
        }
        let cells = (0..<dayCount).map { offset -> ProgressDayCell in
            let date = CalendarRules.day(monthStart, adding: offset, calendar: calendar)
            let session = HomeStats.session(on: date, in: inMonth, calendar: calendar)
            let state = session.map { HomeStats.sessionState($0, today: today, calendar: calendar) } ?? .rest
            return ProgressDayCell(date: date, dayNumber: calendar.component(.day, from: date), state: state,
                                   isToday: CalendarRules.isSameDay(date, today, calendar: calendar))
        }
        let parts = calendar.dateComponents([.year, .month], from: monthStart)
        return ProgressMonth(year: parts.year ?? 0, month: parts.month ?? 0,
                             leadingBlanks: CalendarRules.appWeekday(of: monthStart, calendar: calendar),
                             cells: cells, completedCount: cells.filter { $0.state == .completed }.count)
    }

    /// Spec 5.8. y: `lo = min − 5`, `hi = max + 5`, domain padded by a tenth of the span each side, rules at lo, mid, hi.
    /// x: plotted by position; `n ≥ 2` pads (n − 1) / 30 each side (10 of 320 pt), `n ≤ 1` is −1…1 (one point centred).
    /// No weights → bounds 0 and 10, so the rules still draw inside the domain.
    static func chartGeometry(weights: [Double]) -> ChartGeometry {
        let n = weights.count
        let lo = (weights.min() ?? 0) - 5
        let hi = (weights.max() ?? 10) + 5
        let ext = (hi - lo) / 10
        let xDomain: ClosedRange<Double>
        if n >= 2 {
            let pad = Double(n - 1) / 30
            xDomain = (-pad)...(Double(n - 1) + pad)
        } else {
            xDomain = -1...1
        }
        return ChartGeometry(xDomain: xDomain, yDomain: (lo - ext)...(hi + ext), baselineLb: lo, midLb: (lo + hi) / 2, topLb: hi)
    }
}

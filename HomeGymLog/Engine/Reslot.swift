import Foundation

/// The three facts about a planned session that re-slotting needs. A plain value, not a model row.
nonisolated struct SessionSlot: Equatable, Sendable {
    var index: Int
    var scheduledDate: Date
    var status: SessionStatus
}

/// Moves pending sessions onto consecutive training days. Serves both the mid-week program start
/// and the missed-day "shift". Reads no store and mutates nothing; the caller applies the map.
nonisolated enum Reslot {
    /// Re-dates the pending session at `fromIndex` and every later pending session.
    ///
    /// - The session at `fromIndex` takes `cursor`'s day when `inclusive` is true (even a rest day),
    ///   otherwise the first training day strictly after `cursor`.
    /// - Each later pending session, in index order, takes the first training day strictly after the
    ///   previously assigned date.
    /// - Completed and skipped sessions never move and do not consume a day. Lower indices never move.
    /// - Returns `index → new date` only for sessions whose day actually changed. If the session at
    ///   `fromIndex` is missing or not pending, returns an empty map.
    static func reslot(slots: [SessionSlot], fromIndex: Int, startingAt cursor: Date, inclusive: Bool,
                       trainingWeekdays: [Int], calendar: Calendar) -> [Int: Date] {
        let ordered = slots.sorted { $0.index < $1.index }
        guard let first = ordered.first(where: { $0.index == fromIndex }), first.status == .pending else {
            return [:]
        }
        var moved: [Int: Date] = [:]
        var next = inclusive
            ? CalendarRules.startOfDay(cursor, calendar: calendar)
            : CalendarRules.nextTrainingDay(strictlyAfter: cursor, trainingWeekdays: trainingWeekdays, calendar: calendar)

        func assign(_ slot: SessionSlot, _ date: Date) {
            if !CalendarRules.isSameDay(slot.scheduledDate, date, calendar: calendar) {
                moved[slot.index] = date
            }
        }

        assign(first, next)
        for slot in ordered where slot.index > fromIndex && slot.status == .pending {
            next = CalendarRules.nextTrainingDay(strictlyAfter: next, trainingWeekdays: trainingWeekdays, calendar: calendar)
            assign(slot, next)
        }
        return moved
    }
}

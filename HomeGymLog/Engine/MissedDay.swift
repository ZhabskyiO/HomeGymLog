import Foundation

/// How the missed-session title names its day (spec 5.2). The Engine picks the style; `MissedDayText` writes the words.
nonisolated enum MissedDayLabel: Equatable, Sendable {
    /// 1–6 days ago: the abbreviated weekday ("Wed"); each weekday name is unique within the trailing six days.
    case weekday
    /// Anything else: "Wed, Sep 9" (a bare "Tue" seven days back would read as today).
    case fullDate
}

/// The missed-day rules over plain values: which session the Home prompt names, whether a dismissal silences it, the
/// shift's date map, and the title's day style. Total over stored rows (INSIGHTS 2026-09-14 B2): nothing throws or traps;
/// nil, false and `[:]` mean "nothing to do". Analogy: selectors plus a reducer that returns the unchanged state for an
/// action that no longer applies, instead of throwing.
nonisolated enum MissedDay {
    /// A dismissed prompt: silenced for this session index on this calendar day while the shell stays mounted. Screen state
    /// only, never stored (≈ a plain object held in `useState`). `day` is local midnight of the day the card was rendered
    /// for. Marked `nonisolated` itself because the app target defaults every type to the main actor, and the plain Engine
    /// test suites build it off the main actor.
    nonisolated struct PromptSilence: Equatable, Sendable {
        let sessionIndex: Int
        let day: Date
    }

    /// Pending and scheduled on a calendar day before `today`. Only for callers that hold no `SessionSummary` (the slot guard
    /// in `shiftMap` and `ProgramStore.skipMissed`); a test pins it equal to `HomeStats.sessionState == .missed`.
    static func isMissed(status: SessionStatus, scheduledDate: Date, today: Date, calendar: Calendar) -> Bool {
        status == .pending
            && CalendarRules.startOfDay(scheduledDate, calendar: calendar) < CalendarRules.startOfDay(today, calendar: calendar)
    }

    /// Spec 5.1: among the sessions whose `HomeStats.sessionState` is `.missed` (the one derivation the Program card also
    /// reads, so the prompt and the card never disagree), the lowest `(scheduledDate, index)`; nil when none.
    static func firstMissed(sessions: [SessionSummary], today: Date, calendar: Calendar) -> SessionSummary? {
        let missed = sessions.filter { HomeStats.sessionState($0, today: today, calendar: calendar) == .missed }
        return HomeStats.ordered(missed).first
    }

    /// Spec 5.1: true for a missed session unless the silence names the same session index and today's calendar day. A
    /// silence from another day or for another session never hides the card.
    static func shouldPrompt(missed: SessionSummary?, silence: PromptSilence?, today: Date, calendar: Calendar) -> Bool {
        guard let missed else { return false }
        return silence != PromptSilence(sessionIndex: missed.index, day: CalendarRules.startOfDay(today, calendar: calendar))
    }

    /// Spec 5.3, total: `[:]` unless the slot at `missedIndex` is missed and some weekday lies in 0…6 (the precondition of
    /// `CalendarRules.firstTrainingDay`, guarded here instead of re-validating a generator-checked field). Otherwise the
    /// missed session takes today when no slot dated today is completed or skipped ("shift never doubles up a day"), else the
    /// first training day after today, and every later pending session takes the next training day in order
    /// (`Reslot.reslot`). "Empty ⇔ not a missed session" holds: a missed session always moves to today or later, so its own
    /// entry is in every non-empty map.
    static func shiftMap(slots: [SessionSlot], missedIndex: Int, trainingWeekdays: [Int], today: Date,
                         calendar: Calendar) -> [Int: Date] {
        guard let missed = slots.first(where: { $0.index == missedIndex }),
              isMissed(status: missed.status, scheduledDate: missed.scheduledDate, today: today, calendar: calendar),
              trainingWeekdays.contains(where: { (0...6).contains($0) }) else {
            return [:]
        }
        let todayHoldsFinished = slots.contains { slot in
            slot.status != .pending && CalendarRules.isSameDay(slot.scheduledDate, today, calendar: calendar)
        }
        return Reslot.reslot(slots: slots, fromIndex: missedIndex, startingAt: CalendarRules.startOfDay(today, calendar: calendar),
                             inclusive: !todayHoldsFinished, trainingWeekdays: trainingWeekdays, calendar: calendar)
    }

    /// Spec 5.2: `.weekday` when the session is 1…6 calendar days before `today`, else `.fullDate` (also for 0 and negative
    /// counts, which a missed session never has).
    static func dayLabelStyle(scheduledDate: Date, today: Date, calendar: Calendar) -> MissedDayLabel {
        let days = CalendarRules.days(from: scheduledDate, to: today, calendar: calendar)
        if (1...6).contains(days) { return .weekday }
        return .fullDate
    }
}

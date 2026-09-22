import Foundation

/// How the missed-session title names its day (spec 5.2). The Engine picks the style; `MissedDayText` writes the words.
nonisolated enum MissedDayLabel: Equatable, Sendable {
    /// 1–6 days ago: the abbreviated weekday ("Wed"); each weekday name is unique within the trailing six days.
    case weekday
    /// Anything else: "Wed, Sep 9" (a bare "Tue" seven days back would read as today).
    case fullDate
}

/// What the app does when a session is missed (spec 4.3): ask on Home (the default), always shift, or always skip.
/// Raw strings so `@AppStorage(MissedDayPolicy.storageKey)` stores the value directly; the words the user reads live in
/// `SettingsText.policy(_:)`, never here (Engine stays formatting-free).
nonisolated enum MissedDayPolicy: String, CaseIterable, Sendable {
    case ask, shift, skip

    /// The `UserDefaults` key. Typed once here so the literal never appears anywhere else in the app (AC-22).
    static let storageKey = "missedDayPolicy"

    /// A stored raw value, falling back to `.ask` for anything unknown.
    static func from(raw: String) -> MissedDayPolicy {
        MissedDayPolicy(rawValue: raw) ?? .ask
    }
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

    /// m4-settings spec 5.5: what the prompt host should do, from the rows, the policy and the dismissal silence. Total: no
    /// missed session means `.none` under every policy, and an automatic policy ignores the silence (it belongs to the prompt).
    /// Analogy: a selector that turns store state plus one preference into the action to dispatch, or none.
    static func resolution(policy: MissedDayPolicy, sessions: [SessionSummary], silence: PromptSilence?, today: Date,
                           calendar: Calendar) -> MissedDayResolution {
        let missed = HomeStats.ordered(sessions.filter { HomeStats.sessionState($0, today: today, calendar: calendar) == .missed })
        guard let first = missed.first else { return .none }
        switch policy {
        case .ask:
            return shouldPrompt(missed: first, silence: silence, today: today, calendar: calendar) ? .prompt(first) : .none
        case .shift:
            return .shift(missedIndex: first.index)
        case .skip:
            return .skip(indexes: missed.map(\.index))
        }
    }

    /// m4-settings spec 5.5 / B1: the identity of the automatic write the host should run, or nil when there is nothing to do
    /// automatically (`.none` and `.prompt`). Equal keys mean "already handled", so the host's `.task(id:)` re-runs only on a
    /// policy change, a new calendar day, or a different first missed session. Analogy: the dependency array of a `useEffect`.
    static func automaticActionKey(resolution: MissedDayResolution, policy: MissedDayPolicy, today: Date,
                                   calendar: Calendar) -> AutomaticActionKey? {
        let index: Int
        switch resolution {
        case .none, .prompt: return nil
        case .shift(let missedIndex): index = missedIndex
        case .skip(let indexes):
            guard let first = indexes.first else { return nil }
            index = first
        }
        return AutomaticActionKey(policy: policy, missedIndex: index, day: CalendarRules.startOfDay(today, calendar: calendar))
    }

    /// m4-settings spec 2.7 / NB4: whether the banner names the shifted session's new day as "today" or as a date. The Engine
    /// decides, `MissedDayText.shiftedBanner` writes the words (the same split as `dayLabelStyle` → `MissedDayText.title`).
    static func bannerDayStyle(newDate: Date, today: Date, calendar: Calendar) -> BannerDayStyle {
        CalendarRules.isSameDay(newDate, today, calendar: calendar) ? .today : .date
    }
}

/// What the prompt host should do about the missed sessions right now (m4-settings spec 5.5). One value per render, derived
/// from the rows and the policy, never stored.
nonisolated enum MissedDayResolution: Equatable, Sendable {
    /// Nothing missed, or the prompt is silenced for today.
    case none
    /// Ask: draw the Home prompt for this session.
    case prompt(SessionSummary)
    /// Always shift: one `ProgramStore.shift` on this session index.
    case shift(missedIndex: Int)
    /// Always skip: one `ProgramStore.skipMissed` per index, earliest first.
    case skip(indexes: [Int])
}

/// How the shift banner names the day the session landed on (m4-settings spec 2.7).
nonisolated enum BannerDayStyle: Equatable, Sendable {
    case today
    case date
}

/// The identity of one automatic missed-day action (B1). A struct rather than a tuple because `.task(id:)` needs
/// `Equatable` (and `Hashable`), which tuples do not conform to.
nonisolated struct AutomaticActionKey: Equatable, Hashable, Sendable {
    let policy: MissedDayPolicy
    let missedIndex: Int
    /// Local midnight of the day the action was derived for, so a new calendar day re-runs it.
    let day: Date
}

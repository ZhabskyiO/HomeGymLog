#if DEBUG
import Foundation
import SwiftData

enum DebugSeedError: Error, Equatable {
    case unknownSeed(String)
}

/// The daily-reminder preference pair a reminder seed stores (`reminderEnabled`, `reminderMinutes`).
struct ReminderSeedPreferences: Equatable {
    let enabled: Bool
    let minutes: Int
}

/// Launch-argument seeds mirroring the prototype's Tweaks, so `/design-compare` can reach every screen.
/// `xcrun simctl launch <udid> <bundle> -seed ob3`. Compiled out of Release (this whole file is `#if DEBUG`).
/// A seeded run uses an in-memory store, a throwaway preferences suite, a frozen clock and a silent rest notifier.
enum DebugSeed: String, CaseIterable {
    case onboarding, ob1, ob2, ob3, ob4, ob5, midProgram, missed
    /// midProgram data with sessions 11–14 also completed; today is Sat 2026-09-19, a rest day.
    case restDay
    /// A program from the onboarding defaults with no logs; today is Mon 2026-08-31.
    case freshProgram
    /// midProgram with session 11 (Pull) started 12:34 ago, every set pending. Opens the workout at the root.
    case woStart = "wo-start"
    /// `wo-start` with the active row drawn 72 pt into a right swipe (screenshot-only drag preview).
    case woSwipe = "wo-swipe"
    /// `wo-start` with set 1 logged and its RPE card showing.
    case woRPE = "wo-rpe"
    /// `wo-start` with set 1 logged at RPE 7 and the adjust sheet open on set 2.
    case woAdjust = "wo-adjust"
    /// `wo-start` with set 1 rated RPE 7 thirteen seconds ago: the rest card reads "1:02" of 75 s, "Next: set 2 of 3".
    case woRest = "wo-rest"
    /// Session 11 started 42:00 ago with every set logged (set 1 at 120 lb): the summary screen.
    case summary = "summary"
    /// `wo-start` rows with the exercise detail sheet open on Lat Pulldown (no note: the editor shows its placeholder).
    case woDetail = "wo-detail"
    /// `wo-start` rows with the swap sheet open on Lat Pulldown: 0 candidates, so the empty-state line shows.
    case woSwap = "wo-swap"
    /// Exercises 1–3 done at RPE 7 (set k logged and rated at start + 70·k; the last rest ended 49 s ago): the swap sheet
    /// open on exercise 4, Dumbbell Romanian Deadlift, with its five Legs candidates.
    case woSwapRDL = "wo-swap-rdl"
    /// `wo-start` rows plus a stored Lat Pulldown note from a day earlier: the bar reads "Notes ·". No sheet.
    case woNotes = "wo-notes"
    /// midProgram rows on Thu 2026-09-17: sessions 7, 11 and 12 are missed and 13 is today, so the prompt names
    /// "Legs on Wed, Sep 9" and the Program tab's WK 3 holds two more Missed cards.
    case missedSeveral = "missed-several"
    /// `missed` after "Do it today · shift program" on session 7 (Tue 2026-09-15): Home shows Legs as today's session, the
    /// Program tab has 25 weeks, no prompt.
    case missedShifted = "missed-shifted"
    /// `missed` after "Skip it · stay on schedule" on session 7 (Tue 2026-09-15): Home equals `midProgram`, Program WK 2 · Wed 9
    /// reads "Skipped", no prompt.
    case missedSkipped = "missed-skipped"
    /// An archived 1-month, 3-day (Mon/Wed/Fri) program started Mon 2026-08-03 with all 12 sessions completed at target and
    /// archived Mon 08-31 05:00, then `midProgram` as the current program; today is Tue 2026-09-15. The Progress chart
    /// spans both programs (dbBench 40 · 40 · 45 · 30 · 37.5 · 40 · 42.5).
    case progressHistory = "progress-history"
    /// `midProgram` data with the restart confirmation already presented on the Settings tab, so the dialog can be
    /// screenshot without a tap.
    case settingsRestart = "settings-restart"
    /// `midProgram` data archived Tue 2026-09-15 11:59 with no current program: the root shows onboarding at A2, prefilled
    /// from the archived row.
    case restarted = "restarted"
    /// `midProgram` data with the daily reminder on at 07:00 and notifications allowed: Settings shows "7:00 AM on training
    /// days" and the Reminder time row.
    case reminderOn = "reminder-on"
    /// `midProgram` data with the reminder on and notifications denied: "Notifications are off in iOS Settings" and the
    /// "Open iOS Settings" row.
    case reminderDenied = "reminder-denied"
    /// `midProgram` data with the reminder on and permission never asked: "Notifications not allowed yet" and the "Allow
    /// notifications" row.
    case reminderUnasked = "reminder-unasked"
    /// `midProgram` with Settings' backup replace confirmation up over its own rows (m5-export AC-2).
    case backupConfirm = "backup-confirm"
    /// `midProgram` with Settings' read-failed alert up for a newer-format file (AC-3).
    case backupFailed = "backup-failed"
    /// `midProgram` behind the root's Restoring screen, with no write in flight (AC-4).
    case backupRestoring = "backup-restoring"

    /// nil when no `-seed` is present; throws for an unknown name or a trailing `-seed` with no value.
    static func parse(arguments: [String]) throws -> DebugSeed? {
        guard let index = arguments.firstIndex(of: "-seed") else { return nil }
        let name = arguments.indices.contains(index + 1) ? arguments[index + 1] : ""
        guard let seed = DebugSeed(rawValue: name) else { throw DebugSeedError.unknownSeed(name) }
        return seed
    }

    /// 12:00 local on the seed's reference day.
    func referenceDate(calendar: Calendar) -> Date {
        let day: DateComponents
        switch self {
        case .midProgram, .missed, .missedShifted, .missedSkipped, .woStart, .woSwipe, .woRPE, .woAdjust, .woRest, .summary,
             .woDetail, .woSwap, .woSwapRDL, .woNotes, .progressHistory:
            day = DateComponents(year: 2026, month: 9, day: 15, hour: 12)
        case .settingsRestart, .restarted: day = DateComponents(year: 2026, month: 9, day: 15, hour: 12)
        case .reminderOn, .reminderDenied, .reminderUnasked: day = DateComponents(year: 2026, month: 9, day: 15, hour: 12)
        case .backupConfirm, .backupFailed, .backupRestoring: day = DateComponents(year: 2026, month: 9, day: 15, hour: 12)
        case .missedSeveral: day = DateComponents(year: 2026, month: 9, day: 17, hour: 12)
        case .restDay: day = DateComponents(year: 2026, month: 9, day: 19, hour: 12)
        case .freshProgram: day = DateComponents(year: 2026, month: 8, day: 31, hour: 12)
        default: day = DateComponents(year: 2026, month: 8, day: 31, hour: 12)
        }
        return calendar.date(from: day)!
    }

    func clock(calendar: Calendar) -> AppClock {
        .frozen(at: referenceDate(calendar: calendar), calendar: calendar)
    }

    /// The onboarding draft to open with, or nil for seeds that show the shell or a workout.
    func initialDraft(calendar: Calendar) -> OnboardingDraft? {
        switch self {
        case .onboarding:
            return OnboardingDraft()
        case .ob1, .ob2, .ob3, .ob4, .ob5:
            let draft = OnboardingDraft(months: 6, frequency: 5)
            for _ in 0..<onboardingSteps { draft.advance(now: referenceDate(calendar: calendar), calendar: calendar) }
            return draft
        case .midProgram, .missed, .missedSeveral, .missedShifted, .missedSkipped, .restDay, .freshProgram, .woStart, .woSwipe,
             .woRPE, .woAdjust, .woRest, .summary, .woDetail, .woSwap, .woSwapRDL, .woNotes, .progressHistory,
             .settingsRestart, .restarted, .reminderOn, .reminderDenied, .reminderUnasked, .backupConfirm, .backupFailed,
             .backupRestoring:
            return nil
        }
    }

    /// In-memory container, populated for the mid-program, missed-day and workout seeds.
    func makeContainer(calendar: Calendar) throws -> ModelContainer {
        let container = try AppSchema.makeContainer(inMemory: true)
        switch self {
        case .midProgram, .missed, .missedSeveral, .settingsRestart, .reminderOn, .reminderDenied, .reminderUnasked,
             .backupConfirm, .backupFailed, .backupRestoring:
            try MidProgramSeed.populate(in: container.mainContext, calendar: calendar)
        case .restarted:
            try RestartSeed.populate(in: container.mainContext, calendar: calendar)
        case .missedShifted, .missedSkipped:
            let program = try MidProgramSeed.populate(in: container.mainContext, calendar: calendar)
            try MissedDaySeed.apply(self == .missedShifted ? .shift : .skip, to: program, today: referenceDate(calendar: calendar),
                                    calendar: calendar, in: container.mainContext)
        case .restDay:
            try MidProgramSeed.populate(in: container.mainContext, calendar: calendar, completedIndexes: Array(0...14).filter { $0 != 7 })
        case .freshProgram:
            try FreshProgramSeed.populate(in: container.mainContext, calendar: calendar)
        case .progressHistory:
            try ProgressHistorySeed.populate(in: container.mainContext, calendar: calendar)
            try MidProgramSeed.populate(in: container.mainContext, calendar: calendar)
        case .woStart, .woSwipe, .woRPE, .woAdjust, .woRest, .summary, .woDetail, .woSwap, .woSwapRDL, .woNotes:
            try MidProgramSeed.populate(in: container.mainContext, calendar: calendar)
            if let workoutStage {
                try WorkoutSeed.populate(workoutStage, now: referenceDate(calendar: calendar), in: container.mainContext)
            }
        default:
            break
        }
        return container
    }

    /// Which `WorkoutSeed` recipe a workout seed runs; nil for every other seed.
    private var workoutStage: WorkoutSeed.Stage? {
        switch self {
        case .woStart, .woSwipe, .woDetail, .woSwap: return .started
        case .woRPE: return .awaitingRating
        case .woAdjust: return .rated
        case .woRest: return .resting
        case .summary: return .finishedSets
        case .woSwapRDL: return .legsNext
        case .woNotes: return .noted
        default: return nil
        }
    }

    /// The fixed drag offset the active set row draws with (`workoutDragPreview`); nil except `wo-swipe`.
    var workoutDragPreview: CGFloat? {
        self == .woSwipe ? 72 : nil
    }

    /// Whether the Settings screen opens with its restart confirmation up (`settingsRestartPreview`); nil for every other
    /// seed, so the environment value stays at its nil default.
    var settingsRestartPreview: Bool? {
        self == .settingsRestart ? true : nil
    }

    /// The sheet the workout screen opens on first appearance (`workoutSheetPreview`); nil for every seed without one.
    var workoutSheetPreview: WorkoutSheetPreview? {
        switch self {
        case .woAdjust: return .adjust
        case .woDetail: return .detail
        case .woSwap, .woSwapRDL: return .swap
        default: return nil
        }
    }

    /// The permission status the seed's silent reminder notifier reports (m4-reminder spec 4.4); not determined for every
    /// seed outside the reminder family.
    var reminderStatus: ReminderAuthorization {
        switch self {
        case .reminderOn: return .authorized
        case .reminderDenied: return .denied
        case .reminderUnasked: return .notDetermined
        default: return .notDetermined
        }
    }

    /// The two reminder preferences the root writes into the throwaway suite (on, 07:00) for the three reminder seeds; nil
    /// for every other seed, which keeps the defaults (off, 07:00).
    var reminderPreferences: ReminderSeedPreferences? {
        switch self {
        case .reminderOn, .reminderDenied, .reminderUnasked:
            return ReminderSeedPreferences(enabled: true, minutes: ReminderPlan.defaultMinutes)
        default:
            return nil
        }
    }

    /// How many steps into onboarding an `obN` seed opens.
    private var onboardingSteps: Int {
        switch self {
        case .ob1: return 1
        case .ob2: return 2
        case .ob3: return 3
        case .ob4: return 4
        case .ob5: return 5
        default: return 0
        }
    }

    /// True for the missed-day family, whose screens show or follow the Home prompt; false for every other seed. `midProgram`,
    /// `restDay` and the workout seeds share the `missed` data (session 7 is missed) but must match prototype snapshots with the
    /// prompt off. The root passes this on as the `missedPromptEnabled` environment value.
    var forcesMissedDayPrompt: Bool {
        switch self {
        case .missed, .missedSeveral, .missedShifted, .missedSkipped: return true
        default: return false
        }
    }
}
#endif

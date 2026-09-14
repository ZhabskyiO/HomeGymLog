#if DEBUG
import Foundation
import SwiftData

enum DebugSeedError: Error, Equatable {
    case unknownSeed(String)
}

/// Launch-argument seeds mirroring the prototype's Tweaks, so `/design-compare` can reach every screen.
/// `xcrun simctl launch <udid> <bundle> -seed ob3`. Compiled out of Release (this whole file is `#if DEBUG`).
/// A seeded run uses an in-memory store, a throwaway preferences suite, and a frozen clock.
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
    /// Session 11 started 42:00 ago with every set logged (set 1 at 120 lb): the summary screen.
    case summary = "summary"

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
        case .midProgram, .missed, .woStart, .woSwipe, .woRPE, .woAdjust, .summary:
            day = DateComponents(year: 2026, month: 9, day: 15, hour: 12)
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
        case .midProgram, .missed, .restDay, .freshProgram, .woStart, .woSwipe, .woRPE, .woAdjust, .summary:
            return nil
        }
    }

    /// In-memory container, populated for the mid-program and workout seeds.
    func makeContainer(calendar: Calendar) throws -> ModelContainer {
        let container = try AppSchema.makeContainer(inMemory: true)
        switch self {
        case .midProgram, .missed:
            try MidProgramSeed.populate(in: container.mainContext, calendar: calendar)
        case .restDay:
            try MidProgramSeed.populate(in: container.mainContext, calendar: calendar, completedIndexes: Array(0...14).filter { $0 != 7 })
        case .freshProgram:
            try FreshProgramSeed.populate(in: container.mainContext, calendar: calendar)
        case .woStart, .woSwipe, .woRPE, .woAdjust, .summary:
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
        case .woStart, .woSwipe: return .started
        case .woRPE: return .awaitingRating
        case .woAdjust: return .rated
        case .summary: return .finishedSets
        default: return nil
        }
    }

    /// The fixed drag offset the active set row draws with (`workoutDragPreview`); nil except `wo-swipe`.
    var workoutDragPreview: CGFloat? {
        self == .woSwipe ? 72 : nil
    }

    /// True when the workout screen opens the adjust sheet on first appearance (`workoutAdjustPreview`); nil otherwise.
    var workoutAdjustPreview: Bool? {
        self == .woAdjust ? true : nil
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

    /// M4 reads this to show the missed-day prompt on launch.
    var forcesMissedDayPrompt: Bool { self == .missed }
}
#endif

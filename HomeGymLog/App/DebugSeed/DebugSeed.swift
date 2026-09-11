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
        case .midProgram, .missed: day = DateComponents(year: 2026, month: 9, day: 15, hour: 12)
        default: day = DateComponents(year: 2026, month: 8, day: 31, hour: 12)
        }
        return calendar.date(from: day)!
    }

    func clock(calendar: Calendar) -> AppClock {
        .frozen(at: referenceDate(calendar: calendar), calendar: calendar)
    }

    /// The onboarding draft to open with, or nil for seeds that show the shell.
    func initialDraft(calendar: Calendar) -> OnboardingDraft? {
        switch self {
        case .onboarding:
            return OnboardingDraft()
        case .ob1, .ob2, .ob3, .ob4, .ob5:
            let draft = OnboardingDraft(months: 6, frequency: 5)
            for _ in 0..<onboardingSteps { draft.advance(now: referenceDate(calendar: calendar), calendar: calendar) }
            return draft
        case .midProgram, .missed:
            return nil
        }
    }

    /// In-memory container, populated for the mid-program seeds.
    func makeContainer(calendar: Calendar) throws -> ModelContainer {
        let container = try AppSchema.makeContainer(inMemory: true)
        switch self {
        case .midProgram, .missed:
            try MidProgramSeed.populate(in: container.mainContext, calendar: calendar)
        default:
            break
        }
        return container
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

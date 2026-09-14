#if DEBUG
import Foundation
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct DebugSeedTests {
    private let cal = TestCalendar.calendar

    @Test("every name parses and has its reference day at noon", arguments: DebugSeed.allCases)
    func parses(seed: DebugSeed) throws {
        let parsed = try DebugSeed.parse(arguments: ["app", "-seed", seed.rawValue])
        #expect(parsed == seed)
        let expectedDay: Date
        switch seed {
        case .midProgram, .missed: expectedDay = TestCalendar.day(2026, 9, 15)
        case .woStart, .woSwipe, .woRPE, .woAdjust, .woRest, .summary: expectedDay = TestCalendar.day(2026, 9, 15)
        case .restDay: expectedDay = TestCalendar.day(2026, 9, 19)
        case .freshProgram: expectedDay = TestCalendar.day(2026, 8, 31)
        default: expectedDay = TestCalendar.day(2026, 8, 31)
        }
        #expect(seed.referenceDate(calendar: cal) == expectedDay.addingTimeInterval(12 * 3600))
        #expect(seed.clock(calendar: cal).now() == seed.referenceDate(calendar: cal))
    }

    @Test("the workout seeds use the prototype's hyphenated names")
    func workoutNames() throws {
        let names: [(String, DebugSeed)] = [("wo-start", .woStart), ("wo-swipe", .woSwipe), ("wo-rpe", .woRPE),
                                            ("wo-adjust", .woAdjust), ("wo-rest", .woRest), ("summary", .summary)]
        for (name, seed) in names {
            let parsed = try DebugSeed.parse(arguments: ["app", "-seed", name])
            #expect(parsed == seed)
        }
        #expect(throws: DebugSeedError.unknownSeed("woStart")) { try DebugSeed.parse(arguments: ["app", "-seed", "woStart"]) }
    }

    @Test("absent, unknown, and trailing -seed")
    func edgeCases() throws {
        #expect(try DebugSeed.parse(arguments: []) == nil)
        #expect(try DebugSeed.parse(arguments: ["app", "-other", "x"]) == nil)
        #expect(throws: DebugSeedError.unknownSeed("nope")) { try DebugSeed.parse(arguments: ["app", "-seed", "nope"]) }
        #expect(throws: DebugSeedError.unknownSeed("")) { try DebugSeed.parse(arguments: ["app", "-seed"]) }
    }

    @Test("initial drafts")
    func drafts() throws {
        let onboarding = try #require(DebugSeed.onboarding.initialDraft(calendar: cal))
        #expect(onboarding.step == 0 && onboarding.months == 1 && onboarding.frequency == 4)
        let ob3 = try #require(DebugSeed.ob3.initialDraft(calendar: cal))
        #expect(ob3.step == 3 && ob3.months == 6 && ob3.frequency == 5 && ob3.days == [0, 1, 2, 3, 4])
        #expect(ob3.units == .lb && ob3.bodyWeightLb == 180 && ob3.sessionLengthMinutes == 45)
        let ob5 = try #require(DebugSeed.ob5.initialDraft(calendar: cal))
        #expect(ob5.step == 5 && ob5.preview?.totalSessions == 120)
        #expect(DebugSeed.midProgram.initialDraft(calendar: cal) == nil)
        #expect(DebugSeed.missed.forcesMissedDayPrompt && !DebugSeed.midProgram.forcesMissedDayPrompt)
        #expect(DebugSeed.restDay.initialDraft(calendar: cal) == nil && DebugSeed.freshProgram.initialDraft(calendar: cal) == nil)
        #expect(!DebugSeed.restDay.forcesMissedDayPrompt && !DebugSeed.freshProgram.forcesMissedDayPrompt)
        for seed in [DebugSeed.woStart, .woSwipe, .woRPE, .woAdjust, .woRest, .summary] {
            #expect(seed.initialDraft(calendar: cal) == nil, "\(seed.rawValue)")
            #expect(!seed.forcesMissedDayPrompt, "\(seed.rawValue)")
        }
    }

    @Test("drag preview only for wo-swipe (72 pt); adjust preview only for wo-adjust")
    func previews() {
        #expect(DebugSeed.allCases.filter { $0.workoutDragPreview != nil } == [.woSwipe])
        #expect(DebugSeed.woSwipe.workoutDragPreview == 72)
        #expect(DebugSeed.allCases.filter { $0.workoutAdjustPreview != nil } == [.woAdjust])
        #expect(DebugSeed.woAdjust.workoutAdjustPreview == true)
    }
}
#endif

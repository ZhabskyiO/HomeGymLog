#if DEBUG
import Foundation
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct DebugSeedTests {
    private let cal = TestCalendar.calendar

    @Test("every name parses and has its reference day at noon", arguments: DebugSeed.allCases)
    func parses(seed: DebugSeed) throws {
        #expect(try DebugSeed.parse(arguments: ["app", "-seed", seed.rawValue]) == seed)
        let expectedDay: Date
        switch seed {
        case .midProgram, .missed: expectedDay = TestCalendar.day(2026, 9, 15)
        case .restDay: expectedDay = TestCalendar.day(2026, 9, 19)
        case .freshProgram: expectedDay = TestCalendar.day(2026, 8, 31)
        default: expectedDay = TestCalendar.day(2026, 8, 31)
        }
        #expect(seed.referenceDate(calendar: cal) == expectedDay.addingTimeInterval(12 * 3600))
        #expect(seed.clock(calendar: cal).now() == seed.referenceDate(calendar: cal))
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
    }
}
#endif

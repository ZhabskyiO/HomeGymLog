#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-25 for every seed (not only `ob3`): the step, the answers, the `days`, and the preview state of each
/// seed's initial draft; plus the `missed` container, which must carry the same data as `midProgram`.
@MainActor
@Suite struct SeedDraftTests {
    private let cal = TestCalendar.calendar

    @Test("ob1…ob5 open at their step with months 6, frequency 5, Mo–Fr and every other default", arguments: [
        (DebugSeed.ob1, 1), (.ob2, 2), (.ob3, 3), (.ob4, 4), (.ob5, 5),
    ])
    func obDrafts(seed: DebugSeed, step: Int) throws {
        let draft = try #require(seed.initialDraft(calendar: cal))
        #expect(draft.step == step)
        #expect(draft.months == 6 && draft.frequency == 5 && draft.days == [0, 1, 2, 3, 4])
        #expect(draft.units == .lb && draft.bodyWeightLb == 180 && draft.experience == .intermediate && draft.sessionLengthMinutes == 45)
        #expect(draft.startingWeightsLb.isEmpty)
        #expect(draft.canContinue)
        #expect((draft.preview != nil) == (step == 5), "only the summary step holds a preview")
        #expect(draft.ctaLabel == OnboardingDraft.ctaLabels[step])
    }

    @Test("the ob5 preview equals a fresh generation on the reference day")
    func ob5Preview() throws {
        let draft = try #require(DebugSeed.ob5.initialDraft(calendar: cal))
        let reference = DebugSeed.ob5.referenceDate(calendar: cal)
        let expected = ProgramSummary(generated: try ProgramGenerator.generate(draft.inputs(generatedOn: reference), calendar: cal))
        #expect(draft.preview == expected)
        #expect(draft.preview?.firstSessionDate == TestCalendar.day(2026, 8, 31))
    }

    @Test("the onboarding seed's draft is exactly a default draft")
    func onboardingDraft() throws {
        let draft = try #require(DebugSeed.onboarding.initialDraft(calendar: cal))
        let fresh = OnboardingDraft()
        #expect(draft.step == 0 && draft.units == .lb && draft.months == 1 && draft.frequency == 4)
        #expect(draft.days == [0, 1, 3, 4] && draft.days == fresh.days)
        #expect(draft.bodyWeightLb == 180 && draft.experience == .intermediate && draft.sessionLengthMinutes == 45)
        #expect(draft.startingWeightsLb.isEmpty && draft.preview == nil)
        #expect(draft.ctaLabel == "Set up my program")
    }

    @Test("onboarding seeds get an empty in-memory store", arguments: [DebugSeed.onboarding, .ob1, .ob2, .ob3, .ob4, .ob5])
    func onboardingContainersAreEmpty(seed: DebugSeed) throws {
        let container = try seed.makeContainer(calendar: cal)
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Program>()) == 0)
        #expect(try ProgramStore.current(in: context) == nil)
    }

    @Test("the missed seed carries the midProgram data and only differs by the prompt flag")
    func missedContainer() throws {
        let container = try DebugSeed.missed.makeContainer(calendar: cal)
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
        let context = ModelContext(container)
        let program = try #require(try ProgramStore.current(in: context))
        let sessions = program.sortedSessions
        #expect(sessions.count == 120)
        #expect(sessions.filter { $0.status == .completed }.map(\.index) == MidProgramSeed.completedIndexes)
        #expect(sessions[7].status == .pending && sessions[7].scheduledDate == TestCalendar.day(2026, 9, 9))
        #expect(DebugSeed.missed.referenceDate(calendar: cal) == DebugSeed.midProgram.referenceDate(calendar: cal))
        #expect(DebugSeed.missed.initialDraft(calendar: cal) == nil)
    }
}
#endif

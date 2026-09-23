#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-21 (seed half): `settings-restart` carries `midProgram`'s rows with the confirmation preview flag, and `restarted`
/// carries the same rows archived, with no current program and a prefill equal to AC-19's row.
@MainActor
@Suite struct RestartSeedTests {
    private let cal = TestCalendar.calendar

    @Test("settings-restart holds midProgram's rows, keeps the prompt off, and is the only seed with the restart preview")
    func settingsRestartRows() throws {
        let container = try DebugSeed.settingsRestart.makeContainer(calendar: cal)
        let program = try #require(try ProgramStore.current(in: container.mainContext))
        #expect(program.sessions.count == 120)
        #expect(program.sessions.filter { $0.status == .completed }.count == 10)
        #expect(program.sessions.compactMap(\.workoutLog).count == 10)
        #expect(DebugSeed.settingsRestart.forcesMissedDayPrompt == false)
        #expect(DebugSeed.allCases.filter { $0.settingsRestartPreview != nil } == [.settingsRestart])
        #expect(DebugSeed.settingsRestart.settingsRestartPreview == true)
        withExtendedLifetime(container) {}
    }

    @Test("restarted has no current program, one archived program at Tue 09-15 11:59 with ten completed sessions")
    func restartedRows() throws {
        let container = try DebugSeed.restarted.makeContainer(calendar: cal)
        let context = container.mainContext
        #expect(try ProgramStore.current(in: context) == nil)
        let archived = try context.fetch(FetchDescriptor<Program>(predicate: ProgressSnapshotBuilder.archivedProgramPredicate))
        try #require(archived.count == 1)
        let program = try #require(archived.first)
        #expect(program.archivedAt == cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 11, minute: 59)))
        #expect(program.sessions.count == 120)
        #expect(program.sessions.filter { $0.status == .completed }.count == 10)
        #expect(DebugSeed.restarted.initialDraft(calendar: cal) == nil)
        #expect(DebugSeed.restarted.settingsRestartPreview == nil)
        withExtendedLifetime(container) {}
    }

    @Test("the prefill from restarted's archived row equals the midProgram answers, in exerciseKeys order")
    func prefillFromArchivedRow() throws {
        let container = try DebugSeed.restarted.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try context.fetch(FetchDescriptor<Program>(predicate: ProgressSnapshotBuilder.archivedProgramPredicate)).first)
        let answers = RestartPrefill.answers(months: program.months, frequency: program.frequency,
                                             trainingWeekdays: program.trainingWeekdays,
                                             sessionLengthMinutes: program.sessionLengthMinutes,
                                             bodyWeightLb: program.bodyWeightLb, experience: program.experience,
                                             startingWeightsLb: program.startingWeightsLb)
        #expect(answers.months == 6 && answers.frequency == 5)
        #expect(answers.trainingWeekdays == [0, 1, 2, 3, 4])
        #expect(answers.sessionLengthMinutes == 45 && answers.bodyWeightLb == 180)
        #expect(answers.experience == .intermediate)

        let keys = try #require(SplitPlans.exerciseKeys(frequency: 5, sessionLengthMinutes: 45))
        #expect(keys.count == 17)
        #expect(Set(answers.startingWeightsLb.keys) == Set(keys))

        let draft = OnboardingDraft(answers: answers, units: .lb, bodyWeightUnit: .lb)
        #expect(draft.step == 1)
        #expect(draft.startingWeightRows.map(\.key) == keys)
        withExtendedLifetime(container) {}
    }
}
#endif

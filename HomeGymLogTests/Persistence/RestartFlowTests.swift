#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-20 (restart half): archive then start, over the `midProgram` seed's rows and through the existing writers only.
/// The archived program keeps every session, log, set and note; the new program becomes the one current row.
@MainActor
@Suite struct RestartFlowTests {
    private let cal = TestCalendar.calendar

    @Test("archive then start: one current program, one archived, and the old program's data untouched")
    func archiveThenStart() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let old = try MidProgramSeed.populate(in: context, calendar: cal)
        let oldID = old.id
        let oldSessionCount = old.sessions.count
        let oldCompleted = old.sessions.filter { $0.status == .completed }.count
        let oldLogs = old.sessions.compactMap(\.workoutLog).count
        let oldSets = old.sessions.compactMap(\.workoutLog).flatMap(\.exercises).flatMap(\.sets).count
        let noteCount = try context.fetchCount(FetchDescriptor<ExerciseNote>())

        let archivedAt = cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 11, minute: 59))!
        #expect(try ProgramStore.archive(old, at: archivedAt, in: context) == true)

        // The prefill's own inputs, exactly as the restart path builds them.
        let answers = RestartPrefill.answers(months: old.months, frequency: old.frequency, trainingWeekdays: old.trainingWeekdays,
                                             sessionLengthMinutes: old.sessionLengthMinutes, bodyWeightLb: old.bodyWeightLb,
                                             experience: old.experience, startingWeightsLb: old.startingWeightsLb)
        let startedAt = cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12))!
        let inputs = ProgramInputs(months: answers.months, frequency: answers.frequency,
                                   trainingWeekdays: answers.trainingWeekdays,
                                   sessionLengthMinutes: answers.sessionLengthMinutes,
                                   startingWeightsLb: answers.startingWeightsLb, generatedOn: startedAt)
        let new = try #require(try ProgramStore.start(inputs, bodyWeightLb: answers.bodyWeightLb,
                                                      experience: answers.experience.rawValue, now: startedAt,
                                                      calendar: cal, in: context))
        let newID = new.id
        #expect(newID != oldID)

        let fresh = ModelContext(container)
        #expect(try ProgramStore.current(in: fresh)?.id == newID)
        #expect(try fresh.fetchCount(FetchDescriptor<Program>(predicate: ProgramStore.currentPredicate)) == 1)
        #expect(try fresh.fetchCount(FetchDescriptor<Program>(predicate: ProgressSnapshotBuilder.archivedProgramPredicate)) == 1)

        let reread = try #require(try fresh.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.id == oldID })).first)
        #expect(reread.archivedAt == archivedAt)
        #expect(reread.sessions.count == oldSessionCount && oldSessionCount == 120)
        #expect(reread.sessions.filter { $0.status == .completed }.count == oldCompleted && oldCompleted == 10)
        #expect(reread.sessions.compactMap(\.workoutLog).count == oldLogs && oldLogs == 10)
        #expect(reread.sessions.compactMap(\.workoutLog).flatMap(\.exercises).flatMap(\.sets).count == oldSets && oldSets == 150)
        #expect(try fresh.fetchCount(FetchDescriptor<ExerciseNote>()) == noteCount)

        #expect(try ProgramStore.archive(reread, at: startedAt, in: fresh) == false)
        #expect(fresh.hasChanges == false)
        withExtendedLifetime(container) {}
    }
}
#endif

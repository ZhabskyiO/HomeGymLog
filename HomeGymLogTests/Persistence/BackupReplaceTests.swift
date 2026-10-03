#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-15, AC-17 rows 1–2, AC-8 data half: `replaceAll` over populated seed stores. Counts are derived from their owners
/// (`PhaseSplit`, `MidProgramSeed`, `SplitPlans`, `Phase`), never from the function under test; a fresh context reads the
/// store after each replace.
@MainActor
@Suite struct BackupReplaceTests {
    private let cal = TestCalendar.calendar
    private typealias F = BackupFixtures

    /// midProgram: S = 24 weeks × 5, L = the completed sessions, E = 5 exercises each (45 min), T = 3 Foundation sets each.
    private var midProgramCounts: [String: Int] {
        let logs = MidProgramSeed.completedIndexes.count
        let exercises = logs * SplitPlans.exerciseCount(sessionLengthMinutes: 45)!
        return ["P": 1, "S": PhaseSplit.weeks(months: 6) * 5, "L": logs, "E": exercises, "T": exercises * Phase.foundation.sets, "N": 0]
    }

    @Test("midProgram rows replaced by the sample read P1 S3 L1 E2 T6 N1, the file's current program and its in-progress log")
    func sampleOverMidProgram() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let observed1 = try tableCounts(in: container)
        #expect(observed1 == midProgramCounts)
        try BackupStore.replaceAll(with: F.sampleDocument(), in: container)

        let observed2 = try tableCounts(in: container)
        #expect(observed2 == ["P": 1, "S": 3, "L": 1, "E": 2, "T": 6, "N": 1])
        let fresh = ModelContext(container)
        let current = try ProgramStore.current(in: fresh)
        #expect(current?.id == F.programID)
        let notes = try fresh.fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.map(\.text) == ["incline notch 2"])
        let live = try fresh.fetch(FetchDescriptor<WorkoutLog>(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        #expect(live.map(\.id) == [F.logID])
        let main = try container.mainContext.fetch(FetchDescriptor<WorkoutLog>(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        #expect(main.map(\.id) == [F.logID], "the main context sees the scratch save")
        withExtendedLifetime((container, fresh)) {}
    }

    @Test("midProgram exported and restored over the sample reads midProgram's counts; the document counts (1, L, 0)")
    func midProgramOverSample() throws {
        let source = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let document = try BackupSnapshotBuilder.document(in: source.mainContext, exportedAt: F.exportedAt,
                                                          preferences: midProgramPreferences)
        let counts = document.counts
        #expect(counts.programs == 1)
        #expect(counts.workouts == MidProgramSeed.completedIndexes.count)
        #expect(counts.notes == 0)
        #expect(BackupValidation.validate(document) == nil)

        let target = try makeTestStore()
        try insertSampleGraph(in: target.context)
        try BackupStore.replaceAll(with: document, in: target.container)
        let observed3 = try tableCounts(in: target.container)
        #expect(observed3 == midProgramCounts)
        try expectChainsResolve(in: target.container)
        withExtendedLifetime((source, target)) {}
    }

    @Test("progress-history exported and re-imported keeps every count; the document counts (2, L + 12, 0)")
    func progressHistoryRoundTrip() throws {
        let source = try DebugSeed.progressHistory.makeContainer(calendar: cal)
        let sourceCounts = try tableCounts(in: source)
        let archivedSessions = PhaseSplit.weeks(months: 1) * 3
        #expect(sourceCounts["P"] == 2)
        #expect(sourceCounts["S"] == midProgramCounts["S"]! + archivedSessions)
        let document = try BackupSnapshotBuilder.document(in: source.mainContext, exportedAt: F.exportedAt,
                                                          preferences: midProgramPreferences)
        let counts = document.counts
        #expect(counts.programs == 2)
        #expect(counts.workouts == MidProgramSeed.completedIndexes.count + archivedSessions)
        #expect(counts.notes == 0)

        let data = try BackupCodec.encode(document)
        let target = try makeTestStore()
        try insertRichGraph(in: target.context)
        try BackupStore.replaceAll(with: try BackupCodec.read(data), in: target.container)
        let observed4 = try tableCounts(in: target.container)
        #expect(observed4 == sourceCounts)
        try expectChainsResolve(in: target.container)
        withExtendedLifetime((source, target)) {}
    }

    /// Every session's program and every set's exercise → workout → session resolve after the import.
    private func expectChainsResolve(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let programIDs = Set(try context.fetch(FetchDescriptor<Program>()).map(\.id))
        let sessions = try context.fetch(FetchDescriptor<PlannedSession>())
        #expect(sessions.allSatisfy { $0.program.map { programIDs.contains($0.id) } == true })
        let sessionIDs = Set(sessions.map(\.id))
        let sets = try context.fetch(FetchDescriptor<LoggedSet>())
        #expect(!sets.isEmpty)
        #expect(sets.allSatisfy { $0.exercise?.workout?.session.map { sessionIDs.contains($0.id) } == true })
        withExtendedLifetime(context) {}
    }
}
#endif

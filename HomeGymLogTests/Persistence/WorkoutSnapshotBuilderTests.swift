#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-32 (fallbacks) and AC-33 (id map): session info, the id map with shuffled rows, and the PR baseline.
/// Every seeded test keeps its `ModelContainer` alive to the end of the test: `container.mainContext` does not retain
/// it, and on iOS 26.5 reading a model after its container is released crashes the test process.
@MainActor
@Suite struct WorkoutSnapshotBuilderTests {
    private let cal = TestCalendar.calendar

    private func midProgramWithSession11() throws -> (container: ModelContainer, context: ModelContext, program: Program, log: WorkoutLog) {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        let started = try WorkoutLogStore.start(sessionIndex: 11, rows: rows, at: DebugSeed.midProgram.referenceDate(calendar: cal), in: context)
        return (container, context, program, try #require(started))
    }

    @Test("session info: session 11 reads Pull · week 3 · Foundation; an orphan log reads the fallback")
    func sessionInfo() throws {
        let (container, context, _, log) = try midProgramWithSession11()
        defer { withExtendedLifetime(container) {} }
        #expect(WorkoutSnapshotBuilder.sessionInfo(of: log) == WorkoutSessionInfo(name: "Pull", week: 3, phase: .foundation))
        let orphan = WorkoutLog(startedAt: TestCalendar.day(2026, 9, 15))
        context.insert(orphan)
        #expect(WorkoutSnapshotBuilder.sessionInfo(of: orphan) == WorkoutSessionInfo(name: "", week: 1, phase: .foundation))
    }

    @Test("byID keeps the first of a duplicate id and never traps")
    func byIDDuplicates() {
        struct Row { let id: UUID; let tag: String }
        let shared = WorkoutFixtures.uuid(1)
        let rows = [Row(id: shared, tag: "a1"), Row(id: WorkoutFixtures.uuid(2), tag: "b"), Row(id: shared, tag: "a2")]
        let map = WorkoutSnapshotBuilder.byID(rows, id: \.id)
        #expect(map.count == 2)
        #expect(map[shared]?.tag == "a1")
        #expect(map[WorkoutFixtures.uuid(2)]?.tag == "b")
    }

    @Test("a write resolved through the id map from reversed rows reaches the intended set")
    func idMapReachesRow() throws {
        let (container, context, _, log) = try midProgramWithSession11()
        defer { withExtendedLifetime(container) {} }
        let exercises = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let sets = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exercises.map(\.id))))
        let values = WorkoutFlow.sorted(WorkoutSnapshotBuilder.values(exercises: exercises.reversed(), sets: sets.reversed()))
        let target = values[0].sets[1]   // latPull, second set
        let row = try #require(WorkoutSnapshotBuilder.byID(Array(sets.reversed()), id: \.id)[target.id])
        let wrote = try WorkoutLogStore.logSet(row, at: DebugSeed.midProgram.referenceDate(calendar: cal), in: context)
        #expect(wrote)

        let freshLogs = try ModelContext(container).fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        let freshLog = try #require(freshLogs.first)
        let freshSets = WorkoutStoreFixtures.sets(of: freshLog)
        #expect(freshLog.sortedExercises[0].exerciseKey == "latPull")
        #expect(freshSets[0].map(\.status) == [.pending, .done, .pending])
        #expect(freshSets.flatMap { $0 }.filter { $0.status == .pending }.count == 14)
    }

    @Test("bestsBefore: midProgram's prior bests for Pull; an in-progress heavy set is excluded; nil program → empty")
    func bestsBefore() throws {
        let (container, context, program, log) = try midProgramWithSession11()
        defer { withExtendedLifetime(container) {} }
        let heavy = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.saveAndLogSet(heavy, weightLb: 150, reps: 12, at: log.startedAt, in: context)
        let bests = try WorkoutSnapshotBuilder.bestsBefore(programID: program.id, in: context)
        #expect(bests["latPull"] == 100)
        #expect(bests["lowRow"] == 90)
        #expect(bests["dbRow"] == 45)
        #expect(bests["rdl"] == 50)
        #expect(bests["curl"] == 25)
        let none = try WorkoutSnapshotBuilder.bestsBefore(programID: nil, in: context)
        #expect(none.isEmpty)
    }
}
#endif

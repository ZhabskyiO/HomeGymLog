#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-37: the workout screen's two live queries on `midProgram` (10 finished logs) plus session 11 started.
@MainActor
@Suite struct WorkoutQueriesTests {
    private let cal = TestCalendar.calendar

    @Test("exercise and set predicates return exactly this log's 5 and 15 rows, sorted by order; foreign ids return 0")
    func queries() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        let started = try WorkoutLogStore.start(sessionIndex: 11, rows: rows, at: DebugSeed.midProgram.referenceDate(calendar: cal), in: context)
        let log = try #require(started)

        let fresh = ModelContext(container)
        let exercises = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id),
                                                        sortBy: [SortDescriptor(\LoggedExercise.order)]))
        #expect(exercises.map(\.order) == [0, 1, 2, 3, 4])
        let sets = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exercises.map(\.id)),
                                                   sortBy: [SortDescriptor(\LoggedSet.order)]))
        #expect(sets.map(\.order) == [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2])

        let foreignExercises = try fresh.fetchCount(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: UUID())))
        let foreignSets = try fresh.fetchCount(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: [UUID()])))
        #expect(foreignExercises == 0 && foreignSets == 0)
        let allSets = try fresh.fetchCount(FetchDescriptor<LoggedSet>())
        #expect(allSets == 165)

        let values = WorkoutFlow.sorted(WorkoutSnapshotBuilder.values(exercises: exercises, sets: sets))
        #expect(values.map(\.exerciseKey) == ["latPull", "lowRow", "dbRow", "rdl", "curl"])
        #expect(values.map(\.targetWeightLb) == [110, 100, 47.5, 52.5, 27.5])
        #expect(values.allSatisfy { $0.sets.count == 3 })
        #expect(values.allSatisfy { exercise in
            exercise.sets.allSatisfy { $0.status == .pending && !$0.rpeSkipped && $0.weightLb == exercise.targetWeightLb && $0.reps == 12 }
        })
        #expect(WorkoutFlow.state(exercises: values) == .logging(exercise: 0, set: 0))
    }
}
#endif

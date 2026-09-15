import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// `WorkoutLogStore.swapExercise` edges beyond AC-24 (session 11 of a generated 6-month program; E4 is rdl at 52.5 × 12):
/// a planned array with a duplicate `order`, an empty planned array, a log with no session, Next exercise before a swap,
/// pending sets that differ in weight and reps, and the guard reading only the log's current keys. Read back through a
/// fresh context.
@MainActor
@Suite struct SwapExerciseEdgeTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    private static let session11Planned = [
        PlannedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 110),
        PlannedExercise(order: 1, exerciseKey: "lowRow", targetWeightLb: 100),
        PlannedExercise(order: 2, exerciseKey: "dbRow", targetWeightLb: 47.5),
        PlannedExercise(order: 3, exerciseKey: "rdl", targetWeightLb: 52.5),
        PlannedExercise(order: 4, exerciseKey: "curl", targetWeightLb: 27.5),
    ]

    private struct SetRow: Equatable {
        let status: SetStatus, weightLb: Double, reps: Int, rpe: Int?, rpeSkipped: Bool, loggedAt: Date?
    }

    private struct ExerciseRead: Equatable {
        let key: String
        let swappedFrom: String?
        let target: Double
        let sets: [SetRow]
    }

    private struct Fixture {
        let store: TestStore
        let rows: [PlannedSession]
        let log: WorkoutLog
        func exercise(_ order: Int) -> LoggedExercise { log.sortedExercises[order] }
    }

    private func fixture() throws -> Fixture {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[11], at: t0, in: store.context)
        return Fixture(store: store, rows: rows, log: log)
    }

    /// The exercise of `order` in `logID`, as a fresh context reads it.
    private func readExercise(_ order: Int, logID: UUID, in container: ModelContainer) throws -> ExerciseRead {
        let fresh = ModelContext(container)
        let rows = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: logID)))
        let exercise = try #require(rows.first { $0.order == order })
        return ExerciseRead(key: exercise.exerciseKey, swappedFrom: exercise.swappedFromKey, target: exercise.targetWeightLb,
                            sets: exercise.sortedSets.map { SetRow(status: $0.status, weightLb: $0.weightLb, reps: $0.reps, rpe: $0.rpe,
                                                                   rpeSkipped: $0.rpeSkipped, loggedAt: $0.loggedAt) })
    }

    /// Session 11's planned array in stored order (not sorted), as a fresh context reads it.
    private func storedPlan(_ container: ModelContainer) throws -> [PlannedExercise] {
        try #require(try ModelContext(container).fetch(FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.index == 11 })).first).exercises
    }

    private func pending(_ lb: Double, reps: Int = 12) -> SetRow {
        SetRow(status: .pending, weightLb: lb, reps: reps, rpe: nil, rpeSkipped: false, loggedAt: nil)
    }

    @Test("a planned array with order 3 twice: only the first element with that order changes")
    func duplicateOrderFirstMatch() throws {
        let f = try fixture()
        let duplicate = PlannedExercise(order: 3, exerciseKey: "rdl", targetWeightLb: 52.5)
        f.rows[11].exercises = Self.session11Planned + [duplicate]
        try f.store.context.save()
        #expect(try WorkoutLogStore.swapExercise(f.exercise(3), to: "goblet", targetWeightLb: 52.5, in: f.store.context))
        var expected = Self.session11Planned + [duplicate]
        expected[3] = PlannedExercise(order: 3, exerciseKey: "goblet", targetWeightLb: 52.5)
        #expect(try storedPlan(f.store.container) == expected)
    }

    @Test("a session with an empty planned array gets a log-only swap that returns true and leaves the array empty")
    func emptyPlannedArray() throws {
        let f = try fixture()
        f.rows[11].exercises = []
        try f.store.context.save()
        #expect(try WorkoutLogStore.swapExercise(f.exercise(3), to: "goblet", targetWeightLb: 52.5, in: f.store.context))
        #expect(try readExercise(3, logID: f.log.id, in: f.store.container)
                == ExerciseRead(key: "goblet", swappedFrom: "rdl", target: 52.5, sets: Array(repeating: pending(52.5), count: 3)))
        #expect(try storedPlan(f.store.container) == [])
    }

    @Test("a log with no session gets a log-only swap that returns true")
    func logWithoutSession() throws {
        let store = try makeTestStore()
        let log = WorkoutLog(startedAt: t0)
        store.context.insert(log)
        for (order, key, lb) in [(0, "curl", 27.5), (1, "rdl", 52.5)] {
            let exercise = LoggedExercise(order: order, exerciseKey: key, targetWeightLb: lb)
            store.context.insert(exercise)
            log.exercises.append(exercise)
            for s in 0..<3 {
                let set = LoggedSet(order: s, weightLb: lb, reps: 12)
                store.context.insert(set)
                exercise.sets.append(set)
            }
        }
        try store.context.save()
        #expect(try WorkoutLogStore.swapExercise(log.sortedExercises[1], to: "goblet", targetWeightLb: 50, in: store.context))
        #expect(try readExercise(1, logID: log.id, in: store.container)
                == ExerciseRead(key: "goblet", swappedFrom: "rdl", target: 50, sets: Array(repeating: pending(50), count: 3)))
        #expect(try readExercise(0, logID: log.id, in: store.container).key == "curl")
    }

    @Test("after Next exercise skipped exercise 1's sets, a swap of exercise 1 is refused and writes nothing")
    func refusedAfterNextExercise() throws {
        let f = try fixture()
        #expect(try WorkoutLogStore.nextExercise(f.exercise(0), at: t0.addingTimeInterval(60), in: f.store.context))
        let before = try readExercise(0, logID: f.log.id, in: f.store.container)
        #expect(before.sets.map(\.status) == [.skipped, .skipped, .skipped])
        #expect(!(try WorkoutLogStore.swapExercise(f.exercise(0), to: "goblet", targetWeightLb: 52.5, in: f.store.context)))
        #expect(!f.store.context.hasChanges)
        #expect(try readExercise(0, logID: f.log.id, in: f.store.container) == before)
        #expect(try storedPlan(f.store.container) == Self.session11Planned)
    }

    @Test("after Next exercise ×3, the swap on exercise 4 (all pending) still writes")
    func allowedAfterEarlierExercisesSkipped() throws {
        let f = try fixture()
        for order in 0..<3 {
            #expect(try WorkoutLogStore.nextExercise(f.exercise(order), at: t0.addingTimeInterval(Double(60 * (order + 1))), in: f.store.context))
        }
        #expect(try WorkoutLogStore.swapExercise(f.exercise(3), to: "goblet", targetWeightLb: 52.5, in: f.store.context))
        #expect(try readExercise(3, logID: f.log.id, in: f.store.container).key == "goblet")
    }

    @Test("pending sets of different weights all take the target; reps and every other set field stay as they were")
    func repsAndOtherFieldsUnchanged() throws {
        let f = try fixture()
        let sets = f.exercise(3).sortedSets
        for (set, (lb, reps)) in zip(sets, [(50.0, 8), (55.0, 10), (47.5, 11)]) {
            set.weightLb = lb
            set.reps = reps
        }
        try f.store.context.save()
        #expect(try WorkoutLogStore.swapExercise(f.exercise(3), to: "legExt", targetWeightLb: 80, in: f.store.context))
        #expect(try readExercise(3, logID: f.log.id, in: f.store.container)
                == ExerciseRead(key: "legExt", swappedFrom: "rdl", target: 80, sets: [pending(80, reps: 8), pending(80, reps: 10), pending(80, reps: 11)]))
    }

    @Test("the guard reads current keys: once exercise 5 holds rdl, exercise 4 cannot swap back to its planned rdl")
    func swapBackBlockedByAnotherExercise() throws {
        let f = try fixture()
        #expect(try WorkoutLogStore.swapExercise(f.exercise(3), to: "goblet", targetWeightLb: 52.5, in: f.store.context))
        #expect(try WorkoutLogStore.swapExercise(f.exercise(4), to: "rdl", targetWeightLb: 52.5, in: f.store.context))
        #expect(!(try WorkoutLogStore.swapExercise(f.exercise(3), to: "rdl", targetWeightLb: 52.5, in: f.store.context)))
        #expect(!f.store.context.hasChanges)
        let e4 = try readExercise(3, logID: f.log.id, in: f.store.container)
        #expect(e4.key == "goblet" && e4.swappedFrom == "rdl")
        let e5 = try readExercise(4, logID: f.log.id, in: f.store.container)
        #expect(e5.key == "rdl" && e5.swappedFrom == "curl")
    }
}

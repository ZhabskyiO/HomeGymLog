import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Edges of `WorkoutSnapshotBuilder`: orphan and foreign sets are dropped by `values` and by the set predicate, an
/// empty id list fetches nothing without crashing (an empty log's screen builds exactly that query), and the PR
/// baseline is scoped to its program so an archived program's heavier sets never count.
@MainActor
@Suite struct WorkoutSnapshotBuilderEdgeTests {
    /// Exercise A (latPull, 2 sets), exercise B (lowRow, 1 set) and one set with no exercise, saved.
    private func graph(_ store: TestStore) throws -> (a: LoggedExercise, b: LoggedExercise, orphan: LoggedSet) {
        let a = LoggedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 110)
        let b = LoggedExercise(order: 1, exerciseKey: "lowRow", targetWeightLb: 100)
        store.context.insert(a)
        store.context.insert(b)
        a.sets.append(LoggedSet(order: 1, weightLb: 110, reps: 12))
        a.sets.append(LoggedSet(order: 0, weightLb: 110, reps: 12))
        b.sets.append(LoggedSet(order: 0, weightLb: 100, reps: 12))
        let orphan = LoggedSet(order: 0, weightLb: 999, reps: 1)
        store.context.insert(orphan)
        try store.context.save()
        return (a, b, orphan)
    }

    @Test("values drops orphan sets and sets of exercises not passed in, without trapping")
    func valuesDropsOrphans() throws {
        let store = try makeTestStore()
        let (a, b, orphan) = try graph(store)
        #expect(orphan.exercise == nil)
        let values = WorkoutSnapshotBuilder.values(exercises: [a], sets: [orphan] + a.sets + b.sets)
        #expect(values.count == 1)
        #expect(values[0].id == a.id)
        #expect(Set(values[0].sets.map(\.id)) == Set(a.sets.map(\.id)))
        #expect(!values[0].sets.contains { $0.weightLb == 999 })
    }

    @Test("an exercise with no set rows maps to an empty set list")
    func valuesExerciseWithoutSets() throws {
        let store = try makeTestStore()
        let (a, b, orphan) = try graph(store)
        let values = WorkoutSnapshotBuilder.values(exercises: [a, b], sets: [orphan] + a.sets)
        #expect(values.map(\.exerciseKey) == ["latPull", "lowRow"])
        #expect(values.map(\.sets.count) == [2, 0])
    }

    @Test("the set predicate excludes orphan sets")
    func setPredicateExcludesOrphans() throws {
        let store = try makeTestStore()
        let (a, b, _) = try graph(store)
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetchCount(FetchDescriptor<LoggedSet>()) == 4)
        let matched = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: [a.id, b.id])))
        #expect(matched.count == 3)
        #expect(!matched.contains { $0.weightLb == 999 })
    }

    @Test("the set predicate with an empty id list fetches nothing and does not crash")
    func setPredicateEmptyIDs() throws {
        let store = try makeTestStore()
        _ = try graph(store)
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: []))).isEmpty)
    }

    @Test("the exercise predicate excludes an exercise that belongs to no log")
    func exercisePredicateOrphan() throws {
        let store = try makeTestStore()
        let (_, log) = try insertSampleGraph(in: store.context)
        store.context.insert(LoggedExercise(order: 0, exerciseKey: "curl", targetWeightLb: 27.5))
        try store.context.save()
        let fresh = ModelContext(store.container)
        let rows = try fresh.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        #expect(rows.map(\.exerciseKey).sorted() == ["dbBench", "latPull"])
    }

    #if DEBUG
    @Test("bestsBefore ignores an archived program's heavier finished sets; that program's own baseline sees them")
    func bestsBeforeExcludesArchived() throws {
        let cal = TestCalendar.calendar
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
        let context = container.mainContext
        let current = try #require(try ProgramStore.current(in: context))

        let archived = Program(createdAt: TestCalendar.day(2026, 8, 1), startDate: TestCalendar.day(2026, 8, 3), months: 1, frequency: 3,
                               trainingWeekdays: [0, 2, 4], sessionLengthMinutes: 45, bodyWeightLb: 180, experience: "Intermediate",
                               startingWeightsLb: [:])
        archived.archivedAt = TestCalendar.day(2026, 8, 30)
        context.insert(archived)
        let session = PlannedSession(index: 0, week: 1, phase: .foundation, name: "Full Body A", scheduledDate: TestCalendar.day(2026, 8, 3),
                                     sets: 3, reps: 12, restSeconds: 75,
                                     exercises: [PlannedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 150)])
        archived.sessions.append(session)
        let log = try WorkoutLogStore.start(session: session, at: TestCalendar.day(2026, 8, 3).addingTimeInterval(3600), in: context)
        for set in log.sortedExercises[0].sortedSets {
            try WorkoutLogStore.logSet(set, at: log.startedAt, in: context)
        }
        try WorkoutLogStore.finish(log, at: log.startedAt.addingTimeInterval(1800), in: context)

        let currentBests = try WorkoutSnapshotBuilder.bestsBefore(programID: current.id, in: context)
        #expect(currentBests["latPull"] == 100)
        let archivedBests = try WorkoutSnapshotBuilder.bestsBefore(programID: archived.id, in: context)
        #expect(archivedBests == ["latPull": 150])
    }

    @Test("bestsBefore for an id that matches no program is empty")
    func bestsBeforeUnknownProgram() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: TestCalendar.calendar)
        defer { withExtendedLifetime(container) {} }
        #expect(try WorkoutSnapshotBuilder.bestsBefore(programID: UUID(), in: container.mainContext) == [:])
    }
    #endif
}

import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-33: the six guarded set writers. Values are read back through a fresh `ModelContext`; every no-op also
/// asserts `false` and that the writing context holds no unsaved change.
@MainActor
@Suite struct WorkoutSetWriterTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    /// A fresh store with session `index` started. Session 11: Foundation 3 × 12; session 45: Build 4 × 10.
    private func started(_ index: Int) throws -> (store: TestStore, log: WorkoutLog) {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[index], at: t0, in: store.context)
        return (store, log)
    }

    /// The only log's sets as [exercise][set], read through a fresh context.
    private func freshSets(_ store: TestStore) throws -> [[LoggedSet]] {
        let logs = try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>())
        let log = try #require(logs.first)
        return WorkoutStoreFixtures.sets(of: log)
    }

    @Test("logSet: pending → done with loggedAt; weight, reps, RPE unchanged; a done set is a no-op")
    func logSet() throws {
        let (store, log) = try started(11)
        let set = WorkoutStoreFixtures.sets(of: log)[0][0]
        let at = t0.addingTimeInterval(168)
        let wrote = try WorkoutLogStore.logSet(set, at: at, in: store.context)
        #expect(wrote)
        let fresh = try freshSets(store)
        #expect(fresh[0][0].status == .done && fresh[0][0].loggedAt == at)
        #expect(fresh[0][0].weightLb == 110 && fresh[0][0].reps == 12 && fresh[0][0].rpe == nil && !fresh[0][0].rpeSkipped)
        #expect(fresh[0][1].status == .pending)

        let again = try WorkoutLogStore.logSet(set, at: at.addingTimeInterval(60), in: store.context)
        #expect(!again)
        #expect(!store.context.hasChanges)
        let after = try freshSets(store)
        #expect(after[0][0].loggedAt == at)
    }

    @Test("Save & log set on Build set 2 carries 120 × 11 to sets 3–4 only")
    func saveAndLogCarries() throws {
        let (store, log) = try started(45)
        let sets = WorkoutStoreFixtures.sets(of: log)
        let target = log.sortedExercises[0].targetWeightLb
        let second = log.sortedExercises[1].targetWeightLb
        #expect(sets[0].count == 4 && sets[0][0].reps == 10)
        try WorkoutLogStore.logSet(sets[0][0], at: t0, in: store.context)
        let at = t0.addingTimeInterval(200)
        let wrote = try WorkoutLogStore.saveAndLogSet(sets[0][1], weightLb: 120, reps: 11, at: at, in: store.context)
        #expect(wrote)
        let fresh = try freshSets(store)
        #expect(fresh[0][0].status == .done && fresh[0][0].weightLb == target && fresh[0][0].reps == 10 && fresh[0][0].loggedAt == t0)
        #expect(fresh[0][1].status == .done && fresh[0][1].weightLb == 120 && fresh[0][1].reps == 11 && fresh[0][1].loggedAt == at)
        for s in 2...3 {
            #expect(fresh[0][s].status == .pending && fresh[0][s].weightLb == 120 && fresh[0][s].reps == 11 && fresh[0][s].loggedAt == nil)
        }
        #expect(fresh[1].allSatisfy { $0.status == .pending && $0.weightLb == second && $0.reps == 10 })
    }

    @Test("Save & log set after a skipped set changes only sets 3–4; on the last set only that set")
    func saveAndLogAfterSkip() throws {
        let (store, log) = try started(45)
        let sets = WorkoutStoreFixtures.sets(of: log)
        let target = log.sortedExercises[0].targetWeightLb
        try WorkoutLogStore.logSet(sets[0][0], at: t0, in: store.context)
        try WorkoutLogStore.skipSet(sets[0][1], weightLb: target, reps: 10, at: t0, in: store.context)
        try WorkoutLogStore.saveAndLogSet(sets[0][2], weightLb: 120, reps: 11, at: t0, in: store.context)
        let fresh = try freshSets(store)
        #expect(fresh[0][0].status == .done && fresh[0][0].weightLb == target && fresh[0][0].reps == 10)
        #expect(fresh[0][1].status == .skipped && fresh[0][1].weightLb == target && fresh[0][1].reps == 10)
        #expect(fresh[0][2].status == .done && fresh[0][2].weightLb == 120 && fresh[0][2].reps == 11)
        #expect(fresh[0][3].status == .pending && fresh[0][3].weightLb == 120 && fresh[0][3].reps == 11)

        let (lastStore, lastLog) = try started(45)
        let lastSets = WorkoutStoreFixtures.sets(of: lastLog)
        try WorkoutLogStore.saveAndLogSet(lastSets[0][3], weightLb: 120, reps: 11, at: t0, in: lastStore.context)
        let lastFresh = try freshSets(lastStore)
        #expect(lastFresh[0][3].status == .done && lastFresh[0][3].weightLb == 120 && lastFresh[0][3].reps == 11)
        #expect(lastFresh[0][0..<3].allSatisfy { $0.status == .pending && $0.weightLb == target && $0.reps == 10 })
    }

    @Test("a sibling whose order ties this set's is not carried to")
    func carrySkipsTiedOrder() throws {
        let (store, log) = try started(45)
        let sets = WorkoutStoreFixtures.sets(of: log)
        let target = log.sortedExercises[0].targetWeightLb
        let third = sets[0][2]
        third.order = 1   // ties set 2
        try store.context.save()
        try WorkoutLogStore.saveAndLogSet(sets[0][1], weightLb: 120, reps: 11, at: t0, in: store.context)
        let all = try ModelContext(store.container).fetch(FetchDescriptor<LoggedSet>())
        let freshThird = try #require(all.first { $0.id == third.id })
        let freshFourth = try #require(all.first { $0.id == sets[0][3].id })
        #expect(freshThird.weightLb == target && freshThird.reps == 10 && freshThird.status == .pending)
        #expect(freshFourth.weightLb == 120 && freshFourth.reps == 11 && freshFourth.status == .pending)
    }

    @Test("Skip set stores the draft on that set only; guarded on non-pending")
    func skipSet() throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        let at = t0.addingTimeInterval(90)
        let wrote = try WorkoutLogStore.skipSet(sets[0][0], weightLb: 120, reps: 11, at: at, in: store.context)
        #expect(wrote)
        let fresh = try freshSets(store)
        #expect(fresh[0][0].status == .skipped && fresh[0][0].weightLb == 120 && fresh[0][0].reps == 11)
        #expect(fresh[0][0].loggedAt == at && fresh[0][0].rpe == nil && !fresh[0][0].rpeSkipped)
        #expect(fresh[0][1].status == .pending && fresh[0][1].weightLb == 110 && fresh[0][1].reps == 12)

        let again = try WorkoutLogStore.skipSet(sets[0][0], weightLb: 100, reps: 5, at: at, in: store.context)
        let saveOnSkipped = try WorkoutLogStore.saveAndLogSet(sets[0][0], weightLb: 100, reps: 5, at: at, in: store.context)
        let logOnSkipped = try WorkoutLogStore.logSet(sets[0][0], at: at, in: store.context)
        #expect(!again && !saveOnSkipped && !logOnSkipped && !store.context.hasChanges)
        let after = try freshSets(store)
        #expect(after[0][0].weightLb == 120 && after[0][0].status == .skipped)
    }

    @Test("setRPE writes rpe only; 5 and 11 throw and write nothing; a second rating is a no-op")
    func setRPE() throws {
        let (store, log) = try started(11)
        let set = WorkoutStoreFixtures.sets(of: log)[0][0]
        let onPending = try WorkoutLogStore.setRPE(7, on: set, in: store.context)
        #expect(!onPending && !store.context.hasChanges)

        let at = t0.addingTimeInterval(168)
        try WorkoutLogStore.logSet(set, at: at, in: store.context)
        #expect(throws: WorkoutLogStoreError.invalidRPE(5)) { try WorkoutLogStore.setRPE(5, on: set, in: store.context) }
        #expect(throws: WorkoutLogStoreError.invalidRPE(11)) { try WorkoutLogStore.setRPE(11, on: set, in: store.context) }
        #expect(!store.context.hasChanges)
        let unrated = try freshSets(store)
        #expect(unrated[0][0].rpe == nil)

        let wrote = try WorkoutLogStore.setRPE(7, on: set, in: store.context)
        #expect(wrote)
        let rated = try freshSets(store)[0][0]
        #expect(rated.rpe == 7 && !rated.rpeSkipped && rated.status == .done && rated.loggedAt == at && rated.weightLb == 110 && rated.reps == 12)

        let second = try WorkoutLogStore.setRPE(8, on: set, in: store.context)
        #expect(!second && !store.context.hasChanges)
        let after = try freshSets(store)
        #expect(after[0][0].rpe == 7)
    }

    @Test("a rating after Skip is a no-op")
    func setRPEAfterSkip() throws {
        let (store, log) = try started(11)
        let set = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.logSet(set, at: t0, in: store.context)
        let skipped = try WorkoutLogStore.skipRPE(on: set, in: store.context)
        #expect(skipped)
        let rated = try WorkoutLogStore.setRPE(7, on: set, in: store.context)
        #expect(!rated && !store.context.hasChanges)
        let row = try freshSets(store)[0][0]
        #expect(row.rpe == nil && row.rpeSkipped)
    }

    @Test("skipRPE marks a done unrated set; a second skip, pending, skipped and rated sets are no-ops")
    func skipRPE() throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        try WorkoutLogStore.logSet(sets[0][0], at: t0, in: store.context)
        let wrote = try WorkoutLogStore.skipRPE(on: sets[0][0], in: store.context)
        #expect(wrote)
        let marked = try freshSets(store)
        #expect(marked[0][0].rpeSkipped && marked[0][0].rpe == nil)

        let second = try WorkoutLogStore.skipRPE(on: sets[0][0], in: store.context)
        #expect(!second && !store.context.hasChanges)
        let pending = try WorkoutLogStore.skipRPE(on: sets[1][0], in: store.context)
        #expect(!pending && !store.context.hasChanges)
        try WorkoutLogStore.skipSet(sets[2][0], weightLb: 47.5, reps: 12, at: t0, in: store.context)
        let skippedSet = try WorkoutLogStore.skipRPE(on: sets[2][0], in: store.context)
        #expect(!skippedSet && !store.context.hasChanges)
        try WorkoutLogStore.logSet(sets[3][0], at: t0, in: store.context)
        try WorkoutLogStore.setRPE(7, on: sets[3][0], in: store.context)
        let rated = try WorkoutLogStore.skipRPE(on: sets[3][0], in: store.context)
        #expect(!rated && !store.context.hasChanges)
        let fresh = try freshSets(store)
        #expect(!fresh[1][0].rpeSkipped && !fresh[2][0].rpeSkipped && !fresh[3][0].rpeSkipped && fresh[3][0].rpe == 7)
    }

    @Test("nextExercise skips the exercise's pending sets; no-op while a set awaits RPE or nothing pends")
    func nextExercise() throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        let first = log.sortedExercises[0]
        try WorkoutLogStore.logSet(sets[0][0], at: t0, in: store.context)
        let awaiting = try WorkoutLogStore.nextExercise(first, at: t0, in: store.context)
        #expect(!awaiting && !store.context.hasChanges)
        let untouched = try freshSets(store)
        #expect(untouched[0][1].status == .pending && untouched[0][2].status == .pending)

        try WorkoutLogStore.setRPE(7, on: sets[0][0], in: store.context)
        let at = t0.addingTimeInterval(300)
        let wrote = try WorkoutLogStore.nextExercise(first, at: at, in: store.context)
        #expect(wrote)
        let fresh = try freshSets(store)
        #expect(fresh[0][0].status == .done && fresh[0][0].rpe == 7)
        #expect(fresh[0][1].status == .skipped && fresh[0][1].loggedAt == at && fresh[0][1].weightLb == 110)
        #expect(fresh[0][2].status == .skipped && fresh[0][2].loggedAt == at)
        #expect(fresh[1].allSatisfy { $0.status == .pending && $0.loggedAt == nil })

        let nothingLeft = try WorkoutLogStore.nextExercise(first, at: at, in: store.context)
        #expect(!nothingLeft && !store.context.hasChanges)
    }
}

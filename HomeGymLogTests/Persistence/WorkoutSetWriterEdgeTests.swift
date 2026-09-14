import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-33 edges of the guarded set writers: carry never reaches a non-pending later sibling, the last set carries
/// nothing, Skip set leaves every other row alone, Next exercise on a finished exercise, a skipped rating unblocks Next
/// exercise, and the RPE range at both ends. Values are read back through a fresh `ModelContext`.
@MainActor
@Suite struct WorkoutSetWriterEdgeTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    /// A fresh store with session `index` started (11: Foundation 3 × 12 at 110/100/47.5/52.5/27.5; 45: Build 4 × 10).
    /// The returned `TestStore` holds the container for the whole test (26.5 crashes on a released container).
    private func started(_ index: Int) throws -> (store: TestStore, log: WorkoutLog) {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[index], at: t0, in: store.context)
        return (store, log)
    }

    private func freshSets(_ store: TestStore) throws -> [[LoggedSet]] {
        let log = try #require(try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>()).first)
        return WorkoutStoreFixtures.sets(of: log)
    }

    private struct Snapshot: Equatable {
        let weightLb: Double, reps: Int, status: SetStatus, rpe: Int?, rpeSkipped: Bool, loggedAt: Date?
        init(_ set: LoggedSet) {
            weightLb = set.weightLb; reps = set.reps; status = set.status; rpe = set.rpe; rpeSkipped = set.rpeSkipped; loggedAt = set.loggedAt
        }
    }

    @Test("Save & log set never carries to a later sibling that is already skipped or done")
    func carrySkipsNonPendingLaterSiblings() throws {
        let (store, log) = try started(45)
        let sets = WorkoutStoreFixtures.sets(of: log)
        let target = sets[0][0].weightLb
        try WorkoutLogStore.skipSet(sets[0][2], weightLb: target, reps: 10, at: t0, in: store.context)
        try WorkoutLogStore.logSet(sets[0][3], at: t0, in: store.context)
        try WorkoutLogStore.saveAndLogSet(sets[0][1], weightLb: 120, reps: 11, at: t0.addingTimeInterval(60), in: store.context)
        let fresh = try freshSets(store)
        #expect(fresh[0][1].status == .done && fresh[0][1].weightLb == 120 && fresh[0][1].reps == 11)
        #expect(fresh[0][2].status == .skipped && fresh[0][2].weightLb == target && fresh[0][2].reps == 10)
        #expect(fresh[0][3].status == .done && fresh[0][3].weightLb == target && fresh[0][3].reps == 10)
        #expect(fresh[0][0].status == .pending && fresh[0][0].weightLb == target && fresh[0][0].reps == 10)
    }

    @Test("Save & log set on an exercise's last set carries nothing: earlier sets and every later exercise keep their values")
    func lastSetCarriesNothing() throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        for s in 0..<2 {
            let at = t0.addingTimeInterval(Double(60 * (s + 1)))
            try WorkoutLogStore.logSet(sets[0][s], at: at, in: store.context)
            try WorkoutLogStore.setRPE(7, on: sets[0][s], at: at, in: store.context)
        }
        let wrote = try WorkoutLogStore.saveAndLogSet(sets[0][2], weightLb: 120, reps: 11, at: t0.addingTimeInterval(180), in: store.context)
        #expect(wrote)
        let fresh = try freshSets(store)
        #expect(fresh[0].map(\.weightLb) == [110, 110, 120])
        #expect(fresh[0].map(\.reps) == [12, 12, 11])
        #expect(fresh[0].map(\.rpe) == [7, 7, nil])
        #expect(fresh[0].map(\.loggedAt) == [t0.addingTimeInterval(60), t0.addingTimeInterval(120), t0.addingTimeInterval(180)])
        #expect(fresh[1...].map { $0.map(\.weightLb) } == [[100, 100, 100], [47.5, 47.5, 47.5], [52.5, 52.5, 52.5], [27.5, 27.5, 27.5]])
        #expect(fresh[1...].allSatisfy { $0.allSatisfy { $0.status == .pending && $0.reps == 12 && $0.loggedAt == nil } })
    }

    @Test("Skip set with a changed draft leaves all 19 other sets of the log exactly as they were")
    func skipSetTouchesNoOtherSet() throws {
        let (store, log) = try started(45)
        let before = try freshSets(store).flatMap { $0 }
        #expect(before.count == 20)   // 5 exercises × 4 sets
        let skippedID = WorkoutStoreFixtures.sets(of: log)[0][0].id
        try WorkoutLogStore.skipSet(WorkoutStoreFixtures.sets(of: log)[0][0], weightLb: 120, reps: 11, at: t0, in: store.context)
        let after = try freshSets(store).flatMap { $0 }
        let beforeOthers = Dictionary(uniqueKeysWithValues: before.filter { $0.id != skippedID }.map { ($0.id, Snapshot($0)) })
        let afterOthers = Dictionary(uniqueKeysWithValues: after.filter { $0.id != skippedID }.map { ($0.id, Snapshot($0)) })
        #expect(afterOthers.count == 19)
        #expect(afterOthers == beforeOthers)
        let skipped = try #require(after.first { $0.id == skippedID })
        #expect(skipped.status == .skipped && skipped.weightLb == 120 && skipped.reps == 11)
    }

    enum Finished: String, CaseIterable, Sendable { case doneAndRated, skipped }

    @Test("Next exercise on an exercise whose sets are all done or all skipped writes nothing", arguments: Finished.allCases)
    func nextExerciseOnFinishedExercise(finished: Finished) throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        for s in 0..<3 {
            let at = t0.addingTimeInterval(Double(60 * (s + 1)))
            switch finished {
            case .doneAndRated:
                try WorkoutLogStore.logSet(sets[0][s], at: at, in: store.context)
                try WorkoutLogStore.setRPE(8, on: sets[0][s], at: at, in: store.context)
            case .skipped:
                try WorkoutLogStore.skipSet(sets[0][s], weightLb: 110, reps: 12, at: at, in: store.context)
            }
        }
        let before = try freshSets(store).flatMap { $0 }.map(Snapshot.init)
        let wrote = try WorkoutLogStore.nextExercise(log.sortedExercises[0], at: t0.addingTimeInterval(900), in: store.context)
        #expect(!wrote)
        #expect(!store.context.hasChanges)
        let after = try freshSets(store).flatMap { $0 }.map(Snapshot.init)
        #expect(after == before)
        #expect(after[0...2].allSatisfy { $0.loggedAt != t0.addingTimeInterval(900) })
    }

    @Test("a skipped rating unblocks Next exercise: remaining sets skip and the flow moves to exercise 2")
    func skipRPEThenNextExercise() throws {
        let (store, log) = try started(11)
        let sets = WorkoutStoreFixtures.sets(of: log)
        try WorkoutLogStore.logSet(sets[0][0], at: t0.addingTimeInterval(60), in: store.context)
        try WorkoutLogStore.skipRPE(on: sets[0][0], at: t0.addingTimeInterval(60), in: store.context)
        let at = t0.addingTimeInterval(120)
        let wrote = try WorkoutLogStore.nextExercise(log.sortedExercises[0], at: at, in: store.context)
        #expect(wrote)
        let fresh = try freshSets(store)
        #expect(fresh[0][0].status == .done && fresh[0][0].rpe == nil && fresh[0][0].rpeSkipped)
        #expect(fresh[0][1...].allSatisfy { $0.status == .skipped && $0.loggedAt == at && !$0.rpeSkipped })

        let freshLog = try #require(try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>()).first)
        let exercises = freshLog.sortedExercises
        let values = WorkoutSnapshotBuilder.values(exercises: exercises, sets: exercises.flatMap(\.sets))
        #expect(WorkoutFlow.state(exercises: values) == .logging(exercise: 1, set: 0))
    }

    @Test("RPE 6 and 10, the ends of the range, are stored", arguments: [6, 10])
    func rpeRangeEnds(rpe: Int) throws {
        let (store, log) = try started(11)
        let set = WorkoutStoreFixtures.sets(of: log)[0][0]
        try WorkoutLogStore.logSet(set, at: t0, in: store.context)
        let wrote = try WorkoutLogStore.setRPE(rpe, on: set, at: t0, in: store.context)
        #expect(wrote)
        #expect(try freshSets(store)[0][0].rpe == rpe)
    }

    @Test("an RPE below the range, or far above it, throws even on a pending set and writes nothing", arguments: [-1, 0, 100])
    func rpeOutOfRangeThrowsFirst(rpe: Int) throws {
        let (store, log) = try started(11)
        let set = WorkoutStoreFixtures.sets(of: log)[0][0]
        #expect(throws: WorkoutLogStoreError.invalidRPE(rpe)) { try WorkoutLogStore.setRPE(rpe, on: set, at: t0, in: store.context) }
        try WorkoutLogStore.logSet(set, at: t0, in: store.context)
        #expect(throws: WorkoutLogStoreError.invalidRPE(rpe)) { try WorkoutLogStore.setRPE(rpe, on: set, at: t0, in: store.context) }
        #expect(!store.context.hasChanges)
        let fresh = try freshSets(store)[0][0]
        #expect(fresh.rpe == nil && !fresh.rpeSkipped && fresh.status == .done)
    }
}

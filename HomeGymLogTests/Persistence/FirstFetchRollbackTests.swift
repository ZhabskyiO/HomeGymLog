import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Researcher addendum P4 test rule, applied to the rows the other failed-save suites only read second or from objects.
/// On iOS 26.5 only the **first** same-context fetch after a failed save returned the unsaved values (restore-then-rollback),
/// so a writer that changes several rows needs one run per row fetched first. Here each case fetches one row by id as the
/// very first read after the refused save: the log's rest instants for the set and rating writers, the carried sibling of
/// Save & log, the last set Next exercise skips, the session `finish` completes, and all three rows `swapExercise` writes.
/// Every case also pins `hasChanges == true` (rollback first, then restore; AC-25) and the store's copy.
///
/// Forced failure: the fixture is saved to an on-disk store, reopened through a second container with `allowsSave: false`.
/// Both containers stay bound until every value is read; `rollback()` discards the restored originals before the store file
/// is removed (gotchas 2026-09-14: pending changes abort the 26.5 test process once the file is gone).
@MainActor
@Suite struct FirstFetchRollbackTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    enum Case: String, CaseIterable, Sendable {
        case logSetThenLog, skipSetThenLog, nextExerciseThenLog, saveAndLogSetThenCarriedSet, nextExerciseThenLastSkippedSet,
             setRPEThenLog, skipRPEThenLog, finishThenSession, swapThenExercise, swapThenSet, swapThenSession
    }

    private static let session11Planned = [
        PlannedExercise(order: 0, exerciseKey: "latPull", targetWeightLb: 110),
        PlannedExercise(order: 1, exerciseKey: "lowRow", targetWeightLb: 100),
        PlannedExercise(order: 2, exerciseKey: "dbRow", targetWeightLb: 47.5),
        PlannedExercise(order: 3, exerciseKey: "rdl", targetWeightLb: 52.5),
        PlannedExercise(order: 4, exerciseKey: "curl", targetWeightLb: 27.5),
    ]

    private struct SetValues: Equatable {
        let status: SetStatus, weightLb: Double, reps: Int, rpe: Int?, rpeSkipped: Bool, loggedAt: Date?
    }

    private enum RowValues: Equatable {
        case set(SetValues)
        case log(restStartedAt: Date?, restEndsAt: Date?, finishedAt: Date?)
        case session(statusRaw: String, exercises: [PlannedExercise])
        case exercise(key: String, swappedFromKey: String?, targetWeightLb: Double)
    }

    private enum Target {
        case set(exercise: Int, set: Int), log, session, exercise(Int)
    }

    /// Ids read before the write, so the first fetch needs no other read.
    private struct IDs {
        let log: UUID
        let session: UUID
        let exercises: [UUID]
        let sets: [[UUID]]
    }

    private struct Outcome {
        let threw: Bool
        let before: RowValues
        let firstFetch: RowValues
        let hasChanges: Bool
        let inStore: RowValues
    }

    /// `resting`: E1S1 logged and rated at t0 + 60, so a rest t0 + 60 … t0 + 135 is stored. Otherwise E1S1 is done and unrated.
    private func isResting(_ testCase: Case) -> Bool {
        switch testCase {
        case .setRPEThenLog, .skipRPEThenLog, .finishThenSession: return false
        default: return true
        }
    }

    private func target(_ testCase: Case) -> Target {
        switch testCase {
        case .logSetThenLog, .skipSetThenLog, .nextExerciseThenLog, .setRPEThenLog, .skipRPEThenLog: return .log
        case .saveAndLogSetThenCarriedSet: return .set(exercise: 0, set: 2)
        case .nextExerciseThenLastSkippedSet: return .set(exercise: 1, set: 2)
        case .finishThenSession, .swapThenSession: return .session
        case .swapThenExercise: return .exercise(3)
        case .swapThenSet: return .set(exercise: 3, set: 1)
        }
    }

    /// Typed from the fixture recipe, so a case whose row would not change under the write cannot pass vacuously.
    private func expectedBefore(_ testCase: Case) -> RowValues {
        let pendingSet = { (lb: Double) in RowValues.set(SetValues(status: .pending, weightLb: lb, reps: 12, rpe: nil, rpeSkipped: false, loggedAt: nil)) }
        switch testCase {
        case .logSetThenLog, .skipSetThenLog, .nextExerciseThenLog:
            return .log(restStartedAt: t0.addingTimeInterval(60), restEndsAt: t0.addingTimeInterval(135), finishedAt: nil)
        case .setRPEThenLog, .skipRPEThenLog: return .log(restStartedAt: nil, restEndsAt: nil, finishedAt: nil)
        case .saveAndLogSetThenCarriedSet: return pendingSet(110)
        case .nextExerciseThenLastSkippedSet: return pendingSet(100)
        case .finishThenSession, .swapThenSession: return .session(statusRaw: SessionStatus.pending.rawValue, exercises: Self.session11Planned)
        case .swapThenExercise: return .exercise(key: "rdl", swappedFromKey: nil, targetWeightLb: 52.5)
        case .swapThenSet: return pendingSet(52.5)
        }
    }

    private func perform(_ testCase: Case, on log: WorkoutLog, in context: ModelContext) throws {
        let sets = WorkoutStoreFixtures.sets(of: log)
        let at = t0.addingTimeInterval(90)
        switch testCase {
        case .logSetThenLog: try WorkoutLogStore.logSet(sets[0][1], at: at, in: context)
        case .skipSetThenLog: try WorkoutLogStore.skipSet(sets[0][1], weightLb: 120, reps: 11, at: at, in: context)
        case .nextExerciseThenLog, .nextExerciseThenLastSkippedSet: try WorkoutLogStore.nextExercise(log.sortedExercises[1], at: at, in: context)
        case .saveAndLogSetThenCarriedSet: try WorkoutLogStore.saveAndLogSet(sets[0][1], weightLb: 120, reps: 11, at: at, in: context)
        case .setRPEThenLog: try WorkoutLogStore.setRPE(7, on: sets[0][0], at: at, in: context)
        case .skipRPEThenLog: try WorkoutLogStore.skipRPE(on: sets[0][0], at: at, in: context)
        case .finishThenSession: try WorkoutLogStore.finish(log, at: at, in: context)
        case .swapThenExercise, .swapThenSet, .swapThenSession:
            try WorkoutLogStore.swapExercise(log.sortedExercises[3], to: "legExt", targetWeightLb: 80, in: context)
        }
    }

    private func setValues(_ set: LoggedSet) -> SetValues {
        SetValues(status: set.status, weightLb: set.weightLb, reps: set.reps, rpe: set.rpe, rpeSkipped: set.rpeSkipped, loggedAt: set.loggedAt)
    }

    private func sessionValues(_ session: PlannedSession) -> RowValues {
        .session(statusRaw: session.statusRaw, exercises: session.exercises.sorted { $0.order < $1.order })
    }

    private func objectValues(_ target: Target, of log: WorkoutLog) throws -> RowValues {
        switch target {
        case .set(let e, let s): return .set(setValues(WorkoutStoreFixtures.sets(of: log)[e][s]))
        case .log: return .log(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, finishedAt: log.finishedAt)
        case .session: return sessionValues(try #require(log.session))
        case .exercise(let e):
            let exercise = log.sortedExercises[e]
            return .exercise(key: exercise.exerciseKey, swappedFromKey: exercise.swappedFromKey, targetWeightLb: exercise.targetWeightLb)
        }
    }

    /// One fetch by id of the target row. In the writing context it must be the first fetch after the failure.
    private func fetchValues(_ target: Target, ids: IDs, in context: ModelContext) throws -> RowValues {
        switch target {
        case .set(let e, let s):
            let id = ids.sets[e][s]
            return .set(setValues(try #require(try context.fetch(FetchDescriptor<LoggedSet>(predicate: #Predicate { $0.id == id })).first)))
        case .log:
            let id = ids.log
            let row = try #require(try context.fetch(FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == id })).first)
            return .log(restStartedAt: row.restStartedAt, restEndsAt: row.restEndsAt, finishedAt: row.finishedAt)
        case .session:
            let id = ids.session
            return sessionValues(try #require(try context.fetch(FetchDescriptor<PlannedSession>(predicate: #Predicate { $0.id == id })).first))
        case .exercise(let e):
            let id = ids.exercises[e]
            let row = try #require(try context.fetch(FetchDescriptor<LoggedExercise>(predicate: #Predicate { $0.id == id })).first)
            return .exercise(key: row.exerciseKey, swappedFromKey: row.swappedFromKey, targetWeightLb: row.targetWeightLb)
        }
    }

    private func run(_ testCase: Case, storeAt url: URL) throws -> Outcome {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: setup)
        let started = try WorkoutLogStore.start(session: rows[11], at: t0, in: setup)
        let first = WorkoutStoreFixtures.sets(of: started)[0][0]
        try WorkoutLogStore.logSet(first, at: t0.addingTimeInterval(60), in: setup)
        if isResting(testCase) { try WorkoutLogStore.setRPE(7, on: first, at: t0.addingTimeInterval(60), in: setup) }

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = ModelContext(readOnly)
        let log = try #require(try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let ids = IDs(log: log.id, session: try #require(log.session).id, exercises: log.sortedExercises.map(\.id),
                      sets: WorkoutStoreFixtures.sets(of: log).map { $0.map(\.id) })
        let rowTarget = target(testCase)
        let before = try objectValues(rowTarget, of: log)
        var threw = false
        do { try perform(testCase, on: log, in: context) } catch { threw = true }
        let firstFetch = try fetchValues(rowTarget, ids: ids, in: context)   // the first read of any kind after the failure
        let hasChanges = context.hasChanges
        let inStore = try fetchValues(rowTarget, ids: ids, in: ModelContext(writer))
        context.rollback()   // field writers leave no insert or delete pending; discard the restored originals before the file goes
        withExtendedLifetime((writer, readOnly)) {}   // 26.5 crashes when a container is released while its models are read
        return Outcome(threw: threw, before: before, firstFetch: firstFetch, hasChanges: hasChanges, inStore: inStore)
    }

    private func outcome(_ testCase: Case) throws -> Outcome {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("first-fetch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try run(testCase, storeAt: dir.appendingPathComponent("first-fetch.store")) }
        try? FileManager.default.removeItem(at: dir)
        return try result.get()
    }

    @Test("a failed save leaves the row as it was in the writing context's first fetch by id, holds the originals as changes, and keeps the store",
          arguments: Case.allCases)
    func firstFetchAfterFailure(testCase: Case) throws {
        let result = try outcome(testCase)
        #expect(result.before == expectedBefore(testCase))
        #expect(result.threw)
        #expect(result.firstFetch == result.before, "first same-context fetch of the row after the failure")
        #expect(result.hasChanges, "rollback first, then restore: the restored originals are pending (addendum P4)")
        #expect(result.inStore == result.before)
    }
}

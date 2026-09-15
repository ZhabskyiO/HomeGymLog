import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Failed saves for the rest-affecting writer paths the other two rollback suites leave out. `WorkoutCommitRollbackTests`
/// runs every set writer with no rest stored; `RestCommitRollbackTests` runs +30s, Skip, Log set and Skip set on E1S2 during
/// a live rest. Here: Save & log set (with its carry) and Next exercise during a live rest, Skip set on the last pending set
/// (the clearing branch), and both rating writers over a stored stale rest, where the snapshot must put back non-nil
/// instants rather than nil.
///
/// The failure is forced as in those suites: the fixture goes to an on-disk store, reopened through a second container
/// configured `allowsSave: false`. Both containers stay bound until every value is read; the directory is removed after.
@MainActor
@Suite struct RestWriterRollbackTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    enum Action: String, CaseIterable, Sendable {
        case saveAndLogSetDuringRest, nextExerciseDuringRest, skipLastSetDuringRest, setRPEOverStaleRest, skipRPEOverStaleRest
    }

    private struct SetValues: Equatable {
        let status: SetStatus, weightLb: Double, reps: Int, rpe: Int?, rpeSkipped: Bool, loggedAt: Date?
    }

    private struct LogValues: Equatable {
        let sets: [[SetValues]]
        let restStartedAt: Date?
        let restEndsAt: Date?
    }

    private struct Outcome {
        let threw: Bool
        let before: LogValues
        let inWritingContext: LogValues
        let hasChanges: Bool
        let inStore: LogValues
        /// The written set from the objects before the write, and through the writing context's first fetch after the
        /// failure (researcher addendum P4: on 26.5 only that first fetch returned unsaved values under restore-then-rollback).
        let setBefore: SetValues
        let setFirstFetch: SetValues
    }

    private func setValues(_ set: LoggedSet) -> SetValues {
        SetValues(status: set.status, weightLb: set.weightLb, reps: set.reps, rpe: set.rpe, rpeSkipped: set.rpeSkipped, loggedAt: set.loggedAt)
    }

    /// The set each action writes.
    private func writtenSet(_ action: Action, of log: WorkoutLog) -> LoggedSet {
        let sets = WorkoutStoreFixtures.sets(of: log)
        switch action {
        case .saveAndLogSetDuringRest, .nextExerciseDuringRest: return sets[0][1]
        case .skipLastSetDuringRest: return sets[4][2]
        case .setRPEOverStaleRest, .skipRPEOverStaleRest: return sets[0][0]
        }
    }

    private func values(_ log: WorkoutLog) -> LogValues {
        LogValues(sets: WorkoutStoreFixtures.sets(of: log).map { exercise in
            exercise.map { SetValues(status: $0.status, weightLb: $0.weightLb, reps: $0.reps, rpe: $0.rpe, rpeSkipped: $0.rpeSkipped,
                                     loggedAt: $0.loggedAt) }
        }, restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt)
    }

    /// The instants each fixture stores before the refused write, typed from the fixture recipe below.
    private func storedRest(_ action: Action) -> (startedAt: Date, endsAt: Date) {
        switch action {
        case .saveAndLogSetDuringRest, .nextExerciseDuringRest: return (t0.addingTimeInterval(60), t0.addingTimeInterval(135))
        case .skipLastSetDuringRest: return (t0.addingTimeInterval(840), t0.addingTimeInterval(915))
        case .setRPEOverStaleRest, .skipRPEOverStaleRest: return (t0.addingTimeInterval(-100), t0.addingTimeInterval(-25))
        }
    }

    /// Session 11 started at t0, then: during rest, E1S1 logged and rated at t0 + 60; last set, sets 1–14 logged and rated
    /// at t0 + 60·k (E5S3 pending); stale rest, E1S1 logged unrated at t0 + 60 and a rest t0 − 100 … t0 − 25 stored by hand.
    private func writeFixture(_ action: Action, in context: ModelContext) throws {
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: context)
        let log = try WorkoutLogStore.start(session: rows[11], at: t0, in: context)
        let sets = WorkoutStoreFixtures.sets(of: log).flatMap { $0 }
        switch action {
        case .saveAndLogSetDuringRest, .nextExerciseDuringRest:
            try WorkoutLogStore.logSet(sets[0], at: t0.addingTimeInterval(60), in: context)
            try WorkoutLogStore.setRPE(7, on: sets[0], at: t0.addingTimeInterval(60), in: context)
        case .skipLastSetDuringRest:
            for (k, set) in sets.enumerated() where k < 14 {
                let at = t0.addingTimeInterval(Double(60 * (k + 1)))
                try WorkoutLogStore.logSet(set, at: at, in: context)
                try WorkoutLogStore.setRPE(7, on: set, at: at, in: context)
            }
        case .setRPEOverStaleRest, .skipRPEOverStaleRest:
            try WorkoutLogStore.logSet(sets[0], at: t0.addingTimeInterval(60), in: context)
            log.restStartedAt = t0.addingTimeInterval(-100)
            log.restEndsAt = t0.addingTimeInterval(-25)
            try context.save()
        }
    }

    private func perform(_ action: Action, on log: WorkoutLog, in context: ModelContext) throws {
        let sets = WorkoutStoreFixtures.sets(of: log)
        switch action {
        case .saveAndLogSetDuringRest:
            try WorkoutLogStore.saveAndLogSet(sets[0][1], weightLb: 120, reps: 10, at: t0.addingTimeInterval(90), in: context)
        case .nextExerciseDuringRest:
            try WorkoutLogStore.nextExercise(log.sortedExercises[0], at: t0.addingTimeInterval(90), in: context)
        case .skipLastSetDuringRest:
            try WorkoutLogStore.skipSet(sets[4][2], weightLb: 30, reps: 10, at: t0.addingTimeInterval(880), in: context)
        case .setRPEOverStaleRest:
            try WorkoutLogStore.setRPE(8, on: sets[0][0], at: t0.addingTimeInterval(120), in: context)
        case .skipRPEOverStaleRest:
            try WorkoutLogStore.skipRPE(on: sets[0][0], at: t0.addingTimeInterval(120), in: context)
        }
    }

    private func run(_ action: Action, storeAt url: URL) throws -> Outcome {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        try writeFixture(action, in: ModelContext(writer))

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = ModelContext(readOnly)
        let log = try #require(try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let before = values(log)
        let written = writtenSet(action, of: log)
        let setBefore = setValues(written)
        let setID = written.id
        var threw = false
        do { try perform(action, on: log, in: context) } catch { threw = true }
        // First fetch after the failure, before any other read: a later one hides the 26.5 behaviour.
        let fetched = try context.fetch(FetchDescriptor<LoggedSet>(predicate: #Predicate { $0.id == setID }))
        let setFirstFetch = setValues(try #require(fetched.first))
        let inWritingContext = values(log)
        let hasChanges = context.hasChanges
        let store = ModelContext(writer)
        let storeLog = try #require(try store.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let inStore = values(storeLog)
        // Every value is read: discard the restored originals the failed write left pending. Otherwise SwiftData processes
        // them on a timer after `outcome` has removed the store file, faults a row from the missing file and aborts the test
        // process (NSInternalInconsistencyException, Cocoa 256, seen on 26.5). Safe: a field writer has no insert or delete pending.
        context.rollback()
        withExtendedLifetime((writer, readOnly, store)) {}   // 26.5 crashes when a container is released while its models are read
        return Outcome(threw: threw, before: before, inWritingContext: inWritingContext, hasChanges: hasChanges, inStore: inStore,
                       setBefore: setBefore, setFirstFetch: setFirstFetch)
    }

    private func outcome(_ action: Action) throws -> Outcome {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rest-writer-rollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try run(action, storeAt: dir.appendingPathComponent("rest-writer-rollback.store")) }
        try? FileManager.default.removeItem(at: dir)
        return try result.get()
    }

    @Test("a failed save rethrows and leaves every set and the stored rest as they were, on screen and in the store",
          arguments: Action.allCases)
    func failedSaveRestoresRest(action: Action) throws {
        let result = try outcome(action)
        let rest = storedRest(action)
        #expect(result.before.restStartedAt == rest.startedAt)
        #expect(result.before.restEndsAt == rest.endsAt)
        #expect(result.threw)
        #expect(result.hasChanges, "rollback first, then restore: the restored originals are pending (addendum P4)")
        #expect(result.inWritingContext == result.before)
        #expect(result.inStore == result.before)
        // Researcher addendum P4: what a screen's @Query re-fetch returns. Red on 26.5 with restore-then-rollback.
        #expect(result.setFirstFetch == result.setBefore, "first same-context fetch of the written set after the failure")
    }
}

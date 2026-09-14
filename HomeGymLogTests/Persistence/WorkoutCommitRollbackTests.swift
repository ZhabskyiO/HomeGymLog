import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// Spec 4.2 failure policy and §6 "Save fails": no unsaved change is ever shown as logged. Field writers restore the
/// fields they changed, then roll back; `start` rehearses its insert in a scratch context so a refusing store throws
/// before the writing context changes; `discard` leaves its deletes pending for the next successful save.
///
/// A failed save is forced by writing the rows to an on-disk store, then reopening the same file through a second
/// container configured `allowsSave: false`: its `save()` throws NSCocoaErrorDomain 513. The writer runs on that
/// read-only context. Two halves are checked: the store (a fresh context) and the rows the writing context holds, which
/// are the rows a screen's `@Query` on that context shows. Containers live inside `run`, so the temporary store file
/// is removed only after they are released.
@MainActor
@Suite struct WorkoutCommitRollbackTests {
    private let t0 = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    /// The writer under test. Rows before the call: session 11 started, E1S1 done with no rating, everything else pending.
    enum Action: String, CaseIterable, Sendable {
        case logSet, saveAndLogSet, skipSet, setRPE, skipRPE, nextExercise, finish
    }

    private struct SetValues: Equatable {
        let status: SetStatus, weightLb: Double, reps: Int, rpe: Int?, rpeSkipped: Bool, loggedAt: Date?
    }

    private struct LogValues: Equatable {
        let sets: [[SetValues]]
        let finishedAt: Date?
        let sessionStatus: SessionStatus?

        /// One line per field that differs from `other`, e.g. "E1S2 status pending → done", so a failure reads short.
        func changes(from other: LogValues) -> [String] {
            var lines: [String] = []
            func note<T: Equatable>(_ label: String, _ old: T, _ new: T) { if old != new { lines.append("\(label) \(old) → \(new)") } }
            for (e, exercise) in sets.enumerated() {
                for (s, new) in exercise.enumerated() {
                    guard other.sets.indices.contains(e), other.sets[e].indices.contains(s) else { lines.append("E\(e + 1)S\(s + 1) added"); continue }
                    let old = other.sets[e][s], label = "E\(e + 1)S\(s + 1)"
                    note("\(label) status", old.status, new.status)
                    note("\(label) weightLb", old.weightLb, new.weightLb)
                    note("\(label) reps", old.reps, new.reps)
                    note("\(label) rpe", String(describing: old.rpe), String(describing: new.rpe))
                    note("\(label) rpeSkipped", old.rpeSkipped, new.rpeSkipped)
                    note("\(label) loggedAt", String(describing: old.loggedAt), String(describing: new.loggedAt))
                }
            }
            note("set count", other.sets.flatMap { $0 }.count, sets.flatMap { $0 }.count)
            note("finishedAt", String(describing: other.finishedAt), String(describing: finishedAt))
            note("session status", String(describing: other.sessionStatus), String(describing: sessionStatus))
            return lines
        }
    }

    private struct Outcome {
        let threw: Bool
        let before: LogValues
        let inWritingContext: LogValues
        let hasChanges: Bool
        let inStore: LogValues
    }

    private func values(_ log: WorkoutLog) -> LogValues {
        LogValues(sets: WorkoutStoreFixtures.sets(of: log).map { exercise in
            exercise.map { SetValues(status: $0.status, weightLb: $0.weightLb, reps: $0.reps, rpe: $0.rpe, rpeSkipped: $0.rpeSkipped, loggedAt: $0.loggedAt) }
        }, finishedAt: log.finishedAt, sessionStatus: log.session?.status)
    }

    private func perform(_ action: Action, on log: WorkoutLog, in context: ModelContext) throws {
        let sets = WorkoutStoreFixtures.sets(of: log)
        let at = t0.addingTimeInterval(600)
        switch action {
        case .logSet: try WorkoutLogStore.logSet(sets[0][1], at: at, in: context)
        case .saveAndLogSet: try WorkoutLogStore.saveAndLogSet(sets[0][1], weightLb: 120, reps: 11, at: at, in: context)
        case .skipSet: try WorkoutLogStore.skipSet(sets[0][1], weightLb: 120, reps: 11, at: at, in: context)
        case .setRPE: try WorkoutLogStore.setRPE(7, on: sets[0][0], in: context)
        case .skipRPE: try WorkoutLogStore.skipRPE(on: sets[0][0], in: context)
        case .nextExercise: try WorkoutLogStore.nextExercise(log.sortedExercises[1], at: at, in: context)
        case .finish: try WorkoutLogStore.finish(log, at: at, in: context)
        }
    }

    private func run(_ action: Action, storeAt url: URL) throws -> Outcome {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: setup)
        let started = try WorkoutLogStore.start(session: rows[11], at: t0, in: setup)
        try WorkoutLogStore.logSet(WorkoutStoreFixtures.sets(of: started)[0][0], at: t0.addingTimeInterval(60), in: setup)

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = ModelContext(readOnly)
        let log = try #require(try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let before = values(log)
        var threw = false
        do { try perform(action, on: log, in: context) } catch { threw = true }
        let inWritingContext = values(log)
        let hasChanges = context.hasChanges
        let storeLog = try #require(try ModelContext(writer).fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let inStore = values(storeLog)
        withExtendedLifetime((writer, readOnly)) {}   // 26.5 crashes when a container is released while its models are read
        return Outcome(threw: threw, before: before, inWritingContext: inWritingContext, hasChanges: hasChanges, inStore: inStore)
    }

    private func outcome(_ action: Action) throws -> Outcome {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try run(action, storeAt: dir.appendingPathComponent("rollback.store")) }
        try? FileManager.default.removeItem(at: dir)
        return try result.get()
    }

    @Test("the fixture's rows before any failed write: E1S1 done unrated, 14 sets pending, log in progress")
    func fixtureShape() throws {
        let result = try outcome(.logSet)
        #expect(result.before.sets.flatMap { $0 }.map(\.status).filter { $0 == .pending }.count == 14)
        #expect(result.before.sets[0][0].status == .done && result.before.sets[0][0].rpe == nil)
        #expect(result.before.finishedAt == nil && result.before.sessionStatus == .pending)
    }

    @Test("a failed save rethrows, leaves no unsaved change, and the store keeps the rows as they were", arguments: Action.allCases)
    func failedSaveLeavesStoreUnchanged(action: Action) throws {
        let result = try outcome(action)
        #expect(result.threw)
        #expect(!result.hasChanges)
        #expect(result.inStore.changes(from: result.before) == [])
        #expect(result.inStore == result.before)
    }

    /// Spec-required. `ModelContext.rollback()` alone clears `hasChanges` but leaves every mutated property on the
    /// registered rows (a refetch in the same context returns them too, on 17.5 and 26.5), so `WorkoutLogStore.commit`
    /// restores a snapshot of the changed fields before rolling back. Red before that fix.
    @Test("a failed save leaves the writing context's rows showing the values from before the write", arguments: Action.allCases)
    func failedSaveRevertsRowsInWritingContext(action: Action) throws {
        let result = try outcome(action)
        #expect(result.threw)
        #expect(result.inWritingContext.changes(from: result.before) == [])
    }

    // MARK: start and discard (inserts and deletes: on 17.5 `rollback()` crashes the process while either is pending)

    /// The same fixture as `run` (session 11 started, E1S1 done), reopened read-only; `body` gets that context and the
    /// writable container for reading the store.
    private func withReadOnlyContext(_ body: (ModelContext, ModelContainer) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try readOnlyContext(storeAt: dir.appendingPathComponent("rollback.store"), body) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func readOnlyContext(storeAt url: URL, _ body: (ModelContext, ModelContainer) throws -> Void) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: setup)
        let started = try WorkoutLogStore.start(session: rows[11], at: t0, in: setup)
        try WorkoutLogStore.logSet(WorkoutStoreFixtures.sets(of: started)[0][0], at: t0.addingTimeInterval(60), in: setup)
        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        try body(ModelContext(readOnly), writer)
        withExtendedLifetime((writer, readOnly)) {}   // 26.5 crashes when a container is released while its models are read
    }

    enum StartEntry: String, CaseIterable, Sendable {
        case session, sessionIndex
    }

    @Test("a failed start leaves no link and no unsaved log, so a retry fails again instead of resuming it", arguments: StartEntry.allCases)
    func failedStartLeavesNoLog(entry: StartEntry) throws {
        try withReadOnlyContext { context, writer in
            let rows = try context.fetch(FetchDescriptor<PlannedSession>(sortBy: [SortDescriptor(\.index)]))
            let session = rows[12]
            @MainActor func attemptThrew() -> Bool {   // the store is main-actor isolated; a nested func is not by default
                do {
                    switch entry {
                    case .session: try WorkoutLogStore.start(session: session, at: t0, in: context)
                    case .sessionIndex: try WorkoutLogStore.start(sessionIndex: 12, rows: rows, at: t0, in: context)
                    }
                    return false
                } catch {
                    return true
                }
            }
            #expect(attemptThrew())
            #expect(session.workoutLog == nil)
            #expect(!context.hasChanges)
            #expect(context.insertedModelsArray.isEmpty)
            let logsInContext = try context.fetch(FetchDescriptor<WorkoutLog>())
            #expect(logsInContext.count == 1, "only session 11's saved log")
            // The root routes on this query; on 26.5 an in-place undo of the insert left the unsaved log matching it.
            let routed = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
            #expect(routed.count == 1, "only session 11's saved log is routable")
            #expect(attemptThrew(), "a retry must not return the unsaved log as the session's existing one")
            #expect(session.workoutLog == nil)
            let logsInStore = try ModelContext(writer).fetch(FetchDescriptor<WorkoutLog>())
            #expect(logsInStore.count == 1)
        }
    }

    /// A failed discard rethrows with its 21 deletes (1 log, 5 exercises, 15 sets) still pending and nothing rolled back
    /// (a pending delete cannot be rolled back on 17.5). The store keeps every row, and the objects a screen still holds
    /// read without trapping. Their in-memory relationships are already cut by the pending deletes (probed: 17.5 reads 0
    /// sets, 26.5 reads 3), so their contents are not asserted. That the next successful save completes the discard
    /// cannot be forced with a read-only store.
    @Test("a failed discard keeps the store intact, and the objects it held still read without trapping")
    func failedDiscardKeepsRows() throws {
        try withReadOnlyContext { context, writer in
            let logs = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
            let log = try #require(logs.first)
            let before = values(log)
            #expect(before.sets.flatMap { $0 }.count == 15)
            #expect(throws: (any Error).self) { try WorkoutLogStore.discard(log, in: context) }
            #expect(context.deletedModelsArray.count == 21)
            let afterFailure = values(log)   // the re-render path: reading pending-deleted objects must not trap
            #expect(afterFailure.finishedAt == nil)
            let store = ModelContext(writer)
            let storedLogs = try store.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
            let storedExercises = try store.fetchCount(FetchDescriptor<LoggedExercise>())
            let storedSets = try store.fetchCount(FetchDescriptor<LoggedSet>())
            #expect(storedLogs.count == 1)
            #expect(storedExercises == 5)
            #expect(storedSets == 15)
        }
    }

    /// `discard` walks the log's relationships to delete its exercises and sets; a context that has loaded only the log
    /// must still delete the whole graph (the children load from the store while their rows exist).
    @Test("discard from a context that has loaded only the log deletes the whole graph")
    func discardWithUnloadedChildren() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try discardFromFreshContext(storeAt: dir.appendingPathComponent("rollback.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func discardFromFreshContext(storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: setup)
        try WorkoutLogStore.start(session: rows[11], at: t0, in: setup)

        let context = ModelContext(writer)
        let logs = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        let log = try #require(logs.first)
        #expect(log.startedAt == t0)
        try WorkoutLogStore.discard(log, in: context)

        #expect(!context.hasChanges)
        let inContext = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        #expect(inContext.isEmpty)
        let fresh = ModelContext(writer)
        let storedLogs = try fresh.fetchCount(FetchDescriptor<WorkoutLog>())
        let storedExercises = try fresh.fetchCount(FetchDescriptor<LoggedExercise>())
        let storedSets = try fresh.fetchCount(FetchDescriptor<LoggedSet>())
        #expect(storedLogs == 0)
        #expect(storedExercises == 0)
        #expect(storedSets == 0)
        withExtendedLifetime(writer) {}   // 26.5 crashes when a container is released while its models are read
    }
}

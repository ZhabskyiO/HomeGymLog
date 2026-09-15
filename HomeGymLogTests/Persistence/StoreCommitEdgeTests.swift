import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// `StoreCommit.commit` and `commitInsert` called directly, beyond the rehearsal cases of `StoreCommitTests`: the success
/// paths never run the undo closure, the field-writer path rolls back **before** it restores (researcher addendum P4), the
/// insert path removes the insert **before** it rolls back (17.5 crashes on `rollback()` with an insert pending), and a
/// rehearsal whose body inserts but returns nil saves nothing.
///
/// Failures use an on-disk store holding one saved `dbBench` note, reopened with `allowsSave: false`; both containers stay
/// bound for the check.
@MainActor
@Suite struct StoreCommitEdgeTests {
    private let t0 = TestCalendar.day(2026, 9, 14).addingTimeInterval(12 * 3600)
    private let t1 = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    @Test("commit on a writable store saves and never runs revert")
    func commitSuccess() throws {
        let store = try makeTestStore()
        let note = ExerciseNote(exerciseKey: "latPull", text: "a", updatedAt: t0)
        store.context.insert(note)
        try store.context.save()
        note.text = "b"
        var reverts = 0
        try StoreCommit.commit(store.context) { reverts += 1 }
        #expect(reverts == 0)
        #expect(try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>()).map(\.text) == ["b"])
    }

    @Test("commitInsert on a writable store saves the insert and never runs removeInserts")
    func commitInsertSuccess() throws {
        let store = try makeTestStore()
        store.context.insert(ExerciseNote(exerciseKey: "latPull", text: "a", updatedAt: t0))
        var removals = 0
        try StoreCommit.commitInsert(store.context) { removals += 1 }
        #expect(removals == 0)
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<ExerciseNote>()) == 1)
    }

    @Test("a rehearsal whose body inserts into the scratch context but returns nil saves nothing")
    func rehearsalReturningNilSavesNothing() throws {
        let store = try makeTestStore()
        try StoreCommit.rehearseInsert(in: store.container) { scratch in
            scratch.insert(ExerciseNote(exerciseKey: "latPull", text: "never saved", updatedAt: t0))
            return nil
        }
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<ExerciseNote>()) == 0)
    }

    // MARK: Failures

    /// `body` gets a context on the read-only container (the writing context) and the writable container (the store). When
    /// `body` reports pending changes it could not discard safely, the store file is left in the temporary folder rather
    /// than removed under them (removing it aborts the 26.5 test process).
    private func withRefusingStore(_ body: (ModelContext, ModelContainer) throws -> Bool) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("storecommit-edge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var clean = true
        let result = Result {
            let url = dir.appendingPathComponent("edge.store")
            let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
            let setup = ModelContext(writer)
            setup.insert(ExerciseNote(exerciseKey: "dbBench", text: "incline notch 2", updatedAt: t0))
            try setup.save()
            let readOnly = try ModelContainer(for: AppSchema.schema,
                                              configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
            clean = try body(ModelContext(readOnly), writer)
            withExtendedLifetime((writer, readOnly)) {}   // 26.5 crashes when a container is released while its models are read
        }
        if clean { try? FileManager.default.removeItem(at: dir) }
        try result.get()
    }

    @Test("a failed commit rolls back before it restores: revert sees no pending change, then the originals are pending and the first fetch reads them")
    func commitFailureRollsBackFirst() throws {
        try withRefusingStore { context, writer in
            let note = try #require(try context.fetch(FetchDescriptor<ExerciseNote>()).first)
            let noteID = note.id
            note.text = "incline notch 3"
            note.updatedAt = t1
            var reverts = 0
            var pendingDuringRevert: Bool?
            #expect(throws: (any Error).self) {
                try StoreCommit.commit(context) {
                    reverts += 1
                    pendingDuringRevert = context.hasChanges
                    note.text = "incline notch 2"
                    note.updatedAt = t0
                }
            }
            let first = try context.fetch(FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.id == noteID }))
            #expect(first.map(\.text) == ["incline notch 2"], "first same-context fetch by id")
            #expect(first.map(\.updatedAt) == [t0])
            #expect(reverts == 1)
            #expect(pendingDuringRevert == false, "rollback() ran before revert")
            #expect(context.hasChanges, "the restored originals are pending")
            let stored = try ModelContext(writer).fetch(FetchDescriptor<ExerciseNote>())
            #expect(stored.map(\.text) == ["incline notch 2"])
            context.rollback()   // no insert or delete pending: safe, and required before the store file is removed
            return true
        }
    }

    /// Reached directly: in the app it runs only when a save fails right after a successful rehearsal, which `allowsSave:
    /// false` cannot produce. Researcher addendum P4 ran this order on a relationship-free note on 17.5 and 26.5 without a
    /// trap; on 26.5 a fetch of all notes may still return the unsaved row afterwards (known, P1), so the writing context's
    /// fetches are not asserted here.
    @Test("a failed commitInsert removes the insert while it is still pending, then rolls back, rethrows and stores nothing")
    func commitInsertFailureRemovesFirst() throws {
        try withRefusingStore { context, writer in
            let note = ExerciseNote(exerciseKey: "latPull", text: "never saved", updatedAt: t1)
            context.insert(note)
            var removals = 0
            var insertedDuringRemove: Int?
            #expect(throws: (any Error).self) {
                try StoreCommit.commitInsert(context) {
                    removals += 1
                    insertedDuringRemove = context.insertedModelsArray.count
                    context.delete(note)
                }
            }
            #expect(removals == 1)
            #expect(insertedDuringRemove == 1, "removeInserts ran before rollback() cleared the insert")
            let stored = try ModelContext(writer).fetch(FetchDescriptor<ExerciseNote>())
            #expect(stored.map(\.exerciseKey) == ["dbBench"])
            return !context.hasChanges
        }
    }
}

import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-26: `ExerciseNoteStore.save` stores one row per key with the last text, and on a failed save leaves neither an
/// edited nor an unsaved row in the writing context. Values are read back through a fresh context on the same container.
///
/// Failed saves use an on-disk store holding one saved `dbBench` note, reopened with `allowsSave: false` (save throws
/// NSCocoaErrorDomain 513); the writer runs on a context of the read-only container. Both containers stay bound for the
/// whole check, and the temporary directory is removed only after they are released.
@MainActor
@Suite struct ExerciseNoteSaveTests {
    private let t0 = TestCalendar.day(2026, 9, 14).addingTimeInterval(12 * 3600)
    private let t1 = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    @Test("two saves for one key leave one row with the last text and updatedAt")
    func updateKeepsOneRow() throws {
        let store = try makeTestStore()
        try ExerciseNoteStore.save(text: "Seat notch 3", forExerciseKey: "latPull", updatedAt: t0, in: store.context)
        try ExerciseNoteStore.save(text: "Seat notch 4", forExerciseKey: "latPull", updatedAt: t1, in: store.context)
        let notes = try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.count == 1)
        #expect(notes.first?.exerciseKey == "latPull")
        #expect(notes.first?.text == "Seat notch 4")
        #expect(notes.first?.updatedAt == t1)
    }

    @Test("cleared text is stored as \"\", not deleted")
    func emptyTextStored() throws {
        let store = try makeTestStore()
        try ExerciseNoteStore.save(text: "S", forExerciseKey: "latPull", updatedAt: t0, in: store.context)
        try ExerciseNoteStore.save(text: "", forExerciseKey: "latPull", updatedAt: t1, in: store.context)
        let notes = try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.count == 1)
        #expect(notes.first?.text == "")
    }

    @Test("two keys get two rows")
    func twoKeys() throws {
        let store = try makeTestStore()
        try ExerciseNoteStore.save(text: "a", forExerciseKey: "latPull", updatedAt: t0, in: store.context)
        try ExerciseNoteStore.save(text: "b", forExerciseKey: "lowRow", updatedAt: t1, in: store.context)
        let notes = try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>(sortBy: [SortDescriptor(\.exerciseKey)]))
        #expect(notes.map(\.exerciseKey) == ["latPull", "lowRow"])
        #expect(notes.map(\.text) == ["a", "b"])
    }

    // MARK: Failed saves

    /// `body` gets a context on the read-only container (the writing context) and the writable container (the store).
    private func withRefusingStore(_ body: (ModelContext, ModelContainer) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("notes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try refusingStore(at: dir.appendingPathComponent("notes.store"), body) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func refusingStore(at url: URL, _ body: (ModelContext, ModelContainer) throws -> Void) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        setup.insert(ExerciseNote(exerciseKey: "dbBench", text: "incline notch 2", updatedAt: t0))
        try setup.save()
        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        try body(ModelContext(readOnly), writer)
        withExtendedLifetime((writer, readOnly)) {}   // 26.5 crashes when a container is released while its models are read
    }

    @Test("a failed update throws and restores text and updatedAt on the object, in a same-context refetch and in the store")
    func failedUpdateRestores() throws {
        try withRefusingStore { context, writer in
            let note = try #require(try ExerciseNoteStore.note(forExerciseKey: "dbBench", in: context))
            let noteID = note.id
            #expect(throws: (any Error).self) {
                try ExerciseNoteStore.save(text: "incline notch 3", forExerciseKey: "dbBench", updatedAt: t1, in: context)
            }
            // First fetch after the failure, by id (researcher addendum P4: on 26.5 only the first fetch was dirty).
            let byID = try context.fetch(FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.id == noteID }))
            #expect(byID.map(\.text) == ["incline notch 2"])
            #expect(byID.map(\.updatedAt) == [t0])
            #expect(note.text == "incline notch 2")
            #expect(note.updatedAt == t0)
            let refetched = try context.fetch(FetchDescriptor<ExerciseNote>())
            #expect(refetched.map(\.text) == ["incline notch 2"])
            #expect(refetched.map(\.updatedAt) == [t0])
            #expect(context.hasChanges, "rollback first, then restore: the restored originals are pending (addendum P4)")
            let stored = try ModelContext(writer).fetch(FetchDescriptor<ExerciseNote>())
            #expect(stored.map(\.text) == ["incline notch 2"])
            #expect(stored.map(\.updatedAt) == [t0])
            // Every value is read: discard the restored originals left pending, so SwiftData never processes them after the
            // store file is removed (that faults a missing file and aborts the test process on 26.5).
            context.rollback()
        }
    }

    @Test("a failed first insert throws from the rehearsal: a same-turn fetch of all notes in the writing context holds only dbBench")
    func failedInsertLeavesNoRow() throws {
        try withRefusingStore { context, writer in
            #expect(throws: (any Error).self) {
                try ExerciseNoteStore.save(text: "Seat notch 3", forExerciseKey: "latPull", updatedAt: t1, in: context)
            }
            // Same run-loop turn, all notes (not by key): on 26.5 an in-place undo left the unsaved row only in this fetch.
            let all = try context.fetch(FetchDescriptor<ExerciseNote>())
            #expect(all.count == 1)
            #expect(all.map(\.exerciseKey) == ["dbBench"])
            #expect(all.map(\.text) == ["incline notch 2"])   // reading every row's text must not trap
            let count = try context.fetchCount(FetchDescriptor<ExerciseNote>())
            #expect(count == 1)
            #expect(context.insertedModelsArray.isEmpty)
            #expect(!context.hasChanges)
            let stored = try ModelContext(writer).fetchCount(FetchDescriptor<ExerciseNote>())
            #expect(stored == 1)
        }
    }
}

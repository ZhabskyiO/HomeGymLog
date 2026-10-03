import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-16 (helper half): `StoreCommit.replaceInScratch` saves its scratch context once on success, rethrows a `write`
/// error with nothing stored, and lets a refused save throw with the store unchanged. The main context is never touched.
@MainActor
@Suite struct StoreCommitReplaceTests {
    private struct WriteFailed: Error {}

    private func note(_ text: String) -> ExerciseNote {
        ExerciseNote(exerciseKey: "dbBench", text: text, updatedAt: TestCalendar.day(2026, 9, 7))
    }

    @Test("success: a fresh context reads the write; the main context has no changes")
    func success() throws {
        let store = try makeTestStore()
        try StoreCommit.replaceInScratch(in: store.container) { $0.insert(note("saved")) }
        let notes = try ModelContext(store.container).fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.map(\.text) == ["saved"])
        #expect(store.container.mainContext.hasChanges == false)
        withExtendedLifetime(store) {}
    }

    @Test("a throwing write is rethrown and nothing is stored")
    func writeThrows() throws {
        let store = try makeTestStore()
        #expect(throws: WriteFailed.self) {
            try StoreCommit.replaceInScratch(in: store.container) { context in
                context.insert(note("never"))
                throw WriteFailed()
            }
        }
        let observed1 = try ModelContext(store.container).fetchCount(FetchDescriptor<ExerciseNote>())
        #expect(observed1 == 0)
        withExtendedLifetime(store) {}
    }

    @Test("a refused save throws and leaves the store unchanged")
    func refusedSave() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scratch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try refused(storeAt: dir.appendingPathComponent("scratch.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func refused(storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        setup.insert(note("old"))
        try setup.save()
        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        defer { withExtendedLifetime((writer, readOnly, setup)) {} }
        #expect(throws: (any Error).self) {
            try StoreCommit.replaceInScratch(in: readOnly) { $0.insert(note("new")) }
        }
        let notes = try ModelContext(writer).fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.map(\.text) == ["old"])
        #expect(readOnly.mainContext.hasChanges == false)
    }
}

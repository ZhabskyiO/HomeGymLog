import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// `StoreCommit.rehearseInsert` (plan Step 1, NB3): the body runs once in a scratch context; what it inserts is saved and
/// removed again, so the store ends as it started; a refusing store throws before any caller context changes. Read back
/// through a fresh context on the same container.
@MainActor
@Suite struct StoreCommitTests {
    private let day = TestCalendar.day(2026, 9, 15)

    @Test("a body that returns nil is called exactly once")
    func rehearseInsertCallsBodyOnce() throws {
        let store = try makeTestStore()
        var calls = 0
        try StoreCommit.rehearseInsert(in: store.container) { _ in
            calls += 1
            return nil
        }
        #expect(calls == 1)
    }

    @Test("an inserted note is saved, removed by the returned closure and saved again: the store holds no row")
    func rehearsalLeavesNoRow() throws {
        let store = try makeTestStore()
        var removed = false
        try StoreCommit.rehearseInsert(in: store.container) { scratch in
            let note = ExerciseNote(exerciseKey: "latPull", text: "rehearsal", updatedAt: day)
            scratch.insert(note)
            return {
                scratch.delete(note)
                removed = true
            }
        }
        #expect(removed)
        let stored = try ModelContext(store.container).fetchCount(FetchDescriptor<ExerciseNote>())
        #expect(stored == 0)
    }

    @Test("on a store reopened allowsSave: false the rehearsal throws and nothing reaches the store")
    func refusingStoreThrows() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("storecommit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try refuse(storeAt: dir.appendingPathComponent("commit.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func refuse(storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        var removed = false
        #expect(throws: (any Error).self) {
            try StoreCommit.rehearseInsert(in: readOnly) { scratch in
                let note = ExerciseNote(exerciseKey: "latPull", text: "refused", updatedAt: day)
                scratch.insert(note)
                return {
                    scratch.delete(note)
                    removed = true
                }
            }
        }
        #expect(!removed, "the first save threw, so the removal never ran")
        let stored = try ModelContext(writer).fetchCount(FetchDescriptor<ExerciseNote>())
        #expect(stored == 0)
        withExtendedLifetime((writer, readOnly)) {}   // 26.5 crashes when a container is released while its models are read
    }
}

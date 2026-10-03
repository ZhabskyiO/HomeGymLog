import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-16: a refused replace (the store reopened `allowsSave: false`, the `ProgramArchiveRollbackTests` technique) throws,
/// the store still holds the old graph, and the container's main context was never touched. The writing context is the
/// scratch context `replaceInScratch` opened and dropped, so this test holds no writing context of its own: nothing is
/// pending to roll back before the temporary store is removed (and a pending delete must never be rolled back).
@MainActor
@Suite struct BackupReplaceRollbackTests {
    @Test("a failed replaceAll throws; a fresh context reads the old graph and the main context has no changes")
    func failedReplaceKeepsStore() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("replace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try failedReplace(storeAt: dir.appendingPathComponent("replace.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func failedReplace(storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        try insertSampleGraph(in: setup)
        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        defer { withExtendedLifetime((writer, readOnly, setup)) {} }
        let replacement = BackupFixtures.mutated {
            $0.exerciseNotes[0].text = "replaced"
            $0.sessions.removeLast()
        }

        #expect(throws: (any Error).self) { try BackupStore.replaceAll(with: replacement, in: readOnly) }

        let store = ModelContext(writer)
        let observed1 = try tableCounts(in: writer)
        #expect(observed1 == ["P": 1, "S": 3, "L": 1, "E": 2, "T": 6, "N": 1])
        let notes = try store.fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.map(\.text) == ["incline notch 2"])
        let ids = Set(try store.fetch(FetchDescriptor<Program>()).map(\.id))
        #expect(!ids.contains(BackupFixtures.programID), "no row of the file reached the store")
        #expect(readOnly.mainContext.hasChanges == false)
        let readOnlyNotes = try ModelContext(readOnly).fetch(FetchDescriptor<ExerciseNote>())
        #expect(readOnlyNotes.map(\.text) == ["incline notch 2"])
    }
}

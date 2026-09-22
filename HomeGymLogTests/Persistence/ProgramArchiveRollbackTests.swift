import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-23 (failed save): a refused `archive` throws, and the writing context's first fetch by id, its `hasChanges`, and a fresh
/// context on the store all read `archivedAt == nil`. The failure is forced by reopening an on-disk store with
/// `allowsSave: false`; it fails without the writer's restore (`rollback()` keeps edited values). Both containers stay bound,
/// and `rollback()` runs before the temporary store is deleted (gotchas SwiftData 2026-09-14).
@MainActor
@Suite struct ProgramArchiveRollbackTests {
    @Test("a failed archive throws; the same-context fetch by id, hasChanges and the store show archivedAt nil")
    func failedArchiveRestores() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try failedArchive(storeAt: dir.appendingPathComponent("archive.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func failedArchive(storeAt url: URL) throws {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let setup = ModelContext(writer)
        let id = try insertSampleGraph(in: setup).program.id

        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = ModelContext(readOnly)
        defer {
            context.rollback()
            withExtendedLifetime((writer, readOnly, setup)) {}
        }
        let program = try fetch(id, in: context)

        #expect(throws: (any Error).self) {
            _ = try ProgramStore.archive(program, at: TestCalendar.day(2026, 9, 12), in: context)
        }

        // First read after the failure: a same-context fetch by id.
        #expect(try fetch(id, in: context).archivedAt == nil, "writing context")
        #expect(context.hasChanges, "the restored original stays pending")
        #expect(try fetch(id, in: ModelContext(writer)).archivedAt == nil, "store")
    }

    private func fetch(_ id: UUID, in context: ModelContext) throws -> Program {
        try #require(try context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.id == id })).first)
    }
}

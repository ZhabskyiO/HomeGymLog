import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-13 (outcome half): the three outcomes of the restart handler's one write. The failure is forced by reopening an
/// on-disk store with `allowsSave: false` (the `ProgramArchiveRollbackTests` shape; its helper is private, so the shape is
/// repeated here). `RestartAction.run` carries no assert, which is why this suite can run in Debug.
@MainActor
@Suite struct RestartActionTests {
    @Test("a first run archives at the passed date; a second reports alreadyArchived and writes nothing")
    func archivedThenAlready() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        let at = TestCalendar.day(2026, 9, 15)

        #expect(RestartAction.run(program: program, at: at, in: store.context) == .archived)
        #expect(program.archivedAt == at)
        #expect(store.context.hasChanges == false)

        #expect(RestartAction.run(program: program, at: TestCalendar.day(2026, 9, 16), in: store.context) == .alreadyArchived)
        #expect(program.archivedAt == at)
        #expect(store.context.hasChanges == false)
        withExtendedLifetime(store) {}
    }

    @Test("a refused save reports failed with the alert's message and leaves archivedAt nil in the store")
    func failedSave() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("restart-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = Result { try failedRun(storeAt: dir.appendingPathComponent("restart.store")) }
        try? FileManager.default.removeItem(at: dir)
        try result.get()
    }

    private func failedRun(storeAt url: URL) throws {
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

        #expect(RestartAction.run(program: program, at: TestCalendar.day(2026, 9, 15), in: context)
                == .failed(SettingsText.archiveFailedMessage))

        // First read after the failure: a same-context fetch by id.
        #expect(try fetch(id, in: context).archivedAt == nil, "writing context")
        #expect(try fetch(id, in: ModelContext(writer)).archivedAt == nil, "store")
    }

    private func fetch(_ id: UUID, in context: ModelContext) throws -> Program {
        try #require(try context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.id == id })).first)
    }
}

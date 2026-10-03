import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-11: the schema is frozen as `AppSchemaV1` at 1.0.0 with a one-schema, no-stage plan, and the committed fixture
/// (written once on iOS 26.5 by the unversioned schema before V1 landed, never regenerated) opens under it with every row.
/// The fixture is read from the source tree through `#filePath`, never a bundle (INSIGHTS 2026-09-25, NB3).
@MainActor
@Suite struct SchemaMigrationTests {
    @Test("AppSchema.schema is version 1.0.0")
    func schemaVersion() {
        #expect(AppSchema.schema.version == Schema.Version(1, 0, 0))
    }

    @Test("the migration plan has one schema and no stages")
    func planShape() {
        #expect(AppMigrationPlan.schemas.count == 1)
        #expect(AppMigrationPlan.stages.isEmpty)
    }

    @Test("AppSchemaV1 lists exactly the six model classes")
    func modelNames() {
        let names = AppSchemaV1.models.map { String(describing: $0) }
        #expect(names == ["Program", "PlannedSession", "WorkoutLog", "LoggedExercise", "LoggedSet", "ExerciseNote"])
    }

    @Test("the unversioned 1.0.0 fixture opens under V1 and the plan with every row")
    func fixtureOpensUnderV1() throws {
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Support/Fixtures", isDirectory: true)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for suffix in ["", "-wal", "-shm"] {
            let name = "unversioned-1.0.0.store" + suffix
            let source = fixtures.appendingPathComponent(name)
            try #require(FileManager.default.fileExists(atPath: source.path), "fixture \(name) is committed")
            try FileManager.default.copyItem(at: source, to: dir.appendingPathComponent(name))
        }
        try readFixture(at: dir.appendingPathComponent("unversioned-1.0.0.store"))
    }

    /// Opens, reads and releases the container before the caller deletes the files (gotchas SwiftData 2026-09-14).
    private func readFixture(at url: URL) throws {
        let container = try ModelContainer(for: AppSchema.schema, migrationPlan: AppMigrationPlan.self,
                                           configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        let context = ModelContext(container)
        defer { withExtendedLifetime((container, context)) {} }

        let programs = try context.fetchCount(FetchDescriptor<Program>())
        let sessions = try context.fetchCount(FetchDescriptor<PlannedSession>())
        let logs = try context.fetchCount(FetchDescriptor<WorkoutLog>())
        let exercises = try context.fetchCount(FetchDescriptor<LoggedExercise>())
        let counts: [Int] = [programs, sessions, logs, exercises]
        #expect(counts == [1, 3, 1, 2])
        let sets = try context.fetch(FetchDescriptor<LoggedSet>())
        #expect(sets.count == 6)
        #expect(sets.allSatisfy { $0.rpeSkipped == false })
        let notes = try context.fetch(FetchDescriptor<ExerciseNote>())
        #expect(notes.map(\.text) == ["incline notch 2"])
        #expect(!context.hasChanges, "nothing is left pending before the files are removed")
    }
}

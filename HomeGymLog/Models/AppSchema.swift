import Foundation
import SwiftData

/// The one schema the app ships: the frozen `AppSchemaV1` (every `@Model`), opened through `AppMigrationPlan`.
enum AppSchema {
    static let schema = Schema(versionedSchema: AppSchemaV1.self)

    /// On-disk container for the app, or an in-memory one for previews and tests.
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])
    }
}

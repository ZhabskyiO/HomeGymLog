import Foundation
import SwiftData

/// The frozen shipped schema (m5-export). Its models are the live top-level classes until a V2 exists; at that point
/// copy the six classes here as nested `@Model`s (verbatim stored properties, inverses pointing at the nested types) and
/// point V2 at the top-level ones with a `.lightweight` stage. ≈ the first Prisma migration file, frozen in `migrations/`.
enum AppSchemaV1: VersionedSchema {
    /// What the unversioned `Schema([...])` already wrote into every existing store, so they open with no migration.
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Program.self, PlannedSession.self, WorkoutLog.self, LoggedExercise.self, LoggedSet.self, ExerciseNote.self]
    }
}

/// The ordered list of schema versions and the steps between them (≈ the migrations folder). One version, no stages yet.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

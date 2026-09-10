import Foundation
import SwiftData

/// The one schema the app ships. Every `@Model` is listed here so containers agree.
enum AppSchema {
    static let schema = Schema([
        Program.self, PlannedSession.self, WorkoutLog.self, LoggedExercise.self, LoggedSet.self, ExerciseNote.self,
    ])

    /// On-disk container for the app, or an in-memory one for previews and tests.
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

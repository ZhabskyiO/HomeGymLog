import Foundation
import SwiftData

/// Model-layer actions on workout logs. Deletion is explicit because the iOS 17 runtime does not
/// honor `.cascade` (verified on the 17.5 simulator: children are orphaned, not deleted).
enum WorkoutLogStore {
    /// Deletes a log with its exercises and sets. The session it belonged to keeps its status; the
    /// caller decides whether to reset it. Does not save.
    static func delete(_ log: WorkoutLog, in context: ModelContext) {
        for exercise in log.exercises {
            for set in exercise.sets {
                context.delete(set)
            }
            context.delete(exercise)
        }
        context.delete(log)
    }
}

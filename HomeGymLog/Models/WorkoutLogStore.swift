import Foundation
import SwiftData

/// Model-layer actions on workout logs. Deletion is explicit because the iOS 17 runtime does not
/// honor `.cascade` (verified on the 17.5 simulator: children are orphaned, not deleted).
enum WorkoutLogStore {
    /// Starts a workout for a planned session: one log, one `LoggedExercise` per planned exercise (in order,
    /// at its target), and `session.sets` pending `LoggedSet`s per exercise at the target weight and the
    /// session's reps. Links the log to the session and saves. The session stays `pending` until `finish`.
    /// Calling it again for a session that already has a log returns that log (resume), never a duplicate:
    /// reassigning the to-one link would orphan the old log and every set already swiped in it.
    @discardableResult
    static func start(session: PlannedSession, at: Date, in context: ModelContext) throws -> WorkoutLog {
        if let existing = session.workoutLog { return existing }
        let log = WorkoutLog(startedAt: at)
        context.insert(log)
        session.workoutLog = log
        for planned in session.exercises.sorted(by: { $0.order < $1.order }) {
            let exercise = LoggedExercise(order: planned.order, exerciseKey: planned.exerciseKey, targetWeightLb: planned.targetWeightLb)
            log.exercises.append(exercise)
            for setOrder in 0..<session.sets {
                exercise.sets.append(LoggedSet(order: setOrder, weightLb: planned.targetWeightLb, reps: session.reps))
            }
        }
        try context.save()
        return log
    }

    /// The single writer of completion: sets `finishedAt` and marks the session completed in one save,
    /// upholding "completed iff the log is finished".
    static func finish(_ log: WorkoutLog, at: Date, in context: ModelContext) throws {
        log.finishedAt = at
        log.session?.status = .completed
        try context.save()
    }

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

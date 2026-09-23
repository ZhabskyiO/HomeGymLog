import Foundation
import SwiftData

/// Maps the current program's session rows into the plain values `HomeStats` reads. Rows are main-actor
/// isolated; the outputs are Engine values. Session values are scalar reads and safe to compute while
/// rendering; `finishedLogs` traverses every set and must run once per data change (see INSIGHTS).
@MainActor
enum HomeSnapshotBuilder {
    /// The Home tab's live query: this program's sessions. `$0.program == program` does not compile on iOS 17.
    static func sessionPredicate(programID: UUID) -> Predicate<PlannedSession> {
        #Predicate<PlannedSession> { $0.program?.id == programID }
    }

    static func sessionSummaries(from rows: [PlannedSession]) -> [SessionSummary] {
        rows.map { row in
            SessionSummary(index: row.index, week: row.week, phase: row.phase, name: row.name, scheduledDate: row.scheduledDate,
                           status: row.status, sets: row.sets, reps: row.reps, exercises: row.exercises)
        }
    }

    /// Finished logs only; in-progress logs are not mapped. Expensive on iOS 17 (every set is faulted).
    static func finishedLogs(from rows: [PlannedSession]) -> [FinishedLogValue] {
        rows.compactMap { row in
            guard let log = row.workoutLog, log.finishedAt != nil else { return nil }
            return FinishedLogValue(sessionIndex: row.index, exercises: log.sortedExercises.map { exercise in
                LoggedExerciseValue(order: exercise.order, exerciseKey: exercise.exerciseKey,
                                    sets: exercise.sortedSets.map { LoggedSetValue(weightLb: $0.weightLb, reps: $0.reps, status: $0.status) })
            })
        }
    }

    /// Changes whenever a session's status or date changes, which is when `finishedLogs` must be rebuilt.
    static func fingerprint(of rows: [PlannedSession]) -> String {
        rows.map { "\($0.index)|\($0.statusRaw)|\($0.scheduledDate.timeIntervalSinceReferenceDate)" }.joined(separator: ",")
    }

    /// The day of every pending row (scalar reads only), for the reminder host's reconcile key. Order follows the rows;
    /// `ReminderPlan.reconcileKey` sorts.
    static func pendingDays(from rows: [PlannedSession]) -> [Date] {
        rows.filter { $0.status == .pending }.map { $0.scheduledDate }
    }
}

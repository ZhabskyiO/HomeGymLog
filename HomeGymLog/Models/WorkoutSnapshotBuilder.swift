import Foundation
import SwiftData

/// The workout screen's predicates and the row → Engine value mapping. Rows in, plain values out; maps, never
/// validates (every Engine rule over these values is total). Main-actor isolated like the rows it reads.
@MainActor
enum WorkoutSnapshotBuilder {
    /// The root's route: a log still in progress, attached to a session of a program that is not archived.
    /// Nested `flatMap`, never `log.session?.program?.archivedAt`: a second `?.` hop compiles, then crashes at fetch
    /// on iOS 17.5 and 26.5 (gotchas 2026-09-13). Orphan and archived-program logs do not match.
    static let inProgressPredicate = #Predicate<WorkoutLog> { log in
        log.finishedAt == nil && log.session.flatMap { session in session.program.flatMap { program in program.archivedAt == nil } } == true
    }

    /// The workout screen's exercise query: the rows of one log (one optional hop).
    static func exercisePredicate(logID: UUID) -> Predicate<LoggedExercise> {
        #Predicate<LoggedExercise> { $0.workout?.id == logID }
    }

    /// The workout screen's set query: the sets of the given exercises. `[UUID?].contains($0.exercise?.id)` does
    /// not compile; the explicit `flatMap` does.
    static func setPredicate(exerciseIDs: [UUID]) -> Predicate<LoggedSet> {
        #Predicate<LoggedSet> { set in set.exercise.flatMap { exerciseIDs.contains($0.id) } == true }
    }

    /// Engine values for the query rows. Sets are grouped by their exercise's id (`Dictionary(grouping:)` never
    /// traps on duplicates); a set whose exercise is not among `exercises` is dropped. Order is left to `WorkoutFlow`.
    static func values(exercises: [LoggedExercise], sets: [LoggedSet]) -> [WorkoutExerciseValue] {
        let setsByExercise = Dictionary(grouping: sets) { $0.exercise?.id }
        return exercises.map { exercise in
            WorkoutExerciseValue(
                id: exercise.id, order: exercise.order, exerciseKey: exercise.exerciseKey, targetWeightLb: exercise.targetWeightLb,
                sets: (setsByExercise[exercise.id] ?? []).map { set in
                    WorkoutSetValue(id: set.id, order: set.order, weightLb: set.weightLb, reps: set.reps, status: set.status,
                                    rpe: set.rpe, rpeSkipped: set.rpeSkipped, loggedAt: set.loggedAt)
                })
        }
    }

    /// Name, stored week and phase of the log's session, read once. A log with no session (routing excludes it;
    /// defensive) reads ("", 1, Foundation) rather than trapping.
    static func sessionInfo(of log: WorkoutLog) -> WorkoutSessionInfo {
        guard let session = log.session else { return WorkoutSessionInfo(name: "", week: 1, phase: .foundation) }
        return WorkoutSessionInfo(name: session.name, week: session.week, phase: session.phase)
    }

    /// Rows keyed by id so a write finds its row from an Engine value's id, never by position. A duplicate id keeps
    /// the first row (the unique-keys initializer would trap on it).
    static func byID<Row>(_ rows: [Row], id: (Row) -> UUID) -> [UUID: Row] {
        Dictionary(rows.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The summary's PR baseline: exercise key → best done weight (lb) over the program's completed sessions and
    /// finished logs (an in-progress log is never mapped). Traverses every finished set, so call it once, lazily,
    /// when the summary first shows. nil program → no baseline.
    static func bestsBefore(programID: UUID?, in context: ModelContext) throws -> [String: Double] {
        guard let programID else { return [:] }
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID),
                                                     sortBy: [SortDescriptor(\.index)]))
        let records = HomeStats.personalRecords(sessions: HomeSnapshotBuilder.sessionSummaries(from: rows),
                                                logs: HomeSnapshotBuilder.finishedLogs(from: rows))
        return WorkoutSummary.bests(from: records)
    }
}

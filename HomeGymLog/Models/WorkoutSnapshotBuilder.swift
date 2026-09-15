import Foundation
import SwiftData

/// What the swap sheet's candidates are computed from, read from the log at the tap: the session's stored week and phase,
/// the program's starting weights (lb) and the log's current exercise keys in order.
struct SwapContext: Equatable {
    let week: Int
    let phase: Phase
    let startingWeightsLb: [String: Double]
    let keysInWorkout: [String]
}

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

    /// The progression pill's baseline for one key (INSIGHTS Patterns "Per-key history reads"): the key's exercise rows whose
    /// workout is finished (a one-hop `flatMap` predicate; the in-progress log never matches), kept in Swift only when the
    /// workout's session belongs to `programID` (archived programs drop out). One entry per finished log: top = the heaviest
    /// done set over that log's rows for the key; a log with no done set for it is dropped. Sorted by `finishedAt`.
    /// ~55 ms at program end on 17.5, never the full `bestsBefore` traversal.
    static func finishedTops(key: String, programID: UUID, in context: ModelContext) throws -> [FinishedExerciseTop] {
        let rows = try context.fetch(FetchDescriptor<LoggedExercise>(predicate: #Predicate { exercise in
            exercise.exerciseKey == key && exercise.workout.flatMap { log in log.finishedAt != nil } == true
        }))
        // Keyed by log id and merged by hand: a log holding the key twice must give one entry, never a duplicate-key trap.
        var topsByLog: [UUID: FinishedExerciseTop] = [:]
        for row in rows {
            guard let log = row.workout, let finishedAt = log.finishedAt, log.session?.program?.id == programID,
                  let top = row.sets.filter({ $0.status == .done }).map(\.weightLb).max() else { continue }
            if let existing = topsByLog[log.id], existing.topWeightLb >= top { continue }
            topsByLog[log.id] = FinishedExerciseTop(finishedAt: finishedAt, topWeightLb: top)
        }
        return topsByLog.values.sorted { ($0.finishedAt, $0.topWeightLb) < ($1.finishedAt, $1.topWeightLb) }
    }

    /// The swap sheet's inputs, read once at the tap. Total like `sessionInfo`: a log with no session reads week 1,
    /// Foundation and no starting weights, with its own keys (the writer then does a log-only swap).
    static func swapContext(of log: WorkoutLog) -> SwapContext {
        let keys = log.sortedExercises.map(\.exerciseKey)
        guard let session = log.session else {
            return SwapContext(week: 1, phase: .foundation, startingWeightsLb: [:], keysInWorkout: keys)
        }
        return SwapContext(week: session.week, phase: session.phase, startingWeightsLb: session.program?.startingWeightsLb ?? [:],
                           keysInWorkout: keys)
    }
}

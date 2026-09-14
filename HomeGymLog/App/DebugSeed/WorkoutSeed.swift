#if DEBUG
import Foundation
import SwiftData

enum WorkoutSeedError: Error, Equatable {
    case noCurrentProgram
    case sessionNotStartable
}

/// The workout seeds' in-progress log on session 11 (Pull, Tue 2026-09-15) of the current `midProgram` program.
/// Written through the workout store functions only, exactly as the screen writes, with timestamps derived from the
/// seed's frozen `now`.
enum WorkoutSeed {
    /// `started`: wo-start and wo-swipe. `awaitingRating`: wo-rpe. `rated`: wo-adjust. `resting`: wo-rest.
    /// `finishedSets`: summary.
    enum Stage {
        case started, awaitingRating, rated, resting, finishedSets
    }

    /// Seconds between consecutive set timestamps: set k is logged at `startedAt + 168·k`.
    private static let setInterval = 168.0

    @discardableResult
    static func populate(_ stage: Stage, now: Date, in context: ModelContext) throws -> WorkoutLog {
        guard let program = try ProgramStore.current(in: context) else { throw WorkoutSeedError.noCurrentProgram }
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        // 754 s renders the header clock as 12:34; the summary starts 2 520 s back so its duration reads 42:00.
        let startedAt = now.addingTimeInterval(stage == .finishedSets ? -2520 : -754)
        guard let log = try WorkoutLogStore.start(sessionIndex: 11, rows: rows, at: startedAt, in: context) else {
            throw WorkoutSeedError.sessionNotStartable
        }
        let sets = log.sortedExercises.map(\.sortedSets)
        let firstSet = sets[0][0]
        let firstLoggedAt = startedAt.addingTimeInterval(setInterval)
        switch stage {
        case .started:
            break
        case .awaitingRating:
            try WorkoutLogStore.logSet(firstSet, at: firstLoggedAt, in: context)
        case .rated:
            try WorkoutLogStore.logSet(firstSet, at: firstLoggedAt, in: context)
            // Rated at the logging instant: its rest ended long before `now` (stale, not drawn).
            try WorkoutLogStore.setRPE(7, on: firstSet, at: firstLoggedAt, in: context)
        case .resting:
            try WorkoutLogStore.logSet(firstSet, at: firstLoggedAt, in: context)
            // Rated 13 s before the frozen now: the 75 s rest reads "1:02" with 62/75 of the ring left.
            try WorkoutLogStore.setRPE(7, on: firstSet, at: now.addingTimeInterval(-13), in: context)
        case .finishedSets:
            // Every set but the first first, then the first at one Marcy step above target: with its siblings already
            // done, "Save & log set" carries 120 lb to nothing. Each rating is stamped at its set's own instant; the
            // last one leaves no set pending, so it clears the rest.
            var k = 0
            for exerciseSets in sets {
                for set in exerciseSets {
                    k += 1
                    guard set !== firstSet else { continue }
                    let loggedAt = startedAt.addingTimeInterval(setInterval * Double(k))
                    try WorkoutLogStore.logSet(set, at: loggedAt, in: context)
                    try WorkoutLogStore.setRPE(7, on: set, at: loggedAt, in: context)
                }
            }
            try WorkoutLogStore.saveAndLogSet(firstSet, weightLb: 120, reps: 12, at: firstLoggedAt, in: context)
            try WorkoutLogStore.setRPE(7, on: firstSet, at: firstLoggedAt, in: context)
        }
        return log
    }
}
#endif

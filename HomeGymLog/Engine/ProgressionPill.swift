import Foundation

/// One finished appearance of an exercise key in the current program: when its workout finished and the heaviest done set
/// (pounds) of that appearance.
nonisolated struct FinishedExerciseTop: Equatable, Sendable {
    let finishedAt: Date
    let topWeightLb: Double
}

/// The two baselines a pill could compare against: the heaviest top ever (`best`) and the top of the most recent finished
/// appearance (`last`); both nil when the key was never finished in this program.
nonisolated struct PreviousTops: Equatable, Sendable {
    let best: Double?
    let last: Double?
}

/// Spec 5.2: the progression pill's numbers. Text lives in `Shared/ExerciseToolsText`. Total: nothing throws or traps.
nonisolated enum ProgressionPill {
    /// `best` = the maximum top; `last` = the top of the latest `finishedAt`, ties on `finishedAt` taking the larger weight
    /// (so the result never depends on input order).
    static func previousTops(_ tops: [FinishedExerciseTop]) -> PreviousTops {
        let latest = tops.max { ($0.finishedAt, $0.topWeightLb) < ($1.finishedAt, $1.topWeightLb) }
        return PreviousTops(best: tops.map(\.topWeightLb).max(), last: latest?.topWeightLb)
    }

    /// `current − previous` when a previous top exists and the current weight is strictly above it; otherwise nil (no pill).
    static func delta(currentLb: Double, previousLb: Double?) -> Double? {
        guard let previousLb, currentLb > previousLb else { return nil }
        return currentLb - previousLb
    }
}

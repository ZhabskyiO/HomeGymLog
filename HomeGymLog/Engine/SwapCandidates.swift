import Foundation

/// One exercise the swap sheet offers, at the weight a pick writes (pounds).
nonisolated struct SwapCandidate: Equatable, Sendable {
    let exerciseKey: String
    let targetWeightLb: Double
}

/// Spec 5.1: which exercises can replace the displayed one. Total like every Engine rule over stored rows (B2): never
/// throws, never traps. React analogy: a pure selector over the library and the workout's keys.
nonisolated enum SwapCandidates {
    /// Library exercises with the same muscle as `key`, in library order, leaving out `key` itself and every key in
    /// `keysInWorkout` (the log's current keys, so a swapped-in key is excluded and a swapped-out planned key is offered).
    /// Each weight comes from `WeightFormula.targetWeightLb` at the session's stored week and phase with the program's
    /// starting weights (a key absent from the map takes the library default). A `week` below 2 computes as week 1,
    /// because `WeightFormula.baseTenths` returns the start for it. An unknown `key` has no muscle, so it yields `[]`.
    static func candidates(for key: String, keysInWorkout: [String], week: Int, phase: Phase,
                           startingWeightsLb: [String: Double]) -> [SwapCandidate] {
        guard let displayed = ExerciseLibrary.exercise(for: key) else { return [] }
        return ExerciseLibrary.all.compactMap { exercise in
            guard exercise.muscle == displayed.muscle, exercise.key != key, !keysInWorkout.contains(exercise.key),
                  let target = WeightFormula.targetWeightLb(key: exercise.key, week: week, phase: phase,
                                                            startingWeightsLb: startingWeightsLb) else { return nil }
            return SwapCandidate(exerciseKey: exercise.key, targetWeightLb: target)
        }
    }
}

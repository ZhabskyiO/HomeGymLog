import Foundation
@testable import HomeGymLog

/// Plain workout values for the Engine suites, typed from spec 5.3 and 5.7 (never read from the generator).
enum WorkoutFixtures {
    /// A fixed UUID whose `uuidString` sorts in `n` order (fixed-width decimal digits in the last group).
    static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    /// `midProgram` session 11 (Pull, week 3, 3 × 12): latPull 110, lowRow 100, dbRow 47.5, rdl 52.5, curl 27.5.
    static let session11: [(String, Double)] = [("latPull", 110), ("lowRow", 100), ("dbRow", 47.5), ("rdl", 52.5), ("curl", 27.5)]
    /// `missed` session 7 (Legs, week 2, 3 × 12): goblet 50, rdl 50, legExt 70, legCurl 50, split 30.
    static let session7: [(String, Double)] = [("goblet", 50), ("rdl", 50), ("legExt", 70), ("legCurl", 50), ("split", 30)]

    /// All-pending exercises at their targets. Exercise ids `uuid(100·(i+1))`, set ids `uuid(100·(i+1)+j+1)`.
    static func exercises(_ targets: [(String, Double)], sets: Int = 3, reps: Int = 12) -> [WorkoutExerciseValue] {
        targets.enumerated().map { i, target in
            let base = 100 * (i + 1)
            return WorkoutExerciseValue(
                id: uuid(base), order: i, exerciseKey: target.0, targetWeightLb: target.1,
                sets: (0..<sets).map { j in
                    WorkoutSetValue(id: uuid(base + j + 1), order: j, weightLb: target.1, reps: reps, status: .pending,
                                    rpe: nil, rpeSkipped: false, loggedAt: nil)
                })
        }
    }

    /// A copy with set (`exercise`, `set`) — 0-based positions in the given arrays — replaced by the passed fields.
    static func editing(_ exercises: [WorkoutExerciseValue], exercise e: Int, set s: Int, status: SetStatus,
                        rpe: Int? = nil, rpeSkipped: Bool = false, weightLb: Double? = nil, loggedAt: Date? = nil) -> [WorkoutExerciseValue] {
        exercises.enumerated().map { i, exercise in
            guard i == e else { return exercise }
            return WorkoutExerciseValue(
                id: exercise.id, order: exercise.order, exerciseKey: exercise.exerciseKey, targetWeightLb: exercise.targetWeightLb,
                sets: exercise.sets.enumerated().map { j, set in
                    guard j == s else { return set }
                    return WorkoutSetValue(id: set.id, order: set.order, weightLb: weightLb ?? set.weightLb, reps: set.reps,
                                           status: status, rpe: rpe, rpeSkipped: rpeSkipped, loggedAt: loggedAt)
                })
        }
    }

    /// Every set of every exercise done at RPE 7 (weights unchanged).
    static func allDone(_ exercises: [WorkoutExerciseValue], rpe: Int? = 7) -> [WorkoutExerciseValue] {
        var result = exercises
        for e in exercises.indices {
            for s in exercises[e].sets.indices {
                result = editing(result, exercise: e, set: s, status: .done, rpe: rpe)
            }
        }
        return result
    }

    /// Exercises and each exercise's sets in reverse array order (the ids and orders are unchanged).
    static func shuffled(_ exercises: [WorkoutExerciseValue]) -> [WorkoutExerciseValue] {
        exercises.reversed().map { exercise in
            WorkoutExerciseValue(id: exercise.id, order: exercise.order, exerciseKey: exercise.exerciseKey,
                                 targetWeightLb: exercise.targetWeightLb, sets: exercise.sets.reversed())
        }
    }
}

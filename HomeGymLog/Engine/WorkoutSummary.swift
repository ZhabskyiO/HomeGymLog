import Foundation

/// One personal record set by this workout: the exercise's best done weight beat its previous best (pounds).
nonisolated struct SummaryRecord: Equatable, Sendable {
    let exerciseKey: String
    /// The best done weight before this workout in the current program; nil when there was none ("—").
    let previousBestLb: Double?
    /// This workout's top done weight for the exercise.
    let weightLb: Double
}

/// Everything the summary screen shows, as numbers. Text lives in `Shared/WorkoutText`.
nonisolated struct WorkoutSummaryValue: Equatable, Sendable {
    /// Σ weight × reps over done sets, in pounds.
    let volumeLb: Double
    /// The latest `loggedAt` of a non-pending set, else the start. Done stores this as `finishedAt`.
    let endedAt: Date
    /// Whole seconds from the start to `endedAt`, never negative.
    let durationSeconds: Int
    /// Library muscles of exercises with at least one done set, first appearance, exercise order.
    let muscles: [MuscleGroup]
    let records: [SummaryRecord]
}

/// Summary rules over plain workout values (spec 5.4, 5.6). Pure: no clock, no store.
nonisolated enum WorkoutSummary {
    /// Volume, end instant, duration, muscles and records. `bestsBefore` maps exercise key → best done weight (lb)
    /// in the current program before this workout. A record needs a strictly heavier top (a tie is not a record);
    /// a key appearing twice yields one record at its first position carrying the larger top.
    static func make(exercises: [WorkoutExerciseValue], startedAt: Date, bestsBefore: [String: Double]) -> WorkoutSummaryValue {
        let ordered = WorkoutFlow.sorted(exercises)
        var volume = 0.0
        var topsByKey: [String: Double] = [:]
        var keysInOrder: [String] = []
        var muscles: [MuscleGroup] = []
        for exercise in ordered {
            let done = exercise.sets.filter { $0.status == .done }
            volume += done.reduce(0) { $0 + $1.weightLb * Double($1.reps) }
            guard let top = done.map(\.weightLb).max() else { continue }
            if let current = topsByKey[exercise.exerciseKey] {
                topsByKey[exercise.exerciseKey] = max(current, top)
            } else {
                topsByKey[exercise.exerciseKey] = top
                keysInOrder.append(exercise.exerciseKey)
            }
            if let muscle = ExerciseLibrary.exercise(for: exercise.exerciseKey)?.muscle, !muscles.contains(muscle) {
                muscles.append(muscle)
            }
        }
        let records: [SummaryRecord] = keysInOrder.compactMap { key in
            guard let top = topsByKey[key] else { return nil }
            let previous = bestsBefore[key]
            if let previous, top <= previous { return nil }
            return SummaryRecord(exerciseKey: key, previousBestLb: previous, weightLb: top)
        }
        let end = endInstant(exercises: exercises, startedAt: startedAt)
        return WorkoutSummaryValue(volumeLb: volume, endedAt: end, durationSeconds: elapsedSeconds(from: startedAt, to: end),
                                   muscles: muscles, records: records)
    }

    /// The latest `loggedAt` over done or skipped sets; `startedAt` when no set carries one.
    static func endInstant(exercises: [WorkoutExerciseValue], startedAt: Date) -> Date {
        exercises.flatMap(\.sets).filter { $0.status != .pending }.compactMap(\.loggedAt).max() ?? startedAt
    }

    /// Whole seconds from `start` to `end`: max(0, ⌊end − start⌋). A clock earlier than the start reads 0.
    static func elapsedSeconds(from start: Date, to end: Date) -> Int {
        Int(max(0, end.timeIntervalSince(start)).rounded(.down))
    }

    /// Exercise key → best weight (lb). Duplicate keys keep the heavier weight instead of trapping.
    static func bests(from records: [PersonalRecord]) -> [String: Double] {
        Dictionary(records.map { ($0.exerciseKey, $0.weightLb) }, uniquingKeysWith: { max($0, $1) })
    }
}

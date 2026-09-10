import Foundation
import SwiftData

/// One exercise performed within a workout.
@Model
final class LoggedExercise {
    var id: UUID = UUID()
    /// 0-based position in the workout.
    var order: Int = 0
    /// Library key actually performed.
    var exerciseKey: String = ""
    /// The planned key if the user swapped; nil otherwise.
    var swappedFromKey: String?
    /// Planned or recomputed target in pounds at workout start.
    var targetWeightLb: Double = 0
    var workout: WorkoutLog?
    /// Unordered in the store; read through `sortedSets`.
    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.exercise)
    var sets: [LoggedSet] = []

    init(order: Int, exerciseKey: String, swappedFromKey: String? = nil, targetWeightLb: Double) {
        self.order = order
        self.exerciseKey = exerciseKey
        self.swappedFromKey = swappedFromKey
        self.targetWeightLb = targetWeightLb
    }

    var sortedSets: [LoggedSet] { sets.sorted { $0.order < $1.order } }
}

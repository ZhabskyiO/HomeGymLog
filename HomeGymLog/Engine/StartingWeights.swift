import Foundation

/// One row of the onboarding "Starting weights" step.
nonisolated struct StartingWeightRow: Identifiable, Hashable, Sendable {
    let key: String
    var id: String { key }
    let name: String
    let equipment: String
    let kind: EquipmentKind
    /// Current value in pounds: the user's override, else the library default.
    let weightLb: Double
}

/// Derives the starting-weight rows for a program shape.
nonisolated enum StartingWeights {
    /// Rows in `SplitPlans.exerciseKeys` order; library default unless `overrides` has the key.
    static func rows(frequency: Int, sessionLengthMinutes: Int, overrides: [String: Double]) -> [StartingWeightRow] {
        guard let keys = SplitPlans.exerciseKeys(frequency: frequency, sessionLengthMinutes: sessionLengthMinutes) else { return [] }
        return keys.compactMap { key in
            guard let exercise = ExerciseLibrary.exercise(for: key) else { return nil }
            return StartingWeightRow(key: key, name: exercise.name, equipment: exercise.equipment, kind: exercise.kind,
                                     weightLb: overrides[key] ?? exercise.defaultWeightLb)
        }
    }
}

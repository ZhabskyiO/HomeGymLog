import Foundation

/// The onboarding answers a restart starts from (spec 4.3). Plain values: the archived program's scalar fields after every
/// per-field fallback has been applied, ready for `OnboardingDraft(answers:units:bodyWeightUnit:)`.
nonisolated struct OnboardingAnswers: Equatable, Sendable {
    let months: Int
    let frequency: Int
    /// Sorted, 0 = Monday, exactly `frequency` entries.
    let trainingWeekdays: [Int]
    let sessionLengthMinutes: Int
    let bodyWeightLb: Double
    let experience: Experience
    /// Only keys the library knows and weights the equipment can actually hold.
    let startingWeightsLb: [String: Double]
}

/// "Build a new program…" prefills onboarding from the newest archived program (spec 5.2). Every field falls back on its own
/// to the onboarding default, so a hand-edited or future store can never make onboarding throw or trap.
/// Analogy: parsing persisted form state with a per-field schema, keeping what validates and defaulting the rest.
nonisolated enum RestartPrefill {
    static func answers(months: Int, frequency: Int, trainingWeekdays: [Int], sessionLengthMinutes: Int, bodyWeightLb: Double,
                        experience: String, startingWeightsLb: [String: Double]) -> OnboardingAnswers {
        let months = ProgramGenerator.allowedMonths.contains(months) ? months : 1
        let frequency = ProgramGenerator.allowedFrequencies.contains(frequency) ? frequency : 4
        let length = ProgramGenerator.allowedSessionLengths.contains(sessionLengthMinutes) ? sessionLengthMinutes : 45
        return OnboardingAnswers(
            months: months,
            frequency: frequency,
            trainingWeekdays: weekdays(trainingWeekdays, frequency: frequency),
            sessionLengthMinutes: length,
            bodyWeightLb: min(max(bodyWeightLb, OnboardingDraft.bodyWeightRangeLb.lowerBound),
                              OnboardingDraft.bodyWeightRangeLb.upperBound),
            experience: Experience(rawValue: experience) ?? .intermediate,
            startingWeightsLb: startingWeightsLb.filter { key, lb in
                guard let exercise = ExerciseLibrary.exercise(for: key) else { return false }
                return exercise.kind.isLoadable(lb: lb)
            }
        )
    }

    /// Kept and sorted only when they are exactly `frequency` distinct weekdays in 0…6; otherwise the split's own defaults.
    private static func weekdays(_ days: [Int], frequency: Int) -> [Int] {
        let valid = Set(days.filter { (0...6).contains($0) })
        if valid.count == frequency && valid.count == days.count {
            return valid.sorted()
        }
        return SplitPlans.defaultWeekdays(frequency: frequency) ?? [0, 1, 3, 4]
    }
}

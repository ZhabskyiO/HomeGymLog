import Foundation

/// Everything the generator needs. `generatedOn` is the day the user finishes onboarding.
nonisolated struct ProgramInputs: Equatable, Sendable {
    /// Program length: 1, 2, 3 or 6 (four weeks per month).
    var months: Int
    /// Sessions per week: 3, 4 or 5; selects the split.
    var frequency: Int
    /// Distinct weekdays, 0 = Monday, count == frequency.
    var trainingWeekdays: [Int]
    /// 20, 30, 45 or 60; sets how many exercises each session gets.
    var sessionLengthMinutes: Int
    /// Partial map of starting weights in pounds; missing keys use the library default.
    var startingWeightsLb: [String: Double]
    var generatedOn: Date
}

/// One case per validation rule. Onboarding cannot produce these; they are programming errors.
nonisolated enum ProgramInputError: Error, Equatable {
    case unsupportedMonths(Int)
    case unsupportedFrequency(Int)
    case unsupportedSessionLength(Int)
    case weekdayCountMismatch(expected: Int, actual: Int)
    /// A weekday outside 0…6, or one listed twice.
    case invalidWeekday(Int)
    case unknownExerciseKey(String)
    case unloadableStartingWeight(key: String, weightLb: Double)
}

/// A planned session as a plain value; the model layer copies it into a `PlannedSession` row.
nonisolated struct GeneratedSession: Equatable, Sendable {
    var index: Int
    /// 1-based program week, derived from index, unchanged by re-slotting.
    var week: Int
    var phase: Phase
    var name: String
    /// Start of the scheduled calendar day.
    var scheduledDate: Date
    var sets: Int
    var reps: Int
    var restSeconds: Int
    var exercises: [PlannedExercise]
}

/// The generator's output. Mirrors the `Program` row without identity or relationships.
nonisolated struct GeneratedProgram: Equatable, Sendable {
    /// Monday of the week containing `generatedOn`.
    var startDate: Date
    var months: Int
    var frequency: Int
    var trainingWeekdays: [Int]
    var sessionLengthMinutes: Int
    /// Fully resolved: exactly the keys the program uses, user value or library default.
    var startingWeightsLb: [String: Double]
    var sessions: [GeneratedSession]
}

/// Builds the full session list from the onboarding answers. Pure: no store, no `Date()`.
nonisolated enum ProgramGenerator {
    static let allowedMonths: Set<Int> = [1, 2, 3, 6]
    static let allowedFrequencies: Set<Int> = [3, 4, 5]
    static let allowedSessionLengths: Set<Int> = [20, 30, 45, 60]

    /// Validates `inputs` (throws `ProgramInputError`) and returns every session with its week, phase,
    /// scheduled day and target weights in pounds. Sessions dated before `generatedOn` are re-slotted
    /// forward onto the next training days (mid-week start).
    static func generate(_ inputs: ProgramInputs, calendar: Calendar) throws -> GeneratedProgram {
        try validate(inputs)

        let days = inputs.trainingWeekdays.sorted()
        let weeks = PhaseSplit.weeks(months: inputs.months)
        let splitDays = SplitPlans.days(frequency: inputs.frequency)!
        let exerciseCount = SplitPlans.exerciseCount(sessionLengthMinutes: inputs.sessionLengthMinutes)!
        let startDate = CalendarRules.monday(ofWeekContaining: inputs.generatedOn, calendar: calendar)

        var sessions: [GeneratedSession] = []
        // Same rule as the onboarding starting-weight rows, so stored keys and rows never differ.
        let usedKeys = Set(SplitPlans.exerciseKeys(frequency: inputs.frequency, sessionLengthMinutes: inputs.sessionLengthMinutes)!)
        for index in 0..<(weeks * inputs.frequency) {
            let week = index / inputs.frequency + 1
            let phase = PhaseSplit.phaseOf(week: week, weeks: weeks)
            let day = splitDays[index % inputs.frequency]
            let keys = Array(day.exerciseKeys.prefix(exerciseCount))
            let exercises = keys.enumerated().map { order, key in
                PlannedExercise(
                    order: order,
                    exerciseKey: key,
                    targetWeightLb: WeightFormula.targetWeightLb(key: key, week: week, phase: phase, startingWeightsLb: inputs.startingWeightsLb)!
                )
            }
            let baseDate = CalendarRules.day(startDate, adding: 7 * (week - 1) + days[index % inputs.frequency], calendar: calendar)
            sessions.append(GeneratedSession(
                index: index, week: week, phase: phase, name: day.name, scheduledDate: baseDate,
                sets: phase.sets, reps: phase.reps, restSeconds: phase.restSeconds, exercises: exercises
            ))
        }

        // Mid-week start: sessions whose base date is already past slide onto the next training days.
        // The map is empty when nothing precedes generatedOn, so the call is safe unconditionally.
        let slots = sessions.map { SessionSlot(index: $0.index, scheduledDate: $0.scheduledDate, status: .pending) }
        let cursor = CalendarRules.firstTrainingDay(onOrAfter: inputs.generatedOn, trainingWeekdays: days, calendar: calendar)
        let moved = Reslot.reslot(slots: slots, fromIndex: 0, startingAt: cursor, inclusive: true, trainingWeekdays: days, calendar: calendar)
        for (index, date) in moved {
            sessions[index].scheduledDate = date
        }

        let resolvedWeights = Dictionary(uniqueKeysWithValues: usedKeys.map { key in
            (key, inputs.startingWeightsLb[key] ?? ExerciseLibrary.exercise(for: key)!.defaultWeightLb)
        })

        return GeneratedProgram(
            startDate: startDate, months: inputs.months, frequency: inputs.frequency, trainingWeekdays: days,
            sessionLengthMinutes: inputs.sessionLengthMinutes, startingWeightsLb: resolvedWeights, sessions: sessions
        )
    }

    private static func validate(_ inputs: ProgramInputs) throws {
        guard allowedMonths.contains(inputs.months) else { throw ProgramInputError.unsupportedMonths(inputs.months) }
        guard allowedFrequencies.contains(inputs.frequency) else { throw ProgramInputError.unsupportedFrequency(inputs.frequency) }
        guard allowedSessionLengths.contains(inputs.sessionLengthMinutes) else {
            throw ProgramInputError.unsupportedSessionLength(inputs.sessionLengthMinutes)
        }
        guard inputs.trainingWeekdays.count == inputs.frequency else {
            throw ProgramInputError.weekdayCountMismatch(expected: inputs.frequency, actual: inputs.trainingWeekdays.count)
        }
        var seen: Set<Int> = []
        for weekday in inputs.trainingWeekdays {
            guard (0...6).contains(weekday), seen.insert(weekday).inserted else { throw ProgramInputError.invalidWeekday(weekday) }
        }
        for (key, weight) in inputs.startingWeightsLb.sorted(by: { $0.key < $1.key }) {
            guard let exercise = ExerciseLibrary.exercise(for: key) else { throw ProgramInputError.unknownExerciseKey(key) }
            guard exercise.kind.isLoadable(lb: weight) else { throw ProgramInputError.unloadableStartingWeight(key: key, weightLb: weight) }
        }
    }
}

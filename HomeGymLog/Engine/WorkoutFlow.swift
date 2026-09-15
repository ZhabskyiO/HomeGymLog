import Foundation

// Plain values the workout screen maps its rows into. Every type is `nonisolated` like the rest of the Engine
// (pure logic, callable from tests and background work), and carries row ids so a write finds its row by id,
// never by array position. React analogy: key rows by `id`, never by index.

/// One set of an in-progress workout. `weightLb` is pounds (storage is always pounds).
nonisolated struct WorkoutSetValue: Equatable, Sendable {
    let id: UUID
    /// 0-based position within the exercise; ties break on `id.uuidString`.
    let order: Int
    let weightLb: Double
    let reps: Int
    let status: SetStatus
    /// 6–10, or nil while unrated, when the rating was skipped, or when the set was skipped.
    let rpe: Int?
    /// True when the RPE prompt was dismissed without choosing a value.
    let rpeSkipped: Bool
    let loggedAt: Date?
}

/// One exercise of an in-progress workout, with its sets in any order (`WorkoutFlow.sorted` orders them).
nonisolated struct WorkoutExerciseValue: Equatable, Sendable {
    let id: UUID
    /// 0-based position in the workout; ties break on `id.uuidString`.
    let order: Int
    let exerciseKey: String
    /// Target load in pounds at workout start.
    let targetWeightLb: Double
    let sets: [WorkoutSetValue]
}

/// The session fields the workout and summary headers show, read once from the log's session.
nonisolated struct WorkoutSessionInfo: Equatable, Sendable {
    let name: String
    /// 1-based stored program week.
    let week: Int
    let phase: Phase
}

/// One progress-bar segment: before the displayed exercise, the displayed one, or after it.
nonisolated enum ProgressTone: Equatable, Sendable {
    case passed, current, upcoming
}

/// The workout's sub-state, derived from set rows only (spec 5.1). Positions are 0-based indexes into
/// `WorkoutFlow.sorted` output. React analogy: a selector over the store, never a stored cursor.
nonisolated enum WorkoutState: Equatable, Sendable {
    case logging(exercise: Int, set: Int)
    case rpePending(exercise: Int, set: Int)
    case summary
}

/// How one set row of the displayed exercise is drawn (spec 2.3, 5.2).
nonisolated enum SetRowKind: Equatable, Sendable {
    /// `rpe` is nil while awaiting a rating or when the rating was skipped.
    case done(rpe: Int?)
    case skipped, active, waiting
}

nonisolated struct SetRowState: Equatable, Sendable {
    let kind: SetRowKind
    /// Rows after the focus set are drawn at 45 % opacity.
    let dimmed: Bool
}

/// Workout rules over plain values. Nothing here throws or traps: every rule is total, so rows that break the
/// writers' invariants still yield exactly one answer.
nonisolated enum WorkoutFlow {
    /// Exercises by (`order`, `id.uuidString`), each with its sets sorted the same way, so ties are
    /// deterministic across fetches.
    static func sorted(_ exercises: [WorkoutExerciseValue]) -> [WorkoutExerciseValue] {
        exercises
            .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
            .map { exercise in
                WorkoutExerciseValue(id: exercise.id, order: exercise.order, exerciseKey: exercise.exerciseKey,
                                     targetWeightLb: exercise.targetWeightLb,
                                     sets: exercise.sets.sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) })
            }
    }

    /// A set's place in the flattened (exercise, set) sequence.
    private struct Position {
        let exercise: Int
        let set: Int
        let value: WorkoutSetValue
    }

    private static func flattened(_ exercises: [WorkoutExerciseValue]) -> [Position] {
        sorted(exercises).enumerated().flatMap { exerciseIndex, exercise in
            exercise.sets.enumerated().map { Position(exercise: exerciseIndex, set: $0.offset, value: $0.element) }
        }
    }

    private static func awaitsRating(_ set: WorkoutSetValue) -> Bool {
        set.status == .done && set.rpe == nil && !set.rpeSkipped
    }

    /// Spec 5.1. S = every set in (exercise, set) order; p = the first pending set; q = the set just before p, or
    /// S's last set when nothing is pending. RPE pending at q if q is done, unrated and not skipped; else logging
    /// at p; else summary. No exercises → summary.
    static func state(exercises: [WorkoutExerciseValue]) -> WorkoutState {
        let all = flattened(exercises)
        let pendingIndex = all.firstIndex { $0.value.status == .pending }
        let previousIndex: Int? = {
            if let pendingIndex { return pendingIndex > 0 ? pendingIndex - 1 : nil }
            return all.isEmpty ? nil : all.count - 1
        }()
        if let previousIndex, awaitsRating(all[previousIndex].value) {
            return .rpePending(exercise: all[previousIndex].exercise, set: all[previousIndex].set)
        }
        if let pendingIndex {
            return .logging(exercise: all[pendingIndex].exercise, set: all[pendingIndex].set)
        }
        return .summary
    }

    /// The (exercise, set) position the state points at; nil in summary.
    private static func focusPosition(_ state: WorkoutState) -> (exercise: Int, set: Int)? {
        switch state {
        case .logging(let exercise, let set), .rpePending(let exercise, let set): return (exercise, set)
        case .summary: return nil
        }
    }

    /// True in the Logging state, whatever its position.
    private static func isLogging(_ state: WorkoutState) -> Bool {
        if case .logging = state { return true }
        return false
    }

    /// The set being logged (Logging) or rated (RPE pending); nil in summary or for an out-of-range position.
    static func focusSet(exercises: [WorkoutExerciseValue], state: WorkoutState) -> WorkoutSetValue? {
        guard let position = focusPosition(state) else { return nil }
        let ordered = sorted(exercises)
        guard ordered.indices.contains(position.exercise) else { return nil }
        let sets = ordered[position.exercise].sets
        return sets.indices.contains(position.set) ? sets[position.set] : nil
    }

    static func isRatingPending(_ state: WorkoutState) -> Bool {
        if case .rpePending = state { return true }
        return false
    }

    /// The exercise shown on screen as a position: the focus set's exercise; nil in summary. The header's progress
    /// segments and "Exercise n of m" need the index; `displayedExercise(exercises:state:)` returns the value.
    static func displayedExercise(_ state: WorkoutState) -> Int? {
        focusPosition(state)?.exercise
    }

    /// The exercise shown on screen as a value: the focus position's exercise from `sorted(exercises)`; nil in summary or
    /// for an out-of-range position (including a negative one). The one lookup the screen (bar label, pill, preview, Swap
    /// state) and the logging content share.
    static func displayedExercise(exercises: [WorkoutExerciseValue], state: WorkoutState) -> WorkoutExerciseValue? {
        guard let index = displayedExercise(state) else { return nil }
        let ordered = sorted(exercises)
        return ordered.indices.contains(index) ? ordered[index] : nil
    }

    /// Spec 5.3: Swap is enabled only while every set of the exercise is pending, so a done or skipped weight is never
    /// credited to another key. An exercise with no sets → true.
    static func canSwap(_ exercise: WorkoutExerciseValue) -> Bool {
        exercise.sets.allSatisfy { $0.status == .pending }
    }

    /// Spec 5.2: one row per set of the displayed exercise. Done → `.done(rpe)`, skipped → `.skipped`, the focus
    /// set in Logging with no sheet → `.active`, otherwise `.waiting`; dimmed when after the focus set.
    static func rowStates(exercises: [WorkoutExerciseValue], state: WorkoutState, sheetOpen: Bool) -> [SetRowState] {
        guard let position = focusPosition(state) else { return [] }
        let ordered = sorted(exercises)
        guard ordered.indices.contains(position.exercise) else { return [] }
        let logging = isLogging(state)
        return ordered[position.exercise].sets.enumerated().map { index, set in
            let kind: SetRowKind
            switch set.status {
            case .done: kind = .done(rpe: set.rpe)
            case .skipped: kind = .skipped
            case .pending: kind = (logging && index == position.set && !sheetOpen) ? .active : .waiting
            }
            return SetRowState(kind: kind, dimmed: index > position.set)
        }
    }

    /// The swipe hint shows only at exercise 1, set 1, in Logging, with no sheet.
    static func showsHint(_ state: WorkoutState, sheetOpen: Bool) -> Bool {
        state == .logging(exercise: 0, set: 0) && !sheetOpen
    }

    /// "Next exercise ›" works only while logging (disabled while a rating is pending, absent in summary).
    static func nextExerciseEnabled(_ state: WorkoutState) -> Bool {
        isLogging(state)
    }

    /// One tone per exercise relative to the displayed one. A `displayed` below 0 (before the first segment)
    /// makes every segment upcoming.
    static func progress(exerciseCount: Int, displayed: Int) -> [ProgressTone] {
        (0..<max(0, exerciseCount)).map { index in
            if index < displayed { return .passed }
            return index == displayed ? .current : .upcoming
        }
    }

    /// True when at least one set is done or skipped, which is when Exit asks for confirmation.
    static func hasLoggedSet(_ exercises: [WorkoutExerciseValue]) -> Bool {
        exercises.contains { $0.sets.contains { $0.status != .pending } }
    }

    /// The adjust sheet's reps − : never below 1.
    static func decrementedReps(_ reps: Int) -> Int {
        max(1, reps - 1)
    }

    /// A session can be started only when it is pending and dated today or before today.
    static func isStartable(_ state: WeekStripState) -> Bool {
        state == .today || state == .missed
    }
}

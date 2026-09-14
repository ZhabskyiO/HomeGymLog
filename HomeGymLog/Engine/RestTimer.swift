import Foundation

// Rest-timer rules over plain values (spec 4.3, 5.2–5.5). No SwiftUI, SwiftData or text: the screen reads the two stored
// instants and `clock.now()`, and these functions decide what it shows. React analogy: selectors over a stored deadline,
// never a countdown held in state.

/// What "Next:" names while resting: the first set of the displayed exercise, or set `number` of `of` within it.
nonisolated enum RestNext: Equatable, Sendable {
    case firstSet(exerciseKey: String)
    case set(number: Int, of: Int)
}

/// Everything the rest card draws from: the stored instants (total = `endsAt − startedAt`) and the next set.
nonisolated struct RestDisplay: Equatable, Sendable {
    let startedAt: Date
    let endsAt: Date
    let next: RestNext
}

/// The "Rest over" end rule's output: whether to announce now, and the last-seen end instant the screen stores next.
nonisolated struct RestEndObservation: Equatable, Sendable {
    let announce: Bool
    let lastSeenEndsAt: Date?
}

nonisolated enum RestTimer {
    /// Whole seconds left, rounded up (a tick lands a few ms after `startedAt + k`, so the label reads total − k);
    /// 0 once the end is reached or passed.
    static func remainingSeconds(endsAt: Date, now: Date) -> Int {
        let interval = endsAt.timeIntervalSince(now)
        return interval > 0 ? Int(interval.rounded(.up)) : 0
    }

    /// The remaining share of the rest, clamped to 0…1 (a clock moved back reads 1); 0 when the total is not positive.
    static func remainingFraction(startedAt: Date, endsAt: Date, now: Date) -> Double {
        let total = endsAt.timeIntervalSince(startedAt)
        guard total > 0 else { return 0 }
        return min(1, max(0, endsAt.timeIntervalSince(now) / total))
    }

    /// Spec 5.3: the card's values while resting, else nil. Resting needs both instants, `now < restEndsAt`, and the
    /// Logging state at an exercise that exists in `WorkoutFlow.sorted(exercises)` (the state's positions index that order).
    static func display(restStartedAt: Date?, restEndsAt: Date?, now: Date, exercises: [WorkoutExerciseValue],
                        state: WorkoutState) -> RestDisplay? {
        guard let restStartedAt, let restEndsAt, now < restEndsAt,
              case .logging(let exercise, let set) = state else { return nil }
        let ordered = WorkoutFlow.sorted(exercises)
        guard ordered.indices.contains(exercise) else { return nil }
        let next: RestNext = set == 0
            ? .firstSet(exerciseKey: ordered[exercise].exerciseKey)
            : .set(number: set + 1, of: ordered[exercise].sets.count)
        return RestDisplay(startedAt: restStartedAt, endsAt: restEndsAt, next: next)
    }

    /// Spec 5.5, run only from effects (never in `body`). Announce when the end instant the screen last saw while
    /// resting is still the stored one, the screen is no longer resting, and that instant has passed. The next
    /// last-seen instant is the stored end while resting, else nil, so each end instant can announce at most once.
    static func observeEnd(lastSeenEndsAt: Date?, restEndsAt: Date?, resting: Bool, now: Date) -> RestEndObservation {
        let announce: Bool
        if let lastSeenEndsAt, restEndsAt == lastSeenEndsAt, !resting, now >= lastSeenEndsAt {
            announce = true
        } else {
            announce = false
        }
        return RestEndObservation(announce: announce, lastSeenEndsAt: resting ? restEndsAt : nil)
    }
}

/// What the notifier does for a stored end instant. `decide` is the only place the schedule-or-cancel rule lives.
nonisolated enum RestNotificationPlan: Equatable, Sendable {
    case schedule(Date)
    case cancel

    /// `.schedule(endsAt)` when the end is still ahead of `now`; nil, equal or past → `.cancel`.
    static func decide(restEndsAt: Date?, now: Date) -> RestNotificationPlan {
        guard let restEndsAt, restEndsAt > now else { return .cancel }
        return .schedule(restEndsAt)
    }
}

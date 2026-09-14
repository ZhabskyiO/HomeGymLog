import Foundation
import SwiftData

/// One performed (or in-progress) session. In progress iff `finishedAt == nil`; there is no status field.
@Model
final class WorkoutLog {
    var id: UUID = UUID()
    var startedAt: Date = Date.distantPast
    /// nil while in progress. The only in-progress indicator.
    var finishedAt: Date?
    /// When the current rest began; nil when none is stored. Optional, so an existing store migrates with no default.
    var restStartedAt: Date?
    /// When the current rest ends; the card shows while now < restEndsAt. Nil on every finished log (the writers clear
    /// it before the summary), so nothing outside the workout screen may read it as "a rest happened".
    var restEndsAt: Date?
    var session: PlannedSession?
    /// Unordered in the store; read through `sortedExercises`.
    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.workout)
    var exercises: [LoggedExercise] = []

    init(startedAt: Date, finishedAt: Date? = nil) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    var isInProgress: Bool { finishedAt == nil }
    var sortedExercises: [LoggedExercise] { exercises.sorted { $0.order < $1.order } }
}

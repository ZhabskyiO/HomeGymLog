import Foundation
import SwiftData

/// One set of a logged exercise. Created up front when a workout starts; written the moment it is logged.
@Model
final class LoggedSet {
    var id: UUID = UUID()
    /// 0-based position within the exercise.
    var order: Int = 0
    /// Pounds; starts at the exercise target, changed by "adjust" in equipment steps.
    var weightLb: Double = 0
    /// Starts at the session's planned reps; changed by "adjust".
    var reps: Int = 0
    /// Raw `SetStatus` value; use `status`.
    var statusRaw: String = SetStatus.pending.rawValue
    /// 6–10; nil until chosen or if skipped.
    var rpe: Int?
    /// When marked done or skipped.
    var loggedAt: Date?
    var exercise: LoggedExercise?

    init(order: Int, weightLb: Double, reps: Int, status: SetStatus = .pending, rpe: Int? = nil, loggedAt: Date? = nil) {
        self.order = order
        self.weightLb = weightLb
        self.reps = reps
        self.statusRaw = status.rawValue
        self.rpe = rpe
        self.loggedAt = loggedAt
    }

    var status: SetStatus {
        get { SetStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

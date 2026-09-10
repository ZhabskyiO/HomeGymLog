import Foundation
import SwiftData

/// One scheduled session of a program. `scheduledDate` is the only field that changes after generation.
@Model
final class PlannedSession {
    var id: UUID = UUID()
    /// 0-based position in the program; never changes.
    var index: Int = 0
    /// 1-based program week; never changes, even after a date shift.
    var week: Int = 1
    /// Raw `Phase` value; use `phase`.
    var phaseRaw: String = Phase.foundation.rawValue
    var name: String = ""
    /// Start of the scheduled calendar day. Mutable: re-slotting moves it.
    var scheduledDate: Date = Date()
    var sets: Int = 3
    var reps: Int = 12
    var restSeconds: Int = 75
    /// Embedded ordered value; every field added to `PlannedExercise` later must be optional.
    var exercises: [PlannedExercise] = []
    /// Raw `SessionStatus` value; use `status`.
    var statusRaw: String = SessionStatus.pending.rawValue
    var program: Program?
    /// The log that completed (or is completing) this session.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutLog.session)
    var workoutLog: WorkoutLog?

    init(index: Int, week: Int, phase: Phase, name: String, scheduledDate: Date, sets: Int, reps: Int, restSeconds: Int,
         exercises: [PlannedExercise], status: SessionStatus = .pending) {
        self.index = index
        self.week = week
        self.phaseRaw = phase.rawValue
        self.name = name
        self.scheduledDate = scheduledDate
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.exercises = exercises
        self.statusRaw = status.rawValue
    }

    var phase: Phase {
        get { Phase(rawValue: phaseRaw) ?? .foundation }
        set { phaseRaw = newValue.rawValue }
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// Pending and scheduled on a calendar day before `today`.
    func isMissed(today: Date, calendar: Calendar) -> Bool {
        status == .pending && CalendarRules.startOfDay(scheduledDate, calendar: calendar) < CalendarRules.startOfDay(today, calendar: calendar)
    }
}

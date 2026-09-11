import Foundation

/// A planned session as Home needs it. Plain value mapped from one `PlannedSession`.
nonisolated struct SessionSummary: Equatable, Sendable {
    let index: Int
    let week: Int
    let phase: Phase
    let name: String
    /// Start of the scheduled calendar day.
    let scheduledDate: Date
    let status: SessionStatus
    let sets: Int
    let reps: Int
    let exercises: [PlannedExercise]
}

/// One logged set. `weightLb` is the weight actually used, in pounds (storage is always pounds).
nonisolated struct LoggedSetValue: Equatable, Sendable {
    let weightLb: Double
    let reps: Int
    let status: SetStatus
}

/// One exercise inside a finished log; `order` is its position in the session, starting at 0.
nonisolated struct LoggedExerciseValue: Equatable, Sendable {
    let order: Int
    let exerciseKey: String
    let sets: [LoggedSetValue]
}

/// A finished workout log (in-progress logs are never mapped).
nonisolated struct FinishedLogValue: Equatable, Sendable {
    let sessionIndex: Int
    let exercises: [LoggedExerciseValue]
}

nonisolated enum HomeStatsInputError: Error, Equatable {
    case duplicateSessionIndex(Int)
    /// A finished log whose session index is not among the sessions.
    case unknownSessionIndex(Int)
    /// Two finished logs for the same session.
    case duplicateLogIndex(Int)
}

/// Everything `HomeStats` reads, validated once. Analogy: the normalized store slice a selector runs over.
nonisolated struct HomeStatsInput: Equatable, Sendable {
    let sessions: [SessionSummary]
    let logs: [FinishedLogValue]

    /// The only validating step: session indexes must be unique, every log must belong to a session, and a
    /// session has at most one finished log.
    init(sessions: [SessionSummary], logs: [FinishedLogValue]) throws {
        var seen: Set<Int> = []
        for session in sessions {
            if !seen.insert(session.index).inserted { throw HomeStatsInputError.duplicateSessionIndex(session.index) }
        }
        var seenLogs: Set<Int> = []
        for log in logs {
            guard seen.contains(log.sessionIndex) else { throw HomeStatsInputError.unknownSessionIndex(log.sessionIndex) }
            if !seenLogs.insert(log.sessionIndex).inserted { throw HomeStatsInputError.duplicateLogIndex(log.sessionIndex) }
        }
        self.init(validated: sessions, logs: logs)
    }

    private init(validated sessions: [SessionSummary], logs: [FinishedLogValue]) {
        self.sessions = sessions
        self.logs = logs
    }

    static let empty = HomeStatsInput(validated: [], logs: [])
}

nonisolated enum Greeting: Equatable, Sendable {
    case morning, afternoon, evening
}

nonisolated struct CurrentWeek: Equatable, Sendable {
    let week: Int
    let phase: Phase
}

nonisolated enum WeekStripState: Equatable, Sendable {
    case completed, today, scheduled, missed, skipped, rest
}

nonisolated struct WeekStripDay: Equatable, Sendable {
    let date: Date
    let isToday: Bool
    let state: WeekStripState
    let dayNumber: Int
}

/// The best done weight for one exercise in the current program, in pounds.
nonisolated struct PersonalRecord: Equatable, Sendable {
    let exerciseKey: String
    let weightLb: Double
    /// The session day the best was first reached.
    let date: Date
    let sessionIndex: Int
    let order: Int
}

import Foundation

/// The numbers the "Your program" step shows, as a plain value. Text formatting lives in Shared.
nonisolated struct ProgramSummary: Equatable, Sendable {
    let months: Int
    let weeks: Int
    let phases: [PhaseRange]
    let totalSessions: Int
    let frequency: Int
    let splitName: String
    let sessionLengthMinutes: Int
    let firstSessionName: String
    /// Start of the first session's calendar day.
    let firstSessionDate: Date

    init(generated: GeneratedProgram) {
        months = generated.months
        weeks = PhaseSplit.weeks(months: generated.months)
        phases = PhaseSplit.phaseRanges(weeks: weeks)
        totalSessions = generated.sessions.count
        frequency = generated.frequency
        splitName = SplitPlans.info(frequency: generated.frequency)?.name ?? ""
        sessionLengthMinutes = generated.sessionLengthMinutes
        firstSessionName = generated.sessions.first?.name ?? ""
        firstSessionDate = generated.sessions.first?.scheduledDate ?? generated.startDate
    }
}

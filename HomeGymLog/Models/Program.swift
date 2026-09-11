import Foundation
import SwiftData

/// A generated training program. At most one is current (`archivedAt == nil`).
/// SwiftData `@Model` classes are reference types the store tracks, like ORM rows with change tracking.
@Model
final class Program {
    var id: UUID = UUID()
    /// When the program was generated.
    var createdAt: Date = Date.distantPast
    /// nil while current. Reserved so "Build a new program" can archive or delete without a migration.
    var archivedAt: Date?
    /// Monday of the week containing the generation day; used for week numbering.
    var startDate: Date = Date.distantPast
    /// Program length: 1, 2, 3 or 6 (four weeks per month).
    var months: Int = 1
    /// Sessions per week: 3, 4 or 5.
    var frequency: Int = 3
    /// 0 = Monday … 6 = Sunday, sorted ascending, exactly `frequency` distinct values.
    var trainingWeekdays: [Int] = []
    /// 20, 30, 45 or 60; decided how many exercises each session got at generation.
    var sessionLengthMinutes: Int = 45
    /// Collected in onboarding; unused by any formula in v1.
    var bodyWeightLb: Double = 0
    /// "Beginner", "Intermediate" or "Advanced"; unused by any formula in v1.
    var experience: String = ""
    /// Exercise key → starting weight in pounds, for every exercise the program uses.
    var startingWeightsLb: [String: Double] = [:]
    /// Unordered in the store; read through `sortedSessions`.
    @Relationship(deleteRule: .cascade, inverse: \PlannedSession.program)
    var sessions: [PlannedSession] = []

    init(createdAt: Date, archivedAt: Date? = nil, startDate: Date, months: Int, frequency: Int, trainingWeekdays: [Int],
         sessionLengthMinutes: Int, bodyWeightLb: Double, experience: String, startingWeightsLb: [String: Double]) {
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.startDate = startDate
        self.months = months
        self.frequency = frequency
        self.trainingWeekdays = trainingWeekdays
        self.sessionLengthMinutes = sessionLengthMinutes
        self.bodyWeightLb = bodyWeightLb
        self.experience = experience
        self.startingWeightsLb = startingWeightsLb
    }

    var weeks: Int { PhaseSplit.weeks(months: months) }
    var totalSessions: Int { weeks * frequency }
    var isCurrent: Bool { archivedAt == nil }
    var sortedSessions: [PlannedSession] { sessions.sorted { $0.index < $1.index } }
    /// Latest scheduled date across all sessions; nil for an empty program.
    var endDate: Date? { sessions.map(\.scheduledDate).max() }
}

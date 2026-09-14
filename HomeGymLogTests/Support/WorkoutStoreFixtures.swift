import Foundation
import SwiftData
@testable import HomeGymLog

/// Persistence fixtures for the workout store suites. `@MainActor` because the stores and models live in the app
/// target, which defaults to main-actor isolation.
@MainActor
enum WorkoutStoreFixtures {
    /// A 6-month, 5-day (Mon–Fri), 45-minute program started Mon 2026-08-31 12:00: its 120 session rows sorted by
    /// index, fetched with the Home/Program query predicate. Session 11 is Foundation 3 × 12, session 45 Build 4 × 10.
    static func sixMonthRows(in context: ModelContext) throws -> [PlannedSession] {
        let inputs = ProgramInputs(months: 6, frequency: 5, trainingWeekdays: [0, 1, 2, 3, 4], sessionLengthMinutes: 45,
                                   startingWeightsLb: [:], generatedOn: TestCalendar.day(2026, 8, 31))
        let now = TestCalendar.day(2026, 8, 31).addingTimeInterval(12 * 3600)
        guard let program = try ProgramStore.start(inputs, bodyWeightLb: 180, experience: "Intermediate", now: now,
                                                   calendar: TestCalendar.calendar, in: context) else {
            throw FixtureError.noProgram
        }
        return try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                 sortBy: [SortDescriptor(\.index)]))
    }

    /// The log's sets as [exercise][set], both sorted by `order`.
    static func sets(of log: WorkoutLog) -> [[LoggedSet]] {
        log.sortedExercises.map(\.sortedSets)
    }

    enum FixtureError: Error { case noProgram }
}

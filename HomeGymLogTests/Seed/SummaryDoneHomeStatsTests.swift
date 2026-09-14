#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-21 (numbers): Done on `-seed summary` writes `finish` at the end instant; Home's values from refetched rows
/// must then read streak 4, 11/120, 19 830 lb this week, four Sep 15 records and Legs next (spec AC-21).
@MainActor
@Suite struct SummaryDoneHomeStatsTests {
    private let cal = TestCalendar.calendar

    @Test("Home after Done on the summary seed")
    func homeAfterDone() throws {
        let container = try DebugSeed.summary.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
        let context = container.mainContext
        let today = DebugSeed.summary.referenceDate(calendar: cal)
        let logs = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        let log = try #require(logs.first)
        let exerciseRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let setRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        let values = WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows)
        let end = WorkoutSummary.endInstant(exercises: values, startedAt: log.startedAt)
        #expect(end == today)

        try WorkoutLogStore.finish(log, at: end, in: context)

        let fresh = ModelContext(container)
        let program = try #require(try ProgramStore.current(in: fresh))
        let rows = try fresh.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                   sortBy: [SortDescriptor(\.index)]))
        let input = try HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from: rows),
                                       logs: HomeSnapshotBuilder.finishedLogs(from: rows))
        #expect(HomeStats.streak(sessions: input.sessions, today: today, calendar: cal) == 4)
        #expect(HomeStats.completedCount(sessions: input.sessions) == 11)
        #expect(input.sessions.count == 120)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: today, calendar: cal) == 19830)
        let records = HomeStats.recentRecords(sessions: input.sessions, logs: input.logs)
        #expect(records.map(\.exerciseKey) == ["latPull", "lowRow", "dbRow", "rdl"])
        #expect(records.map(\.weightLb) == [120, 100, 47.5, 52.5])
        #expect(records.allSatisfy { $0.date == TestCalendar.day(2026, 9, 15) })
        let next = try #require(HomeStats.nextSession(sessions: input.sessions, today: today, calendar: cal))
        #expect(next.index == 12 && next.name == "Legs" && next.scheduledDate == TestCalendar.day(2026, 9, 16))
        #expect(HomeStats.todaySession(sessions: input.sessions, today: today, calendar: cal) == nil)
        let active = try fresh.fetchCount(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        #expect(active == 0)
    }
}
#endif

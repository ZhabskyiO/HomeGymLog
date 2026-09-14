#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-35: a missed session trained end to end on `missed` data (Tue 09-15 12:00): shared start of session 7, every
/// set logged at target with RPE 7, finish at the end instant, then Home's numbers from refetched rows (spec 5.7).
@MainActor
@Suite struct MissedWorkoutEndToEndTests {
    private let cal = TestCalendar.calendar

    @Test("session 7 completes on its own date; the summary and Home match spec 5.7")
    func missedSession() throws {
        let now = DebugSeed.missed.referenceDate(calendar: cal)
        let container = try DebugSeed.missed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        let started = try WorkoutLogStore.start(sessionIndex: 7, rows: rows, at: now, in: context)
        let log = try #require(started)

        var k = 0
        for exercise in WorkoutStoreFixtures.sets(of: log) {
            for set in exercise {
                k += 1
                try WorkoutLogStore.logSet(set, at: now.addingTimeInterval(Double(60 * k)), in: context)
                try WorkoutLogStore.setRPE(7, on: set, in: context)
            }
        }
        #expect(k == 15)

        let exerciseRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let setRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        let values = WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows)
        #expect(WorkoutFlow.state(exercises: values) == .summary)
        let bests = try WorkoutSnapshotBuilder.bestsBefore(programID: program.id, in: context)
        let summary = WorkoutSummary.make(exercises: values, startedAt: log.startedAt, bestsBefore: bests)
        #expect(summary.volumeLb == 9000)
        #expect(summary.muscles == [.legs])
        #expect(summary.records == [])
        #expect(summary.endedAt == now.addingTimeInterval(900) && summary.durationSeconds == 900)
        #expect(WorkoutSnapshotBuilder.sessionInfo(of: log) == WorkoutSessionInfo(name: "Legs", week: 2, phase: .foundation))

        try WorkoutLogStore.finish(log, at: WorkoutSummary.endInstant(exercises: values, startedAt: log.startedAt), in: context)

        let fresh = ModelContext(container)
        let freshRows = try fresh.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                        sortBy: [SortDescriptor(\.index)]))
        let session7 = freshRows[7]
        #expect(session7.status == .completed)
        #expect(session7.scheduledDate == TestCalendar.day(2026, 9, 9) && session7.week == 2)
        #expect(session7.workoutLog?.finishedAt == now.addingTimeInterval(900))

        let input = try HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from: freshRows),
                                       logs: HomeSnapshotBuilder.finishedLogs(from: freshRows))
        #expect(HomeStats.streak(sessions: input.sessions, today: now, calendar: cal) == 11)
        #expect(HomeStats.completedCount(sessions: input.sessions) == 11)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: now, calendar: cal) == 7560)
        #expect(HomeStats.todaySession(sessions: input.sessions, today: now, calendar: cal)?.index == 11)
        #expect(HomeStats.recentRecords(sessions: input.sessions, logs: input.logs).map(\.exerciseKey)
                == ["dbBench", "inclineDb", "shoulderPress", "pecDeck"])
        let summary7 = try #require(input.sessions.first { $0.index == 7 })
        #expect(!WorkoutFlow.isStartable(HomeStats.sessionState(summary7, today: now, calendar: cal)))
        let active = try fresh.fetchCount(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate))
        #expect(active == 0)
    }
}
#endif

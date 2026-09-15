#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

@MainActor
@Suite struct SeedHomeStatsTests {
    private let cal = TestCalendar.calendar

    private func input(for seed: DebugSeed) throws -> HomeStatsInput {
        let container = try seed.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sortBy: [SortDescriptor(\.index)]))
        return try HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from: rows), logs: HomeSnapshotBuilder.finishedLogs(from: rows))
    }

    @Test("end to end from each seed", arguments: [
        (DebugSeed.midProgram, 3, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 3),
        // In-progress logs are never mapped, so the workout seeds read midProgram's numbers.
        (DebugSeed.woStart, 3, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 3),
        (DebugSeed.woRest, 3, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 3),
        (DebugSeed.summary, 3, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 3),
        (DebugSeed.woSwapRDL, 3, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 3),
        (DebugSeed.woNotes, 3, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 3),
        // Missed-day seeds (spec 5.5): the shift makes s7 today's session (week 2) and restores the streak; a skip keeps
        // midProgram's numbers; Thu 09-17 with s12 missed has no streak.
        (DebugSeed.missedShifted, 10, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 2),
        (DebugSeed.missedSkipped, 3, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 3),
        (DebugSeed.missedSeveral, 0, 10, 120, 7560.0, ["dbBench", "inclineDb", "shoulderPress", "pecDeck"], 3),
        (DebugSeed.restDay, 7, 14, 120, 49320.0, ["chestPress", "skull", "latPull", "lowRow"], 4),
        (DebugSeed.freshProgram, 0, 0, 16, 0.0, [], 1),
    ])
    func stats(seed: DebugSeed, streak: Int, done: Int, total: Int, volume: Double, recent: [String], week: Int) throws {
        let input = try input(for: seed)
        let today = seed.referenceDate(calendar: cal)
        #expect(HomeStats.streak(sessions: input.sessions, today: today, calendar: cal) == streak)
        #expect(HomeStats.completedCount(sessions: input.sessions) == done && input.sessions.count == total)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: today, calendar: cal) == volume)
        #expect(HomeStats.recentRecords(sessions: input.sessions, logs: input.logs).map(\.exerciseKey) == recent)
        #expect(HomeStats.currentWeek(sessions: input.sessions, today: today, calendar: cal) == CurrentWeek(week: week, phase: .foundation))
    }
}
#endif

#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-21 (automatic half): the seeds never run the view code that fires an automatic missed-day action, so this suite
/// applies `MissedDay.resolution` plus the existing writers to a seed's real rows and asserts the resulting Home numbers
/// (spec 5.5 rows A and B). Every index the pass uses comes from the resolution, never typed here.
@MainActor
@Suite struct AutomaticPolicySeedTests {
    private let cal = TestCalendar.calendar

    private struct Loaded {
        let container: ModelContainer
        let context: ModelContext
        let program: Program
        let rows: [PlannedSession]
        let today: Date
    }

    @MainActor
    private func load(_ seed: DebugSeed) throws -> Loaded {
        let container = try seed.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\PlannedSession.index)]))
        return Loaded(container: container, context: context, program: program, rows: rows,
                      today: seed.referenceDate(calendar: cal))
    }

    /// One automatic pass, exactly as the host runs it: resolve, then shift once or skip each index earliest first.
    private func runPass(_ policy: MissedDayPolicy, on loaded: Loaded) throws {
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: loaded.rows)
        let resolution = MissedDay.resolution(policy: policy, sessions: summaries, silence: nil, today: loaded.today,
                                              calendar: cal)
        switch resolution {
        case .none, .prompt:
            Issue.record("expected an automatic action for \(policy)")
        case .shift(let missedIndex):
            _ = try ProgramStore.shift(missedIndex: missedIndex, rows: loaded.rows,
                                       trainingWeekdays: loaded.program.trainingWeekdays, today: loaded.today,
                                       calendar: cal, in: loaded.context)
        case .skip(let indexes):
            for index in indexes {
                _ = try ProgramStore.skipMissed(sessionIndex: index, rows: loaded.rows, today: loaded.today, calendar: cal,
                                                in: loaded.context)
            }
        }
    }

    private func expectStats(_ loaded: Loaded, streak: Int, done: Int, total: Int, volume: Double, week: Int) throws {
        let input = try HomeStatsInput(sessions: HomeSnapshotBuilder.sessionSummaries(from: loaded.rows),
                                       logs: HomeSnapshotBuilder.finishedLogs(from: loaded.rows))
        #expect(HomeStats.streak(sessions: input.sessions, today: loaded.today, calendar: cal) == streak)
        #expect(HomeStats.completedCount(sessions: input.sessions) == done)
        #expect(input.sessions.count == total)
        #expect(HomeStats.weekVolumeLb(sessions: input.sessions, logs: input.logs, today: loaded.today, calendar: cal) == volume)
        #expect(HomeStats.currentWeek(sessions: input.sessions, today: loaded.today, calendar: cal)
                == CurrentWeek(week: week, phase: .foundation))
    }

    @Test("missed-several + always shift: Home reads 10 · 10 of 120 · 7 560 · week 2 (spec 5.5 row B)")
    func severalShift() throws {
        let loaded = try load(.missedSeveral)
        try runPass(.shift, on: loaded)
        try expectStats(loaded, streak: 10, done: 10, total: 120, volume: 7560, week: 2)
        withExtendedLifetime(loaded.container) {}
    }

    @Test("missed-several + always skip: Home reads 0 · 10 of 120 · 7 560 · week 3 (spec 5.5 row B)")
    func severalSkip() throws {
        let loaded = try load(.missedSeveral)
        try runPass(.skip, on: loaded)
        try expectStats(loaded, streak: 0, done: 10, total: 120, volume: 7560, week: 3)
        withExtendedLifetime(loaded.container) {}
    }

    @Test("missed + always shift reproduces the missed-shifted seed's Home numbers")
    func missedShift() throws {
        let loaded = try load(.missed)
        try runPass(.shift, on: loaded)
        try expectStats(loaded, streak: 10, done: 10, total: 120, volume: 7560, week: 2)
        withExtendedLifetime(loaded.container) {}
    }

    @Test("missed + always skip reproduces the missed-skipped seed's Home numbers")
    func missedSkip() throws {
        let loaded = try load(.missed)
        try runPass(.skip, on: loaded)
        try expectStats(loaded, streak: 3, done: 10, total: 120, volume: 7560, week: 3)
        withExtendedLifetime(loaded.container) {}
    }
}
#endif

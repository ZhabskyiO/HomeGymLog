#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-23 (seeds): each seed's rows through the Progress builder and `ProgressStats`, end to end, at the seed's reference day.
/// Expected values are spec 5.1–5.6 literals (plan open question 1: Sep 9 is missed on `midProgram`).
@MainActor
@Suite struct SeedProgressStatsTests {
    private let cal = TestCalendar.calendar

    private static let midKeys = ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise", "latPull", "lowRow", "dbRow", "rdl",
                                  "curl", "goblet", "legExt", "legCurl", "split", "chestPress", "skull", "lunge"]

    /// Everything the screen derives, computed the way the screen's `body` and task do.
    private struct Snapshot {
        let container: ModelContainer
        let current: Program
        let archived: [Program]
        let sessions: [ProgressSession]
        let keys: [String]
        let month: ProgressMonth
        let map: [UUID: Date]

        @MainActor func points(_ key: String) throws -> [ProgressTop] {
            ProgressStats.points(tops: try ProgressSnapshotBuilder.tops(key: key, programCreatedAt: map, in: container.mainContext))
        }
    }

    private func snapshot(_ seed: DebugSeed) throws -> Snapshot {
        let container = try seed.makeContainer(calendar: cal)
        let context = container.mainContext
        let current = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: current.id),
                                                     sortBy: [SortDescriptor(\PlannedSession.scheduledDate), SortDescriptor(\PlannedSession.index)]))
        let archived = try context.fetch(FetchDescriptor(predicate: ProgressSnapshotBuilder.archivedProgramPredicate,
                                                         sortBy: [SortDescriptor(\Program.createdAt)]))
        let sessions = ProgressSnapshotBuilder.sessions(from: rows, programID: current.id, programCreatedAt: current.createdAt, isArchived: false)
            + (try ProgressSnapshotBuilder.archivedCompletedSessions(of: archived, in: context))
        return Snapshot(container: container, current: current, archived: archived, sessions: sessions,
                        keys: ProgressStats.exerciseKeys(sessions: sessions),
                        month: ProgressStats.month(sessions: sessions, today: seed.referenceDate(calendar: cal), calendar: cal),
                        map: ProgressSnapshotBuilder.createdAtByProgram(current: current, archived: archived))
    }

    @Test("midProgram: 17 chips, dbBench 37.5 · 40 · 42.5, Sep 9 missed, 9 completed")
    func midProgram() throws {
        let s = try snapshot(.midProgram)
        #expect(s.keys == Self.midKeys)
        #expect(try s.points("dbBench").map(\.topWeightLb) == [37.5, 40, 42.5])
        #expect(s.month.cells[8].state == .missed)
        #expect(s.month.completedCount == 9)
        withExtendedLifetime(s.container) {}
    }

    @Test("freshProgram: 16 chips, no dbBench points, fallback 40, August lead 5, 0 completed")
    func freshProgram() throws {
        let s = try snapshot(.freshProgram)
        #expect(s.keys.count == 16)
        #expect(try s.points("dbBench").isEmpty)
        #expect(ProgressStats.plannedFallbackLb(key: "dbBench", sessions: s.sessions) == 40)
        #expect(s.month.month == 8 && s.month.leadingBlanks == 5)
        #expect(s.month.completedCount == 0)
        withExtendedLifetime(s.container) {}
    }

    @Test("restDay: shoulderPress 6 points, best 32.5, +5; 13 completed")
    func restDay() throws {
        let s = try snapshot(.restDay)
        let press = try s.points("shoulderPress")
        #expect(press.count == 6)
        #expect(ProgressStats.bestLb(points: press) == 32.5)
        #expect(ProgressStats.sinceStartLb(points: press) == 5)
        #expect(s.month.completedCount == 13)
        withExtendedLifetime(s.container) {}
    }

    @Test("missed-skipped: Sep 9 skipped; missed-shifted: Sep 9 rest, 15 today; both 9 completed")
    func missedSeeds() throws {
        let skipped = try snapshot(.missedSkipped)
        #expect(skipped.month.cells[8].state == .skipped)
        #expect(skipped.month.completedCount == 9)
        let shifted = try snapshot(.missedShifted)
        #expect(shifted.month.cells[8].state == .rest)
        #expect(shifted.month.cells[14].state == .today)
        #expect(shifted.month.completedCount == 9)
        withExtendedLifetime((skipped.container, shifted.container)) {}
    }

    @Test("progress-history: 12 archived completed sessions, 17 chips, dbBench across both programs, midProgram current")
    func progressHistory() throws {
        let s = try snapshot(.progressHistory)
        #expect(s.archived.count == 1)
        let archived = try #require(s.archived.first)
        #expect(archived.archivedAt == cal.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 5)))
        let archivedSessions = s.sessions.filter(\.isArchived)
        #expect(archivedSessions.count == 12)
        #expect(archivedSessions.allSatisfy { $0.summary.status == .completed })
        #expect(s.keys == Self.midKeys, "the archived plan adds no chip")
        let bench = try s.points("dbBench")
        #expect(bench.map(\.topWeightLb) == [40, 40, 45, 30, 37.5, 40, 42.5])
        #expect(ProgressStats.bestLb(points: bench) == 45)
        #expect(ProgressStats.sinceStartLb(points: bench) == 2.5)
        #expect(bench.first?.scheduledDate == TestCalendar.day(2026, 8, 3))
        #expect(s.current.createdAt == cal.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 6)))
        #expect(s.sessions.filter { !$0.isArchived }.count == 120)
        let mid = try snapshot(.midProgram)
        #expect(s.month == mid.month)
        withExtendedLifetime((s.container, mid.container)) {}
    }
}
#endif

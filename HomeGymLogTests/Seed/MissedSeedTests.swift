#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-26: the three missed-day seeds' rows. Expected dates come from `MissedDayFixtures` (spec 5.3 formula and case A's typed
/// map), never from the seeder or the writers.
@MainActor
@Suite struct MissedSeedTests {
    private let cal = TestCalendar.calendar
    private typealias F = MissedDayFixtures

    /// The current program's sessions sorted by index, in the container's main context (where the seed wrote).
    private func sessionRows(_ container: ModelContainer) throws -> [PlannedSession] {
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        return try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                 sortBy: [SortDescriptor(\.index)]))
    }

    @Test("missed-shifted: every date is case A's, statuses as midProgram, and the seed left nothing pending")
    func shifted() throws {
        let container = try DebugSeed.missedShifted.makeContainer(calendar: cal)
        let rows = try sessionRows(container)
        try #require(rows.count == 120)
        let mapA = F.map(first: (7, TestCalendar.day(2026, 9, 15)), range: 11...119, offset: 1)
        for row in rows {
            #expect(row.scheduledDate == (mapA[row.index] ?? F.originalDate(row.index)), "s\(row.index) date")
            let expectedStatus: SessionStatus = F.midProgramCompleted.contains(row.index) ? .completed : .pending
            #expect(row.status == expectedStatus, "s\(row.index) status")
        }
        #expect(rows[7].scheduledDate == TestCalendar.day(2026, 9, 15))
        #expect(!container.mainContext.hasChanges)
        withExtendedLifetime(container) {}
    }

    @Test("missed-skipped: s7 skipped, s119 pending, 109 pending in all, every date original")
    func skipped() throws {
        let container = try DebugSeed.missedSkipped.makeContainer(calendar: cal)
        let rows = try sessionRows(container)
        try #require(rows.count == 120)
        #expect(rows[7].status == .skipped)
        #expect(rows[119].status == .pending)
        #expect(rows.filter { $0.status == .pending }.count == 109)
        for row in rows {
            #expect(row.scheduledDate == F.originalDate(row.index), "s\(row.index)")
        }
        #expect(!container.mainContext.hasChanges)
        withExtendedLifetime(container) {}
    }

    @Test("missed-several: reference Thu 09-17 12:00, dates original, 10 completed, first missed s7, missed s7, s11, s12")
    func several() throws {
        let seed = DebugSeed.missedSeveral
        #expect(seed.referenceDate(calendar: cal) == F.noon(9, 17))
        let container = try seed.makeContainer(calendar: cal)
        let rows = try sessionRows(container)
        try #require(rows.count == 120)
        for row in rows {
            #expect(row.scheduledDate == F.originalDate(row.index), "s\(row.index)")
        }
        #expect(rows.filter { $0.status == .completed }.map(\.index) == F.midProgramCompleted)
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: rows)
        let today = seed.referenceDate(calendar: cal)
        #expect(MissedDay.firstMissed(sessions: summaries, today: today, calendar: cal)?.index == 7)
        let missed = summaries.filter { HomeStats.sessionState($0, today: today, calendar: cal) == .missed }.map(\.index)
        #expect(missed == [7, 11, 12])
        withExtendedLifetime(container) {}
    }
}
#endif

#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-4 / AC-14 (host half): the reminder host's query on the `midProgram` seed. "No program" is the null UUID through the
/// verified one-hop predicate and matches nothing; the program's id matches its 120 rows; `pendingDays` gives the 110
/// pending days of the fixture formula. The container is held for the whole test (gotchas SwiftData 2026-09-13).
@MainActor
@Suite struct ReminderQueryTests {
    private let cal = TestCalendar.calendar

    private func rows(_ programID: UUID, in context: ModelContext) throws -> [PlannedSession] {
        try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID),
                                          sortBy: [SortDescriptor(\.index)]))
    }

    @Test("the null UUID matches no session; the program's id matches its 120")
    func predicate() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        #expect(ReminderHost.noProgramID.uuidString == "00000000-0000-0000-0000-000000000000")
        #expect(try rows(ReminderHost.noProgramID, in: context).count == 0)
        let program = try #require(try ProgramStore.current(in: context))
        #expect(try rows(program.id, in: context).count == 120)
    }

    @Test("pendingDays over the seed rows equals the fixture's 110 pending days")
    func pendingDays() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let days = HomeSnapshotBuilder.pendingDays(from: try rows(program.id, in: context)).sorted()
        let expected = ReminderFixtures.midProgramDays(completed: MissedDayFixtures.midProgramCompleted).sorted()
        #expect(expected.count == 110)
        #expect(days == expected)
    }

    @Test("after an archive there is no current program, so the host queries the null UUID")
    func archived() throws {
        let container = try DebugSeed.midProgram.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        #expect(try ProgramStore.archive(program, at: ReminderFixtures.at(9, 15, 12), in: context) == true)
        #expect(try ProgramStore.current(in: context) == nil)
        let rowsAfter = try rows(ReminderHost.noProgramID, in: context)
        #expect(rowsAfter.count == 0)
        #expect(HomeSnapshotBuilder.pendingDays(from: rowsAfter) == [])
    }
}
#endif

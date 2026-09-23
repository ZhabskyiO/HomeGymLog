#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-20 (automatic-pass half): the shift and skip passes the prompt host runs under an automatic policy, driven over the
/// `missed-several` seed's real rows by `MissedDay.resolution` and the existing writers. Every expected date and status is
/// a spec 5.5 row-B literal.
@MainActor
@Suite struct AutomaticPolicyPassTests {
    private let cal = TestCalendar.calendar

    private func day(_ month: Int, _ dayOfMonth: Int) -> Date { TestCalendar.day(2026, month, dayOfMonth) }

    /// The seed's container plus its program's session rows in index order.
    private func seedRows() throws -> (container: ModelContainer, context: ModelContext, program: Program, rows: [PlannedSession]) {
        let container = try DebugSeed.missedSeveral.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\PlannedSession.index)]))
        return (container, context, program, rows)
    }

    private func statuses(of ids: [Int], in container: ModelContainer, programID: UUID) throws -> [Int: SessionStatus] {
        let fresh = ModelContext(container)
        let rows = try fresh.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID),
                                                   sortBy: [SortDescriptor(\PlannedSession.index)]))
        var result: [Int: SessionStatus] = [:]
        for row in rows where ids.contains(row.index) { result[row.index] = row.status }
        return result
    }

    @Test("skip pass: the resolution lists 7, 11, 12 and skipMissed marks each, leaving every date alone")
    func skipPass() throws {
        let seed = try seedRows()
        let today = MissedDayFixtures.noon(9, 17)
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: seed.rows)
        let resolution = MissedDay.resolution(policy: .skip, sessions: summaries, silence: nil, today: today, calendar: cal)
        #expect(resolution == .skip(indexes: [7, 11, 12]))
        guard case .skip(let indexes) = resolution else { return }

        let datesBefore = seed.rows.map(\.scheduledDate)
        for index in indexes {
            #expect(try ProgramStore.skipMissed(sessionIndex: index, rows: seed.rows, today: today, calendar: cal,
                                                in: seed.context) == true, "index \(index)")
        }
        #expect(seed.context.hasChanges == false)

        #expect(try statuses(of: [7, 11, 12, 13], in: seed.container, programID: seed.program.id)
                == [7: .skipped, 11: .skipped, 12: .skipped, 13: .pending])
        #expect(seed.rows.map(\.scheduledDate) == datesBefore)

        let after = HomeSnapshotBuilder.sessionSummaries(from: seed.rows)
        #expect(MissedDay.resolution(policy: .skip, sessions: after, silence: nil, today: today, calendar: cal) == .none)
        withExtendedLifetime(seed.container) {}
    }

    @Test("shift pass: one shift re-dates s7 to Thu 09-17 and every later pending session (spec 5.5 row B)")
    func shiftPass() throws {
        let seed = try seedRows()
        let today = MissedDayFixtures.noon(9, 17)
        let summaries = HomeSnapshotBuilder.sessionSummaries(from: seed.rows)
        let resolution = MissedDay.resolution(policy: .shift, sessions: summaries, silence: nil, today: today, calendar: cal)
        #expect(resolution == .shift(missedIndex: 7))
        guard case .shift(let missedIndex) = resolution else { return }

        let map = try ProgramStore.shift(missedIndex: missedIndex, rows: seed.rows,
                                         trainingWeekdays: seed.program.trainingWeekdays, today: today, calendar: cal,
                                         in: seed.context)
        #expect(map.isEmpty == false)
        #expect(seed.context.hasChanges == false)

        let fresh = ModelContext(seed.container)
        let programID = seed.program.id
        let rows = try fresh.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: programID),
                                                   sortBy: [SortDescriptor(\PlannedSession.index)]))
        var dates: [Int: Date] = [:]
        for row in rows where [7, 11, 12, 13].contains(row.index) { dates[row.index] = row.scheduledDate }
        #expect(dates == [7: day(9, 17), 11: day(9, 18), 12: day(9, 21), 13: day(9, 22)])

        let after = HomeSnapshotBuilder.sessionSummaries(from: seed.rows)
        #expect(MissedDay.resolution(policy: .shift, sessions: after, silence: nil, today: today, calendar: cal) == .none)
        withExtendedLifetime(seed.container) {}
    }
}
#endif

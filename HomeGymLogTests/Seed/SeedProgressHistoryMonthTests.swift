#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// `progress-history` beyond `SeedProgressStatsTests`: August's calendar shows the archived program's 12 completed days beside the
/// current program's completed s0 (spec 5.6), and the chart summary spans both programs (D5).
@MainActor
@Suite struct SeedProgressHistoryMonthTests {
    private let cal = TestCalendar.calendar

    private func sessions(in context: ModelContext) throws -> (current: Program, archived: [Program], values: [ProgressSession]) {
        let current = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: current.id),
                                                     sortBy: [SortDescriptor(\PlannedSession.scheduledDate), SortDescriptor(\PlannedSession.index)]))
        let archived = try context.fetch(FetchDescriptor(predicate: ProgressSnapshotBuilder.archivedProgramPredicate))
        let values = ProgressSnapshotBuilder.sessions(from: rows, programID: current.id, programCreatedAt: current.createdAt, isArchived: false)
            + (try ProgressSnapshotBuilder.archivedCompletedSessions(of: archived, in: context))
        return (current, archived, values)
    }

    @Test("August 2026 at Aug 15: lead 5; Mon/Wed/Fri Aug 3–28 and the current s0 on the 31st completed → 13")
    func augustCalendar() throws {
        let container = try DebugSeed.progressHistory.makeContainer(calendar: cal)
        let s = try sessions(in: container.mainContext)
        let today = cal.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12))!
        let month = ProgressStats.month(sessions: s.values, today: today, calendar: cal)
        #expect(month.month == 8 && month.leadingBlanks == 5)
        let completedDays = [3, 5, 7, 10, 12, 14, 17, 19, 21, 24, 26, 28, 31]
        #expect(month.cells.filter { $0.state == .completed }.map(\.dayNumber) == completedDays)
        #expect(month.completedCount == 13)
        #expect(month.cells.filter { $0.state != .completed && $0.state != .rest }.isEmpty, "no archived pending day, no current day before the 31st")
        withExtendedLifetime(container) {}
    }

    @Test("the dbBench summary spans both programs: 7 sessions, 30 to 45 lb")
    func summarySpansPrograms() throws {
        let container = try DebugSeed.progressHistory.makeContainer(calendar: cal)
        let context = container.mainContext
        let s = try sessions(in: context)
        let map = ProgressSnapshotBuilder.createdAtByProgram(current: s.current, archived: s.archived)
        let weights = ProgressStats.points(tops: try ProgressSnapshotBuilder.tops(key: "dbBench", programCreatedAt: map, in: context)).map(\.topWeightLb)
        let low = try #require(weights.min()), high = try #require(weights.max())
        #expect(ProgressText.chartSummary(name: ProgressText.chipLabel(key: "dbBench"), count: weights.count, minLb: low, maxLb: high, unit: .lb)
                == "Dumbbell Bench Press, 7 sessions, 30 to 45 lb")
        withExtendedLifetime(container) {}
    }
}
#endif

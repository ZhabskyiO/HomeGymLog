#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-20: the Program tab's whole read path on real rows — the shared session query, the `sessionSummaries`
/// mapping, and `ProgramTabStats` straight after it, with no validating step in between (decision 7).
/// Nothing here touches `workoutLog`: the tab never faults a log.
@MainActor
@Suite struct ProgramTabSnapshotTests {
    private let cal = TestCalendar.calendar

    @Test("the midProgram container feeds ProgramTabStats directly")
    func midProgramSnapshot() throws {
        let seed = DebugSeed.midProgram
        let container = try seed.makeContainer(calendar: cal)
        let context = container.mainContext
        let program = try #require(try ProgramStore.current(in: context))
        let rows = try context.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                     sortBy: [SortDescriptor(\.index)]))
        #expect(rows.count == 120)

        let summaries = HomeSnapshotBuilder.sessionSummaries(from: rows)
        #expect(summaries.count == 120)

        let chips = ProgramTabStats.weekChips(sessions: summaries, calendar: cal)
        #expect(chips.count == 24)
        #expect(chips[0].phase == .foundation)
        #expect(chips[9].phase == .build)
        #expect(chips[17].phase == .peak)
        #expect(chips[23].phase == .deload)

        let today = seed.referenceDate(calendar: cal)
        #expect(ProgramTabStats.initialWeek(sessions: summaries, today: today, calendar: cal) == 3)
        #expect(ProgramTabStats.dayCells(sessions: summaries, week: 3, calendar: cal).map { $0.session?.index }
                == [10, 11, 12, 13, 14, nil, nil])
        #expect(ProgramTabStats.focus(selection: .followToday, sessions: summaries, today: today, calendar: cal)
                == ProgramFocus(week: 3, day: 1))
    }
}
#endif

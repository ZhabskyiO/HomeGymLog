#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-15 (seed half): `activity-denied` is `midProgram` data at Tue 2026-09-15 12:00 whose silent seam
/// reports Live Activities as off; every other seed reports them on.
@MainActor
@Suite struct LiveActivitySeedTests {
    private let cal = TestCalendar.calendar

    @Test("activity-denied parses, opens at Tue 2026-09-15 12:00, no prompt, no draft, activities off")
    func denied() throws {
        let seed = try #require(try DebugSeed.parse(arguments: ["app", "-seed", "activity-denied"]))
        #expect(seed == .activityDenied)
        #expect(seed.referenceDate(calendar: cal) == TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600))
        #expect(seed.forcesMissedDayPrompt == false)
        #expect(seed.initialDraft(calendar: cal) == nil)
        #expect(seed.activitiesEnabled == false)
    }

    @Test("activity-denied's container holds midProgram's one current program and its 120 sessions")
    func deniedData() throws {
        let container = try DebugSeed.activityDenied.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Program>(predicate: ProgramStore.currentPredicate)) == 1)
        let program = try #require(try ProgramStore.current(in: context))
        #expect(program.startDate == TestCalendar.day(2026, 8, 31))
        #expect(program.sortedSessions.count == 120)
        #expect(program.sortedSessions.filter { $0.status == .completed }.map(\.index) == [0, 1, 2, 3, 4, 5, 6, 8, 9, 10])
    }

    @Test("every other seed reports Live Activities on", arguments: DebugSeed.allCases.filter { $0 != .activityDenied })
    func othersEnabled(seed: DebugSeed) {
        #expect(seed.activitiesEnabled == true)
    }
}
#endif

#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-3 (first pass): what the workout screen's Live Activity pass decides on the seeded rows at the
/// frozen now, from the key inputs it builds (rows read with the screen's own predicates, the `RestSeedFlowTests` shape).
@MainActor
@Suite struct RestActivitySeedFlowTests {
    private let cal = TestCalendar.calendar
    private static func at(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        TestCalendar.calendar.date(bySettingHour: hour, minute: minute, second: second, of: TestCalendar.day(2026, 9, 15))!
    }

    /// The screen's key inputs from one context: the log's instants and the "Next:" line.
    private func decision(_ seed: DebugSeed, shown: [ShownRestActivity] = []) throws -> RestActivityDecision {
        let container = try seed.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let context = ModelContext(container)
        let log = try #require(try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let exerciseRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id)))
        let setRows = try context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        let exercises = WorkoutFlow.sorted(WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows))
        let state = WorkoutFlow.state(exercises: exercises)
        return RestActivityPlan.decide(logID: log.id.uuidString, restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt,
                                       nextText: RestTimer.next(exercises: exercises, state: state).map(RestText.nextLine),
                                       enabled: true, now: Self.at(12, 0, 0), shown: shown)
    }

    @Test("wo-rest at 12:00:00 with nothing shown requests 11:59:47 → 12:01:02, \"Next: set 2 of 3\"")
    func woRestRequests() throws {
        let expected = RestActivityContent(startedAt: Self.at(11, 59, 47), endsAt: Self.at(12, 1, 2), nextText: "Next: set 2 of 3")
        #expect(try decision(.woRest) == RestActivityDecision(endIDs: [], step: .request(expected)))
    }

    @Test("wo-adjust's stale rest (ended 11:51:29) decides nothing and ends nothing")
    func woAdjustNothing() throws {
        #expect(try decision(.woAdjust) == RestActivityDecision(endIDs: [], step: .nothing))
    }
}
#endif

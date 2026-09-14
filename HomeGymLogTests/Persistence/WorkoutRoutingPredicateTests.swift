import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-36: the root's in-progress-log predicate (nested `flatMap`). Runs on 17.5 in every `$TEST` and on 26.5 in the
/// slice sweep; a two-hop `?.` would crash the fetch, which fails the suite.
@MainActor
@Suite struct WorkoutRoutingPredicateTests {
    private func activeLogs(_ store: TestStore) throws -> [WorkoutLog] {
        try ModelContext(store.container).fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate,
                                                                sortBy: [SortDescriptor(\.startedAt)]))
    }

    @Test("the sample graph's in-progress log on the current program matches; finish removes it")
    func inProgressThenFinished() throws {
        let store = try makeTestStore()
        let (_, log) = try insertSampleGraph(in: store.context)
        let before = try activeLogs(store)
        #expect(before.map(\.id) == [log.id])
        try WorkoutLogStore.finish(log, at: TestCalendar.day(2026, 9, 7).addingTimeInterval(7200), in: store.context)
        let after = try activeLogs(store)
        #expect(after.isEmpty)
    }

    @Test("discard leaves nothing to route to")
    func discarded() throws {
        let store = try makeTestStore()
        let (_, log) = try insertSampleGraph(in: store.context)
        try WorkoutLogStore.discard(log, in: store.context)
        let after = try activeLogs(store)
        #expect(after.isEmpty)
    }

    @Test("an orphan in-progress log is ignored")
    func orphan() throws {
        let store = try makeTestStore()
        let (_, log) = try insertSampleGraph(in: store.context)
        store.context.insert(WorkoutLog(startedAt: TestCalendar.day(2026, 9, 1)))
        try store.context.save()
        let total = try ModelContext(store.container).fetchCount(FetchDescriptor<WorkoutLog>())
        #expect(total == 2)
        let active = try activeLogs(store)
        #expect(active.map(\.id) == [log.id])
    }

    @Test("a log on an archived program is ignored")
    func archived() throws {
        let store = try makeTestStore()
        let (program, _) = try insertSampleGraph(in: store.context)
        program.archivedAt = TestCalendar.day(2026, 9, 10)
        try store.context.save()
        let active = try activeLogs(store)
        #expect(active.isEmpty)
    }

    @Test("two in-progress logs both match, sorted by startedAt")
    func twoLogs() throws {
        let store = try makeTestStore()
        let (program, first) = try insertSampleGraph(in: store.context)
        let second = try WorkoutLogStore.start(session: program.sortedSessions[1], at: TestCalendar.day(2026, 9, 6), in: store.context)
        try #require(second.startedAt < first.startedAt, "fixture: the second log starts earlier")
        let active = try activeLogs(store)
        #expect(active.map(\.id) == [second.id, first.id])
    }
}

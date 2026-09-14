import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-34 edges of the shared start `start(sessionIndex:rows:at:in:)`: it decides on the stored status alone (a
/// completed session with no log still cannot start), and on duplicate indexes the first row in `rows` wins even when
/// a later duplicate is pending. Counts are read through a fresh context.
@MainActor
@Suite struct WorkoutStartEdgeTests {
    private let at = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600)

    private func logCount(_ store: TestStore) throws -> Int {
        try ModelContext(store.container).fetchCount(FetchDescriptor<WorkoutLog>())
    }

    @Test("a session marked completed but with no log does not start and writes nothing")
    func completedWithoutLog() throws {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        rows[3].status = .completed
        try store.context.save()
        #expect(rows[3].workoutLog == nil)

        let started = try WorkoutLogStore.start(sessionIndex: 3, rows: rows, at: at, in: store.context)
        #expect(started == nil)
        #expect(try logCount(store) == 0)
        #expect(!store.context.hasChanges)
        let fresh = try ModelContext(store.container).fetch(FetchDescriptor<PlannedSession>()).first { $0.index == 3 }
        #expect(fresh?.status == .completed && fresh?.workoutLog == nil)
    }

    @Test("empty rows start nothing")
    func emptyRows() throws {
        let store = try makeTestStore()
        _ = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let started = try WorkoutLogStore.start(sessionIndex: 0, rows: [], at: at, in: store.context)
        #expect(started == nil)
        #expect(try logCount(store) == 0)
    }

    /// Rows where session 20's stored index is rewritten to 11, passed as [session 20, session 11].
    private func duplicateRows(_ store: TestStore) throws -> (first: PlannedSession, second: PlannedSession) {
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let first = rows[20], second = rows[11]
        first.index = 11
        try store.context.save()
        return (first, second)
    }

    @Test("with two rows sharing an index, the first row in the array is the one started")
    func duplicateIndexFirstWins() throws {
        let store = try makeTestStore()
        let (first, second) = try duplicateRows(store)
        let log = try #require(try WorkoutLogStore.start(sessionIndex: 11, rows: [first, second], at: at, in: store.context))
        #expect(log.session?.id == first.id)
        #expect(second.workoutLog == nil)
        #expect(try logCount(store) == 1)
    }

    @Test("when the first row of a duplicate index is completed, nothing starts even though the second is pending")
    func duplicateIndexFirstCompleted() throws {
        let store = try makeTestStore()
        let (first, second) = try duplicateRows(store)
        first.status = .completed
        try store.context.save()
        #expect(second.status == .pending)
        let started = try WorkoutLogStore.start(sessionIndex: 11, rows: [first, second], at: at, in: store.context)
        #expect(started == nil)
        #expect(try logCount(store) == 0)
    }
}

import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-29 (store half): the two rest instants default to nil with the existing initializer and persist exactly.
/// Read back through a fresh `ModelContext`; the `TestStore` holds the container for the whole test.
@MainActor
@Suite struct RestFieldsTests {
    private let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    @Test("a log created with the existing initializer reads nil for both instants")
    func defaultsToNil() throws {
        let store = try makeTestStore()
        store.context.insert(WorkoutLog(startedAt: t))
        try store.context.save()
        let fresh = try #require(try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>()).first)
        #expect(fresh.restStartedAt == nil)
        #expect(fresh.restEndsAt == nil)
    }

    @Test("both instants round-trip through a fresh context")
    func roundTrip() throws {
        let store = try makeTestStore()
        let log = WorkoutLog(startedAt: t)
        store.context.insert(log)
        try store.context.save()
        log.restStartedAt = t
        log.restEndsAt = t.addingTimeInterval(75)
        try store.context.save()
        let fresh = try #require(try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>()).first)
        #expect(fresh.restStartedAt == t)
        #expect(fresh.restEndsAt == t.addingTimeInterval(75))
        #expect(fresh.startedAt == t && fresh.finishedAt == nil)
    }
}

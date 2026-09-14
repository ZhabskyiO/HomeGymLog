import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// AC-26: "+30s" (`addRestTime`) and the card's "Skip" (`skipRest`). Each test starts from session 11 with E1S1 logged and
/// rated at t, so a 75 s rest runs t → t + 75. Values are read back through a fresh context; each test holds its store.
@MainActor
@Suite struct RestExtendSkipTests {
    private let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(11 * 3600 + 168)

    /// Session 11 started; with `rated`, E1S1 is logged and rated at `ratedAt` (default t).
    private func workout(rated: Bool, ratedAt: Date? = nil) throws -> (store: TestStore, log: WorkoutLog) {
        let store = try makeTestStore()
        let rows = try WorkoutStoreFixtures.sixMonthRows(in: store.context)
        let log = try WorkoutLogStore.start(session: rows[11], at: t.addingTimeInterval(-168), in: store.context)
        if rated {
            let first = WorkoutStoreFixtures.sets(of: log)[0][0]
            let at = ratedAt ?? t
            try WorkoutLogStore.logSet(first, at: at, in: store.context)
            try WorkoutLogStore.setRPE(7, on: first, at: at, in: store.context)
        }
        return (store, log)
    }

    private func freshRest(_ store: TestStore) throws -> (startedAt: Date?, endsAt: Date?) {
        let log = try #require(try ModelContext(store.container).fetch(FetchDescriptor<WorkoutLog>()).first)
        return (log.restStartedAt, log.restEndsAt)
    }

    @Test("+30 on a live rest moves only the end; a second +30 moves it again")
    func extendLive() throws {
        let (store, log) = try workout(rated: true)
        let wrote = try WorkoutLogStore.addRestTime(30, to: log, at: t.addingTimeInterval(13), in: store.context)
        #expect(wrote)
        let rest = try freshRest(store)
        #expect(rest.startedAt == t)
        #expect(rest.endsAt == t.addingTimeInterval(105))
        let again = try WorkoutLogStore.addRestTime(30, to: log, at: t.addingTimeInterval(14), in: store.context)
        #expect(again)
        let twice = try freshRest(store)
        #expect(twice.startedAt == t)
        #expect(twice.endsAt == t.addingTimeInterval(135))
    }

    @Test("+30 at or after the end writes nothing", arguments: [75.0, 80.0])
    func extendAtOrAfterEnd(offset: Double) throws {
        let (store, log) = try workout(rated: true)
        let wrote = try WorkoutLogStore.addRestTime(30, to: log, at: t.addingTimeInterval(offset), in: store.context)
        #expect(!wrote)
        #expect(!store.context.hasChanges)
        let rest = try freshRest(store)
        #expect(rest.startedAt == t)
        #expect(rest.endsAt == t.addingTimeInterval(75))
    }

    @Test("+30 with no rest stored writes nothing")
    func extendWithoutRest() throws {
        let (store, log) = try workout(rated: false)
        let wrote = try WorkoutLogStore.addRestTime(30, to: log, at: t, in: store.context)
        #expect(!wrote)
        #expect(!store.context.hasChanges)
        let rest = try freshRest(store)
        #expect(rest.startedAt == nil && rest.endsAt == nil)
    }

    @Test("an extension of zero or fewer seconds throws on a live rest and writes nothing", arguments: [0, -30])
    func extendInvalid(seconds: Int) throws {
        let (store, log) = try workout(rated: true)
        #expect(throws: WorkoutLogStoreError.invalidRestExtension(seconds)) {
            try WorkoutLogStore.addRestTime(seconds, to: log, at: t.addingTimeInterval(13), in: store.context)
        }
        #expect(!store.context.hasChanges)
        #expect(log.restEndsAt == t.addingTimeInterval(75))
        let rest = try freshRest(store)
        #expect(rest.endsAt == t.addingTimeInterval(75))
    }

    @Test("Skip clears a live rest")
    func skipLive() throws {
        let (store, log) = try workout(rated: true)
        let wrote = try WorkoutLogStore.skipRest(log, in: store.context)
        #expect(wrote)
        let rest = try freshRest(store)
        #expect(rest.startedAt == nil)
        #expect(rest.endsAt == nil)
    }

    @Test("Skip clears a stale rest that already ended")
    func skipStale() throws {
        let (store, log) = try workout(rated: true, ratedAt: t.addingTimeInterval(-200))
        let stale = try freshRest(store)
        #expect(stale.endsAt == t.addingTimeInterval(-125))
        let wrote = try WorkoutLogStore.skipRest(log, in: store.context)
        #expect(wrote)
        let rest = try freshRest(store)
        #expect(rest.startedAt == nil)
        #expect(rest.endsAt == nil)
    }

    @Test("Skip with no rest stored is a no-op with no save")
    func skipWithoutRest() throws {
        let (store, log) = try workout(rated: false)
        let wrote = try WorkoutLogStore.skipRest(log, in: store.context)
        #expect(!wrote)
        #expect(!store.context.hasChanges)
    }
}

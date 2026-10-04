#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-11 gap pass (test-writer): the failed-save cases `RestActivityHandlerRollbackTests` leaves out. The
/// store as a fresh context on the writable container sees it after a refused +30s, and a refused Skip (row, store,
/// activity, notification). Fixture: `midProgram` + the `wo-rest` stage written to an on-disk store, reopened with
/// `allowsSave: false`; the handler runs on the read-only container. The first read after the failure is a same-context
/// fetch by id; `rollback()` runs in a `defer` right after the writing context exists, before the file is deleted.
@MainActor
@Suite struct RestActivityHandlerFailedSaveTests {
    private let cal = TestCalendar.calendar
    private static let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
    private static let start = noon.addingTimeInterval(-13)   // 11:59:47
    private static let end = noon.addingTimeInterval(62)      // 12:01:02

    private struct Outcome {
        let sameContext: (start: Date?, end: Date?)
        let store: (start: Date?, end: Date?)
        let events: [RestActivityCenterRecorder.Event]
    }

    private func run(_ action: RestActivityAction, storeAt url: URL) async throws -> Outcome {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        try MidProgramSeed.populate(in: writer.mainContext, calendar: cal)
        let logID = try WorkoutSeed.populate(.resting, now: Self.noon, in: writer.mainContext).id
        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = readOnly.mainContext
        defer {
            context.rollback()
            withExtendedLifetime((writer, readOnly)) {}
        }
        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(
            id: "a", logID: logID.uuidString,
            content: RestActivityContent(startedAt: Self.start, endsAt: Self.end, nextText: "Next: set 2 of 3"))])
        await RestActivityHandler.perform(action, container: readOnly, clock: .frozen(at: Self.noon, calendar: cal),
                                          notifier: recorder.notifier, center: recorder.center,
                                          liveActivityEnabled: { true }, soundEnabled: { true })
        // First read after the failure: same context, fetched by id.
        let row = try #require(try context.fetch(FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == logID })).first)
        let sameContext = (row.restStartedAt, row.restEndsAt)
        let stored = try #require(try ModelContext(writer).fetch(FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == logID })).first)
        return Outcome(sameContext: sameContext, store: (stored.restStartedAt, stored.restEndsAt), events: recorder.events)
    }

    /// Runs `action` against a temporary on-disk store, deleting the directory only after `run` (and its rollback) returned.
    private func outcome(_ action: RestActivityAction) async throws -> Outcome {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("activity-failed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var ran: Outcome?
        var failure: (any Error)?
        do { ran = try await run(action, storeAt: dir.appendingPathComponent("activity-failed.store")) } catch { failure = error }
        try? FileManager.default.removeItem(at: dir)
        if let failure { throw failure }
        return try #require(ran)
    }

    @Test("a refused +30s: the store (a fresh context on the writable container) still holds 11:59:47 → 12:01:02")
    func addRestStoreUntouched() async throws {
        let outcome = try await outcome(.addRest)
        #expect(outcome.store.start == Self.start)
        #expect(outcome.store.end == Self.end)
    }

    @Test("a refused Skip: the writing context's row still reads both instants")
    func skipRestRowRestored() async throws {
        let outcome = try await outcome(.skipRest)
        #expect(outcome.sameContext.start == Self.start)
        #expect(outcome.sameContext.end == Self.end)
    }

    @Test("a refused Skip: the store still holds both instants")
    func skipRestStoreUntouched() async throws {
        let outcome = try await outcome(.skipRest)
        #expect(outcome.store.start == Self.start)
        #expect(outcome.store.end == Self.end)
    }

    @Test("a refused Skip: the activity is not ended; the notification is re-scheduled at the stored 12:01:02")
    func skipRestKeepsActivity() async throws {
        let outcome = try await outcome(.skipRest)
        #expect(outcome.events == [.schedule(Self.end, withSound: true)])
    }
}
#endif

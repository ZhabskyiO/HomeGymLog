#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-11 (B3): a +30s whose save fails. The wo-rest rows are written to an on-disk store, reopened with
/// `allowsSave: false`, and the handler runs on the read-only container. The first read after the failure is a
/// same-context fetch by id (gotchas SwiftData 2026-09-14); the activity never sees the unsaved 12:01:32.
@MainActor
@Suite struct RestActivityHandlerRollbackTests {
    private let cal = TestCalendar.calendar
    private static let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    private struct Outcome {
        let firstFetchEnd: Date?
        let events: [RestActivityCenterRecorder.Event]
        let hasChanges: Bool
    }

    private func run(storeAt url: URL) async throws -> Outcome {
        let writer = try ModelContainer(for: AppSchema.schema, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])
        try MidProgramSeed.populate(in: writer.mainContext, calendar: cal)
        let written = try WorkoutSeed.populate(.resting, now: Self.noon, in: writer.mainContext)
        let logID = written.id
        let readOnly = try ModelContainer(for: AppSchema.schema,
                                          configurations: [ModelConfiguration(schema: AppSchema.schema, url: url, allowsSave: false)])
        let context = readOnly.mainContext
        // Discard the restored originals the failed write leaves pending before the store file is deleted (gotchas 2026-09-14).
        defer {
            context.rollback()
            withExtendedLifetime((writer, readOnly)) {}
        }
        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(
            id: "a", logID: logID.uuidString,
            content: RestActivityContent(startedAt: Self.noon.addingTimeInterval(-13), endsAt: Self.noon.addingTimeInterval(62),
                                         nextText: "Next: set 2 of 3"))])
        await RestActivityHandler.perform(.addRest, container: readOnly, clock: .frozen(at: Self.noon, calendar: cal),
                                          notifier: recorder.notifier, center: recorder.center,
                                          liveActivityEnabled: { true }, soundEnabled: { true })
        let firstFetch = try context.fetch(FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == logID })).first
        return Outcome(firstFetchEnd: firstFetch?.restEndsAt, events: recorder.events, hasChanges: context.hasChanges)
    }

    @Test("a refused save: the row reads 12:01:02, no event carries 12:01:32, the restored originals stay pending")
    func failedSave() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("activity-rollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var ran: Outcome?
        var failure: (any Error)?
        do { ran = try await run(storeAt: dir.appendingPathComponent("activity-rollback.store")) } catch { failure = error }
        try? FileManager.default.removeItem(at: dir)   // after `run` returned, so its rollback already ran
        if let failure { throw failure }
        let outcome = try #require(ran)
        let original = Self.noon.addingTimeInterval(62)   // 12:01:02
        let unsaved = Self.noon.addingTimeInterval(92)    // 12:01:32
        #expect(outcome.firstFetchEnd == original)
        for event in outcome.events {
            switch event {
            case .update(_, let content): #expect(content.endsAt == original)
            case .schedule(let date, _): #expect(date == original)
            case .request(_, let content): #expect(content.endsAt != unsaved)
            case .end, .cancel: break
            }
        }
        #expect(outcome.events == [.schedule(original, withSound: true)], "the content matched, so no activity call; the notification re-schedules the stored end")
        #expect(outcome.hasChanges == true)
    }
}
#endif

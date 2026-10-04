#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-10: the intent handler on the `wo-rest` rows (rest 11:59:47 → 12:01:02, "Next: set 2 of 3"),
/// an in-memory container, a frozen clock at 12:00:00, and the activity + notifier recorder sharing one event log. Every
/// event is built from the row as re-read after the write, so its values prove what was stored. The serialized-hook test
/// (B1) lives in `LiveActivityIntentHookTests`, the only suite that assigns the hook.
@MainActor
@Suite struct RestActivityHandlerTests {
    private let cal = TestCalendar.calendar
    static func at(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        TestCalendar.calendar.date(bySettingHour: hour, minute: minute, second: second, of: TestCalendar.day(2026, 9, 15))!
    }
    static let start = at(11, 59, 47), end = at(12, 1, 2), noon = at(12, 0, 0)
    static let next = "Next: set 2 of 3"

    /// The wo-rest container, its log, and a recorder already showing activity `a` for that log with the stored content.
    private func fixture() throws -> (container: ModelContainer, log: WorkoutLog, recorder: RestActivityCenterRecorder) {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        let log = try #require(try container.mainContext.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        let shown = ShownRestActivity(id: "a", logID: log.id.uuidString,
                                      content: RestActivityContent(startedAt: Self.start, endsAt: Self.end, nextText: Self.next))
        return (container, log, RestActivityCenterRecorder(shown: [shown]))
    }

    private func perform(_ action: RestActivityAction, container: ModelContainer, recorder: RestActivityCenterRecorder,
                         now: Date = noon, liveActivityEnabled: Bool = true, soundEnabled: Bool = true) async {
        await RestActivityHandler.perform(action, container: container, clock: .frozen(at: now, calendar: cal),
                                          notifier: recorder.notifier, center: recorder.center,
                                          liveActivityEnabled: { liveActivityEnabled }, soundEnabled: { soundEnabled })
    }

    /// The log's two instants read through a brand-new context (what the store holds).
    private func stored(_ id: UUID, in container: ModelContainer) throws -> (start: Date?, end: Date?) {
        let log = try #require(try ModelContext(container).fetch(FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == id })).first)
        return (log.restStartedAt, log.restEndsAt)
    }

    @Test("+30s: the row reads 12:01:32, then one update to 12:01:32, then one schedule at 12:01:32, in that order")
    func addRest() async throws {
        let (container, log, recorder) = try fixture()
        defer { withExtendedLifetime(container) {} }
        await perform(.addRest, container: container, recorder: recorder)
        #expect(try stored(log.id, in: container).end == Self.at(12, 1, 32))
        let extended = RestActivityContent(startedAt: Self.start, endsAt: Self.at(12, 1, 32), nextText: Self.next)
        #expect(recorder.events == [.update(id: "a", extended), .schedule(Self.at(12, 1, 32), withSound: true)])
    }

    @Test("Skip: both instants nil, one end, one notifier cancel")
    func skipRest() async throws {
        let (container, log, recorder) = try fixture()
        defer { withExtendedLifetime(container) {} }
        await perform(.skipRest, container: container, recorder: recorder)
        let row = try stored(log.id, in: container)
        #expect(row.start == nil && row.end == nil)
        #expect(recorder.events == [.end(id: "a"), .cancel])
    }

    @Test("+30s after the rest ended (12:01:10): no write, one end, one cancel")
    func addRestAfterEnd() async throws {
        let (container, log, recorder) = try fixture()
        defer { withExtendedLifetime(container) {} }
        await perform(.addRest, container: container, recorder: recorder, now: Self.at(12, 1, 10))
        #expect(try stored(log.id, in: container).end == Self.end)
        #expect(recorder.events == [.end(id: "a"), .cancel])
    }

    @Test("no in-progress log: every shown activity ends, no notifier call")
    func noLog() async throws {
        let (container, log, recorder) = try fixture()
        defer { withExtendedLifetime(container) {} }
        try WorkoutLogStore.discard(log, in: container.mainContext)
        await perform(.addRest, container: container, recorder: recorder)
        #expect(recorder.events == [.end(id: "a")])
        #expect(try ModelContext(container).fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).isEmpty)
    }

    @Test("Sound off: the schedule carries withSound false")
    func soundOff() async throws {
        let (container, _, recorder) = try fixture()
        defer { withExtendedLifetime(container) {} }
        await perform(.addRest, container: container, recorder: recorder, soundEnabled: false)
        #expect(recorder.events.last == .schedule(Self.at(12, 1, 32), withSound: false))
    }

    @Test("Lock Screen timer off: the write still lands, the activity ends instead of updating")
    func liveActivityOff() async throws {
        let (container, log, recorder) = try fixture()
        defer { withExtendedLifetime(container) {} }
        await perform(.addRest, container: container, recorder: recorder, liveActivityEnabled: false)
        #expect(try stored(log.id, in: container).end == Self.at(12, 1, 32))
        #expect(recorder.events == [.end(id: "a"), .schedule(Self.at(12, 1, 32), withSound: true)])
    }

    @Test("NB3: with a stray log started later, the earlier wo-rest log is the one written")
    func earliestLogWritten() async throws {
        let (container, log, recorder) = try fixture()
        defer { withExtendedLifetime(container) {} }
        let program = try #require(try ProgramStore.current(in: container.mainContext))
        let rows = try container.mainContext.fetch(FetchDescriptor(predicate: HomeSnapshotBuilder.sessionPredicate(programID: program.id),
                                                                   sortBy: [SortDescriptor(\.index)]))
        let stray = try #require(try WorkoutLogStore.start(sessionIndex: 12, rows: rows, at: log.startedAt.addingTimeInterval(60),
                                                           in: container.mainContext))
        #expect(log.startedAt == Self.noon.addingTimeInterval(-754))
        await perform(.addRest, container: container, recorder: recorder)
        #expect(try stored(log.id, in: container).end == Self.at(12, 1, 32))
        let strayRow = try stored(stray.id, in: container)
        #expect(strayRow.start == nil && strayRow.end == nil)
    }
}
#endif

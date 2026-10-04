#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-10 gap pass (test-writer): the handler with more than one shown activity, on the `wo-rest` rows
/// (in-memory, frozen 12:00:00, rest 11:59:47 → 12:01:02). The foreign one and any duplicate end before the match is
/// updated; with nothing shown a live rest is requested by the handler too.
@MainActor
@Suite struct RestActivityHandlerShownTests {
    private let cal = TestCalendar.calendar
    static func at(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        TestCalendar.calendar.date(bySettingHour: hour, minute: minute, second: second, of: TestCalendar.day(2026, 9, 15))!
    }
    static let start = at(11, 59, 47), end = at(12, 1, 2), noon = at(12, 0, 0)
    static let content = RestActivityContent(startedAt: start, endsAt: end, nextText: "Next: set 2 of 3")
    static let extended = RestActivityContent(startedAt: start, endsAt: at(12, 1, 32), nextText: "Next: set 2 of 3")

    private func perform(_ action: RestActivityAction, container: ModelContainer, recorder: RestActivityCenterRecorder,
                         liveActivityEnabled: Bool = true) async {
        await RestActivityHandler.perform(action, container: container, clock: .frozen(at: Self.noon, calendar: cal),
                                          notifier: recorder.notifier, center: recorder.center,
                                          liveActivityEnabled: { liveActivityEnabled }, soundEnabled: { true })
    }

    private func logID(in container: ModelContainer) throws -> String {
        try #require(try container.mainContext.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first).id.uuidString
    }

    @Test("+30s with a foreign activity and the match shown: end the foreign, update the match, then schedule")
    func foreignAndMatch() async throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let id = try logID(in: container)
        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(id: "x", logID: "other", content: Self.content),
                                                          ShownRestActivity(id: "a", logID: id, content: Self.content)])
        await perform(.addRest, container: container, recorder: recorder)
        #expect(recorder.events == [.end(id: "x"), .update(id: "a", Self.extended), .schedule(Self.at(12, 1, 32), withSound: true)])
    }

    @Test("+30s with two matching duplicates: the second ends, the first updates")
    func duplicates() async throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let id = try logID(in: container)
        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(id: "a", logID: id, content: Self.content),
                                                          ShownRestActivity(id: "b", logID: id, content: Self.content)])
        await perform(.addRest, container: container, recorder: recorder)
        #expect(recorder.events == [.end(id: "b"), .update(id: "a", Self.extended), .schedule(Self.at(12, 1, 32), withSound: true)])
    }

    @Test("+30s with nothing shown: the handler requests an activity for the log with the stored 12:01:32")
    func nothingShownRequests() async throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let id = try logID(in: container)
        let recorder = RestActivityCenterRecorder()
        await perform(.addRest, container: container, recorder: recorder)
        #expect(recorder.events == [.request(logID: id, Self.extended), .schedule(Self.at(12, 1, 32), withSound: true)])
    }

    @Test("+30s with the preference off and nothing shown: no activity call, only the schedule")
    func disabledNothingShown() async throws {
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let recorder = RestActivityCenterRecorder()
        await perform(.addRest, container: container, recorder: recorder, liveActivityEnabled: false)
        #expect(recorder.events == [.schedule(Self.at(12, 1, 32), withSound: true)])
    }
}
#endif

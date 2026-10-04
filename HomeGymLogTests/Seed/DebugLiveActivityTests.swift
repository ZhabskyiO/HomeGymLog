#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-15 (parse and live instants): `-liveActivity on|off`, and the workout seeds rebuilt at any `now`
/// (`-liveActivity on` passes the real now so the activity's wall-clock timer counts from it).
@MainActor
@Suite struct DebugLiveActivityTests {
    private let cal = TestCalendar.calendar

    @Test("on → true, off → false, absent → nil")
    func parses() throws {
        #expect(try DebugLiveActivity.parse(arguments: ["app", "-seed", "wo-rest", "-liveActivity", "on"]) == true)
        #expect(try DebugLiveActivity.parse(arguments: ["app", "-liveActivity", "off"]) == false)
        #expect(try DebugLiveActivity.parse(arguments: ["app", "-seed", "wo-rest"]) == nil)
    }

    @Test("an unknown value or a trailing flag throws with the argument and the value")
    func rejects() {
        #expect(throws: DebugFeedbackError.unknownValue(argument: "-liveActivity", value: "maybe")) {
            try DebugLiveActivity.parse(arguments: ["app", "-liveActivity", "maybe"])
        }
        #expect(throws: DebugFeedbackError.unknownValue(argument: "-liveActivity", value: "")) {
            try DebugLiveActivity.parse(arguments: ["app", "-liveActivity"])
        }
    }

    /// The wo-rest log's three instants read through a fresh context.
    private func instants(_ container: ModelContainer) throws -> (started: Date, restStart: Date?, restEnd: Date?) {
        let log = try #require(try ModelContext(container).fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first)
        return (log.startedAt, log.restStartedAt, log.restEndsAt)
    }

    @Test("wo-rest at an arbitrary now: rest now − 13 → now + 62, started now − 754")
    func woRestAtNow() throws {
        let now = cal.date(from: DateComponents(year: 2027, month: 3, day: 3, hour: 8, minute: 17, second: 41))!
        let container = try DebugSeed.woRest.makeContainer(calendar: cal, now: now)
        defer { withExtendedLifetime(container) {} }
        let read = try instants(container)
        #expect(read.restStart == now.addingTimeInterval(-13))
        #expect(read.restEnd == now.addingTimeInterval(62))
        #expect(read.started == now.addingTimeInterval(-754))
    }

    @Test("makeContainer(calendar:) is the same rows at the reference day (Tue 2026-09-15 12:00)")
    func referenceDayOverload() throws {
        let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
        let container = try DebugSeed.woRest.makeContainer(calendar: cal)
        defer { withExtendedLifetime(container) {} }
        let read = try instants(container)
        #expect(read.restStart == noon.addingTimeInterval(-13))
        #expect(read.restEnd == noon.addingTimeInterval(62))
        #expect(read.started == noon.addingTimeInterval(-754))
    }
}
#endif

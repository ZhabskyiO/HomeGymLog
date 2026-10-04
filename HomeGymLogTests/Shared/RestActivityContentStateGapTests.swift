import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity plan S3 gap pass (test-writer): `ContentState.interval` at equal instants and with the instants a
/// whole day reversed. A trap here would crash the extension, so each case also reads `contains`.
@Suite struct RestActivityContentStateGapTests {
    static func at(_ hour: Int, _ minute: Int, _ second: Int, day: Int = 15) -> Date {
        TestCalendar.calendar.date(bySettingHour: hour, minute: minute, second: second, of: TestCalendar.day(2026, 9, day))!
    }

    @Test("equal instants → a zero-length range at that instant")
    func equalInstants() {
        let t = Self.at(12, 0, 0)
        let state = RestActivityAttributes.ContentState(restStartedAt: t, restEndsAt: t, nextText: "Next: set 2 of 3")
        #expect(state.interval == t...t)
        #expect(state.interval.contains(t))
        #expect(!state.interval.contains(t.addingTimeInterval(1)))
    }

    @Test("an end a day before the start → start...start, nothing earlier is inside")
    func reversedByADay() {
        let start = Self.at(12, 0, 0), end = Self.at(12, 0, 0, day: 14)
        let state = RestActivityAttributes.ContentState(restStartedAt: start, restEndsAt: end, nextText: "")
        #expect(state.interval == start...start)
        #expect(!state.interval.contains(end))
    }

    @Test("an end one millisecond after the start is kept, not clamped")
    func oneMillisecond() {
        let start = Self.at(12, 0, 0), end = start.addingTimeInterval(0.001)
        let state = RestActivityAttributes.ContentState(restStartedAt: start, restEndsAt: end, nextText: "")
        #expect(state.interval.upperBound == end)
    }
}

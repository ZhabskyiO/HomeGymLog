import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity plan S3: `ContentState.interval` never traps; an end before the start clamps to a zero-length range.
@Suite struct RestActivityContentStateTests {
    static func at(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        TestCalendar.calendar.date(bySettingHour: hour, minute: minute, second: second, of: TestCalendar.day(2026, 9, 15))!
    }

    @Test("a normal rest: start...end")
    func normal() {
        let start = Self.at(11, 59, 47), end = Self.at(12, 1, 2)
        let state = RestActivityAttributes.ContentState(restStartedAt: start, restEndsAt: end, nextText: "Next: set 2 of 3")
        #expect(state.interval.lowerBound == start)
        #expect(state.interval.upperBound == end)
    }

    @Test("an end before the start: start...start")
    func endBeforeStart() {
        let start = Self.at(11, 59, 47), end = Self.at(11, 59, 0)
        let state = RestActivityAttributes.ContentState(restStartedAt: start, restEndsAt: end, nextText: "")
        #expect(state.interval.lowerBound == start)
        #expect(state.interval.upperBound == start)
    }
}

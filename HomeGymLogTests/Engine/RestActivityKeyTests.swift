import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-8: the two task ids are equal iff every field is; each field alone changes them (NB1).
@Suite struct RestActivityKeyTests {
    static let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    static func key(logID: String = "L", start: Date? = t, end: Date? = t.addingTimeInterval(62), next: String? = "Next: set 2 of 3",
                    enabled: Bool = true, activeTick: Int = 0, endedCount: Int = 0) -> RestActivityKey {
        RestActivityKey(logID: logID, restStartedAt: start, restEndsAt: end, nextText: next, enabled: enabled,
                        activeTick: activeTick, endedCount: endedCount)
    }

    @Test("equal fields → equal keys")
    func equal() {
        #expect(Self.key() == Self.key())
        #expect(RestStrandedKey(workoutInProgress: true, enabled: true, activeTick: 3)
                == RestStrandedKey(workoutInProgress: true, enabled: true, activeTick: 3))
    }

    @Test("each RestActivityKey field alone makes the keys unequal")
    func eachFieldChangesActivityKey() {
        let base = Self.key()
        #expect(base != Self.key(logID: "M"))
        #expect(base != Self.key(start: nil))
        #expect(base != Self.key(start: Self.t.addingTimeInterval(1)))
        #expect(base != Self.key(end: nil))
        #expect(base != Self.key(end: Self.t.addingTimeInterval(92)))
        #expect(base != Self.key(next: nil))
        #expect(base != Self.key(next: "Next: set 3 of 3"))
        #expect(base != Self.key(enabled: false))
        #expect(base != Self.key(activeTick: 1))
        #expect(base != Self.key(endedCount: 1))
    }

    @Test("each RestStrandedKey field alone makes the keys unequal")
    func eachFieldChangesStrandedKey() {
        let base = RestStrandedKey(workoutInProgress: true, enabled: true, activeTick: 0)
        #expect(base != RestStrandedKey(workoutInProgress: false, enabled: true, activeTick: 0))
        #expect(base != RestStrandedKey(workoutInProgress: true, enabled: false, activeTick: 0))
        #expect(base != RestStrandedKey(workoutInProgress: true, enabled: true, activeTick: 1))
    }
}

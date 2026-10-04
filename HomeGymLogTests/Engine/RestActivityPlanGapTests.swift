import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-5 gap pass (test-writer): `decide` cases the per-step suite does not reach. The clock moved back
/// (`now < restStartedAt`; §5.1's `live` gates only on `now < restEndsAt`), the last instant before the end, and a foreign
/// activity beside a matching one whose content changed (end the foreign, update the match). Literals on the `wo-rest`
/// example (log `L`, 11:59:47 → 12:01:02, "Next: set 2 of 3").
@Suite struct RestActivityPlanGapTests {
    static func at(_ hour: Int, _ minute: Int, _ second: Int, day: Int = 15) -> Date {
        TestCalendar.calendar.date(bySettingHour: hour, minute: minute, second: second, of: TestCalendar.day(2026, 9, day))!
    }
    static let start = at(11, 59, 47), end = at(12, 1, 2)
    static let next = "Next: set 2 of 3"
    static let content = RestActivityContent(startedAt: start, endsAt: end, nextText: next)
    static let extended = RestActivityContent(startedAt: start, endsAt: at(12, 1, 32), nextText: next)

    private func decide(restEndsAt: Date = end, now: Date, shown: [ShownRestActivity]) -> RestActivityDecision {
        RestActivityPlan.decide(logID: "L", restStartedAt: Self.start, restEndsAt: restEndsAt, nextText: Self.next,
                                enabled: true, now: now, shown: shown)
    }

    @Test("clock moved back before restStartedAt, nothing shown → request (only now < restEndsAt gates)",
          arguments: [at(11, 59, 46), at(11, 0, 0), at(12, 0, 0, day: 14)])
    func clockBackRequests(now: Date) {
        #expect(decide(now: now, shown: []) == RestActivityDecision(endIDs: [], step: .request(Self.content)))
    }

    @Test("clock moved back before restStartedAt with the same content shown → nothing, the activity is kept")
    func clockBackKeepsMatch() {
        let a = ShownRestActivity(id: "a", logID: "L", content: Self.content)
        #expect(decide(now: Self.at(11, 0, 0), shown: [a]) == RestActivityDecision(endIDs: [], step: .nothing))
    }

    @Test("one second before restEndsAt (12:01:01) the rest is still live → request")
    func lastSecondLive() {
        #expect(decide(now: Self.at(12, 1, 1), shown: []) == RestActivityDecision(endIDs: [], step: .request(Self.content)))
    }

    @Test("a foreign activity before a matching one whose end moved → end the foreign, update the match")
    func foreignThenMatchUpdates() {
        let x = ShownRestActivity(id: "x", logID: "M", content: Self.content)
        let a = ShownRestActivity(id: "a", logID: "L", content: Self.content)
        #expect(decide(restEndsAt: Self.at(12, 1, 32), now: Self.at(12, 0, 0), shown: [x, a])
                == RestActivityDecision(endIDs: ["x"], step: .update(id: "a", Self.extended)))
    }

    @Test("a matching one before a foreign one → the foreign ends, the match updates (order of shown is not ownership)")
    func matchThenForeignUpdates() {
        let a = ShownRestActivity(id: "a", logID: "L", content: Self.content)
        let x = ShownRestActivity(id: "x", logID: "M", content: Self.content)
        #expect(decide(restEndsAt: Self.at(12, 1, 32), now: Self.at(12, 0, 0), shown: [a, x])
                == RestActivityDecision(endIDs: ["x"], step: .update(id: "a", Self.extended)))
    }

    @Test("foreign ids end before duplicate ids, each group in shown order: [b: L, x: M, a: L, y: N] → [x, y, a], update b")
    func endOrderForeignThenDuplicates() {
        let b = ShownRestActivity(id: "b", logID: "L", content: Self.content)
        let x = ShownRestActivity(id: "x", logID: "M", content: Self.content)
        let a = ShownRestActivity(id: "a", logID: "L", content: Self.content)
        let y = ShownRestActivity(id: "y", logID: "N", content: Self.content)
        #expect(decide(restEndsAt: Self.at(12, 1, 32), now: Self.at(12, 0, 0), shown: [b, x, a, y])
                == RestActivityDecision(endIDs: ["x", "y", "a"], step: .update(id: "b", Self.extended)))
    }

    @Test("the first match's content differs only in its start → update (every field is compared)")
    func startOnlyDiffers() {
        let older = RestActivityContent(startedAt: Self.at(11, 58, 0), endsAt: Self.end, nextText: Self.next)
        let a = ShownRestActivity(id: "a", logID: "L", content: older)
        #expect(decide(now: Self.at(12, 0, 0), shown: [a]) == RestActivityDecision(endIDs: [], step: .update(id: "a", Self.content)))
    }

    @Test("stranded: a workout open with the preference on keeps a foreign activity (the screen's pass owns ending it)")
    func strandedLeavesForeignToScreen() {
        let x = ShownRestActivity(id: "x", logID: "M", content: Self.content)
        #expect(RestActivityPlan.stranded(workoutInProgress: true, enabled: true, shown: [x]) == [])
    }

    @Test("stranded: no workout open ends every id in shown order, duplicates included")
    func strandedAllInOrder() {
        let ids = ["c", "a", "a2"]
        let shown = ids.map { ShownRestActivity(id: $0, logID: "L", content: Self.content) }
        #expect(RestActivityPlan.stranded(workoutInProgress: false, enabled: true, shown: shown) == ["c", "a", "a2"])
    }
}

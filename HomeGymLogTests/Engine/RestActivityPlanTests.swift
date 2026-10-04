import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-5, AC-6, AC-7: `decide`, `stranded` and `rowState`, every row of spec §5.1–5.3 typed as literals
/// on the `wo-rest` worked example (log `L`, 11:59:47 → 12:01:02, "Next: set 2 of 3"). Never another `decide` call.
@Suite struct RestActivityPlanTests {
    static func at(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        TestCalendar.calendar.date(bySettingHour: hour, minute: minute, second: second, of: TestCalendar.day(2026, 9, 15))!
    }
    static let start = at(11, 59, 47), end = at(12, 1, 2), noon = at(12, 0, 0)
    static let next = "Next: set 2 of 3"
    static let content = RestActivityContent(startedAt: start, endsAt: end, nextText: next)
    static func shown(_ id: String, _ logID: String = "L", _ content: RestActivityContent = content) -> ShownRestActivity {
        ShownRestActivity(id: id, logID: logID, content: content)
    }

    private func decide(restStartedAt: Date? = start, restEndsAt: Date? = end, nextText: String? = next, enabled: Bool = true,
                        now: Date = noon, shown: [ShownRestActivity]) -> RestActivityDecision {
        RestActivityPlan.decide(logID: "L", restStartedAt: restStartedAt, restEndsAt: restEndsAt, nextText: nextText,
                                enabled: enabled, now: now, shown: shown)
    }

    // MARK: §5.1 rows

    @Test("nothing shown, live rest → request the content")
    func requestWhenNoneShown() {
        #expect(decide(shown: []) == RestActivityDecision(endIDs: [], step: .request(Self.content)))
    }

    @Test("the same content shown → nothing")
    func sameContent() {
        #expect(decide(shown: [Self.shown("a")]) == RestActivityDecision(endIDs: [], step: .nothing))
    }

    @Test("after +30s → update the shown one to 12:01:32")
    func updateAfterAdd() {
        let extended = RestActivityContent(startedAt: Self.start, endsAt: Self.at(12, 1, 32), nextText: Self.next)
        #expect(decide(restEndsAt: Self.at(12, 1, 32), shown: [Self.shown("a")])
                == RestActivityDecision(endIDs: [], step: .update(id: "a", extended)))
    }

    @Test("after a swap the Next text changes → update")
    func updateAfterSwap() {
        let swapped = RestActivityContent(startedAt: Self.start, endsAt: Self.end, nextText: "Next: Chest-Supported Row · set 1")
        #expect(decide(nextText: "Next: Chest-Supported Row · set 1", shown: [Self.shown("a")])
                == RestActivityDecision(endIDs: [], step: .update(id: "a", swapped)))
    }

    @Test("end reached (now == restEndsAt) or passed → end it", arguments: [at(12, 1, 2), at(12, 1, 3), at(13, 0, 0)])
    func endReached(now: Date) {
        #expect(decide(now: now, shown: [Self.shown("a")]) == RestActivityDecision(endIDs: ["a"], step: .nothing))
    }

    @Test("preference off → end it")
    func disabled() {
        #expect(decide(enabled: false, shown: [Self.shown("a")]) == RestActivityDecision(endIDs: ["a"], step: .nothing))
    }

    @Test("another log's activity → end it and request")
    func foreign() {
        #expect(decide(shown: [Self.shown("x", "M")]) == RestActivityDecision(endIDs: ["x"], step: .request(Self.content)))
    }

    @Test("foreign plus two matching duplicates → end the foreign one and the second duplicate, leave the first")
    func duplicates() {
        #expect(decide(shown: [Self.shown("x", "M"), Self.shown("a"), Self.shown("b")])
                == RestActivityDecision(endIDs: ["x", "b"], step: .nothing))
    }

    @Test("after Skip (restEndsAt nil) → end it")
    func afterSkip() {
        #expect(decide(restStartedAt: nil, restEndsAt: nil, now: Self.at(12, 0, 30), shown: [Self.shown("a")])
                == RestActivityDecision(endIDs: ["a"], step: .nothing))
    }

    @Test("nothing shown with restEndsAt nil or nextText nil → nothing")
    func nothingShownNotLive() {
        #expect(decide(restEndsAt: nil, shown: []) == RestActivityDecision(endIDs: [], step: .nothing))
        #expect(decide(restStartedAt: nil, shown: []) == RestActivityDecision(endIDs: [], step: .nothing))
        #expect(decide(nextText: nil, shown: []) == RestActivityDecision(endIDs: [], step: .nothing))
    }

    @Test("restEndsAt before restStartedAt with now < end → request (the shared interval clamps)")
    func endBeforeStart() {
        let start = Self.at(12, 0, 30), end = Self.at(12, 0, 10)
        #expect(decide(restStartedAt: start, restEndsAt: end, shown: [])
                == RestActivityDecision(endIDs: [], step: .request(RestActivityContent(startedAt: start, endsAt: end, nextText: Self.next))))
    }

    // MARK: AC-5 extras

    @Test("disabled with nothing shown → no ends, nothing")
    func disabledNothingShown() {
        #expect(decide(enabled: false, shown: []) == RestActivityDecision(endIDs: [], step: .nothing))
    }

    @Test("not live: every shown id ends, in shown order")
    func shownOrderPreserved() {
        #expect(decide(restEndsAt: nil, shown: [Self.shown("c", "M"), Self.shown("a"), Self.shown("b", "N")])
                == RestActivityDecision(endIDs: ["c", "a", "b"], step: .nothing))
    }

    @Test("a second matching duplicate ends while the first is updated")
    func duplicateEndedFirstUpdated() {
        let extended = RestActivityContent(startedAt: Self.start, endsAt: Self.at(12, 1, 32), nextText: Self.next)
        #expect(decide(restEndsAt: Self.at(12, 1, 32), shown: [Self.shown("a"), Self.shown("b")])
                == RestActivityDecision(endIDs: ["b"], step: .update(id: "a", extended)))
    }

    @Test("nextText nil with a live rest → end all")
    func nextNilEndsAll() {
        #expect(decide(nextText: nil, shown: [Self.shown("a"), Self.shown("x", "M")])
                == RestActivityDecision(endIDs: ["a", "x"], step: .nothing))
    }

    // MARK: §5.2 stranded (AC-6)

    @Test("stranded: every id when no workout is open or the preference is off, else none")
    func stranded() {
        let a = Self.shown("a"), x = Self.shown("x", "M")
        #expect(RestActivityPlan.stranded(workoutInProgress: false, enabled: true, shown: [a]) == ["a"])
        #expect(RestActivityPlan.stranded(workoutInProgress: true, enabled: true, shown: [a, x]) == [])
        #expect(RestActivityPlan.stranded(workoutInProgress: true, enabled: false, shown: [a]) == ["a"])
        #expect(RestActivityPlan.stranded(workoutInProgress: false, enabled: false, shown: []) == [])
        #expect(RestActivityPlan.stranded(workoutInProgress: true, enabled: true, shown: []) == [])
    }

    // MARK: §5.3 rowState (AC-7)

    @Test("rowState: off wins; on with iOS off is denied; unknown reads on", arguments: [
        (false, true as Bool?, LiveActivityRowState.off), (false, nil, .off), (false, false, .off),
        (true, true, .on), (true, nil, .on), (true, false, .denied),
    ])
    func rowState(enabled: Bool, activitiesEnabled: Bool?, expected: LiveActivityRowState) {
        #expect(RestActivityPlan.rowState(enabled: enabled, activitiesEnabled: activitiesEnabled) == expected)
    }

    @Test("the preference key and its default")
    func keyAndDefault() {
        #expect(RestActivityPlan.enabledKey == "liveActivityEnabled")
        #expect(RestActivityPlan.defaultEnabled == true)
    }
}

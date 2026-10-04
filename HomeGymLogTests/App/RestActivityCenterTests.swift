import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-9: `RestActivityCenter.apply` over the recorder (never `.live()`: a hosted test would create a real
/// activity, Q9). The §2.1 lifecycle as sequences of `decide` passes over the recorder's shown list, the B2 cancellation
/// check, call-time id resolution, and the silent seam.
@MainActor
@Suite struct RestActivityCenterTests {
    static func at(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        TestCalendar.calendar.date(bySettingHour: hour, minute: minute, second: second, of: TestCalendar.day(2026, 9, 15))!
    }
    static let start = at(11, 59, 47), end = at(12, 1, 2), noon = at(12, 0, 0)
    static let content = RestActivityContent(startedAt: start, endsAt: end, nextText: "Next: set 2 of 3")

    /// One screen pass: decide over the recorder's shown list, then apply.
    private func pass(_ recorder: RestActivityCenterRecorder, restEndsAt: Date? = end, nextText: String? = "Next: set 2 of 3",
                      now: Date = noon) async {
        let decision = RestActivityPlan.decide(logID: "L", restStartedAt: restEndsAt == nil ? nil : Self.start, restEndsAt: restEndsAt,
                                               nextText: nextText, enabled: true, now: now, shown: recorder.center.shown())
        await recorder.center.apply(decision, logID: "L")
    }

    @Test("apply records the ends before the step")
    func endsBeforeStep() async {
        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(id: "x", logID: "M", content: Self.content)])
        await recorder.center.apply(RestActivityDecision(endIDs: ["x"], step: .request(Self.content)), logID: "L")
        #expect(recorder.events == [.end(id: "x"), .request(logID: "L", Self.content)])
    }

    @Test("request → update (+30s) → update (swap) → end (Skip)")
    func fullLifecycle() async {
        let recorder = RestActivityCenterRecorder()
        await pass(recorder)
        let extended = RestActivityContent(startedAt: Self.start, endsAt: Self.at(12, 1, 32), nextText: "Next: set 2 of 3")
        await pass(recorder, restEndsAt: Self.at(12, 1, 32))
        let swapped = RestActivityContent(startedAt: Self.start, endsAt: Self.at(12, 1, 32), nextText: "Next: Chest-Supported Row · set 1")
        await pass(recorder, restEndsAt: Self.at(12, 1, 32), nextText: "Next: Chest-Supported Row · set 1")
        await pass(recorder, restEndsAt: nil, now: Self.at(12, 0, 30))
        #expect(recorder.events == [.request(logID: "L", Self.content), .update(id: "r1", extended), .update(id: "r1", swapped),
                                    .end(id: "r1")])
        #expect(recorder.shown.isEmpty)
    }

    @Test("request → end by time (now reaches restEndsAt)")
    func endByTime() async {
        let recorder = RestActivityCenterRecorder()
        await pass(recorder)
        await pass(recorder, now: Self.end)
        #expect(recorder.events == [.request(logID: "L", Self.content), .end(id: "r1")])
    }

    @Test("request → stranded (workout gone) ends it")
    func stranded() async {
        let recorder = RestActivityCenterRecorder()
        await pass(recorder)
        let ids = RestActivityPlan.stranded(workoutInProgress: false, enabled: true, shown: recorder.center.shown())
        await recorder.center.end(ids)
        #expect(recorder.events == [.request(logID: "L", Self.content), .end(id: "r1")])
    }

    @Test("a foreign activity and a request in one pass")
    func foreignAndRequest() async {
        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(id: "x", logID: "M", content: Self.content)])
        await pass(recorder)
        #expect(recorder.events == [.end(id: "x"), .request(logID: "L", Self.content)])
        #expect(recorder.shown.map(\.id) == ["r1"])
    }

    @Test("B2: a pass cancelled while its end is awaited makes no step; uncancelled it requests (positive control)")
    func cancelledPassStops() async {
        let decision = RestActivityDecision(endIDs: ["x"], step: .request(Self.content))
        // Positive control: the same flow, released without a cancel, requests.
        let control = RestActivityCenterRecorder(shown: [ShownRestActivity(id: "x", logID: "M", content: Self.content)])
        control.holdsEnd = true
        let controlTask = Task { await control.center.apply(decision, logID: "L") }
        while control.waitingEnds == 0 { await Task.yield() }
        control.releaseEnd(0)
        await controlTask.value
        #expect(control.events == [.end(id: "x"), .request(logID: "L", Self.content)])

        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(id: "x", logID: "M", content: Self.content)])
        recorder.holdsEnd = true
        let task = Task { await recorder.center.apply(decision, logID: "L") }
        while recorder.waitingEnds == 0 { await Task.yield() }
        task.cancel()
        recorder.releaseEnd(0)
        await task.value
        #expect(recorder.events == [.end(id: "x")])
    }

    @Test("end of a present and a missing id records one end")
    func missingIDSkipped() async {
        let recorder = RestActivityCenterRecorder(shown: [ShownRestActivity(id: "a", logID: "L", content: Self.content)])
        await recorder.center.end(["a", "missing"])
        #expect(recorder.events == [.end(id: "a")])
    }

    @Test("the silent seam reports its flag and shows nothing")
    func silent() {
        let denied = RestActivityCenter.silent(activitiesEnabled: false)
        #expect(denied.areActivitiesEnabled() == false)
        #expect(denied.shown().isEmpty)
        #expect(RestActivityCenter.silent(activitiesEnabled: true).areActivitiesEnabled() == true)
    }
}

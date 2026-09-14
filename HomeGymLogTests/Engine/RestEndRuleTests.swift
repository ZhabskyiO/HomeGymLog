import Foundation
import Testing
@testable import HomeGymLog

/// AC-21 and AC-23 (rule): the "Rest over" end rule over every row of spec 5.5, and `RestNotificationPlan.decide`.
/// Worked on `wo-rest`: t = 12:00:00, E = 12:01:02. Every input and output is a literal from the table.
@Suite struct RestEndRuleTests {
    private let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
    private var e: Date { t.addingTimeInterval(62) }

    private func at(_ seconds: Double) -> Date { t.addingTimeInterval(seconds) }

    private func observe(_ lastSeen: Date?, _ stored: Date?, resting: Bool, now: Date) -> RestEndObservation {
        RestTimer.observeEnd(lastSeenEndsAt: lastSeen, restEndsAt: stored, resting: resting, now: now)
    }

    @Test("mount, end tick, later evaluations")
    func mountAndEnd() {
        #expect(observe(nil, e, resting: true, now: t) == RestEndObservation(announce: false, lastSeenEndsAt: e))
        #expect(observe(e, e, resting: false, now: at(62.007)) == RestEndObservation(announce: true, lastSeenEndsAt: nil))
        #expect(observe(nil, e, resting: false, now: at(70)) == RestEndObservation(announce: false, lastSeenEndsAt: nil))
    }

    @Test("+30s moves the last-seen end, and the new end announces once")
    func extended() {
        let e92 = at(92)
        #expect(observe(e, e92, resting: true, now: t) == RestEndObservation(announce: false, lastSeenEndsAt: e92))
        #expect(observe(e92, e92, resting: false, now: at(92.01)) == RestEndObservation(announce: true, lastSeenEndsAt: nil))
        #expect(observe(nil, e92, resting: false, now: at(93)) == RestEndObservation(announce: false, lastSeenEndsAt: nil))
    }

    @Test("Skip, swipe clear and a Skip-set replacement never announce")
    func clears() {
        // Skip and a swipe on E1S2 at 12:00:30 reach the rule with the same inputs: the stored end is cleared.
        #expect(observe(e, nil, resting: false, now: at(30)) == RestEndObservation(announce: false, lastSeenEndsAt: nil), "Skip or swipe")
        let replaced = at(105)   // 12:01:45
        #expect(observe(e, replaced, resting: true, now: at(30)) == RestEndObservation(announce: false, lastSeenEndsAt: replaced))
    }

    @Test("relaunch after the end, background both ways, and an end under the permission prompt")
    func lifecycle() {
        #expect(observe(nil, e, resting: false, now: at(70)) == RestEndObservation(announce: false, lastSeenEndsAt: nil), "relaunch 12:01:10")
        // Background at 12:00:50 while resting, return at 12:01:10: resting stored E, leaving active cleared it, and the
        // first evaluation after the return sees the end passed without announcing.
        let beforeBackground = observe(nil, e, resting: true, now: at(50))
        #expect(beforeBackground == RestEndObservation(announce: false, lastSeenEndsAt: e))
        var lastSeen = beforeBackground.lastSeenEndsAt
        lastSeen = nil   // the scene left the active phase
        #expect(observe(lastSeen, e, resting: false, now: at(70)) == RestEndObservation(announce: false, lastSeenEndsAt: nil), "return 12:01:10")
        // Control: had the clear not happened, the same evaluation would announce.
        #expect(observe(beforeBackground.lastSeenEndsAt, e, resting: false, now: at(70)).announce)
        // Return at 12:00:55: the first evaluation sees resting and stores E; the tick at 12:01:02 announces.
        #expect(observe(nil, e, resting: true, now: at(55)) == RestEndObservation(announce: false, lastSeenEndsAt: e))
        #expect(observe(e, e, resting: false, now: e) == RestEndObservation(announce: true, lastSeenEndsAt: nil))
        #expect(observe(nil, e, resting: false, now: at(63)) == RestEndObservation(announce: false, lastSeenEndsAt: nil), "prompt")
    }

    @Test("announce needs every clause: now ≥ L, E == L, not resting")
    func clauses() {
        #expect(!observe(e, e, resting: false, now: at(61)).announce, "now before L")
        #expect(!observe(e, at(92), resting: false, now: at(95)).announce, "E differs from L")
        #expect(!observe(e, e, resting: true, now: at(63)).announce, "still resting")
    }

    @Test("announce is false whenever the last-seen end is nil", arguments: [(true, 0.0), (true, 70.0), (false, 0.0), (false, 70.0)])
    func nilLastSeen(resting: Bool, offset: Double) {
        #expect(!observe(nil, e, resting: resting, now: at(offset)).announce)
    }

    @Test("decide: schedule only for an end still ahead")
    func decide() {
        #expect(RestNotificationPlan.decide(restEndsAt: at(0.001), now: t) == .schedule(at(0.001)))
        #expect(RestNotificationPlan.decide(restEndsAt: e, now: t) == .schedule(e))
        #expect(RestNotificationPlan.decide(restEndsAt: nil, now: t) == .cancel)
        #expect(RestNotificationPlan.decide(restEndsAt: t, now: t) == .cancel)
        #expect(RestNotificationPlan.decide(restEndsAt: at(-5), now: t) == .cancel)
    }
}

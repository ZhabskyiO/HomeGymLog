import Foundation
import Testing
@testable import HomeGymLog

/// AC-11: `restEndCue` over spec 5.2 and `restSkipCue` over spec 5.3, on the `wo-rest` instants (t = 12:00:00,
/// E = 12:01:02; re-declared from `RestEndRuleTests`, whose members are private), and `RestReconcileKey` equality.
@Suite struct FeedbackRestCueTests {
    private let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
    private var e: Date { t.addingTimeInterval(62) }
    private func at(_ seconds: Double) -> Date { t.addingTimeInterval(seconds) }

    private let both = FeedbackCue(haptic: .success, chime: true)

    private func observe(_ lastSeen: Date?, _ stored: Date?, resting: Bool, now: Date) -> RestEndObservation {
        RestTimer.observeEnd(lastSeenEndsAt: lastSeen, restEndsAt: stored, resting: resting, now: now)
    }

    private func endCue(_ observation: RestEndObservation, haptics: Bool = true, sound: Bool = true) -> FeedbackCue? {
        FeedbackCues.restEndCue(observation, haptics: haptics, sound: sound)
    }

    // MARK: - 5.2

    @Test("5.2 mount, then the end tick")
    func mountThenTick() {
        let mount = observe(nil, e, resting: true, now: t)
        #expect(mount.announce == false)
        #expect(endCue(mount) == nil)
        let tick = observe(e, e, resting: false, now: at(62.007))
        #expect(tick.announce == true)
        #expect(endCue(tick) == both)
    }

    @Test("5.2 +30s: nothing at the extension, then one cue at the new end")
    func extended() {
        let e92 = at(92)
        let extend = observe(e, e92, resting: true, now: t)
        #expect(extend.announce == false)
        #expect(endCue(extend) == nil)
        let tick = observe(e92, e92, resting: false, now: at(92.01))
        #expect(tick.announce == true)
        #expect(endCue(tick) == both)
        let after = observe(nil, e92, resting: false, now: at(93))
        #expect(after.announce == false)
        #expect(endCue(after) == nil)
    }

    @Test("5.2 swipe or Skip clear, and a Skip-set replacement, cue nothing")
    func clears() {
        let swipe = observe(e, nil, resting: false, now: at(30))
        #expect(swipe.announce == false)
        #expect(endCue(swipe) == nil)
        let replaced = observe(e, at(105), resting: true, now: at(30))
        #expect(replaced.announce == false)
        #expect(endCue(replaced) == nil)
    }

    @Test("5.2 relaunch, background return past the end, end under the prompt: nil")
    func lifecycleNil() {
        let relaunch = observe(nil, e, resting: false, now: at(70))
        #expect(relaunch.announce == false)
        #expect(endCue(relaunch) == nil)
        // Background at 12:00:50 cleared the last-seen end; the return at 12:01:10 sees nil.
        let returned = observe(nil, e, resting: false, now: at(70))
        #expect(returned.announce == false)
        #expect(endCue(returned) == nil)
        let prompt = observe(nil, e, resting: false, now: at(63))
        #expect(prompt.announce == false)
        #expect(endCue(prompt) == nil)
    }

    @Test("5.2 background 12:00:50, return 12:00:55, tick 12:01:02: nil then success + chime")
    func returnBeforeEnd() {
        let back = observe(nil, e, resting: true, now: at(55))
        #expect(back.announce == false)
        #expect(endCue(back) == nil)
        let tick = observe(back.lastSeenEndsAt, e, resting: false, now: e)
        #expect(tick.announce == true)
        #expect(endCue(tick) == both)
    }

    @Test("5.2 the end tick under each preference pair")
    func preferences() {
        let tick = observe(e, e, resting: false, now: at(62.007))
        #expect(tick.announce == true)
        #expect(endCue(tick, haptics: false, sound: true) == FeedbackCue(haptic: nil, chime: true))
        #expect(endCue(tick, haptics: true, sound: false) == FeedbackCue(haptic: .success, chime: false))
        #expect(endCue(tick, haptics: false, sound: false) == nil)
    }

    // MARK: - 5.3

    @Test("5.3 Skip on a live rest decides success + chime (also the row whose save throws)")
    func skipLive() {
        #expect(FeedbackCues.restSkipCue(restEndsAt: e, now: at(30), haptics: true, sound: true) == both)
    }

    @Test("5.3 Skip at or after the end instant, or with no rest, decides nothing")
    func skipStaleOrNone() {
        #expect(FeedbackCues.restSkipCue(restEndsAt: e, now: at(62.003), haptics: true, sound: true) == nil)
        #expect(FeedbackCues.restSkipCue(restEndsAt: e, now: at(70), haptics: true, sound: true) == nil)
        #expect(FeedbackCues.restSkipCue(restEndsAt: nil, now: at(30), haptics: true, sound: true) == nil)
        #expect(FeedbackCues.restSkipCue(restEndsAt: e, now: e, haptics: true, sound: true) == nil)
    }

    @Test("5.3 Skip with Haptics off and Sound on decides the chime only")
    func skipChimeOnly() {
        #expect(FeedbackCues.restSkipCue(restEndsAt: e, now: at(30), haptics: false, sound: true) == FeedbackCue(haptic: nil, chime: true))
    }

    // MARK: - RestReconcileKey

    @Test("RestReconcileKey equality")
    func reconcileKey() {
        #expect(RestReconcileKey(restEndsAt: e, withSound: true) == RestReconcileKey(restEndsAt: e, withSound: true))
        #expect(RestReconcileKey(restEndsAt: nil, withSound: false) == RestReconcileKey(restEndsAt: nil, withSound: false))
        #expect(RestReconcileKey(restEndsAt: e, withSound: true) != RestReconcileKey(restEndsAt: e, withSound: false))
        #expect(RestReconcileKey(restEndsAt: e, withSound: true) != RestReconcileKey(restEndsAt: at(92), withSound: true))
        #expect(RestReconcileKey(restEndsAt: e, withSound: true) != RestReconcileKey(restEndsAt: nil, withSound: true))
    }
}

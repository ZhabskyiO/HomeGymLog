import Foundation
import Testing
@testable import HomeGymLog

/// m5-haptics AC-11 edges not in the spec tables: the Skip liveness window on both sides of the end instant, every
/// preference pair on a live and a stale Skip, a non-announcing observation under every preference pair, and
/// `RestReconcileKey` differing on the sound flag alone when there is no rest. `t` = 2026-09-15 12:00:00 New York,
/// E = t + 62 s (the `wo-rest` instants).
@Suite struct FeedbackCueEdgeTests {
    private static let t = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)
    private static let e = t.addingTimeInterval(62)

    /// The four (Haptics, Sound) pairs with the cue a finished rest gets under each (spec 5.1's restFinished rows).
    static let restFinishedByPreferences: [(Bool, Bool, FeedbackCue?)] = [
        (true, true, FeedbackCue(haptic: .success, chime: true)),
        (true, false, FeedbackCue(haptic: .success, chime: false)),
        (false, true, FeedbackCue(haptic: nil, chime: true)),
        (false, false, nil),
    ]

    // MARK: - restSkipCue window

    @Test("Skip 1 ms before the end instant is still live and cues")
    func skipJustBeforeEnd() {
        let cue = FeedbackCues.restSkipCue(restEndsAt: Self.e, now: Self.e.addingTimeInterval(-0.001),
                                           haptics: true, sound: true)
        #expect(cue == FeedbackCue(haptic: .success, chime: true))
    }

    @Test("Skip exactly at the end instant cues nothing (the time-based end owns it)")
    func skipAtEnd() {
        #expect(FeedbackCues.restSkipCue(restEndsAt: Self.e, now: Self.e, haptics: true, sound: true) == nil)
    }

    @Test("Skip a day after the end cues nothing")
    func skipLongAfterEnd() {
        let cue = FeedbackCues.restSkipCue(restEndsAt: Self.e, now: Self.e.addingTimeInterval(86_400),
                                           haptics: true, sound: true)
        #expect(cue == nil)
    }

    @Test("Skip before the rest even started (clock behind the stored end by a day) is live and cues")
    func skipLongBeforeEnd() {
        let cue = FeedbackCues.restSkipCue(restEndsAt: Self.e, now: Self.e.addingTimeInterval(-86_400),
                                           haptics: true, sound: true)
        #expect(cue == FeedbackCue(haptic: .success, chime: true))
    }

    @Test("A live Skip under each preference pair gets the restFinished cue", arguments: restFinishedByPreferences)
    func skipLiveByPreferences(haptics: Bool, sound: Bool, expected: FeedbackCue?) {
        let cue = FeedbackCues.restSkipCue(restEndsAt: Self.e, now: Self.t.addingTimeInterval(30),
                                           haptics: haptics, sound: sound)
        #expect(cue == expected)
    }

    @Test("A stale or absent-rest Skip cues nothing under any preference pair",
          arguments: [true, false], [true, false])
    func skipStaleAnyPreferences(haptics: Bool, sound: Bool) {
        #expect(FeedbackCues.restSkipCue(restEndsAt: Self.e, now: Self.e.addingTimeInterval(8),
                                         haptics: haptics, sound: sound) == nil)
        #expect(FeedbackCues.restSkipCue(restEndsAt: nil, now: Self.t, haptics: haptics, sound: sound) == nil)
    }

    // MARK: - restEndCue gating

    @Test("A non-announcing observation cues nothing under any preference pair", arguments: [true, false], [true, false])
    func noAnnounceAnyPreferences(haptics: Bool, sound: Bool) {
        let quiet = RestEndObservation(announce: false, lastSeenEndsAt: Self.e)
        #expect(FeedbackCues.restEndCue(quiet, haptics: haptics, sound: sound) == nil)
    }

    @Test("An announcing observation gets the restFinished cue under each preference pair",
          arguments: restFinishedByPreferences)
    func announceByPreferences(haptics: Bool, sound: Bool, expected: FeedbackCue?) {
        let loud = RestEndObservation(announce: true, lastSeenEndsAt: nil)
        #expect(FeedbackCues.restEndCue(loud, haptics: haptics, sound: sound) == expected)
    }

    // MARK: - RestReconcileKey

    @Test("With no rest, the sound flag alone still changes the key")
    func noRestSoundAloneDiffers() {
        #expect(RestReconcileKey(restEndsAt: nil, withSound: true) != RestReconcileKey(restEndsAt: nil, withSound: false))
    }

    @Test("Ends 1 ms apart with the same sound flag give different keys")
    func endsOneMillisecondApart() {
        #expect(RestReconcileKey(restEndsAt: Self.e, withSound: true)
                != RestReconcileKey(restEndsAt: Self.e.addingTimeInterval(0.001), withSound: true))
    }
}

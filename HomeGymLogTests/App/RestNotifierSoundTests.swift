import Foundation
import Testing
@testable import HomeGymLog

/// m5-haptics AC-13 (rest half): `reconcile` threads the Sound preference to the one add, and the cancel rows add
/// nothing whatever it says. `now` is Tue 2026-09-15 12:00:00; offsets in seconds.
@MainActor
@Suite struct RestNotifierSoundTests {
    private let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    private func at(_ seconds: Double) -> Date { noon.addingTimeInterval(seconds) }

    @Test("a future end adds once, carrying the flag", arguments: [true, false])
    func futureEnd(withSound: Bool) async {
        let recorder = RestNotifierRecorder(now: noon)
        await RestNotifier.recording(into: recorder).reconcile(restEndsAt: at(62), clock: recorder.clock, withSound: withSound)
        #expect(recorder.added.map(\.endsAt) == [at(62)])
        #expect(recorder.addedWithSound == [withSound])
        #expect(recorder.cancels == 0)
    }

    @Test("with sound records true, without records false")
    func literalFlags() async {
        let loud = RestNotifierRecorder(now: noon)
        await RestNotifier.recording(into: loud).reconcile(restEndsAt: at(62), clock: loud.clock, withSound: true)
        #expect(loud.addedWithSound == [true])
        let quiet = RestNotifierRecorder(now: noon)
        await RestNotifier.recording(into: quiet).reconcile(restEndsAt: at(62), clock: quiet.clock, withSound: false)
        #expect(quiet.addedWithSound == [false])
    }

    @Test("no end, an end equal to now, or a past end: no add and one pending removal, either flag",
          arguments: [nil, 0.0, -60.0] as [Double?], [true, false])
    func cancels(offset: Double?, withSound: Bool) async {
        let recorder = RestNotifierRecorder(now: noon)
        await RestNotifier.recording(into: recorder).reconcile(restEndsAt: offset.map(at), clock: recorder.clock, withSound: withSound)
        #expect(recorder.added.isEmpty)
        #expect(recorder.addedWithSound.isEmpty)
        #expect(recorder.cancels == 1)
    }
}

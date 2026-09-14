import Foundation
import Testing
@testable import HomeGymLog

/// AC-23 (applied) and AC-24: the notifier's rules over a recording center, never the system one. `now` is Tue
/// 2026-09-15 12:00:00; instants are written as offsets in seconds (62 = 12:01:02).
@MainActor
@Suite struct RestNotifierTests {
    private let noon = TestCalendar.day(2026, 9, 15).addingTimeInterval(12 * 3600)

    private func at(_ seconds: Double) -> Date { noon.addingTimeInterval(seconds) }

    /// Yields to the main actor until `condition` holds (the scheduling tasks run between yields).
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        try #require(condition(), "the condition never became true")
    }

    @Test("reconcile with a future end schedules exactly once, for the time left")
    func reconcileFuture() async {
        let recorder = RestNotifierRecorder(now: noon)
        let notifier = RestNotifier.recording(into: recorder)
        await notifier.reconcile(restEndsAt: at(62), clock: recorder.clock)
        #expect(recorder.added.map(\.endsAt) == [at(62)])
        #expect(recorder.added.map(\.interval) == [62])
        #expect(recorder.pending == at(62))
        #expect(recorder.cancels == 0)
    }

    @Test("reconcile with no end, an end equal to now, or a past end cancels once and adds nothing",
          arguments: [nil, 0.0, -60.0] as [Double?])
    func reconcileCancels(offset: Double?) async {
        let recorder = RestNotifierRecorder(now: noon)
        let notifier = RestNotifier.recording(into: recorder)
        await notifier.reconcile(restEndsAt: offset.map(at), clock: recorder.clock)
        #expect(recorder.added.isEmpty)
        #expect(recorder.cancels == 1)
        #expect(recorder.deliveredRemovals == 1)
    }

    @Test("a run superseded while it awaited authorization adds nothing, so the newer end stays pending")
    func supersededRun() async throws {
        let recorder = RestNotifierRecorder(now: noon)
        recorder.holdsAuthorization = true
        let notifier = RestNotifier.recording(into: recorder)
        let clock = recorder.clock
        let first = Task { await notifier.schedule(at(92), clock) }       // 12:01:32
        try await waitUntil { recorder.waitingCount == 1 }
        first.cancel()
        let second = Task { await notifier.schedule(at(122), clock) }     // 12:02:02
        try await waitUntil { recorder.waitingCount == 2 }
        recorder.release(1)
        await second.value
        recorder.release(0)
        await first.value
        // Without the cancellation guard the older run adds last: [12:02:02, 12:01:32], pending 12:01:32.
        #expect(recorder.added.map(\.endsAt) == [at(122)])
        #expect(recorder.pending == at(122))
    }

    @Test("a run cancelled during its await records nothing; cancel afterwards leaves nothing pending")
    func cancelledRun() async throws {
        let recorder = RestNotifierRecorder(now: noon)
        recorder.holdsAuthorization = true
        let notifier = RestNotifier.recording(into: recorder)
        let run = Task { await notifier.schedule(at(62), recorder.clock) }
        try await waitUntil { recorder.waitingCount == 1 }
        run.cancel()
        recorder.release(0)
        await run.value
        #expect(recorder.added.isEmpty)
        notifier.cancel()
        #expect(recorder.pending == nil)
        #expect(recorder.added.isEmpty)
        #expect(recorder.cancels == 1)
    }

    @Test("the interval is measured after the authorization await (a 2.5 s prompt leaves 72.5 s of a 75 s rest)")
    func intervalAfterAwait() async throws {
        let recorder = RestNotifierRecorder(now: noon)
        recorder.holdsAuthorization = true
        let notifier = RestNotifier.recording(into: recorder)
        let run = Task { await notifier.schedule(at(75), recorder.clock) }
        try await waitUntil { recorder.waitingCount == 1 }
        recorder.now = at(2.5)
        recorder.release(0)
        await run.value
        #expect(recorder.added.map(\.interval) == [72.5])
        #expect(recorder.added.map(\.endsAt) == [at(75)])
    }

    @Test("an end that passed during the await cancels instead of adding a zero or negative trigger")
    func pastAfterAwait() async throws {
        let recorder = RestNotifierRecorder(now: noon)
        recorder.holdsAuthorization = true
        let notifier = RestNotifier.recording(into: recorder)
        let run = Task { await notifier.schedule(at(5), recorder.clock) }
        try await waitUntil { recorder.waitingCount == 1 }
        recorder.now = at(6)
        recorder.release(0)
        await run.value
        #expect(recorder.added.isEmpty)
        #expect(recorder.cancels == 1)
        #expect(recorder.deliveredRemovals == 1)
    }

    @Test("removeDelivered removes only delivered notifications")
    func removeDeliveredOnly() {
        let recorder = RestNotifierRecorder(now: noon)
        RestNotifier.recording(into: recorder).removeDelivered()
        #expect(recorder.deliveredRemovals == 1)
        #expect(recorder.cancels == 0)
        #expect(RestNotifier.identifier == "rest-timer")
    }
}

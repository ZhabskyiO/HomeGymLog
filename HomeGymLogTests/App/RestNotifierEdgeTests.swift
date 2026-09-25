import Foundation
import Testing
@testable import HomeGymLog

/// Sequencing edges of `RestNotifier.using(_:)` over the recording center (never the system one): the order of calls,
/// the cancel path never asking for permission, three superseded runs, and the guard order when a superseded run's own
/// end passes during its await. `now` is Tue 2026-09-15 12:00:00; instants are offsets in seconds.
@MainActor
@Suite struct RestNotifierEdgeTests {
    private typealias Event = RestNotifierRecorder.Event
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

    @Test("schedule then cancel: authorize, add, then remove pending and delivered; nothing left pending")
    func scheduleThenCancel() async {
        let recorder = RestNotifierRecorder(now: noon)
        let notifier = RestNotifier.recording(into: recorder)
        await notifier.reconcile(restEndsAt: at(62), clock: recorder.clock, withSound: true)
        await notifier.reconcile(restEndsAt: nil, clock: recorder.clock, withSound: true)
        #expect(recorder.events == [.authorize, .add(endsAt: at(62)), .removePending, .removeDelivered])
        #expect(recorder.pending == nil)
    }

    @Test("cancel then schedule: the removals come first and the new request stays pending")
    func cancelThenSchedule() async {
        let recorder = RestNotifierRecorder(now: noon)
        let notifier = RestNotifier.recording(into: recorder)
        await notifier.reconcile(restEndsAt: nil, clock: recorder.clock, withSound: true)
        await notifier.reconcile(restEndsAt: at(75), clock: recorder.clock, withSound: true)
        #expect(recorder.events == [.removePending, .removeDelivered, .authorize, .add(endsAt: at(75))])
        #expect(recorder.pending == at(75))
    }

    /// Spec 2.5: permission is requested at the first rest. A cancel runs on every screen appearance with no rest, so a
    /// cancel path that authorised would prompt as soon as a workout opens.
    @Test("the cancel path never requests authorization", arguments: [nil, 0.0, -30.0] as [Double?])
    func cancelNeverAuthorizes(offset: Double?) async {
        let recorder = RestNotifierRecorder(now: noon)
        let notifier = RestNotifier.recording(into: recorder)
        await notifier.reconcile(restEndsAt: offset.map(at), clock: recorder.clock, withSound: true)
        notifier.cancel()
        #expect(!recorder.events.contains(.authorize))
    }

    @Test("a later end replaces the pending request by adding again, never removing first")
    func extendReplacesWithoutRemoving() async {
        let recorder = RestNotifierRecorder(now: noon)
        let notifier = RestNotifier.recording(into: recorder)
        await notifier.reconcile(restEndsAt: at(62), clock: recorder.clock, withSound: true)
        recorder.now = at(13)
        await notifier.reconcile(restEndsAt: at(92), clock: recorder.clock, withSound: true)
        #expect(recorder.events == [.authorize, .add(endsAt: at(62)), .authorize, .add(endsAt: at(92))])
        #expect(recorder.added.map(\.interval) == [62, 79])
        #expect(recorder.pending == at(92))
    }

    @Test("removeDelivered leaves a pending request in place")
    func removeDeliveredKeepsPending() async {
        let recorder = RestNotifierRecorder(now: noon)
        let notifier = RestNotifier.recording(into: recorder)
        await notifier.reconcile(restEndsAt: at(62), clock: recorder.clock, withSound: true)
        notifier.removeDelivered()
        #expect(recorder.pending == at(62))
        #expect(recorder.events == [.authorize, .add(endsAt: at(62)), .removeDelivered])
    }

    @Test("three runs, the first two superseded while held: only the newest end is added, whatever the release order",
          arguments: [[0, 1, 2], [2, 1, 0], [1, 2, 0], [2, 0, 1]])
    func threeSupersededRuns(releaseOrder: [Int]) async throws {
        let recorder = RestNotifierRecorder(now: noon)
        recorder.holdsAuthorization = true
        let notifier = RestNotifier.recording(into: recorder)
        let clock = recorder.clock
        let ends = [at(62), at(92), at(122)]
        var runs: [Task<Void, Never>] = []
        for (k, end) in ends.enumerated() {
            if let previous = runs.last { previous.cancel() }   // ≈ `.task(id:)` cancelling the older run when the id changes
            runs.append(Task { await notifier.schedule(end, clock, true) })
            try await waitUntil { recorder.waitingCount == k + 1 }
        }
        for index in releaseOrder {
            recorder.release(index)
            await runs[index].value
        }
        #expect(recorder.added.map(\.endsAt) == [at(122)])
        #expect(recorder.pending == at(122))
        #expect(recorder.cancels == 0)
    }

    /// The cancellation guard must come before the interval check. A superseded run for 12:01:02 held past 12:01:02 would
    /// otherwise take the "end passed" branch and remove the newer 12:01:32 request that the second run already added.
    @Test("a superseded run whose own end passed during its await removes nothing, so the newer request survives")
    func supersededRunPastItsEndRemovesNothing() async throws {
        let recorder = RestNotifierRecorder(now: noon)
        recorder.holdsAuthorization = true
        let notifier = RestNotifier.recording(into: recorder)
        let clock = recorder.clock
        let first = Task { await notifier.schedule(at(62), clock, true) }
        try await waitUntil { recorder.waitingCount == 1 }
        first.cancel()
        let second = Task { await notifier.schedule(at(92), clock, true) }
        try await waitUntil { recorder.waitingCount == 2 }
        recorder.release(1)
        await second.value
        recorder.now = at(70)   // past the first run's end, before the second's
        recorder.release(0)
        await first.value
        #expect(recorder.pending == at(92))
        #expect(recorder.cancels == 0)
        #expect(recorder.deliveredRemovals == 0)
        #expect(recorder.added.map(\.endsAt) == [at(92)])
    }

    @Test("an end 1 ms ahead after the await is still added, with a positive interval under 2 ms")
    func intervalBarelyPositive() async throws {
        let recorder = RestNotifierRecorder(now: noon)
        recorder.holdsAuthorization = true
        let notifier = RestNotifier.recording(into: recorder)
        let run = Task { await notifier.schedule(at(5), recorder.clock, true) }
        try await waitUntil { recorder.waitingCount == 1 }
        recorder.now = at(4.999)
        recorder.release(0)
        await run.value
        let added = try #require(recorder.added.first)
        #expect(recorder.added.count == 1)
        #expect(added.endsAt == at(5))
        #expect(added.interval > 0 && added.interval < 0.002)
        #expect(recorder.cancels == 0)
    }

    /// The system trigger terminates the app at 0 s (gotchas: User notifications), so `> 0`, never `>= 0`.
    @Test("an end reached exactly during the await cancels instead of adding a 0 s trigger")
    func intervalExactlyZero() async throws {
        let recorder = RestNotifierRecorder(now: noon)
        recorder.holdsAuthorization = true
        let notifier = RestNotifier.recording(into: recorder)
        let run = Task { await notifier.schedule(at(5), recorder.clock, true) }
        try await waitUntil { recorder.waitingCount == 1 }
        recorder.now = at(5)
        recorder.release(0)
        await run.value
        #expect(recorder.added.isEmpty)
        #expect(recorder.events == [.authorize, .removePending, .removeDelivered])
    }
}

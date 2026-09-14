import Foundation
@testable import HomeGymLog

/// A fake notification center for `RestNotifier.using(_:)`: records every add and removal, keeps one pending instant
/// (the same identifier replaces it), and can hold each authorization await until the test releases it, the way the
/// real permission prompt or a slow completion-handler call does. Its await ignores cancellation on purpose, like the
/// system call it stands in for. The clock reads `now`, which a test may move while an await is held.
@MainActor
final class RestNotifierRecorder {
    /// One call into the center, in call order (`authorize` is recorded when the call begins, before any hold).
    enum Event: Equatable {
        case authorize
        case add(endsAt: Date)
        case removePending
        case removeDelivered
    }

    var now: Date
    /// When true, each `authorize` call waits until `release(_:)` resumes it.
    var holdsAuthorization = false
    /// Every center call in order, so tests can assert sequencing (schedule then cancel, never remove before add).
    private(set) var events: [Event] = []
    private(set) var added: [(endsAt: Date, interval: TimeInterval)] = []
    /// The instant of the pending request, nil when none.
    private(set) var pending: Date?
    /// Pending-request removals (every notifier cancel removes pending once).
    private(set) var cancels = 0
    private(set) var deliveredRemovals = 0
    /// One slot per held authorization call, in call order; a released slot becomes nil.
    private var held: [CheckedContinuation<Void, Never>?] = []

    init(now: Date) {
        self.now = now
    }

    /// How many authorization calls have been held so far (released ones included).
    var waitingCount: Int { held.count }

    /// Resumes the `index`-th held authorization call (0-based, call order).
    func release(_ index: Int) {
        guard held.indices.contains(index), let continuation = held[index] else { return }
        held[index] = nil
        continuation.resume()
    }

    var clock: AppClock {
        AppClock(now: { [unowned self] in self.now }, calendar: TestCalendar.calendar)
    }

    fileprivate func authorize() async {
        events.append(.authorize)
        guard holdsAuthorization else { return }
        await withCheckedContinuation { continuation in held.append(continuation) }
    }

    fileprivate func recordAdd(endsAt: Date, interval: TimeInterval) {
        events.append(.add(endsAt: endsAt))
        added.append((endsAt, interval))
        pending = endsAt
    }

    fileprivate func recordRemovePending() {
        events.append(.removePending)
        cancels += 1
        pending = nil
    }

    fileprivate func recordRemoveDelivered() {
        events.append(.removeDelivered)
        deliveredRemovals += 1
    }
}

extension RestNotifier {
    /// The production rules (`using`) over the recorder instead of the system center.
    @MainActor
    static func recording(into recorder: RestNotifierRecorder) -> RestNotifier {
        .using(RestNotificationCenter(
            authorize: { await recorder.authorize() },
            add: { _, endsAt, interval in recorder.recordAdd(endsAt: endsAt, interval: interval) },
            removePending: { _ in recorder.recordRemovePending() },
            removeDelivered: { _ in recorder.recordRemoveDelivered() }))
    }
}

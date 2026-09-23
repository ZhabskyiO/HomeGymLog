import Foundation
@testable import HomeGymLog

/// A fake notification center for `ReminderNotifier.using(_:)`: pending and delivered id sets, a fixed status, and every
/// call in order. It can hold each pending-ids read and each status read until the test releases it, the way a slow
/// completion-handler call does; those awaits ignore cancellation on purpose, like the system calls they stand in for.
/// A held status read returns the value `status` had when the call began; a held request answers `requestResult` as it
/// stands at release. Every hold shares one slot list in call order, so `release(i)` names the i-th held call.
@MainActor
final class ReminderNotifierRecorder {
    enum Event: Equatable {
        case status
        case requestAuthorization
        case pendingRead
        case deliveredRead
        case removePending([String])
        case removeDelivered([String])
        case add(String)
    }

    var status: ReminderAuthorization
    /// What `requestAuthorization` answers (and then becomes `status`).
    var requestResult: ReminderAuthorization = .authorized
    var pending: [String]
    var delivered: [String]
    var holdsPendingRead = false
    var holdsStatusRead = false
    /// When true, `requestAuthorization` waits (like the system prompt) until released, then answers `requestResult`.
    var holdsRequest = false
    private(set) var events: [Event] = []
    private(set) var added: [ReminderRequest] = []
    private var held: [CheckedContinuation<Void, Never>?] = []

    init(status: ReminderAuthorization = .authorized, pending: [String] = [], delivered: [String] = []) {
        self.status = status
        self.pending = pending
        self.delivered = delivered
    }

    /// How many reads have been held so far (released ones included).
    var waitingCount: Int { held.count }

    /// Resumes the `index`-th held read (0-based, call order).
    func release(_ index: Int) {
        guard held.indices.contains(index), let continuation = held[index] else { return }
        held[index] = nil
        continuation.resume()
    }

    private func hold() async {
        await withCheckedContinuation { continuation in held.append(continuation) }
    }

    fileprivate func readStatus() async -> ReminderAuthorization {
        events.append(.status)
        let value = status
        if holdsStatusRead { await hold() }
        return value
    }

    fileprivate func request() async -> ReminderAuthorization {
        events.append(.requestAuthorization)
        if holdsRequest { await hold() }
        status = requestResult
        return requestResult
    }

    fileprivate func readPending() async -> [String] {
        events.append(.pendingRead)
        if holdsPendingRead { await hold() }
        return pending
    }

    fileprivate func readDelivered() async -> [String] {
        events.append(.deliveredRead)
        return delivered
    }

    fileprivate func removePending(_ ids: [String]) {
        events.append(.removePending(ids))
        pending.removeAll { ids.contains($0) }
    }

    fileprivate func removeDelivered(_ ids: [String]) {
        events.append(.removeDelivered(ids))
        delivered.removeAll { ids.contains($0) }
    }

    fileprivate func add(_ request: ReminderRequest) {
        events.append(.add(request.identifier))
        added.append(request)
        if !pending.contains(request.identifier) { pending.append(request.identifier) }
    }
}

extension ReminderNotifier {
    /// The production rules (`using`) over the recorder instead of the system center.
    @MainActor
    static func recording(into recorder: ReminderNotifierRecorder) -> ReminderNotifier {
        .using(ReminderNotificationCenter(
            status: { await recorder.readStatus() },
            requestAuthorization: { await recorder.request() },
            pendingIdentifiers: { await recorder.readPending() },
            deliveredIdentifiers: { await recorder.readDelivered() },
            add: { recorder.add($0) },
            removePending: { recorder.removePending($0) },
            removeDelivered: { recorder.removeDelivered($0) }))
    }
}

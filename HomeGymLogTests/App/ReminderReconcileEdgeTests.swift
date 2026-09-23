import Foundation
import Testing
import UserNotifications
@testable import HomeGymLog

/// (enabled, status) pairs for which the desired set is empty (spec 5.1 rule 2). File scope for the `@Test` expansion.
private let reminderOffPairs: [(Bool, ReminderAuthorization)] = [
    (false, .authorized), (false, .provisional), (true, .denied), (true, .notDetermined),
]

/// Ids the foreground delegate shows (the `reminder-` prefix at the very start) and ids it does not.
private let delegateTable: [(String, UNNotificationPresentationOptions)] = [
    ("reminder-", [.banner, .list, .sound]),
    ("reminder-2027-01-01", [.banner, .list, .sound]),
    ("Reminder-2026-09-16", []),
    ("daily-reminder-2026-09-16", []),
    (" reminder-2026-09-16", []),
    ("rest-timer-reminder-", []),
]

/// Spec 5.2 beyond `ReminderNotifierTests`: cancellation after the delivered read and inside the add loop, the whole
/// off / denied path from `desired` through `reconcile` (pending and delivered `reminder-*` gone, `rest-timer` kept), and
/// the prefix rule on odd ids. Ids come from `ReminderFixtures.weekdayIDs`.
@MainActor
@Suite struct ReminderReconcileEdgeTests {
    private typealias F = ReminderFixtures

    private enum Event: Equatable {
        case pendingRead, deliveredRead, removePending([String]), removeDelivered([String]), add(String)
    }

    /// A center whose delivered read can be held and whose add can run a hook; everything else answers at once.
    /// `@MainActor`: a nested type in a `@MainActor` suite is not main-actor itself (the test target has no default
    /// isolation), and it builds the app target's `ReminderNotifier`.
    @MainActor
    private final class Center {
        var pending: [String]
        var delivered: [String]
        var holdsDeliveredRead = false
        var onAdd: () -> Void = {}
        private(set) var events: [Event] = []
        private(set) var waiting: CheckedContinuation<Void, Never>?

        init(pending: [String], delivered: [String] = []) {
            self.pending = pending
            self.delivered = delivered
        }

        func release() {
            waiting?.resume()
            waiting = nil
        }

        func notifier() -> ReminderNotifier {
            .using(ReminderNotificationCenter(
                status: { .authorized },
                requestAuthorization: { .authorized },
                pendingIdentifiers: {
                    self.events.append(.pendingRead)
                    return self.pending
                },
                deliveredIdentifiers: {
                    self.events.append(.deliveredRead)
                    if self.holdsDeliveredRead {
                        await withCheckedContinuation { self.waiting = $0 }
                    }
                    return self.delivered
                },
                add: { request in
                    self.events.append(.add(request.identifier))
                    self.onAdd()
                },
                removePending: { ids in self.events.append(.removePending(ids)) },
                removeDelivered: { ids in self.events.append(.removeDelivered(ids)) }))
        }
    }

    private let rowA = F.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27))

    private func requests(_ ids: [String]) -> [ReminderRequest] {
        ids.map { id in
            let parts = id.dropFirst("reminder-".count).split(separator: "-").map { Int($0)! }
            return ReminderRequest(identifier: id,
                                   dateComponents: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 7, minute: 0))
        }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        try #require(condition(), "the condition never became true")
    }

    @Test("a pass cancelled during its delivered read has removed the stale pending ids, and removes no delivered and adds nothing")
    func cancelledAtDeliveredRead() async throws {
        let center = Center(pending: ["rest-timer", "reminder-2026-09-15"], delivered: ["reminder-2026-09-14"])
        center.holdsDeliveredRead = true
        let notifier = center.notifier()
        let desired = requests(rowA)
        let run = Task { await notifier.reconcile(desired) }
        try await waitUntil { center.waiting != nil }
        run.cancel()
        center.release()
        await run.value
        #expect(center.events == [.pendingRead, .removePending(["reminder-2026-09-15"]), .deliveredRead])
    }

    @Test("a pass cancelled during its first add makes no second add")
    func cancelledInsideAddLoop() async {
        let center = Center(pending: [])
        center.onAdd = { withUnsafeCurrentTask { $0?.cancel() } }
        let notifier = center.notifier()
        let desired = requests(rowA)
        let run = Task { await notifier.reconcile(desired) }
        await run.value
        #expect(center.events.filter { if case .add = $0 { return true } else { return false } } == [.add("reminder-2026-09-16")])
    }

    @Test("off or not allowed: desired is empty and the pass removes every pending and delivered reminder, keeping rest-timer",
          arguments: reminderOffPairs)
    func offPathRemovesAll(enabled: Bool, status: ReminderAuthorization) async {
        let days = F.midProgramDays(completed: MissedDayFixtures.midProgramCompleted)
        let desired = ReminderPlan.desired(sessionDays: days, enabled: enabled, status: status, minutes: 420,
                                           now: F.at(9, 15, 12), calendar: TestCalendar.calendar, workoutInProgress: false)
        #expect(desired == [])
        let recorder = ReminderNotifierRecorder(status: status, pending: ["rest-timer"] + rowA,
                                                delivered: ["reminder-2026-09-15", "rest-timer"])
        await ReminderNotifier.recording(into: recorder).reconcile(desired)
        #expect(recorder.pending == ["rest-timer"])
        #expect(recorder.delivered == ["rest-timer"])
        #expect(recorder.added == [])
        #expect(recorder.events.contains(.requestAuthorization) == false)
    }

    @Test("every not-desired id that starts with reminder- is removed; look-alike ids are left alone")
    func prefixRule() async {
        let lookAlikes = ["Reminder-2026-09-16", "daily-reminder-2026-09-16", "rest-timer"]
        let recorder = ReminderNotifierRecorder(pending: lookAlikes + ["reminder-legacy", "reminder-2026-09-16"])
        await ReminderNotifier.recording(into: recorder).reconcile(requests(["reminder-2026-09-16"]))
        #expect(recorder.events.first(where: { if case .removePending = $0 { return true } else { return false } })
                == .removePending(["reminder-legacy"]))
        #expect(Set(recorder.pending) == Set(lookAlikes + ["reminder-2026-09-16"]))
    }

    @Test("a second pass with the same desired set removes nothing and re-adds the same ids (idempotent)")
    func idempotent() async {
        let recorder = ReminderNotifierRecorder(pending: ["rest-timer"])
        let notifier = ReminderNotifier.recording(into: recorder)
        await notifier.reconcile(requests(rowA))
        let afterFirst = Set(recorder.pending)
        await notifier.reconcile(requests(rowA))
        #expect(Set(recorder.pending) == afterFirst)
        #expect(recorder.events.filter { $0 == .removePending([]) }.count == 2)
        #expect(recorder.added.map(\.identifier) == rowA + rowA)
    }

    @Test("the foreground delegate keys on the reminder- prefix at the start of the id", arguments: delegateTable)
    func delegatePrefix(identifier: String, expected: UNNotificationPresentationOptions) {
        #expect(AppNotificationDelegate.options(forIdentifier: identifier) == expected)
    }
}

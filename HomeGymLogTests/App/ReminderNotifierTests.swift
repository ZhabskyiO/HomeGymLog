import Foundation
import Testing
import UserNotifications
@testable import HomeGymLog

/// The five system statuses and their Engine values (spec 4.1). File scope: a `@MainActor` suite's static is not
/// readable from the `@Test` macro's nonisolated argument expansion.
private let reminderStatusTable: [(UNAuthorizationStatus, ReminderAuthorization)] = [
    (.notDetermined, .notDetermined), (.denied, .denied), (.authorized, .authorized), (.provisional, .provisional),
    (.ephemeral, .authorized),
]

/// AC-11: `ReminderNotifier.using(_:).reconcile` over a recording center (spec 5.2's four rows, event order, the
/// cancellation guard), `.silent(status:)`, and the seam's status mapping. Ids come from `ReminderFixtures.weekdayIDs`.
@MainActor
@Suite struct ReminderNotifierTests {
    private typealias F = ReminderFixtures

    /// Row A′'s 30 ids (09-15 … 10-26) and row A's (09-16 … 10-27).
    private let rowAPrime = F.weekdayIDs(from: TestCalendar.day(2026, 9, 15), through: TestCalendar.day(2026, 10, 26))
    private let rowA = F.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27))

    /// Requests for typed ids; the components are the id's day at 07:00 (the reconcile only reads identifiers).
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

    @Test("row 1: A′'s 30 plus rest-timer pending, A desired → only 09-15 removed, 30 adds, rest-timer kept, in order")
    func rowOne() async {
        #expect(rowAPrime.count == 30 && rowA.count == 30)
        let recorder = ReminderNotifierRecorder(pending: ["rest-timer"] + rowAPrime)
        await ReminderNotifier.recording(into: recorder).reconcile(requests(rowA), true)
        #expect(recorder.events.first == .pendingRead)
        #expect(Array(recorder.events.prefix(4)) == [.pendingRead, .removePending(["reminder-2026-09-15"]), .deliveredRead,
                                                    .removeDelivered([])])
        #expect(Array(recorder.events.dropFirst(4)) == rowA.map { .add($0) })
        #expect(recorder.added.map(\.identifier) == rowA)
        #expect(recorder.pending.contains("rest-timer"))
        #expect(recorder.pending.contains("reminder-2026-09-15") == false)
        #expect(Set(recorder.pending) == Set(["rest-timer"] + rowA))
    }

    @Test("row 2 and 3: toggle off or an archive (nothing desired) removes all 30 and adds none")
    func rowTwoThree() async {
        let recorder = ReminderNotifierRecorder(pending: rowA)
        await ReminderNotifier.recording(into: recorder).reconcile([], true)
        #expect(recorder.events == [.pendingRead, .removePending(rowA), .deliveredRead, .removeDelivered([])])
        #expect(recorder.pending == [])
        #expect(recorder.added == [])
    }

    @Test("row 4: nothing pending, nothing desired → empty removals, no adds")
    func rowFour() async {
        let recorder = ReminderNotifierRecorder(status: .denied)
        await ReminderNotifier.recording(into: recorder).reconcile([], true)
        #expect(recorder.events == [.pendingRead, .removePending([]), .deliveredRead, .removeDelivered([])])
        #expect(recorder.added == [])
    }

    @Test("a delivered reminder for a day no longer desired is removed; a delivered rest-timer is not")
    func delivered() async {
        let recorder = ReminderNotifierRecorder(delivered: ["reminder-2026-09-15", "rest-timer", "reminder-2026-09-16"])
        await ReminderNotifier.recording(into: recorder).reconcile(requests(rowA), true)
        #expect(recorder.events.contains(.removeDelivered(["reminder-2026-09-15"])))
        #expect(recorder.delivered == ["rest-timer", "reminder-2026-09-16"])
    }

    @Test("a pass cancelled during its pending read removes and adds nothing")
    func cancelledPass() async throws {
        let recorder = ReminderNotifierRecorder(pending: rowAPrime)
        recorder.holdsPendingRead = true
        let notifier = ReminderNotifier.recording(into: recorder)
        let desired = requests(rowA)
        let run = Task { await notifier.reconcile(desired, true) }
        try await waitUntil { recorder.waitingCount == 1 }
        run.cancel()
        recorder.release(0)
        await run.value
        #expect(recorder.events == [.pendingRead])
        #expect(recorder.added == [])
        #expect(recorder.pending == rowAPrime)
    }

    @Test("reconcile never asks for permission, even when not determined")
    func neverRequests() async {
        let recorder = ReminderNotifierRecorder(status: .notDetermined)
        await ReminderNotifier.recording(into: recorder).reconcile(requests(rowA), true)
        #expect(recorder.events.contains(.requestAuthorization) == false)
        #expect(recorder.events.contains(.status) == false)
        #expect(recorder.added.count == 30)
    }

    @Test("status and requestAuthorization pass through the center")
    func passThrough() async {
        let recorder = ReminderNotifierRecorder(status: .denied)
        recorder.requestResult = .authorized
        let notifier = ReminderNotifier.recording(into: recorder)
        #expect(await notifier.status() == .denied)
        #expect(await notifier.requestAuthorization() == .authorized)
        #expect(recorder.events == [.status, .requestAuthorization])
    }

    @Test("silent(status:) reports its fixed status from both calls, and a reconcile or a request never changes it",
          arguments: [ReminderAuthorization.denied, .authorized, .notDetermined, .provisional])
    func silent(status: ReminderAuthorization) async {
        let notifier = ReminderNotifier.silent(status: status)
        #expect(await notifier.status() == status)
        #expect(await notifier.requestAuthorization() == status)
        await notifier.reconcile(requests(rowA), true)
        await notifier.reconcile(requests(rowA), false)
        await notifier.reconcile([], true)
        #expect(await notifier.status() == status, "a pass leaves the fixed status alone")
        #expect(await notifier.requestAuthorization() == status, "a request never grants in a seed")
    }

    @Test("authorization(_:) maps all five system statuses", arguments: reminderStatusTable)
    func mapping(system: UNAuthorizationStatus, expected: ReminderAuthorization) {
        #expect(ReminderNotificationCenter.authorization(system) == expected)
    }
}

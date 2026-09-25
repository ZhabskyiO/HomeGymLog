import Foundation
import Testing
@testable import HomeGymLog

/// m5-haptics AC-13 (reminder half): m4-reminder 5.2 row 1 with the Sound flag. The same 30 adds happen either way, each
/// carrying the flag, and `rest-timer` is never removed. `.silent(status:)` is covered by
/// `ReminderNotifierTests.silent` (its status is unchanged by a pass with either flag); its reconcile is a no-op closure
/// that receives no center, so no recorder can observe it. Ids come from `ReminderFixtures.weekdayIDs`.
@MainActor
@Suite struct ReminderNotifierSoundTests {
    private typealias F = ReminderFixtures

    /// Row A′'s 30 ids (09-15 … 10-26) and row A's (09-16 … 10-27).
    private let rowAPrime = F.weekdayIDs(from: TestCalendar.day(2026, 9, 15), through: TestCalendar.day(2026, 10, 26))
    private let rowA = F.weekdayIDs(from: TestCalendar.day(2026, 9, 16), through: TestCalendar.day(2026, 10, 27))

    private func requests(_ ids: [String]) -> [ReminderRequest] {
        ids.map { id in
            let parts = id.dropFirst("reminder-".count).split(separator: "-").map { Int($0)! }
            return ReminderRequest(identifier: id,
                                   dateComponents: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 7, minute: 0))
        }
    }

    private func removals(_ recorder: ReminderNotifierRecorder) -> [String] {
        recorder.events.flatMap { event -> [String] in
            switch event {
            case .removePending(let ids), .removeDelivered(let ids): return ids
            default: return []
            }
        }
    }

    @Test("row 1 without sound: 30 adds, each false, rest-timer kept")
    func rowOneSilent() async {
        #expect(rowA.count == 30)
        let recorder = ReminderNotifierRecorder(pending: ["rest-timer"] + rowAPrime)
        await ReminderNotifier.recording(into: recorder).reconcile(requests(rowA), false)
        #expect(recorder.added.map(\.identifier) == rowA)
        #expect(recorder.addedWithSound == Array(repeating: false, count: 30))
        #expect(!removals(recorder).contains("rest-timer"))
        #expect(recorder.pending.contains("rest-timer"))
    }

    @Test("row 1 with sound: 30 adds, each true")
    func rowOneLoud() async {
        let recorder = ReminderNotifierRecorder(pending: ["rest-timer"] + rowAPrime)
        await ReminderNotifier.recording(into: recorder).reconcile(requests(rowA), true)
        #expect(recorder.added.map(\.identifier) == rowA)
        #expect(recorder.addedWithSound == Array(repeating: true, count: 30))
        #expect(!removals(recorder).contains("rest-timer"))
    }
}

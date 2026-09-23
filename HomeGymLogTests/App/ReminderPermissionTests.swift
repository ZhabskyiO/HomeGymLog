import Foundation
import Testing
@testable import HomeGymLog

/// AC-11 / AC-14 (permission half): `ReminderPermission` over the recorder, including the generation rule (spec 4.1, F1):
/// a refresh released after a later request keeps the request's answer.
@MainActor
@Suite struct ReminderPermissionTests {
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        try #require(condition(), "the condition never became true")
    }

    @Test("a new permission has not been read")
    func startsNil() {
        #expect(ReminderPermission().status == nil)
    }

    @Test("refresh writes the center's status")
    func refreshDenied() async {
        let recorder = ReminderNotifierRecorder(status: .denied)
        let permission = ReminderPermission()
        await permission.refresh(using: .recording(into: recorder))
        #expect(permission.status == .denied)
        #expect(recorder.events == [.status])
    }

    @Test("request writes the answer and asks exactly once")
    func requestAuthorized() async {
        let recorder = ReminderNotifierRecorder(status: .notDetermined)
        recorder.requestResult = .authorized
        let permission = ReminderPermission()
        await permission.request(using: .recording(into: recorder))
        #expect(permission.status == .authorized)
        #expect(recorder.events.filter { $0 == .requestAuthorization }.count == 1)
    }

    @Test("a refresh that read not-determined, released after a request answered authorized, leaves authorized")
    func staleRefreshDropped() async throws {
        let recorder = ReminderNotifierRecorder(status: .notDetermined)
        recorder.holdsStatusRead = true
        recorder.requestResult = .authorized
        let permission = ReminderPermission()
        let notifier = ReminderNotifier.recording(into: recorder)
        let refresh = Task { await permission.refresh(using: notifier) }
        try await waitUntil { recorder.waitingCount == 1 }
        await permission.request(using: notifier)
        #expect(permission.status == .authorized)
        recorder.release(0)
        await refresh.value
        #expect(permission.status == .authorized, "without the generation rule it ends .notDetermined")
        #expect(recorder.events == [.status, .requestAuthorization])
    }

    @Test("a refresh started while the prompt is up, released after the answer, leaves the answer")
    func refreshDuringPrompt() async throws {
        let recorder = ReminderNotifierRecorder(status: .notDetermined)
        recorder.holdsRequest = true
        recorder.holdsStatusRead = true
        recorder.requestResult = .authorized
        let permission = ReminderPermission()
        let notifier = ReminderNotifier.recording(into: recorder)
        let request = Task { await permission.request(using: notifier) }
        try await waitUntil { recorder.waitingCount == 1 }
        let refresh = Task { await permission.refresh(using: notifier) }   // reads .notDetermined: the prompt is still up
        try await waitUntil { recorder.waitingCount == 2 }
        recorder.release(0)
        await request.value
        #expect(permission.status == .authorized)
        recorder.release(1)
        await refresh.value
        #expect(permission.status == .authorized, "without the second generation bump the refresh writes .notDetermined")
        #expect(recorder.events == [.requestAuthorization, .status])
    }

    @Test("a refresh started after the request completed does write")
    func laterRefreshWrites() async {
        let recorder = ReminderNotifierRecorder(status: .notDetermined)
        recorder.requestResult = .authorized
        let permission = ReminderPermission()
        let notifier = ReminderNotifier.recording(into: recorder)
        await permission.request(using: notifier)
        recorder.status = .denied   // revoked in iOS Settings
        await permission.refresh(using: notifier)
        #expect(permission.status == .denied)
    }

    @Test("the settings URL is the app's notification page")
    func settingsURL() {
        #expect(ReminderPermission.settingsURL.absoluteString == "app-settings:notifications")
    }
}

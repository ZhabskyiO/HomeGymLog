import Foundation
import UserNotifications

/// The system calls the daily reminder makes (≈ an injected API client), so the reconcile rules above them can be tested
/// with a recorder. `system()` is the real `UNUserNotificationCenter`, read lazily inside each call and never at
/// construction: the environment builds the live default even in a seeded run, which must not touch the center.
struct ReminderNotificationCenter {
    /// The current permission, mapped to the Engine's value.
    var status: () async -> ReminderAuthorization
    /// Asks alert and sound permission (the system prompts once per install), then returns the status after the answer.
    var requestAuthorization: () async -> ReminderAuthorization
    var pendingIdentifiers: () async -> [String]
    var deliveredIdentifiers: () async -> [String]
    /// Adds one non-repeating calendar request; the same identifier replaces the pending one.
    var add: (_ request: ReminderRequest) async -> Void
    var removePending: (_ ids: [String]) -> Void
    var removeDelivered: (_ ids: [String]) -> Void

    static func system() -> ReminderNotificationCenter {
        ReminderNotificationCenter(
            status: {
                authorization(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
            },
            requestAuthorization: {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                return authorization(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
            },
            pendingIdentifiers: {
                await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
            },
            deliveredIdentifiers: {
                await UNUserNotificationCenter.current().deliveredNotifications().map(\.request.identifier)
            },
            add: { request in
                let content = UNMutableNotificationContent()
                content.title = ReminderText.notificationTitle
                content.body = ReminderText.notificationBody
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: request.dateComponents, repeats: false)
                try? await UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
            },
            removePending: { ids in
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            },
            removeDelivered: { ids in
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
            })
    }

    /// `.ephemeral` (App Clips only) counts as authorized; a status a later iOS adds counts as denied, so nothing is
    /// scheduled on a value the app does not understand (spec 4.1).
    static func authorization(_ status: UNAuthorizationStatus) -> ReminderAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .authorized
        @unknown default:
            return .denied
        }
    }
}

/// The daily-reminder seam (≈ a service provided through context), the `RestNotifier` shape: a struct of closures,
/// `.live()` in the app, `.silent(status:)` in seeds and previews, a recording double in tests.
struct ReminderNotifier {
    var status: () async -> ReminderAuthorization
    var requestAuthorization: () async -> ReminderAuthorization
    /// Makes the pending `reminder-*` requests equal `desired` (spec 5.2).
    var reconcile: (_ desired: [ReminderRequest]) async -> Void

    static func live() -> ReminderNotifier {
        .using(.system())
    }

    /// A fixed status and nothing else: seeds freeze the clock and previews must never touch the system center.
    static func silent(status: ReminderAuthorization) -> ReminderNotifier {
        ReminderNotifier(status: { status }, requestAuthorization: { status }, reconcile: { _ in })
    }

    /// The reconcile rules over any center (spec 5.2). Never asks for permission and asserts on nothing (it runs with no
    /// tap). Stale pending ids are removed before any add (an add is never fired ahead of a remove), and the task is
    /// checked for cancellation after every await and before each add: a superseded pass must not re-add stale
    /// requests (≈ ignoring a stale fetch response).
    static func using(_ center: ReminderNotificationCenter) -> ReminderNotifier {
        ReminderNotifier(
            status: { await center.status() },
            requestAuthorization: { await center.requestAuthorization() },
            reconcile: { desired in
                let wanted = Set(desired.map(\.identifier))
                /// Reminder ids that are no longer wanted; ids without the prefix (`rest-timer`) are never touched.
                func stale(_ ids: [String]) -> [String] {
                    ids.filter { $0.hasPrefix(ReminderPlan.prefix) && !wanted.contains($0) }
                }
                let pending = await center.pendingIdentifiers()
                guard !Task.isCancelled else { return }
                center.removePending(stale(pending))
                let delivered = await center.deliveredIdentifiers()
                guard !Task.isCancelled else { return }
                center.removeDelivered(stale(delivered))
                for request in desired {
                    guard !Task.isCancelled else { return }
                    await center.add(request)
                }
            })
    }
}

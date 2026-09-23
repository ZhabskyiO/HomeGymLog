import Foundation
import UserNotifications

/// Decides how a notification that fires while the app is open is presented (≈ a global `onmessage` handler registered
/// once at app start). Installed as the first statement of `HomeGymLogApp.init` and retained there (the center's
/// `delegate` is weak). Main-actor by the target's default isolation, with async witnesses (researcher Q6: no warnings,
/// called on the main thread on 17.5 and 26.5). A daily reminder shows as a banner and stays in Notification Center; the
/// rest timer's "Rest over" keeps showing nothing in the foreground (the M4 delegate rule). No `didReceive`: a tap just
/// opens the app.
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Self.options(forIdentifier: notification.request.identifier)
    }

    /// Banner, list and sound for `reminder-*` ids; nothing for every other id (`rest-timer`).
    static func options(forIdentifier identifier: String) -> UNNotificationPresentationOptions {
        if identifier.hasPrefix(ReminderPlan.prefix) {
            return [.banner, .list, .sound]
        }
        return []
    }
}

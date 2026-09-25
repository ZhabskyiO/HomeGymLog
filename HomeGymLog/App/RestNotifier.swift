import Foundation
import UserNotifications

/// The four system calls the rest notifier makes (≈ an injected API client), so the scheduling rules above them can be
/// tested with a recorder that holds the authorization await. `system()` is the real `UNUserNotificationCenter`.
struct RestNotificationCenter {
    /// Requests alert and sound permission. The system prompts once per install; later calls return at once.
    var authorize: () async -> Void
    /// Adds a request under `identifier` that fires after `interval` seconds; the same identifier replaces the pending
    /// one. `endsAt` is the instant the interval was measured toward (recorders read it; the system does not).
    /// `withSound` is the Sound preference at reconcile time: the notification plays the default sound or none.
    var add: (_ identifier: String, _ endsAt: Date, _ interval: TimeInterval, _ withSound: Bool) async -> Void
    var removePending: (_ identifier: String) -> Void
    var removeDelivered: (_ identifier: String) -> Void

    /// The real center, read inside each call and never at construction: the environment builds the live default even in
    /// a seeded run, which must not touch the center.
    static func system() -> RestNotificationCenter {
        RestNotificationCenter(
            authorize: {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            },
            add: { identifier, _, interval, withSound in
                let content = RestNotificationCenter.content(withSound: withSound)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                try? await UNUserNotificationCenter.current().add(request)
            },
            removePending: { identifier in
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            },
            removeDelivered: { identifier in
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            })
    }

    /// The "Rest over" content (m5-haptics 5.5). Sound is content, not scheduling: with Sound off the banner still shows,
    /// silently (`sound = nil`).
    static func content(withSound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = RestText.restOver
        content.body = RestText.notificationBody
        content.sound = withSound ? .default : nil
        return content
    }
}

/// The rest-end notification seam (≈ a service provided through context; `UNUserNotificationCenter` ≈ the browser
/// Notification API with a scheduled, server-less delivery). A struct of closures like `AppClock`: `.live()` in the app,
/// `.silent()` in seeds and previews, a recording double in tests. Reads time only through `AppClock`.
struct RestNotifier {
    /// Schedules the one rest notification for `endsAt` (replacing any pending one), with or without its sound.
    var schedule: (_ endsAt: Date, _ clock: AppClock, _ withSound: Bool) async -> Void
    /// Removes the pending and the delivered rest notification.
    var cancel: () -> Void
    /// Removes a delivered "Rest over" from Notification Center (every return to the foreground).
    var removeDelivered: () -> Void

    static let identifier = "rest-timer"

    static func live() -> RestNotifier {
        .using(.system())
    }

    /// Does nothing: seeds are screenshot-only and previews never start rests.
    static func silent() -> RestNotifier {
        RestNotifier(schedule: { _, _, _ in }, cancel: {}, removeDelivered: {})
    }

    /// The notifier's rules over any center.
    /// - `schedule` awaits authorization first (an `add` before it is dropped silently), then stops if its task was
    ///   cancelled while it waited: a newer `.task(id:)` run owns the request now (≈ ignoring a stale fetch response).
    ///   Only then is the interval measured, since the permission prompt can hold the await for seconds, and a
    ///   non-positive interval cancels instead (a 0 s trigger terminates the app).
    /// - `cancel` removes pending and delivered. Scheduling never removes first: the same identifier replaces.
    static func using(_ center: RestNotificationCenter) -> RestNotifier {
        RestNotifier(
            schedule: { endsAt, clock, withSound in
                await center.authorize()
                guard !Task.isCancelled else { return }
                let interval = endsAt.timeIntervalSince(clock.now())
                guard interval > 0 else {
                    center.removePending(identifier)
                    center.removeDelivered(identifier)
                    return
                }
                await center.add(identifier, endsAt, interval, withSound)
            },
            cancel: {
                center.removePending(identifier)
                center.removeDelivered(identifier)
            },
            removeDelivered: {
                center.removeDelivered(identifier)
            })
    }

    /// Applies `RestNotificationPlan.decide` to the stored end instant: schedule while it is ahead, cancel otherwise.
    /// The workout screen's `.task(id:)` calls only this; `withSound` comes from its captured `RestReconcileKey`.
    func reconcile(restEndsAt: Date?, clock: AppClock, withSound: Bool) async {
        switch RestNotificationPlan.decide(restEndsAt: restEndsAt, now: clock.now()) {
        case .schedule(let endsAt): await schedule(endsAt, clock, withSound)
        case .cancel: cancel()
        }
    }
}

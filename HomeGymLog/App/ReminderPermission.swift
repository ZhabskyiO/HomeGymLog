import SwiftUI

/// The one owner of the notification permission status (architecture B1). `@Observable` ≈ a small store shared through
/// context: `RootView` creates it as `@State` and puts it in the environment; the reminder host and the Settings rows read
/// `status`, the host refreshes it at mount and on every scene-active, and Settings writes a request's answer. Nothing else
/// reads `notificationSettings()`. It holds no notifier: the caller passes its environment one (`using:`), because a root
/// `@State` object cannot read the environment itself.
@Observable final class ReminderPermission {
    /// Nil until the first read (the first frame renders as scheduled, spec 2.1).
    private(set) var status: ReminderAuthorization?
    /// Bumped by each request; a refresh that started before it drops its (older) answer.
    @ObservationIgnored private var requestGeneration = 0

    /// The app's notification page in the Settings app (`app-settings:notifications`, iOS 16+). Kept in `App/` so no
    /// Features file names a UIKit symbol (NB3).
    static let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString)!

    init(status: ReminderAuthorization? = nil) {
        self.status = status
    }

    /// Re-reads the status. Writes only if no request started while it awaited, so a slow read can never overwrite a
    /// newer answer (≈ ignoring a stale response by request id).
    func refresh(using notifier: ReminderNotifier) async {
        let generation = requestGeneration
        let read = await notifier.status()
        guard generation == requestGeneration else { return }
        status = read
    }

    /// Asks for permission (the system prompt shows only while not determined) and always writes the answer. The
    /// generation is bumped before the await (drops refreshes already running) and again after it (drops a refresh started
    /// while the prompt was up, whose read predates the answer).
    func request(using notifier: ReminderNotifier) async {
        requestGeneration += 1
        let answer = await notifier.requestAuthorization()
        requestGeneration += 1
        status = answer
    }
}

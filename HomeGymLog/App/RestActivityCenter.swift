import ActivityKit
import SwiftUI

/// The Live Activity seam (≈ an injected API client; ActivityKit ≈ a system API that draws on the Lock Screen and in the
/// Dynamic Island while the app sleeps). A struct of closures like `RestNotifier`: `.live()` in the app, `.silent(…)` in
/// seeds and previews, a recorder in tests. The only app file that imports ActivityKit (spec AC-21). `.live()` holds no
/// state, because the `@Entry` default is rebuilt on every read: each closure looks the system's activities up at call
/// time, so an id that ended meanwhile is skipped instead of trapping (B2). No `Activity` object ever leaves a closure
/// (`Activity` is not `Sendable`); callers see ids and Engine values only.
struct RestActivityCenter {
    /// The activities the system shows now (active or stale), in its order.
    var shown: () -> [ShownRestActivity]
    /// Starts an activity for `logID`; a failure (not in the foreground, Live Activities off) is silent.
    var request: (_ logID: String, _ content: RestActivityContent) -> Void
    /// Replaces the content of the activity with `id`, if it still exists.
    var update: (_ id: String, _ content: RestActivityContent) async -> Void
    /// Ends and removes each activity in `ids` that still exists, in order.
    var end: (_ ids: [String]) async -> Void
    /// Whether the user allows this app's Live Activities (iOS Settings → HomeGymLog → Live Activities).
    var areActivitiesEnabled: () -> Bool

    /// The app's own page in the Settings app, which holds the Live Activities toggle (researcher P7). The one home of
    /// this URL, beside the feature it serves (NB12).
    static let settingsURL = URL(string: UIApplication.openSettingsURLString)!

    static func live() -> RestActivityCenter {
        RestActivityCenter(
            shown: {
                Activity<RestActivityAttributes>.activities
                    .filter { $0.activityState == .active || $0.activityState == .stale }
                    .map { ShownRestActivity(id: $0.id, logID: $0.attributes.logID, content: engineContent($0.content.state)) }
            },
            request: { logID, content in
                let initial = ActivityContent(state: contentState(content), staleDate: content.endsAt)
                _ = try? Activity.request(attributes: RestActivityAttributes(logID: logID), content: initial, pushType: nil)
            },
            update: { id, content in
                guard let activity = Activity<RestActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
                await activity.update(ActivityContent(state: contentState(content), staleDate: content.endsAt))
            },
            end: { ids in
                for id in ids {
                    guard let activity = Activity<RestActivityAttributes>.activities.first(where: { $0.id == id }) else { continue }
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            },
            areActivitiesEnabled: { ActivityAuthorizationInfo().areActivitiesEnabled })
    }

    /// No activity, ever: seeds are screenshot-only and previews never start rests. `activitiesEnabled` is what the
    /// Settings row reads (false for the `activity-denied` seed).
    static func silent(activitiesEnabled: Bool) -> RestActivityCenter {
        RestActivityCenter(shown: { [] }, request: { _, _ in }, update: { _, _ in }, end: { _ in },
                           areActivitiesEnabled: { activitiesEnabled })
    }

    /// Performs one decision: the ends first (one `end` call), then the step. A pass whose task was cancelled while an end
    /// was awaited stops before its step (B2, ≈ ignoring a stale fetch response): a newer pass owns the activity now.
    /// `logID` names the log a `.request` is made for (the decision carries only content).
    func apply(_ decision: RestActivityDecision, logID: String) async {
        if !decision.endIDs.isEmpty {
            await end(decision.endIDs)
            guard !Task.isCancelled else { return }
        }
        switch decision.step {
        case .request(let content): request(logID, content)
        case .update(let id, let content): await update(id, content)
        case .nothing: break
        }
    }

    // The one place Engine's value meets ActivityKit's (NB10): field for field, both directions.
    private static func contentState(_ content: RestActivityContent) -> RestActivityAttributes.ContentState {
        RestActivityAttributes.ContentState(restStartedAt: content.startedAt, restEndsAt: content.endsAt, nextText: content.nextText)
    }

    private static func engineContent(_ state: RestActivityAttributes.ContentState) -> RestActivityContent {
        RestActivityContent(startedAt: state.restStartedAt, endsAt: state.restEndsAt, nextText: state.nextText)
    }
}

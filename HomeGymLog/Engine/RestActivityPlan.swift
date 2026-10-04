import Foundation

// Live Activity rules over plain values (spec m5-live-activity §5.1–5.3). No ActivityKit here: the app's
// `RestActivityCenter` turns these decisions into ActivityKit calls, so the rules stay testable without a real activity.
// React analogy: a reducer that returns "what to do" as data; an effect elsewhere performs it.

/// One rest as the activity shows it. **Deliberately mirrors `RestActivityAttributes.ContentState` field for field**
/// (spec §4.4, NB10): the two meet only in `RestActivityCenter.live()`, which keeps Engine ActivityKit-free. Never
/// "deduplicate" by importing ActivityKit here.
nonisolated struct RestActivityContent: Equatable, Sendable {
    let startedAt: Date
    let endsAt: Date
    let nextText: String
}

/// An activity the system currently shows: its ActivityKit id, the workout log it belongs to, and its content.
nonisolated struct ShownRestActivity: Equatable, Sendable {
    let id: String
    let logID: String
    let content: RestActivityContent
}

/// The one request or update a pass makes after its ends.
nonisolated enum RestActivityStep: Equatable, Sendable {
    case request(RestActivityContent)
    case update(id: String, RestActivityContent)
    case nothing
}

/// One pass's outcome: the activities to end (in `shown` order), then the step (plan S9: a struct, since a tuple is not
/// `Equatable`).
nonisolated struct RestActivityDecision: Equatable, Sendable {
    let endIDs: [String]
    let step: RestActivityStep
}

/// The Settings row's three looks (spec §2.3).
nonisolated enum LiveActivityRowState: Equatable, Sendable {
    case on, off, denied
}

/// The workout screen's reconcile task id: every input of `decide` except `now` and `shown`, plus a scene-active tick and
/// a rest-end count so a return to the foreground or a rest ending in place re-runs the pass. React analogy: a
/// `useEffect` dependency array as one value.
nonisolated struct RestActivityKey: Equatable, Sendable {
    let logID: String
    let restStartedAt: Date?
    let restEndsAt: Date?
    let nextText: String?
    let enabled: Bool
    let activeTick: Int
    let endedCount: Int
}

/// The root host's task id (NB1: a struct, since a tuple is not `Equatable`).
nonisolated struct RestStrandedKey: Equatable, Sendable {
    let workoutInProgress: Bool
    let enabled: Bool
    let activeTick: Int
}

nonisolated enum RestActivityPlan {
    /// The Settings preference's `UserDefaults` key; typed once (the scans pin it to this line).
    static let enabledKey = "liveActivityEnabled"
    /// The preference's default and the backup's fallback: on.
    static let defaultEnabled = true

    /// §5.1. A rest is live when both instants exist, `now < restEndsAt`, the "Next:" text exists and the preference is
    /// on. Not live → end every shown activity. Live → end the foreign ones and any duplicate of this log's, then request
    /// (no match), leave alone (equal content) or update the first match.
    static func decide(logID: String, restStartedAt: Date?, restEndsAt: Date?, nextText: String?, enabled: Bool, now: Date,
                       shown: [ShownRestActivity]) -> RestActivityDecision {
        guard let restStartedAt, let restEndsAt, let nextText, enabled, now < restEndsAt else {
            return RestActivityDecision(endIDs: shown.map(\.id), step: .nothing)
        }
        let content = RestActivityContent(startedAt: restStartedAt, endsAt: restEndsAt, nextText: nextText)
        let matching = shown.filter { $0.logID == logID }
        let foreign = shown.filter { $0.logID != logID }
        let endIDs = foreign.map(\.id) + matching.dropFirst().map(\.id)
        guard let first = matching.first else {
            return RestActivityDecision(endIDs: endIDs, step: .request(content))
        }
        let step: RestActivityStep = first.content == content ? .nothing : .update(id: first.id, content)
        return RestActivityDecision(endIDs: endIDs, step: step)
    }

    /// §5.2. Every shown id once no workout is open or the preference is off; otherwise none (the workout screen owns them).
    static func stranded(workoutInProgress: Bool, enabled: Bool, shown: [ShownRestActivity]) -> [String] {
        guard workoutInProgress, enabled else { return shown.map(\.id) }
        return []
    }

    /// §5.3. Off wins; on with Live Activities disabled in iOS is the denied pair; not read yet (nil) reads as on.
    static func rowState(enabled: Bool, activitiesEnabled: Bool?) -> LiveActivityRowState {
        guard enabled else { return .off }
        return activitiesEnabled == false ? .denied : .on
    }
}

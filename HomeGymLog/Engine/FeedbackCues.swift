import Foundation

// Which haptic and chime each workout event gets under the Haptics and Sound preferences (m5-haptics spec 5.1–5.3).
// Pure values: the workout screen asks this table, then bumps a counter or plays the chime. React analogy: a selector
// that maps (event, settings) to the side effects to run, kept out of the component.

/// A workout moment that can produce feedback.
nonisolated enum FeedbackEvent: Equatable, Sendable {
    case setLogged, restFinished, workoutDone
}

/// The haptic kinds the app uses; the workout's modifier group maps them to SwiftUI's `.impact` / `.success`.
nonisolated enum HapticKind: Equatable, Sendable {
    case impact, success
}

/// What to play for one event. Never empty: when neither a haptic nor the chime applies, the table returns nil instead.
nonisolated struct FeedbackCue: Equatable, Sendable {
    let haptic: HapticKind?
    let chime: Bool
}

nonisolated enum FeedbackCues {
    /// `@AppStorage` keys and their default (both preferences default on). The only place these literals live.
    static let hapticsKey = "hapticsEnabled"
    static let soundKey = "soundEnabled"
    static let defaultEnabled = true

    /// Spec 5.1: the haptic is the event's kind when Haptics is on; the chime plays only for a finished rest with Sound
    /// on; nil when neither applies.
    static func cue(for event: FeedbackEvent, haptics: Bool, sound: Bool) -> FeedbackCue? {
        let kind: HapticKind
        switch event {
        case .setLogged: kind = .impact
        case .restFinished, .workoutDone: kind = .success
        }
        let haptic: HapticKind? = haptics ? kind : nil
        let chime = sound && event == .restFinished
        guard haptic != nil || chime else { return nil }
        return FeedbackCue(haptic: haptic, chime: chime)
    }

    /// Spec 5.2: a rest ended by time cues only at the moments the "Rest over" rule announces.
    static func restEndCue(_ observation: RestEndObservation, haptics: Bool, sound: Bool) -> FeedbackCue? {
        observation.announce ? cue(for: .restFinished, haptics: haptics, sound: sound) : nil
    }

    /// Spec 5.3: a Skip cues only when the rest is still live at the tap (read before the store call), so one end
    /// instant never cues twice.
    static func restSkipCue(restEndsAt: Date?, now: Date, haptics: Bool, sound: Bool) -> FeedbackCue? {
        guard case .schedule = RestNotificationPlan.decide(restEndsAt: restEndsAt, now: now) else { return nil }
        return cue(for: .restFinished, haptics: haptics, sound: sound)
    }
}

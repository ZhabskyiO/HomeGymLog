import SwiftUI

/// The workout screen's haptics (m5-haptics NB1, spec 5.1 and 5.4), applied once to its outermost, always-mounted view.
/// ≈ a wrapper component owning three effects, with the counters passed in as props: `WorkoutView` bumps an `Int`
/// counter in the handler whose save succeeded, and `.sensoryFeedback(trigger:)` plays when that counter changes (never
/// on first appearance). Each closure asks `FeedbackCues` again with the current preference, so the toggle gates at
/// playback. Also owns the summary transition: a false → true change of `isSummary` while mounted calls
/// `onSummaryShown`; a relaunch onto the summary starts true and changes nothing, so it never cues.
struct WorkoutFeedback: ViewModifier {
    let setLogged: Int
    let restFinished: Int
    let workoutDone: Int
    let haptics: Bool
    let sound: Bool
    let isSummary: Bool
    let onSummaryShown: () -> Void

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: setLogged) { _, _ in kind(.setLogged) }
            .sensoryFeedback(trigger: restFinished) { _, _ in kind(.restFinished) }
            .sensoryFeedback(trigger: workoutDone) { _, _ in kind(.workoutDone) }
            // No initial run: only a change while mounted counts (spec 5.4). ≈ useEffect that skips the first render.
            .onChange(of: isSummary) { old, new in
                if !old && new { onSummaryShown() }
            }
    }

    /// The system haptic for an event under the current preferences, nil when Haptics is off.
    private func kind(_ event: FeedbackEvent) -> SensoryFeedback? {
        switch FeedbackCues.cue(for: event, haptics: haptics, sound: sound)?.haptic {
        case .impact: return .impact
        case .success: return .success
        case nil: return nil
        }
    }
}

extension View {
    /// Attaches the workout's three haptic triggers and the summary change handler (see `WorkoutFeedback`).
    func workoutFeedback(setLogged: Int, restFinished: Int, workoutDone: Int, haptics: Bool, sound: Bool,
                         isSummary: Bool, onSummaryShown: @escaping () -> Void) -> some View {
        modifier(WorkoutFeedback(setLogged: setLogged, restFinished: restFinished, workoutDone: workoutDone, haptics: haptics,
                                 sound: sound, isSummary: isSummary, onSummaryShown: onSummaryShown))
    }
}

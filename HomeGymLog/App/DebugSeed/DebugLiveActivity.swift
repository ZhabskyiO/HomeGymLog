#if DEBUG
import Foundation

/// `-liveActivity on|off` (spec §4.5): inside a `-seed` launch, `on` keeps the Live Activity seam live and switches the
/// clock to the real one with the seed's rest rebuilt around the real now, so `-seed wo-rest -liveActivity on` shows a real,
/// counting activity for the Dynamic Island screenshot. `off` is the same as absent (silent seam, frozen clock); it is
/// parsed so a typo is still reported. The app screenshot under `on` is not a baseline (its header clock drifts).
enum DebugLiveActivity {
    static func parse(arguments: [String]) throws -> Bool? {
        try DebugFeedbackPreferences.onOff("-liveActivity", in: arguments)
    }
}

extension DebugSeed {
    /// What the seed's silent Live Activity seam reports as the iOS permission: false only for `activity-denied`, which
    /// shows the Settings row's denied pair.
    var activitiesEnabled: Bool { self != .activityDenied }
}
#endif

import ActivityKit
import Foundation

/// The Live Activity's data model, compiled into the app (which requests and updates the activity) and the widget
/// extension (which draws it). `logID` is fixed for the activity's life; `ContentState` is what each update replaces.
/// React analogy: the props type shared between the code that calls `setState` and the component that renders it —
/// the system serializes it between the two processes, so both sides must compile the same declaration.
nonisolated struct RestActivityAttributes: ActivityAttributes {
    /// The workout log's id (`WorkoutLog.id.uuidString`); the app ends an activity whose log is no longer the open one.
    var logID: String

    /// One rest: its two instants and the pre-formatted "Next: …" line (the app formats it; the extension draws it
    /// verbatim). Mirrored field for field by Engine's `RestActivityContent` (spec §4.4, NB10).
    nonisolated struct ContentState: Codable, Hashable {
        var restStartedAt: Date
        var restEndsAt: Date
        var nextText: String

        /// The range every `timerInterval:` view reads. `start...end` traps when `end < start`, so the end is clamped to
        /// the start: a corrupt or zero-length rest draws as already over instead of crashing the extension (plan S3).
        var interval: ClosedRange<Date> {
            restStartedAt...max(restStartedAt, restEndsAt)
        }
    }
}

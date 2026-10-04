import SwiftUI

/// Ends any rest Live Activity left behind once no workout is open or the Lock Screen timer is off (spec §5.2): after a
/// finish, a discard, a crash, a restore, or a launch with a stale activity. Draws nothing; `RootView` mounts it beside
/// `ReminderHost` in its `.background`, so it survives the workout ↔ shell switch. The workout screen owns request and
/// update while a workout is open. Reads no rows: `workoutInProgress` is the root's scalar (a hop on a log being
/// discarded traps on 26.5). It never writes the store and never asserts. React analogy: a renderless component whose
/// only job is one `useEffect(cleanup, [workoutInProgress, enabled, tick])`.
struct RestActivityHost: View {
    let workoutInProgress: Bool
    /// Bumped on every scene-active, so a return to the app re-runs the pass (an activity may have outlived a kill).
    @State private var activeTick = 0
    @AppStorage(RestActivityPlan.enabledKey) private var enabled = RestActivityPlan.defaultEnabled
    @Environment(\.restActivityCenter) private var center
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let key = RestStrandedKey(workoutInProgress: workoutInProgress, enabled: enabled, activeTick: activeTick)
        // An empty concrete root: its handlers run while it draws nothing (gotchas SwiftUI 2026-09-15).
        ZStack {}
            .task(id: key) {
                let ids = RestActivityPlan.stranded(workoutInProgress: key.workoutInProgress, enabled: key.enabled, shown: center.shown())
                if !ids.isEmpty { await center.end(ids) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { activeTick += 1 }
            }
    }
}

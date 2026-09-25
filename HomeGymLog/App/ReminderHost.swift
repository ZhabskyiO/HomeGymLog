import SwiftUI
import SwiftData

/// Keeps the daily-reminder notifications in step with the program (spec 3, "Reminder host"). Draws nothing: `RootView`
/// mounts it once as the `.background` of the `ZStack` around its routes, keyed `.id(programID)`, so it survives the
/// workout ↔ shell switch and remounts only when the program changes. Every input goes into one `Equatable` key and one
/// `.task(id:)` reconciles the notification center whenever it changes (≈ `useEffect(reconcile, [key])`): a start,
/// shift, skip, finish or archive changes the rows; a toggle or picker changes the preferences; a scene-active bumps the
/// tick and re-reads the permission. Two passes at cold launch are expected (the first status read, then the launch's
/// scene-active tick); each is idempotent. It never writes the store and never asserts (it runs with no tap).
struct ReminderHost: View {
    /// No program carries the null UUID, so "no program" reuses the verified one-hop predicate and matches zero rows.
    static let noProgramID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    let programID: UUID?
    /// True while any workout log is open (the root's scalar; never a hop to the log's session, B3d).
    let workoutInProgress: Bool
    /// ≈ `useQuery`: this program's sessions, re-fetched on every save.
    @Query private var sessions: [PlannedSession]
    /// Bumped on every scene-active, so a return from iOS Settings or a new day re-runs the pass.
    @State private var activeTick = 0
    @AppStorage(ReminderPlan.enabledKey) private var enabled = false
    @AppStorage(ReminderPlan.minutesKey) private var minutes = ReminderPlan.defaultMinutes
    /// Settings' Sound preference: whether each reminder carries the default sound.
    @AppStorage(FeedbackCues.soundKey) private var sound = FeedbackCues.defaultEnabled
    @Environment(ReminderPermission.self) private var permission
    @Environment(\.reminderNotifier) private var notifier
    @Environment(\.appClock) private var clock
    @Environment(\.scenePhase) private var scenePhase

    init(programID: UUID?, workoutInProgress: Bool) {
        self.programID = programID
        self.workoutInProgress = workoutInProgress
        _sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: programID ?? Self.noProgramID),
                          sort: \PlannedSession.index)
    }

    var body: some View {
        let key = ReminderPlan.reconcileKey(enabled: enabled, minutes: minutes, status: permission.status,
                                            activeTick: activeTick,
                                            pendingDays: HomeSnapshotBuilder.pendingDays(from: sessions),
                                            workoutInProgress: workoutInProgress, sound: sound)
        // An empty concrete root: its handlers run while it draws nothing and it intercepts no touch (gotchas SwiftUI
        // 2026-09-15). Never a `Group { if }`, whose handlers skip the mount.
        ZStack {}
            .task { await permission.refresh(using: notifier) }   // at mount; reads nothing onAppear writes
            .task(id: key) { await reconcile(key) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    activeTick += 1
                    Task { await permission.refresh(using: notifier) }
                }
            }
    }

    /// One pass: nil key (status not read yet) does nothing; otherwise today's desired set from a fresh `clock.now()`,
    /// then the notifier's diff. Everything it needs comes in the key or is read before the await (the environment is
    /// captured at task start, gotchas Swift 2026-09-22).
    private func reconcile(_ key: ReminderPlan.ReconcileKey?) async {
        guard let key else { return }
        let desired = ReminderPlan.desired(sessionDays: key.pendingDays, enabled: key.enabled, status: key.status,
                                           minutes: key.minutes, now: clock.now(), calendar: clock.calendar,
                                           workoutInProgress: key.workoutInProgress)
        await notifier.reconcile(desired, key.sound)
    }
}

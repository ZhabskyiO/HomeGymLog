import Foundation
import SwiftData

/// What the Live Activity's "+30s" and "Skip" buttons do, in the app's process (spec §4.4). The system may run it with no
/// scene at all (the app suspended or launched in the background), so it reads nothing from SwiftUI: the app's one
/// container's `mainContext` (a second container would leave the screen's rows stale, researcher P2), the clock, and the
/// two preferences from `UserDefaults`. It writes through the same store functions as the rest card, then re-syncs the
/// activity and the "Rest over" notification from the stored row. React analogy: a server action that mutates the store
/// and then revalidates every view of it.
@MainActor
enum RestActivityHandler {
    /// One button press. Steps (spec §4.4): (1) the routed log — the in-progress log with the earliest `startedAt`, as
    /// `RootView`'s query — or, with none, end every shown activity; (2) the write (a throw is swallowed: the store has
    /// already rolled back and restored the row); (3) decide from the row as stored, never from the intended values;
    /// (4) reconcile the notification. Asserts nothing.
    static func perform(_ action: RestActivityAction, container: ModelContainer, clock: AppClock, notifier: RestNotifier,
                        center: RestActivityCenter, liveActivityEnabled: () -> Bool, soundEnabled: () -> Bool) async {
        let context = container.mainContext
        let descriptor = FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate, sortBy: [SortDescriptor(\.startedAt)])
        guard let logs = try? context.fetch(descriptor) else { return }
        guard let log = logs.first else {
            await center.end(center.shown().map(\.id))
            return
        }
        do {
            switch action {
            case .addRest: try WorkoutLogStore.addRestTime(30, to: log, at: clock.now(), in: context)
            case .skipRest: try WorkoutLogStore.skipRest(log, in: context)
            }
        } catch {
            // StoreCommit already rolled back and restored the originals; the re-sync below shows what is stored.
        }
        // Read every row value before the first await: nothing touches the model object after it (the 26.5 delete trap).
        let logID = log.id.uuidString
        let restStartedAt = log.restStartedAt
        let restEndsAt = log.restEndsAt
        let nextText = nextLine(logID: log.id, in: context)
        let decision = RestActivityPlan.decide(logID: logID, restStartedAt: restStartedAt, restEndsAt: restEndsAt, nextText: nextText,
                                               enabled: liveActivityEnabled(), now: clock.now(), shown: center.shown())
        await center.apply(decision, logID: logID)
        await notifier.reconcile(restEndsAt: restEndsAt, clock: clock, withSound: soundEnabled())
    }

    /// The hook `App.init` installs (`LiveActivityIntentHooks.handler`). Runs are serialized (B1): each press waits for the
    /// previous run to finish, so it re-syncs from the row its predecessor wrote (two tasks awaiting one main-actor closure
    /// are not FIFO). The closure awaits its own run, not `inFlight`, which a later press may already have replaced.
    static func makeHook(container: ModelContainer, clock: AppClock, defaults: UserDefaults, notifier: RestNotifier,
                         center: RestActivityCenter) -> @MainActor (RestActivityAction) async -> Void {
        let liveActivityEnabled = { preference(RestActivityPlan.enabledKey, default: RestActivityPlan.defaultEnabled, in: defaults) }
        let soundEnabled = { preference(FeedbackCues.soundKey, default: FeedbackCues.defaultEnabled, in: defaults) }
        return { action in
            let previous = LiveActivityIntentHooks.inFlight
            let run = Task {
                await previous?.value
                await perform(action, container: container, clock: clock, notifier: notifier, center: center,
                              liveActivityEnabled: liveActivityEnabled, soundEnabled: soundEnabled)
            }
            LiveActivityIntentHooks.inFlight = run
            await run.value
        }
    }

    /// A stored `Bool` preference, or `fallback` when it is missing or not a `Bool` (NB7: `bool(forKey:)` reads a missing
    /// key as false, which would turn a default-on preference off).
    static func preference(_ key: String, default fallback: Bool, in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    /// The "Next: …" line for the log's rows, read with the workout screen's own predicates (never relationship hops).
    private static func nextLine(logID: UUID, in context: ModelContext) -> String? {
        guard let exerciseRows = try? context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.exercisePredicate(logID: logID))),
              let setRows = try? context.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: exerciseRows.map(\.id))))
        else { return nil }
        let exercises = WorkoutFlow.sorted(WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows))
        let state = WorkoutFlow.state(exercises: exercises)
        return RestTimer.next(exercises: exercises, state: state).map(RestText.nextLine)
    }
}

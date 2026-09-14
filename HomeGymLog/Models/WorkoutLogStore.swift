import Foundation
import SwiftData

enum WorkoutLogStoreError: Error, Equatable {
    /// An RPE outside 6…10; nothing was written.
    case invalidRPE(Int)
    /// A rest extension of zero or fewer seconds; nothing was written.
    case invalidRestExtension(Int)
}

/// Model-layer actions on workout logs. Deletion is explicit because the iOS 17 runtime does not
/// honor `.cascade` (verified on the 17.5 simulator: children are orphaned, not deleted).
/// Every action ends in one save, and none calls `rollback()` while an insert or a delete is pending (iOS 17.5 crashes the
/// process). When the save fails: the set writers and `finish` put back the fields they changed, so no unsaved change is
/// shown as logged; `start` has already proved the save in a rehearsal, so the writing context is not touched; `discard`
/// rethrows with its deletes pending, and the next successful save in the context completes it.
enum WorkoutLogStore {
    /// The fields a set writer may change, read before it writes so a failed save can put them back.
    private struct SetSnapshot {
        let set: LoggedSet
        let weightLb: Double
        let reps: Int
        let statusRaw: String
        let rpe: Int?
        let rpeSkipped: Bool
        let loggedAt: Date?

        init(_ set: LoggedSet) {
            self.set = set
            weightLb = set.weightLb
            reps = set.reps
            statusRaw = set.statusRaw
            rpe = set.rpe
            rpeSkipped = set.rpeSkipped
            loggedAt = set.loggedAt
        }

        func restore() {
            set.weightLb = weightLb
            set.reps = reps
            set.statusRaw = statusRaw
            set.rpe = rpe
            set.rpeSkipped = rpeSkipped
            set.loggedAt = loggedAt
        }
    }

    /// The log's two rest instants, read before a writer changes them so a failed save can put them back. A nil log
    /// (a set with no exercise or workout) restores nothing.
    private struct RestSnapshot {
        let log: WorkoutLog?
        let startedAt: Date?
        let endsAt: Date?

        init(_ log: WorkoutLog?) {
            self.log = log
            startedAt = log?.restStartedAt
            endsAt = log?.restEndsAt
        }

        func restore() {
            log?.restStartedAt = startedAt
            log?.restEndsAt = endsAt
        }
    }

    /// Saves. If the save throws: `revert` puts back every field the action changed (and removes anything it inserted),
    /// then `rollback()` clears the unsaved-change flag, then the error is rethrown. ≈ a transaction that restores its own
    /// snapshot on abort. Rollback alone is not enough: it clears `hasChanges` but leaves edited values on the rows
    /// (iOS 17.5 and 26.5), and on 17.5 it crashes the process while an insert or a delete is still pending.
    private static func commit(_ context: ModelContext, revert: () -> Void) throws {
        do {
            try context.save()
        } catch {
            revert()
            context.rollback()
            throw error
        }
    }

    /// Starts a workout for a planned session: one log, one `LoggedExercise` per planned exercise (in order,
    /// at its target), and `session.sets` pending `LoggedSet`s per exercise at the target weight and the
    /// session's reps. Links the log to the session and saves. The session stays `pending` until `finish`.
    /// Calling it again for a session that already has a log returns that log (resume), never a duplicate:
    /// reassigning the to-one link would orphan the old log and every set already swiped in it.
    ///
    /// A failed insert cannot be undone cleanly in place: `rollback()` with inserts pending crashes on iOS 17.5, and on
    /// 26.5 the unsaved log keeps matching the root's in-progress query after any undo. So the insert is rehearsed first
    /// in a scratch context on the same container (insert + save, then delete + save; ≈ a dry run in its own
    /// transaction). If the store refuses it, this context is never touched and nothing is left to undo.
    @discardableResult
    static func start(session: PlannedSession, at: Date, in context: ModelContext) throws -> WorkoutLog {
        if let existing = session.workoutLog { return existing }
        try rehearseStart(sessionID: session.id, at: at, container: context.container)
        let log = insertLog(for: session, at: at, in: context)
        try commit(context) {
            // Last resort only (the rehearsal just saved the same graph): unlink so a retry never returns this unsaved
            // log as the session's existing one, and remove the inserts before the rollback, which crashes on 17.5 while
            // they are pending.
            session.workoutLog = nil
            delete(log, in: context)
        }
        return log
    }

    /// Inserts the log graph `start` creates and links it to the session. Does not save.
    private static func insertLog(for session: PlannedSession, at: Date, in context: ModelContext) -> WorkoutLog {
        let log = WorkoutLog(startedAt: at)
        context.insert(log)
        session.workoutLog = log
        for planned in session.exercises.sorted(by: { $0.order < $1.order }) {
            let exercise = LoggedExercise(order: planned.order, exerciseKey: planned.exerciseKey, targetWeightLb: planned.targetWeightLb)
            log.exercises.append(exercise)
            for setOrder in 0..<session.sets {
                exercise.sets.append(LoggedSet(order: setOrder, weightLb: planned.targetWeightLb, reps: session.reps))
            }
        }
        return log
    }

    /// Saves the start graph from a scratch context and removes it again, so a store that refuses the write throws here,
    /// before the writing context changes. A session that is not in the store yet has nothing to rehearse against.
    private static func rehearseStart(sessionID: UUID, at: Date, container: ModelContainer) throws {
        let scratch = ModelContext(container)
        let matches = try scratch.fetch(FetchDescriptor(predicate: #Predicate<PlannedSession> { $0.id == sessionID }))
        guard let stored = matches.first else { return }
        let rehearsal = insertLog(for: stored, at: at, in: scratch)
        try scratch.save()
        delete(rehearsal, in: scratch)
        try scratch.save()
    }

    /// The shared "Start workout" of Home's Today card and the Program card. Finds the first row with
    /// `sessionIndex` among the screen's query rows and starts it only while it is still pending; returns nil and
    /// writes nothing when no row matches or the session is completed or skipped (a stale card cannot start it).
    /// `at` is `clock.now()` read at the tap, never a screen's cached `now`.
    @discardableResult
    static func start(sessionIndex: Int, rows: [PlannedSession], at: Date, in context: ModelContext) throws -> WorkoutLog? {
        guard let session = rows.first(where: { $0.index == sessionIndex }), session.status == .pending else { return nil }
        return try start(session: session, at: at, in: context)
    }

    /// The single writer of completion: sets `finishedAt` and marks the session completed in one save,
    /// upholding "completed iff the log is finished". The rest instants are untouched: every path into the summary has
    /// already cleared them.
    static func finish(_ log: WorkoutLog, at: Date, in context: ModelContext) throws {
        let previousFinishedAt = log.finishedAt
        let previousStatusRaw = log.session?.statusRaw
        log.finishedAt = at
        log.session?.status = .completed
        try commit(context) {
            log.finishedAt = previousFinishedAt
            if let previousStatusRaw { log.session?.statusRaw = previousStatusRaw }
        }
    }

    // MARK: Rest (spec 4.2)

    /// Starts a rest of the session's `restSeconds` at `at` when any set of the log is still pending (the next exercise's
    /// first set included); otherwise, and when the log has no session or a rest that is not positive, clears it. This is
    /// the single writer of "a rest exists ⇒ a pending set exists", so seeds, tests and the screen cannot disagree.
    /// Does not save.
    private static func startRestIfSetFollows(_ log: WorkoutLog?, at: Date) {
        guard let log else { return }
        let pendingRemains = log.exercises.contains { exercise in exercise.sets.contains { $0.status == .pending } }
        let seconds = log.session?.restSeconds ?? 0
        if pendingRemains && seconds > 0 {
            log.restStartedAt = at
            log.restEndsAt = at.addingTimeInterval(TimeInterval(seconds))
        } else {
            clearRest(log)
        }
    }

    /// Clears both rest instants. Does not save.
    private static func clearRest(_ log: WorkoutLog?) {
        log?.restStartedAt = nil
        log?.restEndsAt = nil
    }

    /// Rest card "+30s": moves the end `seconds` later, so the total grows by the same amount; the start stays. Throws
    /// `invalidRestExtension` for `seconds ≤ 0` before looking at the log. Returns false and saves nothing unless a rest
    /// is stored and still live at `at` (a tap as the rest ends is a no-op). Unlimited.
    @discardableResult
    static func addRestTime(_ seconds: Int, to log: WorkoutLog, at: Date, in context: ModelContext) throws -> Bool {
        guard seconds > 0 else { throw WorkoutLogStoreError.invalidRestExtension(seconds) }
        guard let endsAt = log.restEndsAt, at < endsAt else { return false }
        let rest = RestSnapshot(log)
        log.restEndsAt = endsAt.addingTimeInterval(TimeInterval(seconds))
        try commit(context) { rest.restore() }
        return true
    }

    /// Rest card "Skip": clears both instants. Returns false and saves nothing when no rest is stored; a stale rest that
    /// already ended is cleared too, harmlessly.
    @discardableResult
    static func skipRest(_ log: WorkoutLog, in context: ModelContext) throws -> Bool {
        guard log.restEndsAt != nil else { return false }
        let rest = RestSnapshot(log)
        clearRest(log)
        try commit(context) { rest.restore() }
        return true
    }

    // MARK: Set writers
    // Each is guarded: when the row is no longer in the expected state (a double swipe, a second RPE tap before the
    // redraw, a rating after Skip) it returns false before mutating anything and saves nothing. Otherwise it snapshots
    // the sets and the rest instants it will change, writes, and commits, and returns true. `at` is always `clock.now()`
    // read at the action.

    /// Swipe right / "Log set": a pending set becomes done at its stored weight and reps. RPE fields stay as they are.
    /// Clears any rest in the same save (the set can be logged mid-rest).
    @discardableResult
    static func logSet(_ set: LoggedSet, at: Date, in context: ModelContext) throws -> Bool {
        guard set.status == .pending else { return false }
        let snapshot = SetSnapshot(set)
        let rest = RestSnapshot(set.exercise?.workout)
        set.status = .done
        set.loggedAt = at
        clearRest(set.exercise?.workout)
        try commit(context) { snapshot.restore(); rest.restore() }
        return true
    }

    /// Adjust sheet "Save & log set": this pending set takes the draft's weight (lb) and reps and becomes done; the
    /// same exercise's pending sets with a greater `order` take the weight and reps too and stay pending (carry).
    /// Done or skipped sets, tied `order` values and other exercises are never touched. Clears any rest.
    @discardableResult
    static func saveAndLogSet(_ set: LoggedSet, weightLb: Double, reps: Int, at: Date, in context: ModelContext) throws -> Bool {
        guard set.status == .pending else { return false }
        let order = set.order
        let carried = (set.exercise?.sets ?? []).filter { $0.order > order && $0.status == .pending }
        let snapshots = ([set] + carried).map(SetSnapshot.init)
        let rest = RestSnapshot(set.exercise?.workout)
        set.weightLb = weightLb
        set.reps = reps
        set.status = .done
        set.loggedAt = at
        for sibling in carried {
            sibling.weightLb = weightLb
            sibling.reps = reps
        }
        clearRest(set.exercise?.workout)
        try commit(context) { snapshots.forEach { $0.restore() }; rest.restore() }
        return true
    }

    /// Adjust sheet "Skip set": this pending set only takes the draft's weight (lb) and reps and becomes skipped. Starts a
    /// new rest from `at` when a set remains (replacing any live one), else clears it.
    @discardableResult
    static func skipSet(_ set: LoggedSet, weightLb: Double, reps: Int, at: Date, in context: ModelContext) throws -> Bool {
        guard set.status == .pending else { return false }
        let snapshot = SetSnapshot(set)
        let rest = RestSnapshot(set.exercise?.workout)
        set.weightLb = weightLb
        set.reps = reps
        set.status = .skipped
        set.loggedAt = at
        startRestIfSetFollows(set.exercise?.workout, at: at)
        try commit(context) { snapshot.restore(); rest.restore() }
        return true
    }

    /// A done set still awaiting its rating: no RPE chosen and the prompt not skipped.
    private static func awaitsRating(_ set: LoggedSet) -> Bool {
        set.status == .done && set.rpe == nil && !set.rpeSkipped
    }

    /// RPE card pick. Throws `invalidRPE` for anything outside 6…10 before looking at the set; otherwise writes
    /// `rpe` only when the set awaits a rating, and starts a rest from `at` when a set remains (else clears it).
    @discardableResult
    static func setRPE(_ rpe: Int, on set: LoggedSet, at: Date, in context: ModelContext) throws -> Bool {
        guard (6...10).contains(rpe) else { throw WorkoutLogStoreError.invalidRPE(rpe) }
        guard awaitsRating(set) else { return false }
        let snapshot = SetSnapshot(set)
        let rest = RestSnapshot(set.exercise?.workout)
        set.rpe = rpe
        startRestIfSetFollows(set.exercise?.workout, at: at)
        try commit(context) { snapshot.restore(); rest.restore() }
        return true
    }

    /// RPE card "Skip": stores that the prompt was dismissed, under the same guard as `setRPE`, and rests the same way.
    @discardableResult
    static func skipRPE(on set: LoggedSet, at: Date, in context: ModelContext) throws -> Bool {
        guard awaitsRating(set) else { return false }
        let snapshot = SetSnapshot(set)
        let rest = RestSnapshot(set.exercise?.workout)
        set.rpeSkipped = true
        startRestIfSetFollows(set.exercise?.workout, at: at)
        try commit(context) { snapshot.restore(); rest.restore() }
        return true
    }

    /// "Next exercise ›": every pending set of the exercise becomes skipped. Does nothing while one of its done
    /// sets awaits a rating (keeps "only the last non-pending set may await RPE"), or when no set is pending.
    /// Clears any stored rest (the button is not on screen while resting; this is the guard).
    @discardableResult
    static func nextExercise(_ exercise: LoggedExercise, at: Date, in context: ModelContext) throws -> Bool {
        let sets = exercise.sets
        guard !sets.contains(where: awaitsRating) else { return false }
        let pending = sets.filter { $0.status == .pending }
        guard !pending.isEmpty else { return false }
        let snapshots = pending.map(SetSnapshot.init)
        let rest = RestSnapshot(exercise.workout)
        for set in pending {
            set.status = .skipped
            set.loggedAt = at
        }
        clearRest(exercise.workout)
        try commit(context) { snapshots.forEach { $0.restore() }; rest.restore() }
        return true
    }

    /// Exit without finishing: deletes the log with its exercises and sets and saves. The session stays pending and can
    /// be started fresh. A failed save is rethrown with the deletes still pending and nothing rolled back (on iOS 17.5
    /// `rollback()` crashes the process while a delete is pending): the rows still exist in the store, so anything that
    /// holds them reads them safely, this context's fetches already leave them out, and the next successful save in this
    /// context completes the discard.
    static func discard(_ log: WorkoutLog, in context: ModelContext) throws {
        delete(log, in: context)
        try context.save()
    }

    /// Deletes a log with its exercises and sets. The session it belonged to keeps its status; the
    /// caller decides whether to reset it. Does not save.
    static func delete(_ log: WorkoutLog, in context: ModelContext) {
        for exercise in log.exercises {
            for set in exercise.sets {
                context.delete(set)
            }
            context.delete(exercise)
        }
        context.delete(log)
    }
}

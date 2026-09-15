import SwiftUI
import SwiftData

/// The full-screen workout. Owns the log's two live queries (≈ useQuery, re-fetched after every save, which is what
/// keeps this view current on iOS 17), maps the rows to Engine values on every render, derives the state from them,
/// and runs every write through `WorkoutLogStore` with `clock.now()` read at the action. Nothing on screen is stored
/// state except presentation and the lazily built PR baseline, so a relaunch resumes exactly; the rest card derives from
/// the log's two stored instants and the clock, and its effects (end announcement, notification) run only in handlers.
struct WorkoutView: View {
    /// The row passed to the writers. Immutable fields are read once in `init`; the rest instants are read in `body`
    /// (every save re-runs it) and never after Exit starts discarding.
    let log: WorkoutLog
    /// The root's Done handler, given the end instant; it switches to Home before finishing the log.
    let onDone: (Date) -> Void
    private let info: WorkoutSessionInfo
    private let startedAt: Date
    /// The current program's id, read once, for the PR baseline.
    private let programID: UUID?
    @Query private var exerciseRows: [LoggedExercise]
    @Query private var setRows: [LoggedSet]
    /// Every stored note (one per exercise key, 18 at most; ≈ useQuery of all notes). The bar label and the detail sheet's
    /// seed text read it, so a note save re-renders the label at once.
    @Query private var notes: [ExerciseNote]
    /// The one presented sheet, or nil. `.sheet(item:)` ≈ a modal rendered while a state value is non-null.
    @State private var sheet: WorkoutSheet?
    /// `.alert(isPresented:)` ≈ a controlled `<Dialog open>`.
    @State private var isConfirmingExit = false
    /// Set just before Exit deletes the log: the emptied queries would otherwise map to Summary for a frame and start
    /// the PR baseline while the screen is leaving (≈ an "is unmounting" ref).
    @State private var isDiscarding = false
    /// Exercise key → best weight before this workout; nil until the summary first shows (≈ a memo filled by an effect).
    @State private var bestsBefore: [String: Double]?
    /// The rest end instant last seen while resting, for the "Rest over" rule (≈ a `useRef`: written only in effects).
    @State private var lastSeenRestEnd: Date?
    /// The progression pill's baseline for one exercise key (≈ a memo keyed on the exercise, filled by an effect). Drawn
    /// only while its key is the displayed one, so a key change never shows the previous key's pill. Finished logs cannot
    /// change while a workout is open, so a key is never re-fetched while it stays displayed.
    @State private var pillBaseline: (key: String, previous: PreviousTops)?
    @Environment(\.appClock) private var clock
    @Environment(\.modelContext) private var modelContext
    /// Live in the app, silent in seeds and previews.
    @Environment(\.restNotifier) private var notifier
    /// Active, inactive or background (≈ `document.visibilityState`).
    @Environment(\.scenePhase) private var scenePhase
    /// Nil except a DEBUG sheet seed (`-seed wo-adjust`, …), which opens that sheet as the screen appears.
    @Environment(\.workoutSheetPreview) private var sheetPreview
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue

    init(log: WorkoutLog, onDone: @escaping (Date) -> Void) {
        self.log = log
        self.onDone = onDone
        info = WorkoutSnapshotBuilder.sessionInfo(of: log)
        startedAt = log.startedAt
        programID = log.session?.program?.id
        _exerciseRows = Query(filter: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id), sort: \LoggedExercise.order)
        // The exercise ids are fixed for the workout's lifetime (a swap rewrites a row's key, never the row).
        _setRows = Query(filter: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: log.exercises.map(\.id)), sort: \LoggedSet.order)
        _notes = Query(sort: \ExerciseNote.exerciseKey)
    }

    private var unit: WeightUnit { WeightUnit(rawValue: unitsRaw) ?? .lb }

    var body: some View {
        let exercises = WorkoutFlow.sorted(WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows))
        let state = WorkoutFlow.state(exercises: exercises)
        let displayed = WorkoutFlow.displayedExercise(exercises: exercises, state: state)
        Group {
            if isDiscarding {
                Theme.bg.ignoresSafeArea()
            } else if state == .summary {
                let summary = WorkoutSummary.make(exercises: exercises, startedAt: startedAt, bestsBefore: bestsBefore ?? [:])
                WorkoutSummaryView(info: info, startedAt: startedAt, summary: summary, recordsReady: bestsBefore != nil, unit: unit,
                                   calendar: clock.calendar, onDone: { onDone(summary.endedAt) })
            } else {
                // ≈ a setInterval the framework owns, anchored on the rest start so ticks land on whole rest seconds (spec 4.4)
                TimelineView(.periodic(from: log.restStartedAt ?? startedAt, by: 1)) { _ in
                    let rest = RestTimer.display(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, now: clock.now(),
                                                 exercises: exercises, state: state)
                    WorkoutLoggingContent(info: info, startedAt: startedAt, exercises: exercises, state: state, sheetOpen: sheet != nil,
                                          unit: unit, rest: rest, previousTopLb: previousTop(for: displayed),
                                          hasNote: hasNote(displayed?.exerciseKey),
                                          onExit: { exitTapped(exercises) }, onDetail: openDetail,
                                          onSwap: { openSwap($0, in: exercises) }, onNext: nextExercise,
                                          onLog: logSet, onAdjust: { openAdjust($0, in: exercises) }, onRate: rate, onSkipRating: skipRating,
                                          onAddRest: addRest, onSkipRest: skipRest)
                        // Once each and only here: outside this closure a time-based end never fires; twice, a save runs it twice.
                        .onChange(of: rest != nil, initial: true) { _, resting in observeRestEnd(resting: resting) }   // ≈ useEffect(…, [resting])
                        .onChange(of: log.restEndsAt) { observeRestEnd(resting: rest != nil) }
                }
            }
        }
        .sheet(item: $sheet) { item in
            WorkoutSheetContent(item: item, unit: unit, noteText: noteText(for: item), onSaveAndLog: saveAndLog, onSkipSet: skipSet,
                                onNoteChange: saveNote, onClose: { sheet = nil }, onPick: pick)
        }
        .alert(WorkoutText.discardTitle, isPresented: $isConfirmingExit) {
            Button("Discard", role: .destructive) { discard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(WorkoutText.discardMessage)
        }
        .onAppear {
            if let sheetPreview { openPreview(sheetPreview, exercises: exercises, state: state) }
        }
        // ≈ an effect keyed on "is summary": the baseline traverses every finished set (~0.4 s at program end on 17.5),
        // so it is built once, when the summary first shows, never at mount, per render, or while Exit is leaving. It
        // cannot change while a workout is open. A failure leaves nil, which hides only the records cards.
        .task(id: state == .summary && !isDiscarding) {
            guard state == .summary, !isDiscarding, bestsBefore == nil else { return }
            do {
                bestsBefore = try WorkoutSnapshotBuilder.bestsBefore(programID: programID, in: modelContext)
            } catch {
                assertionFailure("PR baseline failed: \(error)")
            }
        }
        // ≈ an effect whose AbortController fires when the id changes: schedules or cancels the rest notification.
        .task(id: isDiscarding ? nil : log.restEndsAt) {
            await notifier.reconcile(restEndsAt: isDiscarding ? nil : log.restEndsAt, clock: clock)
        }
        // ≈ useEffect(load, [displayedKey]); keyed on nil while Exit deletes rows, so no fetch starts then (NB5).
        .task(id: isDiscarding ? nil : displayed?.exerciseKey) { loadPillBaseline(key: displayed?.exerciseKey) }
        .onChange(of: scenePhase) { _, phase in   // ≈ a visibilitychange listener
            if phase == .active {
                notifier.removeDelivered()
                guard !isDiscarding else { return }   // the log row is being deleted: never read its rest instants
                observeRestEnd(resting: RestTimer.display(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, now: clock.now(),
                                                          exercises: exercises, state: state) != nil)
            } else {
                lastSeenRestEnd = nil
            }
        }
        .onDisappear { notifier.cancel() }
    }

    // MARK: Rest effects

    /// Spec 5.5, run from change handlers only: stores the next last-seen end and posts "Rest over" when a rest the screen
    /// saw ends by time in the foreground (≈ an `aria-live` message; nothing happens without VoiceOver).
    private func observeRestEnd(resting: Bool) {
        guard !isDiscarding else { return }
        let result = RestTimer.observeEnd(lastSeenEndsAt: lastSeenRestEnd, restEndsAt: log.restEndsAt, resting: resting, now: clock.now())
        lastSeenRestEnd = result.lastSeenEndsAt
        if result.announce {
            AccessibilityNotification.Announcement(RestText.restOver).post()
        }
    }

    // MARK: Progression pill

    /// The "last" previous top for the displayed exercise, only when the held baseline is for its key.
    private func previousTop(for exercise: WorkoutExerciseValue?) -> Double? {
        guard let exercise, let pillBaseline, pillBaseline.key == exercise.exerciseKey else { return nil }
        return pillBaseline.previous.last
    }

    /// Fetches the key's finished tops in the current program on the main context (~55 ms at program end on 17.5). A
    /// failure keeps the held baseline, which hides the pill for this key: the rest of the screen is unaffected.
    private func loadPillBaseline(key: String?) {
        guard let key, let programID, !isDiscarding, pillBaseline?.key != key else { return }
        do {
            let tops = try WorkoutSnapshotBuilder.finishedTops(key: key, programID: programID, in: modelContext)
            pillBaseline = (key, ProgressionPill.previousTops(tops))
        } catch {
            assertionFailure("Pill baseline failed: \(error)")
        }
    }

    // MARK: Notes and previews

    /// True when `key` has a stored note with non-empty text (whitespace counts, as in the prototype).
    private func hasNote(_ key: String?) -> Bool {
        guard let key else { return false }
        return notes.contains { $0.exerciseKey == key && !$0.text.isEmpty }
    }

    /// The stored text a `.detail` sheet opens with: a scalar read of the query rows, never a fetch (the sheet closure runs
    /// on every body pass, i.e. every keystroke).
    private func noteText(for item: WorkoutSheet) -> String {
        guard case .detail(let key) = item else { return "" }
        return notes.first { $0.exerciseKey == key }?.text ?? ""
    }

    /// The name button and "Add note" / "Notes ·".
    private func openDetail(_ key: String) {
        guard ExerciseLibrary.exercise(for: key) != nil else { return }   // an unknown key would present an empty sheet
        sheet = .detail(exerciseKey: key)
    }

    /// Every editor change: the note for `key` with the full text, stamped `clock.now()` at the keystroke.
    private func saveNote(_ key: String, _ text: String) {
        do {
            try ExerciseNoteStore.save(text: text, forExerciseKey: key, updatedAt: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Save note failed: \(error)")
        }
    }

    /// DEBUG sheet seeds: opens the requested sheet on the displayed exercise as the screen first appears. Adjust needs a
    /// set being logged, so it does nothing while a rating is pending.
    private func openPreview(_ preview: WorkoutSheetPreview, exercises: [WorkoutExerciseValue], state: WorkoutState) {
        switch preview {
        case .adjust:
            guard !WorkoutFlow.isRatingPending(state), let set = WorkoutFlow.focusSet(exercises: exercises, state: state) else { return }
            openAdjust(set.id, in: exercises)
        case .detail:
            if let displayed = WorkoutFlow.displayedExercise(exercises: exercises, state: state) { openDetail(displayed.exerciseKey) }
        case .swap:
            if let displayed = WorkoutFlow.displayedExercise(exercises: exercises, state: state) { openSwap(displayed.id, in: exercises) }
        }
    }

    // MARK: Swap

    /// Header Swap: the candidates for the exercise's current key at the session's stored week and phase with the program's
    /// starting weights, computed at the tap. Nothing opens once a set of it is done or skipped (the button is disabled too).
    private func openSwap(_ exerciseID: UUID, in exercises: [WorkoutExerciseValue]) {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }), WorkoutFlow.canSwap(exercise) else { return }
        let context = WorkoutSnapshotBuilder.swapContext(of: log)
        let candidates = SwapCandidates.candidates(for: exercise.exerciseKey, keysInWorkout: context.keysInWorkout, week: context.week,
                                                   phase: context.phase, startingWeightsLb: context.startingWeightsLb)
        sheet = .swap(SwapDraft(exerciseID: exercise.id, exerciseKey: exercise.exerciseKey, candidates: candidates))
    }

    /// A candidate row: the sheet closes first, then the one-save swap runs (as Save & log does), so a failed save never
    /// leaves the list open over unchanged rows. The store guard refuses a stale draft (a set logged meanwhile).
    private func pick(_ draft: SwapDraft, _ candidate: SwapCandidate) {
        sheet = nil
        guard let row = WorkoutSnapshotBuilder.byID(exerciseRows, id: \.id)[draft.exerciseID] else { return }
        do {
            try WorkoutLogStore.swapExercise(row, to: candidate.exerciseKey, targetWeightLb: candidate.targetWeightLb, in: modelContext)
        } catch {
            assertionFailure("Swap failed: \(error)")
        }
    }

    // MARK: Handlers. Rows are found by id; the store guards every write (a second commit is a no-op) and restores the
    // rows on a failed save, so the screen stays derived from the saved rows and is never blank in Release, where
    // `assertionFailure` does nothing.

    private func setRow(_ setID: UUID) -> LoggedSet? {
        WorkoutSnapshotBuilder.byID(setRows, id: \.id)[setID]
    }

    /// Opens the adjust sheet on a set: its stored weight and reps, its 1-based position and its equipment grid.
    private func openAdjust(_ setID: UUID, in exercises: [WorkoutExerciseValue]) {
        for exercise in exercises {
            guard let index = exercise.sets.firstIndex(where: { $0.id == setID }) else { continue }
            let set = exercise.sets[index]
            sheet = .adjust(AdjustDraft(setID: setID, setNumber: index + 1, kind: ExerciseLibrary.exercise(for: exercise.exerciseKey)?.kind,
                                        weightLb: set.weightLb, reps: set.reps))
            return
        }
    }

    private func saveAndLog(_ draft: AdjustDraft) {
        sheet = nil
        guard let row = setRow(draft.setID) else { return }
        do {
            try WorkoutLogStore.saveAndLogSet(row, weightLb: draft.weightLb, reps: draft.reps, at: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Save & log set failed: \(error)")
        }
    }

    private func skipSet(_ draft: AdjustDraft) {
        sheet = nil
        guard let row = setRow(draft.setID) else { return }
        do {
            try WorkoutLogStore.skipSet(row, weightLb: draft.weightLb, reps: draft.reps, at: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Skip set failed: \(error)")
        }
    }

    private func logSet(_ setID: UUID) {
        guard let row = setRow(setID) else { return }
        do {
            try WorkoutLogStore.logSet(row, at: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Log set failed: \(error)")
        }
    }

    private func rate(_ setID: UUID, _ rpe: Int) {
        guard let row = setRow(setID) else { return }
        do {
            try WorkoutLogStore.setRPE(rpe, on: row, at: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Set RPE failed: \(error)")
        }
    }

    private func skipRating(_ setID: UUID) {
        guard let row = setRow(setID) else { return }
        do {
            try WorkoutLogStore.skipRPE(on: row, at: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Skip RPE failed: \(error)")
        }
    }

    /// Rest card "+30s": extends a live rest; a tap at or after its end writes nothing.
    private func addRest() {
        do {
            try WorkoutLogStore.addRestTime(30, to: log, at: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Add rest time failed: \(error)")
        }
    }

    /// Rest card "Skip": clears the rest; the bar comes back and the rows are unchanged.
    private func skipRest() {
        do {
            try WorkoutLogStore.skipRest(log, in: modelContext)
        } catch {
            assertionFailure("Skip rest failed: \(error)")
        }
    }

    private func nextExercise(_ exerciseID: UUID) {
        guard let row = WorkoutSnapshotBuilder.byID(exerciseRows, id: \.id)[exerciseID] else { return }
        do {
            try WorkoutLogStore.nextExercise(row, at: clock.now(), in: modelContext)
        } catch {
            assertionFailure("Next exercise failed: \(error)")
        }
    }

    /// Exit confirms once anything is logged; otherwise it discards at once.
    private func exitTapped(_ exercises: [WorkoutExerciseValue]) {
        if WorkoutFlow.hasLoggedSet(exercises) {
            isConfirmingExit = true
        } else {
            discard()
        }
    }

    /// Deletes the log; the root's query then routes back to the shell on the tab that was selected. The flag goes up
    /// first so no summary frame renders in between, and comes down again if the save failed (the rows stay in the
    /// store, their deletes pending until the next successful save). The pending rest notification is cancelled when
    /// the screen disappears.
    private func discard() {
        isDiscarding = true
        do {
            try WorkoutLogStore.discard(log, in: modelContext)
        } catch {
            isDiscarding = false
            assertionFailure("Discard workout failed: \(error)")
        }
    }
}

#if DEBUG
#Preview {
    let calendar = AppClock.live().calendar
    let container = try! DebugSeed.woStart.makeContainer(calendar: calendar)
    let log = try! container.mainContext.fetch(FetchDescriptor(predicate: WorkoutSnapshotBuilder.inProgressPredicate)).first!
    return WorkoutView(log: log, onDone: { _ in })
        .modelContainer(container)
        .environment(\.appClock, DebugSeed.woStart.clock(calendar: calendar))
        .environment(\.restNotifier, .silent())
}
#endif

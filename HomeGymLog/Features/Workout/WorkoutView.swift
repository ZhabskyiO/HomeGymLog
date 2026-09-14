import SwiftUI
import SwiftData

/// The full-screen workout. Owns the log's two live queries (≈ useQuery, re-fetched after every save, which is what
/// keeps this view current on iOS 17), maps the rows to Engine values on every render, derives the state from them,
/// and runs every write through `WorkoutLogStore` with `clock.now()` read at the action. Nothing on screen is stored
/// state except presentation and the lazily built PR baseline, so a relaunch resumes exactly.
struct WorkoutView: View {
    /// The row passed to `discard`. Immutable fields are read once in `init`, never in `body`.
    let log: WorkoutLog
    /// The root's Done handler, given the end instant; it switches to Home before finishing the log.
    let onDone: (Date) -> Void
    private let info: WorkoutSessionInfo
    private let startedAt: Date
    /// The current program's id, read once, for the PR baseline.
    private let programID: UUID?
    @Query private var exerciseRows: [LoggedExercise]
    @Query private var setRows: [LoggedSet]
    /// The one presented sheet, or nil. `.sheet(item:)` ≈ a modal rendered while a state value is non-null.
    @State private var sheet: WorkoutSheet?
    /// `.alert(isPresented:)` ≈ a controlled `<Dialog open>`.
    @State private var isConfirmingExit = false
    /// Set just before Exit deletes the log: the emptied queries would otherwise map to Summary for a frame and start
    /// the PR baseline while the screen is leaving (≈ an "is unmounting" ref).
    @State private var isDiscarding = false
    /// Exercise key → best weight before this workout; nil until the summary first shows (≈ a memo filled by an effect).
    @State private var bestsBefore: [String: Double]?
    @Environment(\.appClock) private var clock
    @Environment(\.modelContext) private var modelContext
    /// Nil except a DEBUG `-seed wo-adjust` launch, which opens the sheet on the active set as the screen appears.
    @Environment(\.workoutAdjustPreview) private var adjustPreview
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
    }

    private var unit: WeightUnit { WeightUnit(rawValue: unitsRaw) ?? .lb }

    var body: some View {
        let exercises = WorkoutFlow.sorted(WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows))
        let state = WorkoutFlow.state(exercises: exercises)
        Group {
            if isDiscarding {
                Theme.bg.ignoresSafeArea()
            } else if state == .summary {
                let summary = WorkoutSummary.make(exercises: exercises, startedAt: startedAt, bestsBefore: bestsBefore ?? [:])
                WorkoutSummaryView(info: info, startedAt: startedAt, summary: summary, recordsReady: bestsBefore != nil, unit: unit,
                                   calendar: clock.calendar, onDone: { onDone(summary.endedAt) })
            } else {
                WorkoutLoggingContent(info: info, startedAt: startedAt, exercises: exercises, state: state, sheetOpen: sheet != nil, unit: unit,
                                      onExit: { exitTapped(exercises) }, onNext: nextExercise,
                                      onLog: logSet, onAdjust: { openAdjust($0, in: exercises) }, onRate: rate, onSkipRating: skipRating)
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .adjust(let draft):
                AdjustSheet(initial: draft, unit: unit, onSave: saveAndLog, onSkip: skipSet)
                    .presentationDetents([.height(251)])
                    .presentationCornerRadius(28)
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(Theme.sf)
            }
        }
        .alert(WorkoutText.discardTitle, isPresented: $isConfirmingExit) {
            Button("Discard", role: .destructive) { discard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(WorkoutText.discardMessage)
        }
        .onAppear {
            if adjustPreview == true, !WorkoutFlow.isRatingPending(state), let set = WorkoutFlow.focusSet(exercises: exercises, state: state) {
                openAdjust(set.id, in: exercises)
            }
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
            try WorkoutLogStore.setRPE(rpe, on: row, in: modelContext)
        } catch {
            assertionFailure("Set RPE failed: \(error)")
        }
    }

    private func skipRating(_ setID: UUID) {
        guard let row = setRow(setID) else { return }
        do {
            try WorkoutLogStore.skipRPE(on: row, in: modelContext)
        } catch {
            assertionFailure("Skip RPE failed: \(error)")
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
    /// store, their deletes pending until the next successful save).
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
}
#endif

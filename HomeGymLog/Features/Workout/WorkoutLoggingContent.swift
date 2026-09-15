import SwiftUI

/// Lays out the logging screen from Engine values: header, the displayed exercise with its set rows, the hint and the
/// RPE card in a scroll view, and the pinned bottom bar, or the rest card in its place while resting. Every derived value
/// comes from `WorkoutFlow` and `RestTimer`; taps and swipes report row ids upward, never positions.
struct WorkoutLoggingContent: View {
    let info: WorkoutSessionInfo
    let startedAt: Date
    /// Sorted by `WorkoutFlow.sorted`.
    let exercises: [WorkoutExerciseValue]
    let state: WorkoutState
    let sheetOpen: Bool
    let unit: WeightUnit
    /// The rest card's values while resting; nil shows the bottom bar.
    let rest: RestDisplay?
    /// The displayed exercise's previous top (lb) from the screen's pill baseline; nil while it loads or when there is none.
    let previousTopLb: Double?
    /// True when the displayed key has a note with non-empty text ("Notes ·" instead of "Add note").
    let hasNote: Bool
    let onExit: () -> Void
    /// The name button and the bar's note button; receives the displayed exercise's key.
    let onDetail: (String) -> Void
    /// Header Swap; receives the displayed exercise's id.
    let onSwap: (UUID) -> Void
    /// Receives the displayed exercise's id.
    let onNext: (UUID) -> Void
    /// Each receives a set id.
    let onLog: (UUID) -> Void
    let onAdjust: (UUID) -> Void
    let onRate: (UUID, Int) -> Void
    let onSkipRating: (UUID) -> Void
    /// Rest card "+30s" and "Skip".
    let onAddRest: () -> Void
    let onSkipRest: () -> Void

    var body: some View {
        let displayed = WorkoutFlow.displayedExercise(state) ?? 0   // the index, for the line and the progress segments
        let exercise = WorkoutFlow.displayedExercise(exercises: exercises, state: state)
        let rows = WorkoutFlow.rowStates(exercises: exercises, state: state, sheetOpen: sheetOpen)
        // Spec 5.2: the focus set's stored weight against the previous top (the set being rated while RPE is pending).
        let pillDeltaLb = WorkoutFlow.focusSet(exercises: exercises, state: state).flatMap {
            ProgressionPill.delta(currentLb: $0.weightLb, previousLb: previousTopLb)
        }

        VStack(spacing: 0) {
            WorkoutHeader(name: info.name, startedAt: startedAt,
                          tones: WorkoutFlow.progress(exerciseCount: exercises.count, displayed: displayed),
                          swapEnabled: exercise.map(WorkoutFlow.canSwap) ?? false,
                          onExit: onExit, onSwap: { if let exercise { onSwap(exercise.id) } })
                .padding(.horizontal, 18)
                .padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let exercise {
                        ExerciseBlock(line: WorkoutText.exerciseLine(number: displayed + 1, count: exercises.count, key: exercise.exerciseKey),
                                      name: WorkoutText.exerciseName(key: exercise.exerciseKey),
                                      equipment: WorkoutText.equipment(key: exercise.exerciseKey),
                                      pillDeltaLb: pillDeltaLb, unit: unit, onName: { onDetail(exercise.exerciseKey) })
                            .padding(.top, 22)
                        VStack(spacing: 8) {
                            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                setRow(number: index + 1, set: set,
                                       row: rows.indices.contains(index) ? rows[index] : SetRowState(kind: .waiting, dimmed: false))
                            }
                        }
                        .padding(.top, 16)
                    }
                    if WorkoutFlow.showsHint(state, sheetOpen: sheetOpen) {
                        Text(WorkoutText.swipeHint)
                            .font(.system(size: 12)).foregroundStyle(Theme.mu)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 14)
                    }
                    if WorkoutFlow.isRatingPending(state), let rated = WorkoutFlow.focusSet(exercises: exercises, state: state) {
                        RPECard(onPick: { onRate(rated.id, $0) }, onSkip: { onSkipRating(rated.id) })
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // `.safeAreaInset(edge: .bottom)` ≈ a sticky footer the scroll content ends above. Its child switches between the
        // bar and the rest card, so the content always clears whichever is shown and the bar leaves the tree while resting.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let rest {
                RestOverlay(rest: rest, onAdd: onAddRest, onSkip: onSkipRest)
            } else {
                WorkoutBottomBar(hasNote: hasNote, nextEnabled: WorkoutFlow.nextExerciseEnabled(state),
                                 onNote: { if let exercise { onDetail(exercise.exerciseKey) } },
                                 onNext: { if let exercise { onNext(exercise.id) } })
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)
                .background(Theme.bg)
            }
        }
        // The card is 46 pt taller than the bar: animating the swap slides scrolled-to-bottom content instead of jumping it.
        .animation(.easeInOut(duration: 0.3), value: rest != nil)
        .background(Theme.bg.ignoresSafeArea())
    }

    /// Only the active row swipes; every other row is static. if/else, not a ternary: the branches are different View types.
    @ViewBuilder
    private func setRow(number: Int, set: WorkoutSetValue, row: SetRowState) -> some View {
        if row.kind == .active {
            SetSwipeRow(label: WorkoutText.setAccessibilityLabel(number: number, weightLb: set.weightLb, reps: set.reps, unit: unit),
                        onLog: { onLog(set.id) }, onAdjust: { onAdjust(set.id) }) {
                SetRow(number: number, set: set, row: row, unit: unit)
            }
        } else {
            SetRow(number: number, set: set, row: row, unit: unit)
        }
    }
}

/// "Exercise 1 of 5 · Back", the name with its ⓘ as one button that opens the detail sheet, the equipment line, and the
/// progression pill when the focus set is above the previous top. The name wraps (no line limit).
private struct ExerciseBlock: View {
    let line: String
    let name: String
    let equipment: String
    /// Pounds above the previous top; nil hides the pill.
    let pillDeltaLb: Double?
    let unit: WeightUnit
    let onName: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(line).font(.system(size: 12)).foregroundStyle(Theme.mu)
            Button(action: onName) {
                // Two styled spans joined into one wrapping Text (≈ two <span>s in one paragraph).
                (Text(name).font(.system(size: 24, weight: .bold)).tracking(-0.6).foregroundStyle(Theme.tx)
                    + Text(" ⓘ").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.mu))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)   // the ⓘ is decoration
            .accessibilityHint(ExerciseToolsText.nameHint)
            .padding(.top, 4)
            if !equipment.isEmpty {
                Text(equipment).font(.system(size: 12.5)).foregroundStyle(Theme.mu).padding(.top, 6)
            }
            if let pillDeltaLb {
                ProgressionPillView(text: ExerciseToolsText.pill(deltaLb: pillDeltaLb, unit: unit, name: name),
                                    spoken: ExerciseToolsText.pillSpoken(deltaLb: pillDeltaLb, unit: unit, name: name))
                    .padding(.top, 12)
            }
        }
    }
}

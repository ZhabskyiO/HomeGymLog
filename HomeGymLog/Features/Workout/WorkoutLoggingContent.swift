import SwiftUI

/// Lays out the logging screen from Engine values: header, the displayed exercise with its set rows, the hint and the
/// RPE card in a scroll view, and the pinned bottom bar. Every derived value comes from `WorkoutFlow`; taps and swipes
/// report row ids upward, never positions.
struct WorkoutLoggingContent: View {
    let info: WorkoutSessionInfo
    let startedAt: Date
    /// Sorted by `WorkoutFlow.sorted`.
    let exercises: [WorkoutExerciseValue]
    let state: WorkoutState
    let sheetOpen: Bool
    let unit: WeightUnit
    let onExit: () -> Void
    /// Receives the displayed exercise's id.
    let onNext: (UUID) -> Void
    /// Each receives a set id.
    let onLog: (UUID) -> Void
    let onAdjust: (UUID) -> Void
    let onRate: (UUID, Int) -> Void
    let onSkipRating: (UUID) -> Void

    var body: some View {
        let displayed = WorkoutFlow.displayedExercise(state) ?? 0
        let exercise: WorkoutExerciseValue? = exercises.indices.contains(displayed) ? exercises[displayed] : nil
        let rows = WorkoutFlow.rowStates(exercises: exercises, state: state, sheetOpen: sheetOpen)

        VStack(spacing: 0) {
            WorkoutHeader(name: info.name, startedAt: startedAt,
                          tones: WorkoutFlow.progress(exerciseCount: exercises.count, displayed: displayed), onExit: onExit)
                .padding(.horizontal, 18)
                .padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let exercise {
                        ExerciseBlock(line: WorkoutText.exerciseLine(number: displayed + 1, count: exercises.count, key: exercise.exerciseKey),
                                      name: WorkoutText.exerciseName(key: exercise.exerciseKey),
                                      equipment: WorkoutText.equipment(key: exercise.exerciseKey))
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
        // `.safeAreaInset(edge: .bottom)` ≈ a sticky footer the scroll content ends above.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WorkoutBottomBar(nextEnabled: WorkoutFlow.nextExerciseEnabled(state), onNext: {
                if let exercise { onNext(exercise.id) }
            })
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(Theme.bg)
        }
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

/// "Exercise 1 of 5 · Back", the name with an inert ⓘ, and the equipment line. The name wraps (no line limit).
private struct ExerciseBlock: View {
    let line: String
    let name: String
    let equipment: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(line).font(.system(size: 12)).foregroundStyle(Theme.mu)
            // Two styled spans joined into one wrapping Text (≈ two <span>s in one paragraph).
            (Text(name).font(.system(size: 24, weight: .bold)).tracking(-0.6).foregroundStyle(Theme.tx)
                + Text(" ⓘ").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.mu))
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
            if !equipment.isEmpty {
                Text(equipment).font(.system(size: 12.5)).foregroundStyle(Theme.mu).padding(.top, 6)
            }
        }
    }
}

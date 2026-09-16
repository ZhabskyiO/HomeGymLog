import SwiftUI

/// The selected day's session: its name, its status relative to today, one row per planned exercise, and "Start
/// workout" when the session can be started (today's or a missed pending session), plus the missed-day shift and skip
/// under it on a missed card.
/// Weights are the planned targets for every status, Completed included (logged weights are Progress, M4).
struct SessionCard: View {
    let session: SessionSummary
    let state: WeekStripState
    let unit: WeightUnit
    let calendar: Calendar
    let onInfo: (Exercise) -> Void
    /// True only for `.today` and `.missed` (`WorkoutFlow.isStartable`).
    let showsStart: Bool
    /// Reports the tap; `ProgramView` owns the rows and calls the shared start.
    let onStart: () -> Void
    /// "Do it today · shift program" on a missed card; `ProgramView` calls the shift writer.
    let onShift: () -> Void
    /// "Skip it · stay on schedule" on a missed card; `ProgramView` calls the skip writer.
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.name).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.tx)
                Spacer()
                Text(ProgramTabText.status(state, date: session.scheduledDate, calendar: calendar))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ProgramTabText.tone(for: state).color)
            }
            VStack(spacing: 9) {
                ForEach(Array(session.exercises.sorted { $0.order < $1.order }.enumerated()), id: \.element.exerciseKey) { index, planned in
                    ProgramExerciseRow(number: index + 1, planned: planned,
                                       scheme: ProgramTabText.rowScheme(sets: session.sets, reps: session.reps),
                                       unit: unit, onInfo: onInfo)
                }
            }
            .padding(.top, 12)
            if showsStart {
                StartWorkoutButton(action: onStart)
                    .padding(.top, 14)
            }
            if state == .missed {   // derived from state, no second flag beside showsStart (NB7)
                VStack(spacing: 8) {
                    SecondaryActionButton(title: MissedDayText.shift, action: onShift)
                    SecondaryActionButton(title: MissedDayText.skip, action: onSkip)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// One planned exercise. Wider than Home's `ExerciseRow` (which stays as it is): the name block carries an
/// equipment sub-line and wraps rather than shrinking.
struct ProgramExerciseRow: View {
    let number: Int
    let planned: PlannedExercise
    let scheme: String
    let unit: WeightUnit
    let onInfo: (Exercise) -> Void

    var body: some View {
        let exercise = ExerciseLibrary.exercise(for: planned.exerciseKey)
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 13.5)).monospacedDigit().foregroundStyle(Theme.mu)
                .frame(width: 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(exercise?.name ?? planned.exerciseKey)
                    .font(.system(size: 13.5, weight: .medium)).foregroundStyle(Theme.tx).lineLimit(2)
                if let exercise {
                    Text(exercise.equipment).font(.system(size: 11)).foregroundStyle(Theme.mu).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(scheme).font(.system(size: 13.5)).monospacedDigit().foregroundStyle(Theme.mu)
            Text("\(WeightDisplay.text(lb: planned.targetWeightLb, unit: unit)) \(unit.rawValue)")
                .font(.system(size: 13.5, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.tx)
                .frame(minWidth: 52, alignment: .trailing)
            if let exercise {
                Button { onInfo(exercise) } label: {
                    Text("i").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mu)
                        .frame(width: 24, height: 24).background(Theme.sf2, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About \(exercise.name)")
            }
        }
    }
}

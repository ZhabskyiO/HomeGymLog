import SwiftUI

/// Today's session: gradient header, exercise rows, and the Start workout button.
struct TodayCard: View {
    let session: SessionSummary
    let sessionLengthMinutes: Int
    let unit: WeightUnit
    let onInfo: (Exercise) -> Void
    /// Reports the tap; `HomeView` owns the rows and calls the shared start.
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY").font(.system(size: 12, weight: .bold)).tracking(0.5).foregroundStyle(Theme.accent)
                HStack(alignment: .firstTextBaseline) {
                    Text(session.name).font(.system(size: 24, weight: .bold)).tracking(-0.6).foregroundStyle(Theme.tx)
                    Spacer()
                    Text(HomeText.sessionMeta(exercises: session.exercises.count, sets: session.sets, reps: session.reps, minutes: sessionLengthMinutes))
                        .font(.system(size: 13)).foregroundStyle(Theme.mu)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(stops: [.init(color: Theme.accent.opacity(0.22), location: 0), .init(color: Theme.accent.opacity(0), location: 0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 9) {
                ForEach(Array(session.exercises.sorted { $0.order < $1.order }.enumerated()), id: \.element.exerciseKey) { index, planned in
                    ExerciseRow(number: index + 1, planned: planned, scheme: "\(session.sets)×\(session.reps)", unit: unit, onInfo: onInfo)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            StartWorkoutButton(action: onStart)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct ExerciseRow: View {
    let number: Int
    let planned: PlannedExercise
    let scheme: String
    let unit: WeightUnit
    let onInfo: (Exercise) -> Void

    var body: some View {
        let exercise = ExerciseLibrary.exercise(for: planned.exerciseKey)
        HStack(spacing: 8) {
            Text("\(number)").font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.mu).frame(width: 14, alignment: .leading)
            Text(exercise?.name ?? planned.exerciseKey).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Theme.tx)
                .lineLimit(1).minimumScaleFactor(0.8)   // shrink a long name a little instead of truncating it
            Spacer(minLength: 6)
            Text(scheme).font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.mu)
            Text("\(WeightDisplay.text(lb: planned.targetWeightLb, unit: unit)) \(unit.rawValue)")
                .font(.system(size: 13.5, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.tx)
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

import SwiftUI

/// Muscle, equipment, and form cues for one exercise. No images until real assets exist.
struct ExerciseInfoSheet: View {
    let exercise: Exercise
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(exercise.muscle.rawValue) · \(exercise.equipment)").font(.system(size: 12)).foregroundStyle(Theme.mu)
                Text(exercise.name).font(.system(size: 22, weight: .bold)).tracking(-0.5).foregroundStyle(Theme.tx).padding(.top, 2)
                Text("Form cues").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.tx).padding(.top, 16)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(exercise.cues.enumerated()), id: \.offset) { index, cue in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.accent)
                            Text(cue).font(.system(size: 14)).lineSpacing(3).foregroundStyle(Theme.tx)
                        }
                    }
                }
                .padding(.top, 8)
                Button(action: onDone) {
                    Text("Done").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.sf)
    }
}

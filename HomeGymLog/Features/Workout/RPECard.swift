import SwiftUI

/// "How hard was that set?" with a "Skip" text button and five equal RPE buttons, 6 easy … 10 max (spec 2.5).
/// "Skip" is the only way to dismiss it.
struct RPECard: View {
    let onPick: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(WorkoutText.rpeTitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tx)
                Spacer()
                Button(action: onSkip) {
                    Text("Skip").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mu)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip rating")
            }
            HStack(spacing: 6) {
                ForEach(6...10, id: \.self) { rpe in
                    Button { onPick(rpe) } label: {
                        VStack(spacing: 2) {
                            Text("\(rpe)").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.tx)
                            Text(WorkoutText.rpeLabel(rpe)).font(.system(size: 9.5)).foregroundStyle(Theme.mu)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.sf2, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent, lineWidth: 1.5))
    }
}

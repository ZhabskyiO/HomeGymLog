import SwiftUI

/// "Swap <name>" (spec 2.4): the subtitle, then one button per candidate in library order, or the empty-state line when every
/// exercise of the muscle is already in the workout. Its detent is a fixed height from the row count, never measured.
struct SwapSheet: View {
    let draft: SwapDraft
    let unit: WeightUnit
    let onPick: (SwapCandidate) -> Void

    /// The sheet's content height for this layout (researcher Q6 and addendum P2, identical on 17.5 and 26.5): 101.0 with
    /// the one-line empty state, else 77.33 + 64.33 per row (5 rows → 399.0). Recompute if the layout below changes.
    static func height(candidateCount n: Int) -> CGFloat {
        n == 0 ? 101.0 : 77.33 + 64.33 * CGFloat(n)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ExerciseToolsText.swapTitle(name: WorkoutText.exerciseName(key: draft.exerciseKey)))
                .font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.tx)
            Text(ExerciseToolsText.swapSubtitle)
                .font(.system(size: 13)).foregroundStyle(Theme.mu)
                .padding(.top, 2)
            if draft.candidates.isEmpty {
                // An unknown key has no muscle to name: title and subtitle only (not producible with library keys).
                if let muscle = ExerciseLibrary.exercise(for: draft.exerciseKey)?.muscle {
                    Text(ExerciseToolsText.emptySwap(muscle: muscle))
                        .font(.system(size: 13)).foregroundStyle(Theme.mu)
                        .padding(.top, 14)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(draft.candidates, id: \.exerciseKey) { candidate in
                        SwapCandidateRow(candidate: candidate, unit: unit, onPick: { onPick(candidate) })
                    }
                }
                .padding(.top, 14)
            }
        }
        .padding(.top, 22)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        // `.topLeading`, not `.top`: with no rows nothing stretches the column, and `.top` would centre the texts.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.sf)
    }
}

/// One candidate as a button: name over equipment on the left (wrapping), the weight on the right at its own width. Read by
/// VoiceOver as one label, "Goblet Squat, Dumbbell, 52.5 lb".
private struct SwapCandidateRow: View {
    let candidate: SwapCandidate
    let unit: WeightUnit
    let onPick: () -> Void

    var body: some View {
        let name = WorkoutText.exerciseName(key: candidate.exerciseKey)
        let equipment = WorkoutText.equipment(key: candidate.exerciseKey)
        Button(action: onPick) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx)
                    Text(equipment).font(.system(size: 12)).foregroundStyle(Theme.mu)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 12)
                Text(ExerciseToolsText.candidateWeight(lb: candidate.targetWeightLb, unit: unit))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tx)
                    .fixedSize()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Theme.sf2, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ExerciseToolsText.candidateAccessibilityLabel(name: name, equipment: equipment,
                                                                          lb: candidate.targetWeightLb, unit: unit))
    }
}

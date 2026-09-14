import SwiftUI

/// "Adjust set n": weight and reps steppers over a draft, then "Skip set" or "Save & log set" (spec 2.6). Weight moves
/// one equipment step in pounds whatever the display unit and stops at the equipment bounds; reps never go below 1.
/// Dismissing the sheet writes nothing.
struct AdjustSheet: View {
    let unit: WeightUnit
    let onSave: (AdjustDraft) -> Void
    let onSkip: (AdjustDraft) -> Void
    /// Seeded once from `initial` (≈ `useState(initialProp)`); the screen keys the sheet on the set id.
    @State private var draft: AdjustDraft

    init(initial: AdjustDraft, unit: WeightUnit, onSave: @escaping (AdjustDraft) -> Void, onSkip: @escaping (AdjustDraft) -> Void) {
        self.unit = unit
        self.onSave = onSave
        self.onSkip = onSkip
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Adjust set \(draft.setNumber)")
                .font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.tx)
            HStack(spacing: 10) {
                AdjustTile(caption: WorkoutText.weightCaption(unit: unit), value: WeightDisplay.text(lb: draft.weightLb, unit: unit),
                           onMinus: { stepWeight(by: -1) }, onPlus: { stepWeight(by: 1) })
                AdjustTile(caption: "Reps", value: "\(draft.reps)",
                           onMinus: { draft.reps = WorkoutFlow.decrementedReps(draft.reps) }, onPlus: { draft.reps += 1 })
            }
            .padding(.top, 16)
            GeometryReader { geometry in
                let unitWidth = max(0, geometry.size.width - 8) / 3   // flex 1 : 2
                HStack(spacing: 8) {
                    Button { onSkip(draft) } label: {
                        Text("Skip set").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx)
                            .frame(width: unitWidth, height: 48)
                            .background(Theme.sf2, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    Button { onSave(draft) } label: {
                        Text("Save & log set").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.white)
                            .frame(width: unitWidth * 2, height: 48)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 48)
            .padding(.top, 14)
        }
        .padding(.top, 22)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)   // the 251 pt detent plus the home-indicator inset gives the prototype's bottom space
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.sf)
    }

    /// One equipment step; nil at a bound (or an unknown exercise) leaves the weight unchanged.
    private func stepWeight(by steps: Int) {
        if let next = draft.kind?.stepped(lb: draft.weightLb, by: steps) {
            draft.weightLb = next
        }
    }
}

/// A caption over a − value + stepper, on `sf2` with the buttons on `sf`.
private struct AdjustTile: View {
    let caption: String
    let value: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(caption).font(.system(size: 11)).foregroundStyle(Theme.mu)
            HStack(spacing: 0) {
                StepperButton(symbol: "−", size: 36, fill: Theme.sf, action: onMinus)
                Text(value)
                    .font(.system(size: 26, weight: .bold)).monospacedDigit().foregroundStyle(Theme.tx)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                StepperButton(symbol: "+", size: 36, fill: Theme.sf, action: onPlus)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Theme.sf2, in: RoundedRectangle(cornerRadius: 14))
    }
}

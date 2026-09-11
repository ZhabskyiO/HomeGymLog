import SwiftUI

/// A5: one row per exercise the program will use, stepped by equipment.
struct StartingWeightsStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTitle(title: "Starting weights", subtitle: "What you can lift for a clean 10 reps. Everything else is inferred.", bottomSpacing: 18)
            VStack(spacing: 8) {
                ForEach(draft.startingWeightRows) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tx)
                            Text(row.equipment).font(.system(size: 11.5)).foregroundStyle(Theme.mu)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            StepperButton(symbol: "−", size: 32) { draft.adjustStartingWeight(key: row.key, steps: -1) }
                            (Text(WeightDisplay.text(lb: row.weightLb, unit: draft.units)).font(.system(size: 18, weight: .bold))
                             + Text(" \(draft.units.rawValue)").font(.system(size: 11, weight: .medium)).foregroundColor(Theme.mu))
                                .monospacedDigit()
                                .foregroundStyle(Theme.tx)
                                .frame(minWidth: 52)
                            StepperButton(symbol: "+", size: 32) { draft.adjustStartingWeight(key: row.key, steps: 1) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.sf, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

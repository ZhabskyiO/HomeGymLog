import SwiftUI

/// A4: body weight stepper, experience, session length.
struct AboutYouStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTitle(title: "About you", subtitle: "Used to size sessions and starting loads.")
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Body weight").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx)
                        SegmentedPicker(options: [(WeightUnit.lb, "lb"), (WeightUnit.kg, "kg")], selection: $draft.bodyWeightUnit,
                                        style: .pill, container: Theme.sf2)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        StepperButton(symbol: "−", size: 34) { draft.adjustBodyWeight(steps: -1) }
                        Text(WeightDisplay.wholeText(lb: draft.bodyWeightLb, unit: draft.bodyWeightUnit))
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.tx)
                            .frame(minWidth: 44)
                        StepperButton(symbol: "+", size: 34) { draft.adjustBodyWeight(steps: 1) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.sf, in: RoundedRectangle(cornerRadius: 14))

                card(title: "Experience", caption: nil) {
                    SegmentedPicker(options: Experience.allCases.map { ($0, $0.rawValue) }, selection: $draft.experience, style: .chip)
                }
                card(title: "Session length", caption: "\(draft.exerciseCount) exercises per session") {
                    SegmentedPicker(options: ProgramGenerator.allowedSessionLengths.sorted().map { ($0, "\($0)m") },
                                    selection: $draft.sessionLengthMinutes, style: .chip)
                }
            }
        }
    }

    private func card<Content: View>(title: String, caption: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx)
                .padding(.bottom, caption == nil ? 10 : 2)
            if let caption {
                Text(caption).font(.system(size: 12)).foregroundStyle(Theme.mu).padding(.bottom, 10)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 14))
    }
}

import SwiftUI

/// A2: four option cards with a proportional phase bar each, plus a legend.
struct LengthStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTitle(title: "How long?", subtitle: "Longer programs get longer Build and Peak phases.")
            VStack(spacing: 8) {
                ForEach(ProgramGenerator.allowedMonths.sorted(), id: \.self) { months in
                    let weeks = PhaseSplit.weeks(months: months)
                    let isSelected = draft.months == months
                    Button {
                        draft.months = months
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(months == 1 ? "1 month" : "\(months) months")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.tx)
                                Spacer()
                                Text("\(weeks) weeks")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.mu)
                            }
                            PhaseBar(ranges: PhaseSplit.phaseRanges(weeks: weeks), height: 5)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            HStack(spacing: 14) {
                ForEach(Phase.allCases, id: \.self) { phase in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.phaseColor(phase)).frame(width: 8, height: 8)
                        Text(phase.rawValue).font(.system(size: 11)).foregroundStyle(Theme.mu)
                    }
                }
            }
            .padding(.top, 14)
        }
    }
}

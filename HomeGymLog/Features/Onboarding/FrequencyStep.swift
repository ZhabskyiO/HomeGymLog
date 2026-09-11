import SwiftUI

/// A3: frequency segments, the split card, and the seven day buttons.
struct FrequencyStep: View {
    @Bindable var draft: OnboardingDraft
    private let dayLabels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTitle(title: "How often?", subtitle: "The split is chosen for you from frequency.")
            SegmentedPicker(
                options: ProgramGenerator.allowedFrequencies.sorted().map { ($0, "\($0) days") },
                selection: Binding(get: { draft.frequency }, set: { draft.selectFrequency($0) }),
                style: .wide
            )
            if let info = SplitPlans.info(frequency: draft.frequency) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Split").font(.system(size: 12)).foregroundStyle(Theme.mu).padding(.bottom, 6)
                    Text(info.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.tx)
                    Text(info.description).font(.system(size: 13)).lineSpacing(2).foregroundStyle(Theme.mu).padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.sf, in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 14)
            }
            HStack(spacing: 0) {
                Text("Training days").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tx)
                Text(" · pick \(draft.frequency)").font(.system(size: 13)).foregroundStyle(Theme.mu)
            }
            .padding(.top, 22)
            .padding(.bottom, 10)
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { day in
                    let isOn = draft.days.contains(day)
                    Button {
                        draft.toggleDay(day)
                    } label: {
                        Text(dayLabels[day])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isOn ? Color.white : Theme.tx)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isOn ? Theme.accent : Theme.sf, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
        }
    }
}

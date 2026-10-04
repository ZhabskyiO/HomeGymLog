import SwiftUI

/// A1: tile, headline, equipment rows, units toggle. Bottom-aligned by the flow root.
struct WelcomeStep: View {
    @Bindable var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The app icon artwork; `decorative` keeps it out of VoiceOver (≈ `alt=""` with `aria-hidden`).
            Image(decorative: "WelcomeTile").resizable().scaledToFit().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Your gym.\nYour program.")
                .font(.system(size: 38, weight: .bold))
                .tracking(-1.4)
                .lineSpacing(0)
                .foregroundStyle(Theme.tx)
                .padding(.top, 22)
                .padding(.bottom, 10)
            Text("HomeGymLog builds a phased strength program around exactly what you own — then tracks every set.")
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(Theme.mu)
                .padding(.bottom, 26)
            VStack(spacing: 8) {
                equipmentRow("Dumbbells", detail: "up to \(WeightDisplay.text(lb: 52.5, unit: draft.units)) \(draft.units.rawValue)")
                equipmentRow("Adjustable bench", detail: "flat · incline")
                equipmentRow("Marcy home gym", detail: "\(WeightDisplay.text(lb: 150, unit: draft.units)) \(draft.units.rawValue) stack")
            }
            HStack {
                Text("Units")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tx)
                Spacer()
                SegmentedPicker(options: [(WeightUnit.lb, "lb"), (WeightUnit.kg, "kg")], selection: $draft.units, style: .pill)
            }
            .padding(.top, 14)
        }
        .padding(.bottom, 28)
    }

    private func equipmentRow(_ title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.accent).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.tx)
            Spacer()
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.mu)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 12))
    }
}

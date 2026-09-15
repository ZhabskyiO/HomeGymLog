import SwiftUI

/// The green "↑ +10 lb from your last Lat Pulldown" pill under the exercise name (spec 2.1): self-sized to its text, 12 pt
/// semibold `success` on `success` at 14 %. VoiceOver reads it as one static text, `spoken` ("Up 10 lb from your last …"),
/// so the arrow is never announced on its own (≈ one element with an `aria-label` whose children are hidden).
struct ProgressionPillView: View {
    let text: String
    let spoken: String

    var body: some View {
        HStack(spacing: 6) {
            Text(ExerciseToolsText.pillArrow)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Theme.success)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Theme.success.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isStaticText)
    }
}

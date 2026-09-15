import SwiftUI

/// The pinned bar: "Add note" / "Notes ·" (opens the detail sheet) and "Next exercise ›", disabled at 40 % while a rating
/// is pending.
struct WorkoutBottomBar: View {
    /// True when the displayed exercise has a note with non-empty text.
    let hasNote: Bool
    let nextEnabled: Bool
    let onNote: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onNote) { BarLabel(title: ExerciseToolsText.noteLabel(hasNote: hasNote)) }
                .buttonStyle(.plain)
                // The visible "Notes ·" is read as "Notes", so Voice Control's "Tap Notes" matches.
                .accessibilityLabel(ExerciseToolsText.noteAccessibilityLabel(hasNote: hasNote))
                .accessibilityHint(hasNote ? ExerciseToolsText.noteAccessibilityHint : "")
            Button(action: onNext) { BarLabel(title: "Next exercise ›") }
                .buttonStyle(.plain)
                .disabled(!nextEnabled)
                .opacity(nextEnabled ? 1 : 0.4)
        }
    }
}

private struct BarLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tx)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Theme.sf, in: RoundedRectangle(cornerRadius: 12))
    }
}

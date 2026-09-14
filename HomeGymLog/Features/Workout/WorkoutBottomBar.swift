import SwiftUI

/// The pinned bar: "Add note" (inert until m3-exercise-tools, so plain text rather than a button) and
/// "Next exercise ›", disabled at 40 % while a rating is pending.
struct WorkoutBottomBar: View {
    let nextEnabled: Bool
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            BarLabel(title: "Add note")
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

import SwiftUI

/// The prototype's missed-session card (spec 2.1): kicker, title, body, the accent shift button and the secondary skip
/// button on `sf`, 28 pt top corners, its 64 pt bottom padding reaching the screen edge (20 pt more than the prototype's 44:
/// a tap on the hidden tab pill just below "Skip it" performed Skip through the button's touch tolerance; user decision
/// 2026-09-15). A downward drag moves the card with the finger and dismisses at ≥ 80 pt; a shorter drag springs back.
/// Reports every action upward; the host writes.
struct MissedSessionCard: View {
    let title: String
    let onShift: () -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void
    /// The finger's downward travel while dragging, never above the rest position (≈ `useState` for a drag offset).
    @State private var dragY: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(MissedDayText.kicker)
                .font(.system(size: 12, weight: .bold)).tracking(0.5).foregroundStyle(Theme.warning)
            Text(title)
                .font(.system(size: 22, weight: .bold)).tracking(-0.4).foregroundStyle(Theme.tx)
                .padding(.top, 6)
            Text(MissedDayText.body)
                .font(.system(size: 14)).lineSpacing(3).foregroundStyle(Theme.mu)
                .padding(.top, 6)
            VStack(spacing: 8) {
                Button(action: onShift) {
                    Text(MissedDayText.shift)
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                SecondaryActionButton(title: MissedDayText.skip, action: onSkip)
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 64)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Only the top corners round (≈ `border-top-left-radius` / `border-top-right-radius`).
        .background(Theme.sf, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .ignoresSafeArea(edges: .bottom)
        .offset(y: dragY)
        // After `.offset`: inside it the gesture measures against the moving card and never reaches 80 pt. High priority
        // cancels a button once a drag starting on it moves 20 pt, so a drag never also taps it; plain taps still reach the
        // buttons (researcher addendum P2) (≈ a capture-phase pointer handler that claims the gesture from child buttons).
        .highPriorityGesture(drag)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { dragY = max(0, $0.translation.height) }
            .onEnded { value in
                if value.translation.height >= 80 {
                    onDismiss()
                    dragY = 0   // a card that re-renders for another session (or re-mounts) starts at rest
                } else {
                    withAnimation(.spring()) { dragY = 0 }
                }
            }
    }
}

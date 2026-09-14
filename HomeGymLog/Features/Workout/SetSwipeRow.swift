import SwiftUI

/// Wraps the active set row with the swipe: drag right past 90 pt to log, left past 90 pt to adjust, clamped to
/// ±140 pt, springing back either way. Behind the row a `success` "✓ Logged" or `warning` "Adjust / skip" track fades
/// in with the distance. `DragGesture` ≈ pointer events on an element with `touch-action: pan-y`; the 20 pt minimum
/// keeps a vertical drag that starts on the row scrolling on iOS 18+ (below 15 the row swallows it).
/// VoiceOver gets the same two actions as named custom actions (≈ ARIA custom actions).
struct SetSwipeRow<Content: View>: View {
    /// "Set 1, 110 lb × 12 reps"
    let label: String
    let onLog: () -> Void
    let onAdjust: () -> Void
    /// The row itself (≈ `children`).
    @ViewBuilder let content: () -> Content
    /// nil before the first drag, 0 after a spring-back; drag state lives here, never above.
    @State private var dragX: CGFloat?
    /// Nil except a DEBUG `-seed wo-swipe` screenshot, which draws the row at a fixed offset.
    @Environment(\.workoutDragPreview) private var preview

    var body: some View {
        let x = dragX ?? preview ?? 0
        ZStack {
            HStack {
                Text("✓ Logged").opacity(x > 0 ? min(1, x / 90) : 0)
                Spacer()
                Text("Adjust / skip").opacity(x < 0 ? min(1, -x / 90) : 0)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(x > 0 ? Theme.success : (x < 0 ? Theme.warning : Color.clear))
            content().offset(x: x)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .gesture(DragGesture(minimumDistance: 20)
            .onChanged { dragX = min(140, max(-140, $0.translation.width)) }
            .onEnded { value in
                let x = min(140, max(-140, value.translation.width))
                if x > 90 {
                    onLog()
                } else if x < -90 {
                    onAdjust()
                }
                withAnimation(.spring(duration: 0.25)) { dragX = 0 }
            })
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAction(named: "Log set", onLog)
        .accessibilityAction(named: "Adjust set", onAdjust)
    }
}

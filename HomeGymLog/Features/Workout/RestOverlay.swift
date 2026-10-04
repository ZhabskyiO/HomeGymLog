import SwiftUI

/// The rest card that replaces the bottom bar while resting (B5): the ring, "Rest", the countdown, "Next: …", "+30s" and
/// "Skip". It ticks on its own 1 Hz timeline anchored at the rest start (≈ a `setInterval` the framework owns) and reads
/// the app clock, so a frozen seed clock draws the same frame every time. Its background runs under the bottom safe area.
/// It sits inside `WorkoutView`'s own 1 Hz timeline on purpose (spec 4.4): that outer timeline only decides `rest` (card
/// or bar, and the end effects); this inner one draws the label and the ring.
struct RestOverlay: View {
    let rest: RestDisplay
    let onAdd: () -> Void
    let onSkip: () -> Void
    @Environment(\.appClock) private var clock

    var body: some View {
        TimelineView(.periodic(from: rest.startedAt, by: 1)) { _ in
            let now = clock.now()
            let seconds = RestTimer.remainingSeconds(endsAt: rest.endsAt, now: now)
            HStack(spacing: 18) {
                RestRing(remainingFraction: RestTimer.remainingFraction(startedAt: rest.startedAt, endsAt: rest.endsAt, now: now))
                VStack(alignment: .leading, spacing: 0) {
                    // "Rest" and the countdown are one accessibility element (children ignored, ≈ one `role="timer"`
                    // node with an aria-label): its value is read on focus, never announced per second.
                    VStack(alignment: .leading, spacing: 0) {
                        Text(RestText.title)
                            .font(.system(size: 12)).foregroundStyle(Theme.mu)
                        Text(RestText.clock(seconds: seconds))
                            .font(.system(size: 34, weight: .bold)).tracking(-1).monospacedDigit().foregroundStyle(Theme.tx)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(RestText.title)
                    .accessibilityValue(RestText.spoken(seconds: seconds))
                    .accessibilityAddTraits(.updatesFrequently)
                    Text(RestText.nextLine(rest.next))
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mu)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 6) {
                    Button(action: onAdd) {
                        RestButtonLabel(title: RestText.addLabel, weight: .semibold, foreground: Theme.tx, background: Theme.sf2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(RestText.addAccessibility)
                    Button(action: onSkip) {
                        RestButtonLabel(title: RestText.skipLabel, weight: .bold, foreground: .white, background: Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(RestText.skipAccessibility)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                    .fill(Theme.sf)
                    .shadow(color: .black.opacity(0.4), radius: 25, y: -20)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

/// "+30s" / "Skip": 38 pt high, 14 pt side padding, radius 10.
private struct RestButtonLabel: View {
    let title: String
    let weight: Font.Weight
    let foreground: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: weight)).foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// An 84 pt box holding a 72 pt ring: an `sf2` track and an accent arc for the remaining share, clockwise from
/// 12 o'clock with round caps. The arc eases linearly over each 1 s tick, like the prototype's stroke transition.
private struct RestRing: View {
    let remainingFraction: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.sf2, lineWidth: 7)
            Circle()
                .trim(from: 0, to: remainingFraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remainingFraction)
        }
        .frame(width: 72, height: 72)
        .frame(width: 84, height: 84)
        .accessibilityHidden(true)
    }
}

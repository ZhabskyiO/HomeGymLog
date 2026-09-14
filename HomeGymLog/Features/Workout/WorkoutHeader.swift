import SwiftUI

/// "Exit" pill, the session name over the elapsed clock, an inert "Swap" pill, and one progress segment per exercise.
struct WorkoutHeader: View {
    let name: String
    let startedAt: Date
    let tones: [ProgressTone]
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                HStack {
                    Button(action: onExit) { HeaderPill(title: "Exit") }
                        .buttonStyle(.plain)
                    Spacer()
                    HeaderPill(title: "Swap")   // inert until m3-exercise-tools: plain text, not a button
                }
                VStack(spacing: 1) {
                    Text(name).font(.system(size: 12)).foregroundStyle(Theme.mu)
                    WorkoutElapsedClock(startedAt: startedAt)
                }
            }
            ProgressSegments(tones: tones)
        }
    }
}

private struct HeaderPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tx)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Theme.sf, in: RoundedRectangle(cornerRadius: 17))
    }
}

/// "mm:ss" since `startedAt`, from the app clock (a frozen seed clock renders a fixed "12:34").
/// `TimelineView(.periodic)` ≈ a `setInterval` the framework owns and clears on unmount.
struct WorkoutElapsedClock: View {
    let startedAt: Date
    @Environment(\.appClock) private var clock

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { _ in
            Text(WorkoutText.clock(seconds: WorkoutSummary.elapsedSeconds(from: startedAt, to: clock.now())))
                .font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(Theme.tx)
        }
    }
}

/// Equal-width 3 pt bars, 4 pt apart: `success` before the displayed exercise, accent for it, `sf2` after.
struct ProgressSegments: View {
    let tones: [ProgressTone]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tones.enumerated()), id: \.offset) { _, tone in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(tone))
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
            }
        }
    }

    private func color(_ tone: ProgressTone) -> Color {
        switch tone {
        case .passed: return Theme.success
        case .current: return Theme.accent
        case .upcoming: return Theme.sf2
        }
    }
}

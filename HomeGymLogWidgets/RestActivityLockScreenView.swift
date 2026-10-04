import AppIntents
import SwiftUI
import WidgetKit

/// The Lock Screen (and no-Dynamic-Island banner) presentation, mirroring the in-app rest card (spec §2.2): ring, "Rest",
/// the counting `m:ss`, the "Next:" line, "+30s" and "Skip". Once the end passed while the app was away (`isStale`), the
/// countdown becomes "Rest over" and the ring and buttons hide until the app ends the activity.
struct RestActivityLockScreenView: View {
    let state: RestActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 16) {
            if !isStale { RestActivityRing(interval: state.interval) }
            VStack(alignment: .leading, spacing: 0) {
                Text(RestActivityText.title)
                    .font(.system(size: 12)).foregroundStyle(Color("mu"))
                if isStale {
                    Text(RestActivityText.restOver)
                        .font(.system(size: 34, weight: .bold)).tracking(-1).foregroundStyle(Color("tx"))
                } else {
                    Text(timerInterval: state.interval, pauseTime: nil, countsDown: true, showsHours: false)
                        .font(.system(size: 34, weight: .bold)).tracking(-1).monospacedDigit().foregroundStyle(Color("tx"))
                        .frame(width: 110, alignment: .leading)
                }
                Text(state.nextText)
                    .font(.system(size: 12.5)).foregroundStyle(Color("mu"))
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isStale { RestActivityButtons(vertical: true) }
        }
        .padding(16)
    }
}

/// The system-driven countdown ring, 44 × 44, accent tint. The system circular style rather than the card's 7 pt arc: a
/// custom trim cannot animate without updates (a listed deviation, researcher P5).
struct RestActivityRing: View {
    let interval: ClosedRange<Date>

    var body: some View {
        ProgressView(timerInterval: interval, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
            .progressViewStyle(.circular)
            .tint(Color("AccentColor"))
            .frame(width: 44, height: 44)
    }
}

/// "+30s" and "Skip" as App Intent buttons (≈ a form posting to a server action): the system runs the intent in the
/// app's process, which writes the rest and re-syncs this activity. Allowed only on the Lock Screen and in the expanded
/// island (spec AC-20); the file's only two `Button(intent:)`.
struct RestActivityButtons: View {
    let vertical: Bool

    var body: some View {
        if vertical {
            VStack(spacing: 6) { buttons }
        } else {
            HStack(spacing: 8) { buttons }
        }
    }

    @ViewBuilder private var buttons: some View {
        Button(intent: AddRestTimeIntent()) {
            Text(RestActivityText.addLabel)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color("tx"))
                .frame(minWidth: 56, minHeight: 38)
                .background(Color("sf2"), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(RestActivityText.addAccessibility)
        Button(intent: SkipRestIntent()) {
            Text(RestActivityText.skipLabel)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .frame(minWidth: 56, minHeight: 38)
                .background(Color("AccentColor"), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(RestActivityText.skipAccessibility)
    }
}

import SwiftUI

/// The session summary (spec 2.9): kicker, name, the day trained with the stored week and phase, volume and duration
/// tiles, muscles worked, and the records card once the PR baseline exists. "Done" is pinned at the bottom and runs
/// the root's handler, which switches to Home before finishing the log.
struct WorkoutSummaryView: View {
    let info: WorkoutSessionInfo
    let startedAt: Date
    let summary: WorkoutSummaryValue
    /// False until the PR baseline is built; neither records card shows before then, so "No new records" never flashes.
    let recordsReady: Bool
    let unit: WeightUnit
    let calendar: Calendar
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(WorkoutText.kicker)
                    .font(.system(size: 12, weight: .bold)).tracking(0.6).foregroundStyle(Theme.accent)
                Text(info.name)
                    .font(.system(size: 34, weight: .bold)).tracking(-1.2).foregroundStyle(Theme.tx)
                    .padding(.top, 6)
                Text(WorkoutText.meta(startedAt: startedAt, info: info, calendar: calendar))
                    .font(.system(size: 14)).foregroundStyle(Theme.mu)
                SummaryTiles(volume: WorkoutText.volume(lb: summary.volumeLb, unit: unit), volumeCaption: WorkoutText.volumeCaption(unit: unit),
                             duration: WorkoutText.clock(seconds: summary.durationSeconds))
                    .padding(.top, 22)
                MusclesCard(muscles: summary.muscles)
                    .padding(.top, 10)
                if recordsReady {
                    if summary.records.isEmpty {
                        NoRecordsCard().padding(.top, 10)
                    } else {
                        RecordsCard(records: summary.records, unit: unit).padding(.top, 10)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // `.safeAreaInset(edge: .bottom)` ≈ a sticky footer the scroll content ends above.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .background(Theme.bg)
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}

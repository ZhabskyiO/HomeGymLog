import SwiftUI

/// Lays out the Progress tab from already-mapped values; every derived number is computed once per render. A chip tap
/// reports its key upward; nothing here writes.
struct ProgressContent: View {
    let sessions: [ProgressSession]
    let keys: [String]
    /// The effective key (a listed chip), nil only when no session plans anything.
    let selectedKey: String?
    /// Tops for `selectedKey` only (`ProgressStats.heldTops`); empty while its fetch is pending.
    let tops: [ProgressTop]
    /// True for the frame between a chip change and its fetch: the card draws the rules only, with no fallback and no empty line.
    let isLoading: Bool
    let today: Date
    let unit: WeightUnit
    let calendar: Calendar
    let onSelect: (String) -> Void

    var body: some View {
        let points = ProgressStats.points(tops: tops)
        let name = ProgressText.chipLabel(key: selectedKey ?? "")

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(ProgressText.title)
                    .font(.system(size: 28, weight: .bold)).tracking(-0.8).foregroundStyle(Theme.tx)
                ExerciseChipRow(keys: keys, selectedKey: selectedKey, onSelect: onSelect)
                    .padding(.horizontal, -18)   // bleed to the screen edges; the row re-adds the 18 pt inset itself
                    .padding(.top, 16)
                ProgressChartCard(name: name, points: points,
                                  bestLb: ProgressStats.bestLb(points: points),
                                  sinceStartLb: ProgressStats.sinceStartLb(points: points),
                                  fallbackLb: fallback(points: points),
                                  geometry: ProgressStats.chartGeometry(weights: points.map(\.topWeightLb)),
                                  isLoading: isLoading, unit: unit, calendar: calendar)
                    .padding(.top, 14)
                MonthCalendar(month: ProgressStats.month(sessions: sessions, today: today, calendar: calendar), calendar: calendar)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The planned Best shown with no points (spec 5.4); never while the key's fetch is pending.
    private func fallback(points: [ProgressTop]) -> Double? {
        guard points.isEmpty, !isLoading, let selectedKey else { return nil }
        return ProgressStats.plannedFallbackLb(key: selectedKey, sessions: sessions)
    }
}

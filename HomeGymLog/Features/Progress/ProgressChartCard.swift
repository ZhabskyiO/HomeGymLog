import SwiftUI

/// The chart card: Best and Since start, the top-weight line, the first and last day, and the empty-state line.
struct ProgressChartCard: View {
    let name: String
    let points: [ProgressTop]
    let bestLb: Double?
    let sinceStartLb: Double?
    /// The planned target shown as Best when there are no points; nil while loading or when nothing plans the key.
    let fallbackLb: Double?
    let geometry: ChartGeometry
    let isLoading: Bool
    let unit: WeightUnit
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            TopWeightChart(points: points, geometry: geometry, unit: unit, calendar: calendar, summary: summary)
                .padding(.top, 10)
            HStack {
                if let first = points.first, let last = points.last {
                    Text(ProgressText.pointLabel(date: first.scheduledDate, calendar: calendar))
                    Spacer()
                    Text(ProgressText.pointLabel(date: last.scheduledDate, calendar: calendar))
                }
            }
            .font(.system(size: 11)).foregroundStyle(Theme.mu)
            if points.isEmpty && !isLoading {
                Text(ProgressText.empty)
                    .font(.system(size: 13)).foregroundStyle(Theme.mu)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text(ProgressText.best).font(.system(size: 12)).foregroundStyle(Theme.mu)
                bestValue
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(ProgressText.sinceStart).font(.system(size: 12)).foregroundStyle(Theme.mu)
                Text(sinceStartLb.map { ProgressText.delta(lb: $0, unit: unit) } ?? ProgressText.none)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ProgressText.deltaTone(lb: sinceStartLb).color)
            }
        }
    }

    @ViewBuilder
    private var bestValue: some View {
        if let lb = bestLb ?? fallbackLb {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(ProgressText.weight(lb: lb, unit: unit))
                    .font(.system(size: 26, weight: .bold)).tracking(-0.5).foregroundStyle(Theme.tx)
                Text(unit.rawValue)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.mu)
            }
            .accessibilityElement(children: .combine)
        } else {
            Text(ProgressText.none)
                .font(.system(size: 26, weight: .bold)).tracking(-0.5).foregroundStyle(Theme.mu)
        }
    }

    private var summary: String {
        let weights = points.map(\.topWeightLb)
        guard let low = weights.min(), let high = weights.max() else { return ProgressText.chartEmptySummary(name: name) }
        return ProgressText.chartSummary(name: name, count: points.count, minLb: low, maxLb: high, unit: unit)
    }
}

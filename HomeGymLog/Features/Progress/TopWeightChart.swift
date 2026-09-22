import SwiftUI
import Charts

/// The prototype's top-weight line in Swift Charts (researcher recipe, 17.5 and 26.5): points plotted by **position**, three
/// `RuleMark` grid lines, both axes and the legend hidden, and explicit domains from `ProgressStats.chartGeometry` so the plot
/// reproduces the SVG (rules at 110 / 60 / 10 of 120). `Chart { }` ≈ Recharts' `<LineChart>`; `chartYScale(domain:)` ≈ d3's
/// `scaleLinear().domain()`. Line and rules are hidden from accessibility, or each dot's label is swallowed ("2 values").
struct TopWeightChart: View {
    let points: [ProgressTop]
    let geometry: ChartGeometry
    let unit: WeightUnit
    let calendar: Calendar
    /// The container's spoken label (`ProgressText.chartSummary` / `chartEmptySummary`).
    let summary: String

    var body: some View {
        Chart {
            // Identity = position: session indexes repeat across programs.
            ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                LineMark(x: .value("Session", i), y: .value("Top weight", p.topWeightLb))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                PointMark(x: .value("Session", i), y: .value("Top weight", p.topWeightLb))
                    .symbol {
                        Circle().fill(Theme.sf)
                            .overlay(Circle().stroke(Theme.accent, lineWidth: 2.5))
                            .frame(width: 8, height: 8)
                    }
                    .accessibilityLabel(Text(ProgressText.pointLabel(date: p.scheduledDate, calendar: calendar)))
                    .accessibilityValue(Text(ProgressText.pointValue(lb: p.topWeightLb, unit: unit)))
            }
            RuleMark(y: .value("Baseline", geometry.baselineLb))
                .lineStyle(StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.bd).accessibilityHidden(true)
            RuleMark(y: .value("Mid", geometry.midLb))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4])).foregroundStyle(Theme.bd).accessibilityHidden(true)
            RuleMark(y: .value("Top", geometry.topLb))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4])).foregroundStyle(Theme.bd).accessibilityHidden(true)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: geometry.xDomain)
        .chartYScale(domain: geometry.yDomain)
        .frame(height: 120)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(summary)
    }
}

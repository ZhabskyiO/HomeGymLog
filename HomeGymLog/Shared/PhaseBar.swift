import SwiftUI

/// Proportional phase bar: one segment per non-empty phase, width = weeks in that phase.
struct PhaseBar: View {
    let ranges: [PhaseRange]
    var height: CGFloat = 5
    private let gap: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let totalWeeks = max(1, ranges.reduce(0) { $0 + $1.lastWeek - $1.firstWeek + 1 })
            let unit = (geometry.size.width - gap * CGFloat(max(0, ranges.count - 1))) / CGFloat(totalWeeks)
            HStack(spacing: gap) {
                ForEach(ranges, id: \.firstWeek) { range in
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Theme.phaseColor(range.phase))
                        .frame(width: max(0, unit * CGFloat(range.lastWeek - range.firstWeek + 1)), height: height)
                }
            }
        }
        .frame(height: height)
    }
}

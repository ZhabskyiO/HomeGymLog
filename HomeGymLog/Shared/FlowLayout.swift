import SwiftUI

/// Places children left to right and wraps to a new row when the next one would pass the proposed width, with the
/// same `spacing` between items and between rows. `Layout` ≈ a CSS `display: flex; flex-wrap: wrap; gap: 6px` box.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    /// Subview indexes per row plus each row's height, for a given maximum width.
    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [(indexes: [Int], height: CGFloat, width: CGFloat)] {
        var rows: [(indexes: [Int], height: CGFloat, width: CGFloat)] = []
        var current: [Int] = []
        var x: CGFloat = 0
        var height: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.isEmpty ? size.width : x + spacing + size.width
            if !current.isEmpty && needed > maxWidth {
                rows.append((current, height, x))
                current = [index]
                x = size.width
                height = size.height
            } else {
                current.append(index)
                x = needed
                height = max(height, size.height)
            }
        }
        if !current.isEmpty { rows.append((current, height, x)) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: maxWidth.isFinite ? maxWidth : widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indexes {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
}

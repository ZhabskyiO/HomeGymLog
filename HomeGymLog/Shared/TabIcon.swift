import SwiftUI

/// The four tab icons, drawn from the prototype's 22×22 SVG paths. Tinted by the caller's foregroundStyle.
struct TabIcon: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            filled.fill()
            stroked.stroke(lineWidth: 2)
        }
        .frame(width: 22, height: 22)
    }

    private func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r))
    }

    private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
    }

    /// Shapes drawn filled.
    private var filled: Path {
        var path = Path()
        switch tab {
        case .home:
            path.addPath(circle(11, 11, 3.5))
        case .program:
            path.addPath(rounded(3, 3, 7, 7, 2))
            path.addPath(rounded(12, 3, 7, 7, 2))
            path.addPath(rounded(3, 12, 7, 7, 2))
        case .progress:
            path.addPath(rounded(3, 12, 4, 7, 1.5))
            path.addPath(rounded(9, 7, 4, 12, 1.5))
            path.addPath(rounded(15, 3, 4, 16, 1.5))
        case .settings:
            path.addPath(rounded(3, 6, 16, 2.5, 1.25))
            path.addPath(circle(14, 7.25, 3))
            path.addPath(rounded(3, 14, 16, 2.5, 1.25))
            path.addPath(circle(8, 15.25, 3))
        }
        return path
    }

    /// Shapes drawn as a 2 pt outline.
    private var stroked: Path {
        var path = Path()
        switch tab {
        case .home:
            path.addPath(circle(11, 11, 8))
        case .program:
            path.addPath(rounded(12, 12, 7, 7, 2))
        case .progress, .settings:
            break
        }
        return path
    }
}

#Preview {
    HStack(spacing: 24) {
        ForEach(AppTab.allCases) { TabIcon(tab: $0) }
    }
    .foregroundStyle(Theme.accent)
    .padding()
    .background(Theme.sf)
}

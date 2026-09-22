import Foundation
import Testing
@testable import HomeGymLog

/// `ProgressStats.chartGeometry` against the prototype's SVG pixels (spec 2.2, 5.8): a single point centred on the middle rule,
/// and for any n ≥ 2 the first and last dots 10 pt in from a 320-pt width with the rules at 110 / 60 / 10 of 120.
@Suite struct ChartGeometryEdgeTests {
    private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    /// Pixel x of a position in a 320-pt plot.
    private func px(_ x: Double, _ domain: ClosedRange<Double>) -> Double {
        (x - domain.lowerBound) / (domain.upperBound - domain.lowerBound) * 320
    }

    /// Pixel y (0 at the top) of a weight in a 120-pt plot.
    private func py(_ lb: Double, _ domain: ClosedRange<Double>) -> Double {
        (domain.upperBound - lb) / (domain.upperBound - domain.lowerBound) * 120
    }

    @Test("a single point sits at x 160 on the middle rule at y 60, whatever its weight", arguments: [0.0, 5, 40, 52.5, 150])
    func singlePoint(weight: Double) {
        let g = ProgressStats.chartGeometry(weights: [weight])
        #expect(near(px(0, g.xDomain), 160))
        #expect(near(g.midLb, weight))
        #expect(near(py(weight, g.yDomain), 60))
        #expect(near(py(g.baselineLb, g.yDomain), 110))
        #expect(near(py(g.topLb, g.yDomain), 10))
    }

    @Test("n points: first dot at x 10, last at x 310; rules at y 110 / 60 / 10", arguments: 2...12)
    func pixelInsets(n: Int) {
        let weights = (0..<n).map { 30 + 2.5 * Double($0 % 4) }
        let g = ProgressStats.chartGeometry(weights: weights)
        #expect(near(px(0, g.xDomain), 10))
        #expect(near(px(Double(n - 1), g.xDomain), 310))
        #expect(near(py(g.baselineLb, g.yDomain), 110))
        #expect(near(py(g.midLb, g.yDomain), 60))
        #expect(near(py(g.topLb, g.yDomain), 10))
    }

    @Test("a flat line of two equal tops keeps a 10-lb span: y 34…46, x −1/30…1 + 1/30")
    func flatLine() {
        let g = ProgressStats.chartGeometry(weights: [40, 40])
        #expect(near(g.yDomain.lowerBound, 34) && near(g.yDomain.upperBound, 46))
        #expect(near(g.xDomain.lowerBound, -1.0 / 30) && near(g.xDomain.upperBound, 1 + 1.0 / 30))
    }

    @Test("the lowest and highest top lie 5 lb inside the outer rules whatever the input order")
    func unorderedWeights() {
        let g = ProgressStats.chartGeometry(weights: [42.5, 30, 45, 37.5])
        #expect(near(g.baselineLb, 25) && near(g.topLb, 50) && near(g.midLb, 37.5))
    }
}

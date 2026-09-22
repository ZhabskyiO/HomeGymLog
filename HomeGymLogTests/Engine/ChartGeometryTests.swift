import Foundation
import Testing
@testable import HomeGymLog

/// AC-21 (geometry): spec 5.8's worked cases, the empty chart, and the rules-inside-domain invariant over every AC-16/17 input.
@Suite struct ChartGeometryTests {
    private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    private func matches(_ g: ChartGeometry, y: (Double, Double), rules: (Double, Double, Double), x: (Double, Double)) -> Bool {
        near(g.yDomain.lowerBound, y.0) && near(g.yDomain.upperBound, y.1)
            && near(g.baselineLb, rules.0) && near(g.midLb, rules.1) && near(g.topLb, rules.2)
            && near(g.xDomain.lowerBound, x.0) && near(g.xDomain.upperBound, x.1)
    }

    @Test("dbBench 37.5 · 40 · 42.5 → y 31…49, rules 32.5 / 40 / 47.5, x −1/15…2 + 1/15")
    func threePoints() {
        let g = ProgressStats.chartGeometry(weights: [37.5, 40, 42.5])
        #expect(matches(g, y: (31, 49), rules: (32.5, 40, 47.5), x: (-1.0 / 15, 2 + 1.0 / 15)))
    }

    @Test("a single 40 → y 34…46, rules 35 / 40 / 45, x −1…1")
    func onePoint() {
        #expect(matches(ProgressStats.chartGeometry(weights: [40]), y: (34, 46), rules: (35, 40, 45), x: (-1, 1)))
    }

    @Test("no weights → rules −5 / 5 / 15, y −7…17, x −1…1")
    func empty() {
        #expect(matches(ProgressStats.chartGeometry(weights: []), y: (-7, 17), rules: (-5, 5, 15), x: (-1, 1)))
    }

    @Test("every rule lies inside the y domain and every position inside the x domain")
    func invariant() throws {
        let mid = try HomeFixtures.midProgramInput(completedIndexes: MissedDayFixtures.midProgramCompleted)
        let created = ProgressFixtures.at(8, 31, hour: 6)
        let keys = ["dbBench", "inclineDb", "shoulderPress", "pecDeck", "latRaise", "latPull", "rdl", "goblet", "legExt", "lunge", "chestPress"]
        var lists: [[Double]] = keys.map { key in
            ProgressStats.points(tops: ProgressFixtures.tops(mid, key: key, programID: ProgressFixtures.currentID, createdAt: created)).map(\.topWeightLb)
        }
        let history = ProgressFixtures.tops(try ProgressFixtures.historyInput(), key: "dbBench", programID: ProgressFixtures.archivedID,
                                            createdAt: ProgressFixtures.at(8, 3, hour: 6))
        let bench = ProgressFixtures.tops(mid, key: "dbBench", programID: ProgressFixtures.currentID, createdAt: created)
        lists.append(ProgressStats.points(tops: history + bench).map(\.topWeightLb))
        lists += [[50, 47.5], [40], []]
        #expect(lists.count == 15)
        #expect(lists[11].count == 7)
        for weights in lists {
            let g = ProgressStats.chartGeometry(weights: weights)
            for rule in [g.baselineLb, g.midLb, g.topLb] {
                #expect(g.yDomain.contains(rule), "rule \(rule) outside \(g.yDomain) for \(weights)")
            }
            for weight in weights {
                #expect(g.yDomain.contains(weight))
            }
            if !weights.isEmpty {
                #expect(g.xDomain.contains(0) && g.xDomain.contains(Double(weights.count - 1)), "x \(g.xDomain) for \(weights)")
            }
        }
    }
}

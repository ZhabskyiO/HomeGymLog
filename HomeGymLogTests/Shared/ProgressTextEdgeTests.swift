import Foundation
import Testing
@testable import HomeGymLog

/// `ProgressText` edges beyond `ProgressTextTests` (spec 5.3, 5.7): kg rounding of Best at the reachable weights, the delta
/// converted as a difference (which can differ from the difference of the two rounded Bests), signs at zero, and the
/// `progress-history` summary.
@MainActor
@Suite struct ProgressTextEdgeTests {
    private var cal: Calendar {
        var c = TestCalendar.calendar
        c.locale = Locale(identifier: "en_US")
        return c
    }

    @Test("Best in kg: one decimal, trailing .0 dropped",
          arguments: [(5.0, "2.3"), (30, "13.6"), (45, "20.4"), (47.5, "21.5"), (52.5, "23.8"), (150, "68")])
    func bestInKg(lb: Double, kg: String) {
        #expect(ProgressText.weight(lb: lb, unit: .kg) == kg)
    }

    @Test("40 → 42.5 lb: the delta reads +1.1 kg (2.5 lb converted), not 19.3 − 18.1 = 1.2")
    func deltaIsConvertedAsDifference() {
        #expect(ProgressText.weight(lb: 40, unit: .kg) == "18.1")
        #expect(ProgressText.weight(lb: 42.5, unit: .kg) == "19.3")
        #expect(ProgressText.delta(lb: 42.5 - 40, unit: .kg) == "+1.1 kg")
    }

    @Test("delta signs and units",
          arguments: [(-5.0, WeightUnit.kg, "\u{2212}2.3 kg"), (-42.5, .lb, "\u{2212}42.5 lb"), (150, .kg, "+68 kg"),
                      (0, .kg, "0 kg"), (12.5, .kg, "+5.7 kg"), (-150, .lb, "\u{2212}150 lb")])
    func deltaCases(lb: Double, unit: WeightUnit, text: String) {
        #expect(ProgressText.delta(lb: lb, unit: unit) == text)
    }

    @Test("negative zero reads 0 lb with no sign and a muted tone")
    func negativeZero() {
        #expect(ProgressText.delta(lb: -0.0, unit: .lb) == "0 lb")
        #expect(ProgressText.deltaTone(lb: -0.0) == .muted)
    }

    @Test("progress-history's summary: 7 sessions, 30 to 45 lb; in kg 13.6 to 20.4 kg")
    func historySummary() {
        #expect(ProgressText.chartSummary(name: "Dumbbell Bench Press", count: 7, minLb: 30, maxLb: 45, unit: .lb)
                == "Dumbbell Bench Press, 7 sessions, 30 to 45 lb")
        #expect(ProgressText.chartSummary(name: "Dumbbell Bench Press", count: 7, minLb: 30, maxLb: 45, unit: .kg)
                == "Dumbbell Bench Press, 7 sessions, 13.6 to 20.4 kg")
    }

    @Test("point labels on the DST days name the local day", arguments: [(3, 8), (11, 1)])
    func dstPointLabels(month: Int, day: Int) {
        let label = ProgressText.pointLabel(date: TestCalendar.day(2026, month, day).addingTimeInterval(2.5 * 3600), calendar: cal)
        #expect(label == (month == 3 ? "Mar 8" : "Nov 1"))
    }
}

import Foundation

/// The user's display unit. Raw string so `@AppStorage("units")` stores it directly. Storage is always pounds.
nonisolated enum WeightUnit: String, CaseIterable, Sendable {
    case lb, kg
}

/// Number text for a weight in the chosen unit. Screens only append the unit suffix.
nonisolated enum WeightDisplay {
    static let kgPerLb = 0.45359237

    /// Loads and targets: lb as stored; kg to one decimal (integer tenths, halves away from zero).
    /// A trailing ".0" is dropped in both units: 40 → "40", 42.5 → "42.5", 150 lb → "68" kg.
    static func text(lb: Double, unit: WeightUnit) -> String {
        let value = unit == .lb ? lb : lb * kgPerLb
        let tenths = Int((value * 10).rounded())
        let whole = tenths / 10
        let fraction = abs(tenths % 10)
        return fraction == 0 ? "\(whole)" : "\(whole).\(fraction)"
    }

    /// Body weight and volume totals as a whole number: lb rounded, or kg = round(lb × kgPerLb).
    static func whole(lb: Double, unit: WeightUnit) -> Int {
        let value = unit == .lb ? lb : lb * kgPerLb
        return Int(value.rounded())
    }

    /// `whole` as text.
    static func wholeText(lb: Double, unit: WeightUnit) -> String {
        "\(whole(lb: lb, unit: unit))"
    }
}

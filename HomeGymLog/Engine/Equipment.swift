import Foundation

/// The two pieces of loadable equipment and their weight grids.
/// All arithmetic is in integer tenths of a pound so exact halves round predictably.
nonisolated enum EquipmentKind: String, CaseIterable, Codable, Sendable {
    /// Adjustable dumbbells, 5–52.5 lb in 2.5 lb steps.
    case dumbbell
    /// Marcy MWM-8147 stack, 15 × 10 lb plates including the top carriage plate: 10–150 lb.
    case marcy

    /// Smallest load increment, in tenths of a pound (25 = 2.5 lb, 100 = 10 lb).
    var stepTenths: Int {
        switch self {
        case .dumbbell: return 25
        case .marcy: return 100
        }
    }

    /// Lightest load, in tenths of a pound.
    var minTenths: Int {
        switch self {
        case .dumbbell: return 50
        case .marcy: return 100
        }
    }

    /// Heaviest load, in tenths of a pound.
    var maxTenths: Int {
        switch self {
        case .dumbbell: return 525
        case .marcy: return 1500
        }
    }

    var stepLb: Double { Self.lb(fromTenths: stepTenths) }
    var minLb: Double { Self.lb(fromTenths: minTenths) }
    var maxLb: Double { Self.lb(fromTenths: maxTenths) }

    /// 30 % of the maximum, in pounds: 15.75 (dumbbell) or 45 (Marcy). Display and tests only;
    /// the progression compares in integers via `isBelowThreshold`.
    var thresholdLb: Double { Double(maxTenths) * 0.3 / 10 }

    /// True while a base weight is under 30 % of the equipment maximum (the fast progression regime).
    /// Compares `base × 10 < max × 3` so no floating point is involved.
    func isBelowThreshold(baseTenths: Int) -> Bool {
        baseTenths * 10 < maxTenths * 3
    }

    /// True when `lb` sits on this equipment's grid: a multiple of the step and within min…max.
    func isLoadable(lb: Double) -> Bool {
        guard let tenths = Self.tenths(fromLb: lb) else { return false }
        return tenths >= minTenths && tenths <= maxTenths && tenths % stepTenths == 0
    }

    /// Converts pounds to integer tenths; nil unless `lb` is an exact tenth (e.g. 15.75 → nil).
    static func tenths(fromLb lb: Double) -> Int? {
        let scaled = lb * 10
        let rounded = scaled.rounded()
        guard abs(scaled - rounded) < 1e-6 else { return nil }
        return Int(rounded)
    }

    /// Converts integer tenths back to pounds.
    static func lb(fromTenths tenths: Int) -> Double {
        Double(tenths) / 10
    }
}

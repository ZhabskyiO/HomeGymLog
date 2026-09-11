import Foundation

/// The prototype's `kfmt`: whole numbers below 1 000, otherwise one decimal plus "k".
enum VolumeText {
    static func kfmt(_ n: Int) -> String {
        guard n >= 1000 else { return "\(n)" }
        let tenths = Int((Double(n) / 100).rounded())   // half away from zero
        return "\(tenths / 10).\(tenths % 10)k"
    }

    /// Week volume text in the display unit, converted before formatting.
    static func weekVolume(lb: Double, unit: WeightUnit) -> String {
        kfmt(WeightDisplay.whole(lb: lb, unit: unit))
    }

    /// "lb this week" / "kg this week"
    static func caption(unit: WeightUnit) -> String {
        "\(unit.rawValue) this week"
    }
}

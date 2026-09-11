import Foundation
import Testing
@testable import HomeGymLog

/// Spec 5.3's reason for one-decimal kg: adjacent equipment steps must never collapse, and switching back
/// to lb must show the exact stored value (no round-trip loss). Checked over every loadable value.
@Suite struct WeightDisplayGridTests {
    private static func loads(_ kind: EquipmentKind) -> [Double] {
        stride(from: kind.minTenths, through: kind.maxTenths, by: kind.stepTenths).map { EquipmentKind.lb(fromTenths: $0) }
    }

    @Test("lb text parses back to the exact stored value for every loadable weight", arguments: EquipmentKind.allCases)
    func lbRoundTrip(kind: EquipmentKind) {
        for lb in Self.loads(kind) {
            #expect(Double(WeightDisplay.text(lb: lb, unit: .lb)) == lb, "\(lb)")
            #expect(!WeightDisplay.text(lb: lb, unit: .lb).hasSuffix(".0"), "\(lb)")
        }
    }

    @Test("adjacent steps never share a kg text and kg ascends with lb", arguments: EquipmentKind.allCases)
    func kgNeverCollapses(kind: EquipmentKind) {
        let texts = Self.loads(kind).map { WeightDisplay.text(lb: $0, unit: .kg) }
        #expect(Set(texts).count == texts.count, "\(kind) has duplicate kg texts")
        let values = texts.compactMap(Double.init)
        #expect(values.count == texts.count)
        #expect(values == values.sorted())
    }

    @Test("one dumbbell step reads as about 1.1 kg, one Marcy plate as about 4.5 kg")
    func kgStepSize() {
        let dumbbell = Self.loads(.dumbbell).compactMap { Double(WeightDisplay.text(lb: $0, unit: .kg)) }
        for (a, b) in zip(dumbbell, dumbbell.dropFirst()) {
            #expect((1.0...1.3).contains(b - a), "\(a) → \(b)")
        }
        let marcy = Self.loads(.marcy).compactMap { Double(WeightDisplay.text(lb: $0, unit: .kg)) }
        for (a, b) in zip(marcy, marcy.dropFirst()) {
            #expect((4.4...4.7).contains(b - a), "\(a) → \(b)")
        }
    }

    @Test("dumbbell 42.5 and 45 lb stay distinct in kg (the prototype's 2.5 kg rounding merged them)")
    func prototypeCollapseFixed() {
        #expect(WeightDisplay.text(lb: 42.5, unit: .kg) != WeightDisplay.text(lb: 45, unit: .kg))
        #expect(WeightDisplay.text(lb: 42.5, unit: .kg) == "19.3" && WeightDisplay.text(lb: 45, unit: .kg) == "20.4")
    }

    @Test("A1 equipment rows: 52.5 lb → 23.8 kg, 150 lb stack → 68 kg")
    func welcomeRows() {
        #expect(WeightDisplay.text(lb: EquipmentKind.dumbbell.maxLb, unit: .kg) == "23.8")
        #expect(WeightDisplay.text(lb: EquipmentKind.marcy.maxLb, unit: .kg) == "68")
        #expect(WeightDisplay.text(lb: EquipmentKind.dumbbell.maxLb, unit: .lb) == "52.5")
        #expect(WeightDisplay.text(lb: EquipmentKind.marcy.maxLb, unit: .lb) == "150")
    }
}

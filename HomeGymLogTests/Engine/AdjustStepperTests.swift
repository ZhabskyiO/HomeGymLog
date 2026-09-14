import Foundation
import Testing
@testable import HomeGymLog

/// AC-31: the adjust sheet's stepper table (spec 5.3) through `EquipmentKind.stepped`, the reps floor, and the kg
/// text of the stepped values. Literal expectations only.
@Suite struct AdjustStepperTests {
    @Test("Marcy: 110 → 100 / 120; 150 + and 10 − are no-ops")
    func marcy() {
        #expect(EquipmentKind.marcy.stepped(lb: 110, by: -1) == 100)
        #expect(EquipmentKind.marcy.stepped(lb: 110, by: 1) == 120)
        #expect(EquipmentKind.marcy.stepped(lb: 150, by: 1) == nil)
        #expect(EquipmentKind.marcy.stepped(lb: 10, by: -1) == nil)
    }

    @Test("dumbbell: 47.5 → 45 / 50; + twice reaches 52.5 then stops; 5 − stops, 5 + is 7.5")
    func dumbbell() {
        #expect(EquipmentKind.dumbbell.stepped(lb: 47.5, by: -1) == 45)
        #expect(EquipmentKind.dumbbell.stepped(lb: 47.5, by: 1) == 50)
        #expect(EquipmentKind.dumbbell.stepped(lb: 50, by: 1) == 52.5)
        #expect(EquipmentKind.dumbbell.stepped(lb: 52.5, by: 1) == nil)
        #expect(EquipmentKind.dumbbell.stepped(lb: 52.5, by: -1) == 50)
        #expect(EquipmentKind.dumbbell.stepped(lb: 5, by: -1) == nil)
        #expect(EquipmentKind.dumbbell.stepped(lb: 5, by: 1) == 7.5)
    }

    @Test("curl 27.5 stepped down nine times lands on 5, the tenth is a no-op")
    func curlToMinimum() {
        var weight = 27.5
        for _ in 0..<9 {
            guard let next = EquipmentKind.dumbbell.stepped(lb: weight, by: -1) else { break }
            weight = next
        }
        #expect(weight == 5)
        #expect(EquipmentKind.dumbbell.stepped(lb: weight, by: -1) == nil)
    }

    @Test("reps floor: 12 → 11, 1 → 1, 0 → 1")
    func repsFloor() {
        #expect(WorkoutFlow.decrementedReps(12) == 11)
        #expect(WorkoutFlow.decrementedReps(2) == 1)
        #expect(WorkoutFlow.decrementedReps(1) == 1)
        #expect(WorkoutFlow.decrementedReps(0) == 1)
    }

    @Test("kg text of the stepped values")
    func kgText() {
        #expect([100.0, 110, 120].map { WeightDisplay.text(lb: $0, unit: .kg) } == ["45.4", "49.9", "54.4"])
        #expect(WeightDisplay.text(lb: 150, unit: .kg) == "68")
        #expect([45.0, 47.5, 50].map { WeightDisplay.text(lb: $0, unit: .kg) } == ["20.4", "21.5", "22.7"])
        #expect(WeightDisplay.text(lb: 52.5, unit: .kg) == "23.8")
        #expect(WeightDisplay.text(lb: 5, unit: .kg) == "2.3")
    }
}

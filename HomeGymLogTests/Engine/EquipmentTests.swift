import Testing
@testable import HomeGymLog

// Swift Testing: `@Suite` groups tests, `@Test` marks one, `#expect` asserts. Like describe/it/expect.
@Suite struct EquipmentTests {
    @Test("dumbbell grid is 2.5 step, 5 min, 52.5 max, 15.75 threshold")
    func dumbbellGrid() {
        let kind = EquipmentKind.dumbbell
        #expect(kind.stepLb == 2.5)
        #expect(kind.minLb == 5)
        #expect(kind.maxLb == 52.5)
        #expect(kind.thresholdLb == 15.75)
        #expect(kind.stepTenths == 25 && kind.minTenths == 50 && kind.maxTenths == 525)
    }

    @Test("marcy grid is 10 step, 10 min, 150 max, 45 threshold")
    func marcyGrid() {
        let kind = EquipmentKind.marcy
        #expect(kind.stepLb == 10)
        #expect(kind.minLb == 10)
        #expect(kind.maxLb == 150)
        #expect(kind.thresholdLb == 45)
        #expect(kind.stepTenths == 100 && kind.minTenths == 100 && kind.maxTenths == 1500)
    }

    @Test("dumbbell loadability", arguments: [
        (41.0, false), (55.0, false), (2.5, false), (52.5, true), (5.0, true), (47.5, true), (15.75, false),
    ])
    func dumbbellLoadable(lb: Double, expected: Bool) {
        #expect(EquipmentKind.dumbbell.isLoadable(lb: lb) == expected)
    }

    @Test("marcy loadability", arguments: [
        (45.0, false), (150.0, true), (160.0, false), (10.0, true), (5.0, false), (110.0, true),
    ])
    func marcyLoadable(lb: Double, expected: Bool) {
        #expect(EquipmentKind.marcy.isLoadable(lb: lb) == expected)
    }

    @Test("tenths round-trips exact tenths and rejects others")
    func tenthsConversion() {
        #expect(EquipmentKind.tenths(fromLb: 42.5) == 425)
        #expect(EquipmentKind.tenths(fromLb: 150) == 1500)
        #expect(EquipmentKind.tenths(fromLb: 15.75) == nil)
        #expect(EquipmentKind.lb(fromTenths: 425) == 42.5)
        #expect(EquipmentKind.lb(fromTenths: EquipmentKind.tenths(fromLb: 12.5)!) == 12.5)
    }

    @Test("threshold comparison for dumbbells", arguments: [
        (150, true), (175, false), (400, false),
    ])
    func dumbbellThreshold(baseTenths: Int, below: Bool) {
        #expect(EquipmentKind.dumbbell.isBelowThreshold(baseTenths: baseTenths) == below)
    }

    @Test("threshold comparison for marcy: 40 is below, 45 is not")
    func marcyThreshold() {
        #expect(EquipmentKind.marcy.isBelowThreshold(baseTenths: 400))
        #expect(!EquipmentKind.marcy.isBelowThreshold(baseTenths: 450))
    }
}

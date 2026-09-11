import Testing
@testable import HomeGymLog

@Suite struct WeightDisplayTests {
    @Test("kg is one decimal per the spec table", arguments: [
        (5.0, "2.3"), (15.0, "6.8"), (40.0, "18.1"), (42.5, "19.3"), (45.0, "20.4"),
        (100.0, "45.4"), (110.0, "49.9"), (150.0, "68"), (52.5, "23.8"), (10.0, "4.5"),
    ])
    func kgTable(lb: Double, expected: String) {
        #expect(WeightDisplay.text(lb: lb, unit: .kg) == expected)
    }

    @Test("rounding examples from the spec edge cases", arguments: [(12.5, "5.7"), (17.5, "7.9"), (47.5, "21.5"), (22.5, "10.2")])
    func roundingExamples(lb: Double, expected: String) {
        #expect(WeightDisplay.text(lb: lb, unit: .kg) == expected)
    }

    @Test("lb shows as stored with a trailing .0 dropped")
    func lbText() {
        #expect(WeightDisplay.text(lb: 40, unit: .lb) == "40")
        #expect(WeightDisplay.text(lb: 42.5, unit: .lb) == "42.5")
        #expect(WeightDisplay.text(lb: 150, unit: .kg) == "68")
    }

    @Test("whole text for body weight and volumes")
    func wholeText() {
        #expect(WeightDisplay.wholeText(lb: 180, unit: .kg) == "82")
        #expect(WeightDisplay.wholeText(lb: 175, unit: .kg) == "79")
        #expect(WeightDisplay.wholeText(lb: 185, unit: .kg) == "84")
        #expect(WeightDisplay.wholeText(lb: 7560, unit: .kg) == "3429")
        #expect(WeightDisplay.wholeText(lb: 180, unit: .lb) == "180")
        #expect(WeightDisplay.wholeText(lb: 7560, unit: .lb) == "7560")
    }

    @Test("WeightUnit raw values are the preference strings")
    func rawValues() {
        #expect(WeightUnit.lb.rawValue == "lb" && WeightUnit.kg.rawValue == "kg")
        #expect(WeightUnit(rawValue: "kg") == .kg)
    }
}

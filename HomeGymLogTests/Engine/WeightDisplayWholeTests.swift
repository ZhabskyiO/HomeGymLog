import Testing
@testable import HomeGymLog

@Suite struct WeightDisplayWholeTests {
    @Test("whole numbers in lb and kg")
    func whole() {
        #expect(WeightDisplay.whole(lb: 7560, unit: .lb) == 7560)
        #expect(WeightDisplay.whole(lb: 7560, unit: .kg) == 3429)
        #expect(WeightDisplay.whole(lb: 180, unit: .lb) == 180)
        #expect(WeightDisplay.whole(lb: 180, unit: .kg) == 82)
        #expect(WeightDisplay.whole(lb: 49320, unit: .kg) == 22371)
        #expect(WeightDisplay.wholeText(lb: 180, unit: .kg) == "82")
    }
}

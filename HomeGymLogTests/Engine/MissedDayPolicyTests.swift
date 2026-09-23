import Foundation
import Testing
@testable import HomeGymLog

/// AC-17 (policy half): the stored raw values, the `.ask` fallback, the case order and the key, each expected value
/// typed here from spec 4.3. Plain suite: `MissedDayPolicy` is `nonisolated` Engine code.
@Suite struct MissedDayPolicyTests {
    @Test("raw values round trip for all three cases")
    func rawRoundTrip() {
        #expect(MissedDayPolicy.ask.rawValue == "ask")
        #expect(MissedDayPolicy.shift.rawValue == "shift")
        #expect(MissedDayPolicy.skip.rawValue == "skip")
        #expect(MissedDayPolicy.from(raw: "ask") == .ask)
        #expect(MissedDayPolicy.from(raw: "shift") == .shift)
        #expect(MissedDayPolicy.from(raw: "skip") == .skip)
    }

    @Test("an unknown, empty or wrongly cased raw value falls back to Ask")
    func unknownFallsBack() {
        #expect(MissedDayPolicy.from(raw: "sepia") == .ask)
        #expect(MissedDayPolicy.from(raw: "") == .ask)
        #expect(MissedDayPolicy.from(raw: "Shift") == .ask)
    }

    @Test("allCases is ask, shift, skip in that order and the storage key is \"missedDayPolicy\"")
    func casesAndKey() {
        #expect(MissedDayPolicy.allCases == [.ask, .shift, .skip])
        #expect(MissedDayPolicy.storageKey == "missedDayPolicy")
    }
}

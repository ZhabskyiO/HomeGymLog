import Foundation
import Testing
@testable import HomeGymLog

/// AC-17 (appearance half): the stored raw values, the fallback for anything unknown, the segment labels and the key,
/// each expected value typed here from spec 4.3 rather than read back from the enum.
@MainActor
@Suite struct AppearanceModeTests {
    @Test("raw values round trip for all three cases")
    func rawRoundTrip() {
        #expect(AppearanceMode.system.rawValue == "system")
        #expect(AppearanceMode.dark.rawValue == "dark")
        #expect(AppearanceMode.light.rawValue == "light")
        #expect(AppearanceMode.from(raw: "system") == .system)
        #expect(AppearanceMode.from(raw: "dark") == .dark)
        #expect(AppearanceMode.from(raw: "light") == .light)
    }

    @Test("an unknown, empty or wrongly cased raw value falls back to System")
    func unknownFallsBack() {
        #expect(AppearanceMode.from(raw: "sepia") == .system)
        #expect(AppearanceMode.from(raw: "") == .system)
        #expect(AppearanceMode.from(raw: "Dark") == .system)
    }

    @Test("labels are the visible strings of spec 4.3")
    func labels() {
        #expect(AppearanceMode.system.label == "System")
        #expect(AppearanceMode.dark.label == "Dark")
        #expect(AppearanceMode.light.label == "Light")
    }

    @Test("allCases is System, Dark, Light in that order and the storage key is \"appearance\"")
    func casesAndKey() {
        #expect(AppearanceMode.allCases == [.system, .dark, .light])
        #expect(AppearanceMode.storageKey == "appearance")
    }
}

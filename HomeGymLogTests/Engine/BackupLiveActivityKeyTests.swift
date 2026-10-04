import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-14: the ninth backup preference (§5.4): lenient, falls back to on, and rides in the export as a
/// ninth sorted key. Pre-slice files (eight keys) decode with the field nil.
@Suite struct BackupLiveActivityKeyTests {
    private func decode(_ json: String) throws -> BackupPreferences {
        try JSONDecoder().decode(BackupPreferences.self, from: Data(json.utf8))
    }

    @Test("an explicit false survives resolving; missing resolves to on")
    func resolves() throws {
        #expect(BackupPreferences(liveActivityEnabled: false).resolved().liveActivityEnabled == false)
        #expect(BackupPreferences(liveActivityEnabled: true).resolved().liveActivityEnabled == true)
        #expect(try decode("{}").resolved().liveActivityEnabled == true)
    }

    @Test("a wrong type decodes as nil and resolves to on, without failing the other keys")
    func wrongType() throws {
        let preferences = try decode(#"{"liveActivityEnabled": "yes", "soundEnabled": false}"#)
        #expect(preferences.liveActivityEnabled == nil)
        #expect(preferences.resolved().liveActivityEnabled == true)
        #expect(preferences.soundEnabled == false)
    }

    @Test("the fallback column says on")
    func defaults() {
        #expect(ResolvedPreferences.defaults.liveActivityEnabled == true)
    }

    @Test("midProgram's preferences export the nine keys of §5.4, sorted")
    func nineSortedKeys() throws {
        let data = try BackupCodec.encode(BackupFixtures.mutated { $0.preferences = midProgramPreferences })
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let preferences = try #require(object["preferences"] as? [String: Any])
        #expect(preferences.keys.sorted() == ["appearance", "bodyWeightUnits", "hapticsEnabled", "liveActivityEnabled", "missedDayPolicy",
                                              "reminderEnabled", "reminderMinutes", "soundEnabled", "units"])
        #expect(preferences["liveActivityEnabled"] as? Bool == true)
        let text = String(decoding: data, as: UTF8.self)
        let order = ["\"hapticsEnabled\"", "\"liveActivityEnabled\"", "\"missedDayPolicy\""].map { text.range(of: $0)?.lowerBound }
        let positions = try order.map { try #require($0) }
        #expect(positions == positions.sorted(), "the encoder writes the new key in sorted position")
    }

    @Test("a pre-slice eight-key object decodes with the field nil")
    func preSliceFile() throws {
        let old = try decode(#"""
            {"appearance": "system", "bodyWeightUnits": "lb", "hapticsEnabled": true, "missedDayPolicy": "ask",
             "reminderEnabled": false, "reminderMinutes": 420, "soundEnabled": true, "units": "lb"}
            """#)
        #expect(old.liveActivityEnabled == nil)
        #expect(old.resolved() == .defaults)
    }
}

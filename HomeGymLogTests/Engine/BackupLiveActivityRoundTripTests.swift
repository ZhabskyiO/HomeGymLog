import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-14 gap pass (test-writer): the ninth key through the whole-file path (`BackupCodec.encode` →
/// `BackupCodec.read`, header check and validation included), not just `BackupPreferences`' own decoder. Present (both
/// values), absent (fallback on), and wrong JSON types (fallback on, the file still reads, the other keys survive).
@Suite struct BackupLiveActivityRoundTripTests {
    private static func withPreferences(_ preferences: BackupPreferences) -> BackupDocument {
        BackupFixtures.mutated { $0.preferences = preferences }
    }

    @Test("present: the value survives encode → read → resolve", arguments: [false, true])
    func present(value: Bool) throws {
        let document = Self.withPreferences(BackupPreferences(soundEnabled: false, liveActivityEnabled: value))
        let read = try BackupCodec.read(try BackupCodec.encode(document))
        #expect(read.preferences?.liveActivityEnabled == value)
        #expect(read.preferences?.resolved().liveActivityEnabled == value)
        #expect(read == document)
    }

    @Test("absent from a file that has the other eight keys: reads, resolves to on, the others are kept")
    func absent() throws {
        let edited = BackupPreferences(units: "kg", bodyWeightUnits: "kg", appearance: "dark", missedDayPolicy: "skip",
                                       reminderEnabled: true, reminderMinutes: 1080, hapticsEnabled: false, soundEnabled: false,
                                       liveActivityEnabled: false)
        let data = try BackupFixtures.editedJSON(Self.withPreferences(edited)) { object in
            var preferences = object["preferences"] as! [String: Any]
            preferences.removeValue(forKey: "liveActivityEnabled")
            object["preferences"] = preferences
        }
        let read = try BackupCodec.read(data)
        let preferences = try #require(read.preferences)
        #expect(preferences.liveActivityEnabled == nil)
        let resolved = preferences.resolved()
        #expect(resolved.liveActivityEnabled == true)
        #expect(resolved == ResolvedPreferences(units: .kg, bodyWeightUnits: .kg, appearance: .dark, missedDayPolicy: .skip,
                                                reminderEnabled: true, reminderMinutes: 1080, hapticsEnabled: false,
                                                soundEnabled: false, liveActivityEnabled: true))
    }

    @Test("a wrong JSON type: the file reads, the key resolves to on, Sound stays off",
          arguments: ["\"false\"", "\"no\"", "null", "[]", "{}"])
    func wrongType(json: String) throws {
        let fragment = try JSONSerialization.jsonObject(with: Data(json.utf8), options: .fragmentsAllowed)
        let data = try BackupFixtures.editedJSON(Self.withPreferences(BackupPreferences(soundEnabled: false, liveActivityEnabled: false))) { object in
            var preferences = object["preferences"] as! [String: Any]
            preferences["liveActivityEnabled"] = fragment
            object["preferences"] = preferences
        }
        let read = try BackupCodec.read(data)
        #expect(read.preferences?.liveActivityEnabled == nil)
        #expect(read.preferences?.resolved().liveActivityEnabled == true)
        #expect(read.preferences?.soundEnabled == false)
    }

    @Test("no preferences object at all: every key falls back, the ninth to on")
    func noPreferencesObject() throws {
        let read = try BackupCodec.read(try BackupCodec.encode(BackupFixtures.sampleDocument()))
        #expect(read.preferences == nil)
        #expect((read.preferences ?? BackupPreferences()).resolved().liveActivityEnabled == true)
    }
}

import Foundation
import Testing
@testable import HomeGymLog

/// AC-13 (preferences half): spec 5.7's fallbacks through `resolved()`, the two seed rows typed out, lenient decoding of a
/// wrong-typed field, and a non-object `preferences` reading as absent without failing the file.
@Suite struct BackupPreferencesTests {
    private func decode(_ json: String) throws -> BackupPreferences {
        try JSONDecoder().decode(BackupPreferences.self, from: Data(json.utf8))
    }

    @Test("the fallback column, typed from 5.7")
    func defaults() {
        let d = ResolvedPreferences.defaults
        #expect(d == ResolvedPreferences(units: .lb, bodyWeightUnits: .lb, appearance: .system, missedDayPolicy: .ask,
                                         reminderEnabled: false, reminderMinutes: 420, hapticsEnabled: true, soundEnabled: true,
                                         liveActivityEnabled: true))
        #expect(BackupPreferences().resolved() == d, "an empty object resolves every key to its fallback")
    }

    @Test("hand cases of 5.7")
    func handCases() throws {
        #expect(BackupPreferences(units: "kg").resolved().units == .kg)
        #expect(BackupPreferences(units: "stone").resolved().units == .lb)
        #expect(BackupPreferences(bodyWeightUnits: "kg").resolved().bodyWeightUnits == .kg)
        #expect(BackupPreferences(appearance: "sepia").resolved().appearance == .system)
        #expect(BackupPreferences(appearance: "light").resolved().appearance == .light)
        #expect(BackupPreferences(missedDayPolicy: "skip").resolved().missedDayPolicy == .skip)
        #expect(BackupPreferences(missedDayPolicy: "never").resolved().missedDayPolicy == .ask)
        #expect(BackupPreferences(reminderMinutes: 1440).resolved().reminderMinutes == 420)
        #expect(BackupPreferences(reminderMinutes: -1).resolved().reminderMinutes == 420)
        #expect(BackupPreferences(reminderMinutes: 419).resolved().reminderMinutes == 419)
        #expect(BackupPreferences(reminderMinutes: 0).resolved().reminderMinutes == 0)
        #expect(BackupPreferences(reminderMinutes: 1439).resolved().reminderMinutes == 1439)
        #expect(BackupPreferences(hapticsEnabled: false).resolved().hapticsEnabled == false)
        #expect(BackupPreferences(soundEnabled: false).resolved().soundEnabled == false)
        let wrongType = try decode(#"{"reminderEnabled": "yes", "units": 3, "hapticsEnabled": false}"#)
        #expect(wrongType.reminderEnabled == nil)
        #expect(wrongType.units == nil)
        #expect(wrongType.resolved().reminderEnabled == false)
        #expect(wrongType.resolved().hapticsEnabled == false, "the valid field beside a wrong one still reads")
        let missing = try decode(#"{"soundEnabled": false}"#)
        #expect(missing.resolved().hapticsEnabled == true)
    }

    @Test("midProgram's and reminder-on's exported rows, typed out")
    func seedRows() throws {
        let midProgram = try decode(#"""
            {"appearance": "system", "bodyWeightUnits": "lb", "hapticsEnabled": true, "missedDayPolicy": "ask",
             "reminderEnabled": false, "reminderMinutes": 420, "soundEnabled": true, "units": "lb"}
            """#)
        #expect(midProgram == BackupPreferences(units: "lb", bodyWeightUnits: "lb", appearance: "system", missedDayPolicy: "ask",
                                                reminderEnabled: false, reminderMinutes: 420, hapticsEnabled: true, soundEnabled: true))
        #expect(midProgram.resolved() == .defaults)
        let reminderOn = try decode(#"""
            {"appearance": "system", "bodyWeightUnits": "lb", "hapticsEnabled": true, "missedDayPolicy": "ask",
             "reminderEnabled": true, "reminderMinutes": 420, "soundEnabled": true, "units": "lb"}
            """#)
        var expected = ResolvedPreferences.defaults
        expected.reminderEnabled = true
        #expect(reminderOn.resolved() == expected)
    }

    @Test("\"preferences\": 7 (not an object) reads as absent and the file still decodes")
    func nonObjectPreferences() throws {
        let data = try BackupFixtures.editedJSON(BackupFixtures.sampleDocument()) { $0["preferences"] = 7 }
        let document = try BackupCodec.read(data)
        #expect(document.preferences == nil)
        let wrongField = try BackupFixtures.editedJSON(BackupFixtures.sampleDocument()) {
            $0["preferences"] = ["units": "kg", "reminderMinutes": "seven"]
        }
        let partial = try BackupCodec.read(wrongField)
        #expect(partial.preferences == BackupPreferences(units: "kg"))
    }
}

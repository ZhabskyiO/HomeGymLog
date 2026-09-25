#if DEBUG
import Foundation
import Testing
@testable import HomeGymLog

/// m5-haptics AC-18: `-haptics on|off` and `-sound on|off`, nil when absent, a typed error for anything else.
@Suite struct DebugFeedbackPreferencesTests {
    private func parse(_ arguments: [String]) throws -> FeedbackSeedPreferences {
        try DebugFeedbackPreferences.parse(arguments: arguments)
    }

    @Test("-haptics on → (true, nil)")
    func hapticsOn() throws {
        let parsed = try parse(["-haptics", "on"])
        #expect(parsed == FeedbackSeedPreferences(haptics: true, sound: nil))
    }

    @Test("-sound off → (nil, false)")
    func soundOff() throws {
        let parsed = try parse(["-sound", "off"])
        #expect(parsed == FeedbackSeedPreferences(haptics: nil, sound: false))
    }

    @Test("both among other arguments → (false, true)")
    func both() throws {
        let parsed = try parse(["-seed", "midProgram", "-haptics", "off", "-sound", "on", "-tab", "settings"])
        #expect(parsed == FeedbackSeedPreferences(haptics: false, sound: true))
    }

    @Test("absent → (nil, nil)")
    func absent() throws {
        let parsed = try parse(["-seed", "midProgram", "-tab", "settings"])
        #expect(parsed == FeedbackSeedPreferences(haptics: nil, sound: nil))
    }

    @Test("a trailing -haptics throws with an empty value")
    func trailing() {
        #expect(throws: DebugFeedbackError.unknownValue(argument: "-haptics", value: "")) {
            try DebugFeedbackPreferences.parse(arguments: ["-haptics"])
        }
    }

    @Test("-sound maybe throws with that value")
    func unknownValue() {
        #expect(throws: DebugFeedbackError.unknownValue(argument: "-sound", value: "maybe")) {
            try DebugFeedbackPreferences.parse(arguments: ["-sound", "maybe"])
        }
    }

    @Test("the spelling is exact: OFF is not off")
    func exactSpelling() {
        #expect(throws: DebugFeedbackError.unknownValue(argument: "-haptics", value: "OFF")) {
            try DebugFeedbackPreferences.parse(arguments: ["-haptics", "OFF"])
        }
    }
}
#endif

#if DEBUG
import Foundation
import Testing
@testable import HomeGymLog

/// m5-haptics AC-18 edges: repeated arguments (the first occurrence wins, as `firstIndex(of:)` reads them), an argument
/// whose value slot holds the next flag, and a flag name appearing only as another argument's value.
@Suite struct DebugFeedbackPreferencesEdgeTests {
    private func parse(_ arguments: [String]) throws -> FeedbackSeedPreferences {
        try DebugFeedbackPreferences.parse(arguments: arguments)
    }

    @Test("A repeated -haptics: the first value wins")
    func repeatedFirstWins() throws {
        #expect(try parse(["-haptics", "off", "-haptics", "on"]) == FeedbackSeedPreferences(haptics: false, sound: nil))
        #expect(try parse(["-sound", "on", "-sound", "off"]) == FeedbackSeedPreferences(haptics: nil, sound: true))
    }

    @Test("A repeated -haptics with a bad second value is not read (only the first occurrence is validated)")
    func repeatedBadSecondIgnored() throws {
        #expect(try parse(["-haptics", "off", "-haptics", "maybe"]) == FeedbackSeedPreferences(haptics: false, sound: nil))
    }

    @Test("A repeated -sound whose first value is bad throws for that value")
    func repeatedBadFirstThrows() {
        #expect(throws: DebugFeedbackError.unknownValue(argument: "-sound", value: "loud")) {
            try DebugFeedbackPreferences.parse(arguments: ["-sound", "loud", "-sound", "on"])
        }
    }

    @Test("-haptics followed directly by -sound throws with \"-sound\" as its value")
    func flagAsValue() {
        #expect(throws: DebugFeedbackError.unknownValue(argument: "-haptics", value: "-sound")) {
            try DebugFeedbackPreferences.parse(arguments: ["-haptics", "-sound", "off"])
        }
    }

    @Test("An empty argument list parses to (nil, nil)")
    func empty() throws {
        #expect(try parse([]) == FeedbackSeedPreferences(haptics: nil, sound: nil))
    }
}
#endif

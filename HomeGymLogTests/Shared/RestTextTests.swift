import Foundation
import Testing
@testable import HomeGymLog

/// AC-22: the rest card's label, spoken value, "Next:" text and constants, typed from spec 5.2 and 2.2.
@MainActor
@Suite struct RestTextTests {
    @Test("clock: m:ss, minutes uncapped, negative clamps to 0:00", arguments: [
        (62, "1:02"), (75, "1:15"), (60, "1:00"), (632, "10:32"), (5, "0:05"), (1, "0:01"), (0, "0:00"), (-3, "0:00"),
        (3600, "60:00"),   // past the first hour: fails if minutes wrap
    ])
    func clock(seconds: Int, expected: String) {
        #expect(RestText.clock(seconds: seconds) == expected)
    }

    @Test("spoken: minutes and seconds with singulars", arguments: [
        (62, "1 minute 2 seconds"), (92, "1 minute 32 seconds"), (60, "1 minute"), (120, "2 minutes"),
        (632, "10 minutes 32 seconds"), (5, "5 seconds"), (1, "1 second"), (0, "0 seconds"), (-3, "0 seconds"), (3600, "60 minutes"),
    ])
    func spoken(seconds: Int, expected: String) {
        #expect(RestText.spoken(seconds: seconds) == expected)
    }

    @Test("next: set n of N, the library name for a first set, the key when unknown")
    func next() {
        #expect(RestText.next(.set(number: 2, of: 3)) == "set 2 of 3")
        #expect(RestText.next(.firstSet(exerciseKey: "lowRow")) == "Seated Low Row · set 1")
        #expect(RestText.next(.firstSet(exerciseKey: "mystery")) == "mystery · set 1")
    }

    @Test("the seven constants")
    func constants() {
        #expect(RestText.title == "Rest")
        #expect(RestText.addLabel == "+30s")
        #expect(RestText.skipLabel == "Skip")
        #expect(RestText.addAccessibility == "Add 30 seconds")
        #expect(RestText.skipAccessibility == "Skip rest")
        #expect(RestText.restOver == "Rest over")
        #expect(RestText.notificationBody == "Time for your next set.")
    }
}

import Foundation
import Testing
@testable import HomeGymLog

/// m5-live-activity AC-16: the shared card strings pinned to literals (an equality with `RestText` would be trivially true
/// once aliased, plan S7), and the one "Next:" line builder.
@MainActor
@Suite struct RestActivityTextTests {
    @Test("the seven shared constants")
    func constants() {
        #expect(RestActivityText.title == "Rest")
        #expect(RestActivityText.addLabel == "+30s")
        #expect(RestActivityText.skipLabel == "Skip")
        #expect(RestActivityText.addAccessibility == "Add 30 seconds")
        #expect(RestActivityText.skipAccessibility == "Skip rest")
        #expect(RestActivityText.restOver == "Rest over")
        #expect(RestActivityText.nextPrefix == "Next: ")
    }

    @Test("nextLine: the prefix plus the set count or the next exercise's name")
    func nextLine() {
        #expect(RestText.nextLine(.set(number: 2, of: 3)) == "Next: set 2 of 3")
        #expect(RestText.nextLine(.firstSet(exerciseKey: "lowRow")) == "Next: Seated Low Row · set 1")
    }
}

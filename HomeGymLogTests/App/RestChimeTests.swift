import Foundation
import Testing
@testable import HomeGymLog

/// m5-haptics AC-14: the chime seam's shape. A smoke test only: the unit suites must not touch the audio session, so
/// `.silent()` has nothing observable and `.live()` is only constructed; the real guard is `FeedbackSourceTests`.
@MainActor
@Suite struct RestChimeTests {
    @Test("a counting double counts every play")
    func countingDouble() {
        var plays = 0
        let chime = RestChime(play: { plays += 1 })
        chime.play()
        chime.play()
        #expect(plays == 2)
    }

    @Test(".silent().play() returns, and .live() can be built repeatedly without playing")
    func smoke() {
        RestChime.silent().play()
        // No expectation: nothing is observable without touching the audio session (AC-14). The test fails only if
        // building `.live()` or a silent play traps.
        for _ in 0..<3 { _ = RestChime.live() }
    }
}

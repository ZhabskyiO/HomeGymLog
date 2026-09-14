import Foundation
import Testing
@testable import HomeGymLog

/// `RestText` edges past spec 5.2's rows: singular and plural in both parts at once, minutes past the first hour, and the
/// label a boundary instant produces through `RestTimer.remainingSeconds`.
@MainActor
@Suite struct RestTextEdgeTests {
    @Test("spoken: singular and plural in each part independently", arguments: [
        (61, "1 minute 1 second"),        // both singular: fails if either part pluralises from the other's count
        (121, "2 minutes 1 second"),
        (119, "1 minute 59 seconds"),
        (59, "59 seconds"),
        (2, "2 seconds"),
        (3660, "61 minutes"),             // 2 minutes 0 seconds' pattern past the hour: no "0 seconds", no hours
        (3661, "61 minutes 1 second"),
    ])
    func spokenPlurals(seconds: Int, expected: String) {
        #expect(RestText.spoken(seconds: seconds) == expected)
    }

    @Test("clock: the last second of the first hour, past it, and negatives", arguments: [
        (3599, "59:59"), (3601, "60:01"), (36_000, "600:00"), (59, "0:59"), (-1, "0:00"), (Int.min, "0:00"),
    ])
    func clockEdges(seconds: Int, expected: String) {
        #expect(RestText.clock(seconds: seconds) == expected)
    }

    /// The label the card draws for a gap just over and just under a minute (instants near the reference date, where the
    /// gap is exact). Fails if either the rounding or the formatting drops a second.
    @Test("a gap of 60.0000001 s reads 1:01, 59.9999 s reads 1:00, 0.0000001 s reads 0:01", arguments: [
        (60.0000001, "1:01", "1 minute 1 second"), (59.9999, "1:00", "1 minute"), (0.0000001, "0:01", "1 second"),
    ])
    func labelAtBoundary(left: Double, clock: String, spoken: String) {
        let seconds = RestTimer.remainingSeconds(endsAt: Date(timeIntervalSinceReferenceDate: left),
                                                 now: Date(timeIntervalSinceReferenceDate: 0))
        #expect(RestText.clock(seconds: seconds) == clock)
        #expect(RestText.spoken(seconds: seconds) == spoken)
    }
}

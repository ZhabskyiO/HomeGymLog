#if DEBUG
import Foundation
import Testing
@testable import HomeGymLog

/// AC-23 (parser): `-progressExercise <key>` yields the raw key; absent or trailing → nil.
@MainActor
@Suite struct DebugProgressExerciseTests {
    @Test("the value after the flag, raw")
    func value() {
        #expect(DebugProgressExercise.parse(arguments: ["-seed", "midProgram", "-tab", "progress", "-progressExercise", "goblet"]) == "goblet")
        #expect(DebugProgressExercise.parse(arguments: ["-progressExercise", "nope"]) == "nope")
    }

    @Test("absent or trailing flag → nil")
    func missing() {
        #expect(DebugProgressExercise.parse(arguments: ["-seed", "midProgram", "-tab", "progress"]) == nil)
        #expect(DebugProgressExercise.parse(arguments: []) == nil)
        #expect(DebugProgressExercise.parse(arguments: ["-progressExercise"]) == nil)
    }
}
#endif

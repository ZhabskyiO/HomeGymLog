import Foundation
import Testing
@testable import HomeGymLog

/// One row of spec 5.1: event, Haptics, Sound, expected cue (typed from the spec's table).
struct FeedbackCueRow: Sendable, CustomTestStringConvertible {
    let event: FeedbackEvent
    let haptics: Bool
    let sound: Bool
    let expected: FeedbackCue?
    var testDescription: String { "\(event) H=\(haptics) S=\(sound)" }
}

/// Spec 5.1's ten rows (the two `workoutDone` rows with `*` for Sound are expanded to both values).
let feedbackCueTable: [FeedbackCueRow] = [
    FeedbackCueRow(event: .setLogged, haptics: true, sound: true, expected: FeedbackCue(haptic: .impact, chime: false)),
    FeedbackCueRow(event: .setLogged, haptics: true, sound: false, expected: FeedbackCue(haptic: .impact, chime: false)),
    FeedbackCueRow(event: .setLogged, haptics: false, sound: true, expected: nil),
    FeedbackCueRow(event: .setLogged, haptics: false, sound: false, expected: nil),
    FeedbackCueRow(event: .restFinished, haptics: true, sound: true, expected: FeedbackCue(haptic: .success, chime: true)),
    FeedbackCueRow(event: .restFinished, haptics: true, sound: false, expected: FeedbackCue(haptic: .success, chime: false)),
    FeedbackCueRow(event: .restFinished, haptics: false, sound: true, expected: FeedbackCue(haptic: nil, chime: true)),
    FeedbackCueRow(event: .restFinished, haptics: false, sound: false, expected: nil),
    FeedbackCueRow(event: .workoutDone, haptics: true, sound: true, expected: FeedbackCue(haptic: .success, chime: false)),
    FeedbackCueRow(event: .workoutDone, haptics: true, sound: false, expected: FeedbackCue(haptic: .success, chime: false)),
    FeedbackCueRow(event: .workoutDone, haptics: false, sound: true, expected: nil),
    FeedbackCueRow(event: .workoutDone, haptics: false, sound: false, expected: nil),
]

/// AC-11: the cue table of spec 5.1 and the preference keys.
@Suite struct FeedbackCuesTests {
    @Test("cue(for:haptics:sound:) matches spec 5.1", arguments: feedbackCueTable)
    func cueTable(row: FeedbackCueRow) {
        #expect(FeedbackCues.cue(for: row.event, haptics: row.haptics, sound: row.sound) == row.expected)
    }

    @Test("the table covers every event and preference pair exactly once")
    func tableIsComplete() {
        let events: [FeedbackEvent] = [.setLogged, .restFinished, .workoutDone]
        for event in events {
            for haptics in [true, false] {
                for sound in [true, false] {
                    let rows = feedbackCueTable.filter { $0.event == event && $0.haptics == haptics && $0.sound == sound }
                    #expect(rows.count == 1, "\(event) H=\(haptics) S=\(sound)")
                }
            }
        }
        #expect(feedbackCueTable.count == 12)
    }

    @Test("preference keys and default")
    func keys() {
        #expect(FeedbackCues.hapticsKey == "hapticsEnabled")
        #expect(FeedbackCues.soundKey == "soundEnabled")
        #expect(FeedbackCues.defaultEnabled == true)
    }
}

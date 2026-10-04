import Foundation

/// Strings for the rest card and the rest-end notification. `RestTimer` returns numbers and `RestNext`; this turns them
/// into text (the Engine stays text-free). The six card strings the Live Activity also draws are typed once in the
/// shared `RestActivityText` (`HomeGymLogShared/`) and aliased here.
enum RestText {
    static let title = RestActivityText.title
    static let addLabel = RestActivityText.addLabel
    static let skipLabel = RestActivityText.skipLabel
    static let addAccessibility = RestActivityText.addAccessibility
    static let skipAccessibility = RestActivityText.skipAccessibility
    /// The notification title and the VoiceOver announcement at the end of a rest.
    static let restOver = RestActivityText.restOver
    static let notificationBody = "Time for your next set."

    /// "m:ss" with minutes uncapped: 62 → "1:02", 632 → "10:32", 3 600 → "60:00". Negative → "0:00".
    static func clock(seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    /// The countdown's VoiceOver value: 62 → "1 minute 2 seconds", 60 → "1 minute", 5 → "5 seconds", 0 → "0 seconds".
    /// The minutes part only when there are minutes; the seconds part when there are seconds or no minutes; singular at 1.
    static func spoken(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60, remainder = clamped % 60
        var parts: [String] = []
        if minutes > 0 { parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes") }
        if remainder > 0 || minutes == 0 { parts.append(remainder == 1 ? "1 second" : "\(remainder) seconds") }
        return parts.joined(separator: " ")
    }

    /// What follows "Next: ": "set 2 of 3", or "Seated Low Row · set 1" (the key itself when it is not in the library).
    static func next(_ next: RestNext) -> String {
        switch next {
        case .firstSet(let exerciseKey): return "\(WorkoutText.exerciseName(key: exerciseKey)) · set 1"
        case .set(let number, let count): return "set \(number) of \(count)"
        }
    }

    /// The whole "Next: …" line under the countdown, on the rest card and in the Live Activity: "Next: set 2 of 3".
    static func nextLine(_ next: RestNext) -> String {
        RestActivityText.nextPrefix + self.next(next)
    }
}

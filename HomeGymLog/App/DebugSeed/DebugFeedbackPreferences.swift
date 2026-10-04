#if DEBUG
import Foundation

/// The Haptics and Sound preferences a `-seed` launch starts with (nil = not given, the default `true` stays).
struct FeedbackSeedPreferences: Equatable {
    let haptics: Bool?
    let sound: Bool?
}

/// A `-haptics` or `-sound` argument followed by anything but `on` / `off` (`""` when it is the last argument).
enum DebugFeedbackError: Error, Equatable {
    case unknownValue(argument: String, value: String)
}

/// `-haptics on|off` and `-sound on|off` (m5-haptics 4.3): the root writes each given value into the seed's throwaway
/// preferences suite, so a screenshot recipe reads like the screen
/// (`xcrun simctl launch <udid> <bundle> -seed midProgram -tab settings -haptics off`). Honoured only inside a `-seed`
/// launch; compiled out of Release with the whole file.
enum DebugFeedbackPreferences {
    static func parse(arguments: [String]) throws -> FeedbackSeedPreferences {
        FeedbackSeedPreferences(haptics: try onOff("-haptics", in: arguments),
                                sound: try onOff("-sound", in: arguments))
    }

    /// nil when `argument` is absent; true / false for `on` / `off`; throws for any other value or none. Shared with
    /// `DebugLiveActivity` (`-liveActivity on|off`).
    static func onOff(_ argument: String, in arguments: [String]) throws -> Bool? {
        guard let index = arguments.firstIndex(of: argument) else { return nil }
        let next = index + 1 < arguments.count ? arguments[index + 1] : ""
        switch next {
        case "on": return true
        case "off": return false
        default: throw DebugFeedbackError.unknownValue(argument: argument, value: next)
        }
    }
}
#endif

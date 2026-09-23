#if DEBUG
import Foundation

/// `-holdBanner` keeps the Home missed-action banner up with no auto-dismiss, so a frozen-clock screenshot can catch it.
/// Sibling of `DebugInitialTab`; compiled out of Release with the whole file, which is why the argument string lives
/// nowhere else in the app. `xcrun simctl launch <udid> <bundle> -seed missed -missedDayPolicy shift -holdBanner`.
enum DebugBannerHold {
    /// True when the flag is present; nil when it is absent, so a launch without it leaves the environment value nil
    /// exactly as Release does.
    static func parse(arguments: [String]) -> Bool? {
        arguments.contains("-holdBanner") ? true : nil
    }
}
#endif

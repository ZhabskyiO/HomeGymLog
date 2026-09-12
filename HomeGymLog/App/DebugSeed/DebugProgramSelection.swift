#if DEBUG
import Foundation

/// Debug launch arguments that preselect a week and/or a day on the Program tab, so every card state can be
/// screenshot without taps (scripted taps are refused on this machine). Sibling of `DebugSeed`; compiled out
/// of Release with the whole file, which is why the argument strings live nowhere else in the app.
/// `xcrun simctl launch <udid> <bundle> -seed missed -programWeek 2 -programDay 2`
enum DebugProgramSelection {
    /// Raw values: no range check and no throw, because the use-time validity rule in
    /// `ProgramTabStats.focus` already turns a bad week or day into "follow today". nil when neither flag
    /// yielded a value, so a launch without them leaves the environment value nil exactly as Release does.
    static func parse(arguments: [String]) -> ProgramTabPreselection? {
        let week = value(of: "-programWeek", in: arguments)
        let day = value(of: "-programDay", in: arguments)
        guard week != nil || day != nil else { return nil }
        return ProgramTabPreselection(week: week, day: day)
    }

    /// The integer after `flag`; nil when the flag is absent, last, or followed by a non-integer.
    private static func value(of flag: String, in arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }
}

/// `-tab program` opens the shell on that tab. An unknown or missing name yields nil (Home).
enum DebugInitialTab {
    static func parse(arguments: [String]) -> AppTab? {
        guard let index = arguments.firstIndex(of: "-tab"), arguments.indices.contains(index + 1) else { return nil }
        return AppTab(rawValue: arguments[index + 1])
    }
}
#endif

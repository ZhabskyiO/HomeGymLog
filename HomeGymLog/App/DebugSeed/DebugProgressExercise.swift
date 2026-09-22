#if DEBUG
import Foundation

/// `-progressExercise goblet` preselects a Progress chip on launch, so a chart can be screenshot without taps. Sibling of
/// `DebugInitialTab`; compiled out of Release with the whole file. Works with or without `-seed`.
enum DebugProgressExercise {
    /// The raw value after the flag (an unknown key falls back to the first chip on screen); nil when absent or last.
    static func parse(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "-progressExercise"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif

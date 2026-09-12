import Foundation

/// A week and/or day the Program tab should open on instead of following today. Production type with no
/// `#if`: the environment value defaults to nil and is only ever filled in by a Debug build's launch-argument
/// parser, so the screen needs no compile-time branch. Values are raw — the use-time validity rule in
/// `ProgramTabStats.focus` rejects out-of-range ones. Analogy: a nullable prop a test harness may inject.
struct ProgramTabPreselection: Equatable {
    /// 1-based week.
    let week: Int?
    /// 0 = Monday … 6 = Sunday.
    let day: Int?
}

#if DEBUG
import Foundation
import Testing
@testable import HomeGymLog

/// AC-22 (parser half): the debug preselection and initial-tab arguments are read raw, never validated and
/// never throwing. Out-of-range values are rejected later, by `ProgramTabStats.focus`.
@MainActor
@Suite struct DebugProgramSelectionTests {
    private func parse(_ arguments: [String]) -> ProgramTabPreselection? {
        DebugProgramSelection.parse(arguments: arguments)
    }

    @Test("a week and a day are both read")
    func bothArguments() {
        #expect(parse(["-seed", "missed", "-programWeek", "2", "-programDay", "2"]) == ProgramTabPreselection(week: 2, day: 2))
    }

    @Test("either argument works alone")
    func oneArgument() {
        #expect(parse(["-programWeek", "24"]) == ProgramTabPreselection(week: 24, day: nil))
        #expect(parse(["-programDay", "5"]) == ProgramTabPreselection(week: nil, day: 5))
    }

    @Test("a non-integer or missing value yields nil, never a throw")
    func badValues() {
        // Neither flag yielded a value, so there is no preselection at all (the Release shape).
        #expect(parse(["-programWeek", "x"]) == nil)
        #expect(parse(["app", "-programWeek"]) == nil)
        #expect(parse([]) == nil)
    }

    @Test("out-of-range values are kept raw")
    func rawValues() {
        #expect(parse(["-programDay", "7"]) == ProgramTabPreselection(week: nil, day: 7))
        #expect(parse(["-programDay", "-1"]) == ProgramTabPreselection(week: nil, day: -1))
    }

    @Test("the initial tab argument takes a tab name, nil for anything else")
    func initialTab() {
        #expect(DebugInitialTab.parse(arguments: ["-tab", "program"]) == .program)
        #expect(DebugInitialTab.parse(arguments: ["-tab", "settings"]) == .settings)
        #expect(DebugInitialTab.parse(arguments: ["-tab", "nope"]) == nil)
        #expect(DebugInitialTab.parse(arguments: ["-tab"]) == nil)
        #expect(DebugInitialTab.parse(arguments: []) == nil)
    }
}
#endif

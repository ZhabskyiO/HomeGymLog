#if DEBUG
import Foundation
import Testing
@testable import HomeGymLog

/// Argument shapes a hand-typed `simctl launch` produces that AC-22 does not list. These pin the parsers'
/// documented behavior (first occurrence wins, exact-case tab names) so a rewrite has to be deliberate.
@MainActor
@Suite struct DebugProgramSelectionEdgeTests {
    private func parse(_ arguments: [String]) -> ProgramTabPreselection? {
        DebugProgramSelection.parse(arguments: arguments)
    }

    @Test("a repeated flag takes the first occurrence")
    func repeatedFlags() {
        #expect(parse(["-programWeek", "2", "-programWeek", "5"]) == ProgramTabPreselection(week: 2, day: nil))
        #expect(parse(["-programDay", "1", "-programDay", "4"]) == ProgramTabPreselection(week: nil, day: 1))
    }

    @Test("a flag whose value is the next flag yields nil for it and still reads the next flag")
    func flagAsValue() {
        #expect(parse(["-programWeek", "-programDay", "3"]) == ProgramTabPreselection(week: nil, day: 3))
    }

    @Test("a value too large for Int yields nil instead of trapping")
    func overflowingValue() {
        #expect(parse(["-programWeek", "99999999999999999999", "-programDay", "3"]) == ProgramTabPreselection(week: nil, day: 3))
    }

    @Test("the arguments are read wherever they sit in the list")
    func positionDoesNotMatter() {
        #expect(parse(["/path/app", "-programDay", "6", "-seed", "missed", "-units", "kg", "-programWeek", "9"])
                == ProgramTabPreselection(week: 9, day: 6))
    }

    @Test("every tab name opens that tab", arguments: AppTab.allCases)
    func everyTabName(tab: AppTab) {
        #expect(DebugInitialTab.parse(arguments: ["-seed", "midProgram", "-tab", tab.rawValue]) == tab)
    }

    @Test("tab names are matched exactly, so a capitalized name is ignored")
    func tabNameIsCaseSensitive() {
        #expect(DebugInitialTab.parse(arguments: ["-tab", "Program"]) == nil)
        #expect(DebugInitialTab.parse(arguments: ["-tab", "PROGRAM"]) == nil)
        #expect(DebugInitialTab.parse(arguments: ["-TAB", "program"]) == nil)
    }

    @Test("a repeated tab flag takes the first occurrence")
    func repeatedTabFlag() {
        #expect(DebugInitialTab.parse(arguments: ["-tab", "program", "-tab", "settings"]) == .program)
    }

    @Test("an empty tab name is not a tab")
    func emptyTabName() {
        #expect(DebugInitialTab.parse(arguments: ["-tab", ""]) == nil)
    }
}
#endif

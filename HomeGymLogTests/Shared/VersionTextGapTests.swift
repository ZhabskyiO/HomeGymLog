import Testing
@testable import HomeGymLog

/// m5-release test-writer gap pass: `SettingsText.versionText` passes non-empty values through verbatim (no trimming,
/// no reformatting) and treats "both empty" as missing. The implementer's suite covers ("1.0", "1"), ("2.3", "45")
/// and each single nil or empty side.
@MainActor
@Suite struct VersionTextGapTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let short: String?
        let build: String?
        let expected: String
        var testDescription: String { "(\(short.map { "\"\($0)\"" } ?? "nil"), \(build.map { "\"\($0)\"" } ?? "nil")) → \(expected)" }
    }

    @Test("versionText keeps a three-part version and a build with spaces verbatim; both empty is the dash",
          arguments: [
              Case(short: "1.0.1", build: "42", expected: "1.0.1 (42)"),
              Case(short: "1.0", build: "1 beta", expected: "1.0 (1 beta)"),
              Case(short: "", build: "", expected: "\u{2014}"),
              Case(short: nil, build: "", expected: "\u{2014}"),
          ])
    func verbatim(_ testCase: Case) {
        #expect(SettingsText.versionText(short: testCase.short, build: testCase.build) == testCase.expected)
    }
}

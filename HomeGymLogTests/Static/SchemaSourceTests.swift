import Foundation
import Testing

/// AC-41 (source half): an in-memory store cannot notice a stored property without a default, but an existing
/// on-disk store then fails to open. This reads `HomeGymLog/Models/LoggedSet.swift` (via `#filePath`, like
/// `ClockUsageTests`) and requires the declaration with its default, outside comments.
@Suite struct SchemaSourceTests {
    private static var loggedSetSource: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog/Models/LoggedSet.swift")
    }

    private static var workoutLogSource: URL {
        loggedSetSource.deletingLastPathComponent().appendingPathComponent("WorkoutLog.swift")
    }

    /// Code lines of a source file with `//` comments removed.
    private static func codeLines(_ url: URL) throws -> [String] {
        try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines).map { line -> String in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
    }

    @Test("LoggedSet declares `var rpeSkipped: Bool = false` exactly once in code")
    func rpeSkippedKeepsItsDefault() throws {
        let code = try Self.codeLines(Self.loggedSetSource)
        #expect(code.count > 10, "the model file was read")
        let declarations = code.filter { $0.trimmingCharacters(in: .whitespaces) == "var rpeSkipped: Bool = false" }
        #expect(declarations.count == 1)
    }

    /// m3-rest-timer AC-29: both rest instants stay declared and optional, no required default (an optional migrates an
    /// existing store with or without `= nil`; a non-optional field without a default would stop it from opening).
    @Test("WorkoutLog declares `var restStartedAt: Date?` and `var restEndsAt: Date?` (optionally `= nil`) exactly once each")
    func restInstantsStayOptional() throws {
        let code = try Self.codeLines(Self.workoutLogSource)
        #expect(code.count > 10, "the model file was read")
        let trimmed = code.map { $0.trimmingCharacters(in: .whitespaces) }
        func count(_ pattern: String) -> Int {
            trimmed.filter { $0.range(of: pattern, options: .regularExpression) != nil }.count
        }
        #expect(count(#"^var restStartedAt: Date\?( = nil)?$"#) == 1)
        #expect(count(#"^var restEndsAt: Date\?( = nil)?$"#) == 1)
    }
}

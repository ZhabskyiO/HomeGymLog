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

    @Test("LoggedSet declares `var rpeSkipped: Bool = false` exactly once in code")
    func rpeSkippedKeepsItsDefault() throws {
        let text = try String(contentsOf: Self.loggedSetSource, encoding: .utf8)
        let code = text.components(separatedBy: .newlines).map { line -> String in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
        #expect(code.count > 10, "the model file was read")
        let declarations = code.filter { $0.trimmingCharacters(in: .whitespaces) == "var rpeSkipped: Bool = false" }
        #expect(declarations.count == 1)
    }
}

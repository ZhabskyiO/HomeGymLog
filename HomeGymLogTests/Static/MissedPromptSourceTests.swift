import Foundation
import Testing

/// AC-27 (prompt switch): the DEBUG prompt switch reaches the app only from the root's seed branch. `forcesMissedDayPrompt`
/// is read once, inside `if let seed = try DebugSeed.parse(…)` and before that block's `#endif`; `AppClock.swift` declares
/// the `missedPromptEnabled` `@Entry` nil by default; one line in the app sets it. Mirrors
/// `RestNotifierSourceTests.silentOnlyInSeedBranch`; stable tokens only, `//` comments stripped.
@Suite struct MissedPromptSourceTests {
    /// `<repo>/HomeGymLog`, derived from `<repo>/HomeGymLogTests/Static/…`.
    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    /// Lines with `//` comments removed.
    private static func codeLines(_ file: URL) throws -> [String] {
        try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines).map { line in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
    }

    @Test("HomeGymLogApp reads forcesMissedDayPrompt on exactly one line, inside the -seed branch and before its #endif")
    func forcesOnlyInSeedBranch() throws {
        let lines = try Self.codeLines(Self.appSourceRoot.appendingPathComponent("App/HomeGymLogApp.swift"))
        let hits = lines.indices.filter { lines[$0].contains("forcesMissedDayPrompt") }
        #expect(hits.count == 1)
        let seedBranch = try #require(lines.firstIndex { $0.contains("DebugSeed.parse(") })
        let endif = try #require(lines.indices.first { $0 > seedBranch && lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("#endif") })
        let hit = try #require(hits.first)
        #expect(hit > seedBranch)
        #expect(hit < endif)
    }

    @Test("AppClock declares the missedPromptEnabled @Entry on exactly one line: Bool?, nil by default or no initializer")
    func entryNilByDefault() throws {
        let entries = try Self.codeLines(Self.appSourceRoot.appendingPathComponent("App/AppClock.swift"))
            .filter { $0.contains("@Entry") && $0.contains("missedPromptEnabled") }
        #expect(entries.count == 1)
        let line = try #require(entries.first).trimmingCharacters(in: .whitespaces)
        #expect(line.contains("Bool?"))
        let initializer = line.components(separatedBy: "=").dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
        #expect(initializer == "" || initializer == "nil", "initializer: \(initializer)")
    }

    @Test("across the app target exactly one code line sets .environment(\\.missedPromptEnabled, in App/HomeGymLogApp.swift")
    func environmentSetOnce() throws {
        let enumerator = try #require(FileManager.default.enumerator(at: Self.appSourceRoot, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count > 40, "the whole app target was scanned")
        var found: [String] = []
        for file in files {
            for line in try Self.codeLines(file) where line.contains(".environment(\\.missedPromptEnabled") {
                found.append(file.path.replacingOccurrences(of: Self.appSourceRoot.path + "/", with: ""))
            }
        }
        #expect(found == ["App/HomeGymLogApp.swift"])
    }
}

import Foundation
import Testing

/// AC-30 (static half): seeded runs never reach the system notification center and production never overrides the live
/// notifier or chime. `.silent()` is set once per seam, inside the root's DEBUG seed branch; a `.live()` on a line that names the rest
/// notifier appears only as the `restNotifier` environment default. Reads the checked-in sources via `#filePath`, comments
/// stripped.
@Suite struct RestNotifierSourceTests {
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

    @Test("HomeGymLogApp sets .silent() on exactly two lines (rest notifier, rest chime), inside the -seed branch before its #endif")
    func silentOnlyInSeedBranch() throws {
        let lines = try Self.codeLines(Self.appSourceRoot.appendingPathComponent("App/HomeGymLogApp.swift"))
        let silentLines = lines.indices.filter { lines[$0].contains(".silent()") }
        #expect(silentLines.count == 2)
        #expect(silentLines.filter { lines[$0].contains("restNotifier") }.count == 1)
        #expect(silentLines.filter { lines[$0].contains("restChime") }.count == 1)
        let seedBranch = try #require(lines.firstIndex { $0.contains("DebugSeed.parse(") })
        let endif = try #require(lines.indices.first { $0 > seedBranch && lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("#endif") })
        for silent in silentLines {
            #expect(silent > seedBranch)
            #expect(silent < endif)
        }
    }

    @Test("a .live() on a line naming the rest notifier appears once in the app target: the restNotifier @Entry default")
    func liveOnlyAsEntryDefault() throws {
        let enumerator = try #require(FileManager.default.enumerator(at: Self.appSourceRoot, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count > 40, "the whole app target was scanned")
        var found: [(path: String, line: String)] = []
        for file in files {
            for line in try Self.codeLines(file)
            where line.contains(".live()") && (line.contains("RestNotifier") || line.contains("restNotifier")) {
                found.append((file.path.replacingOccurrences(of: Self.appSourceRoot.path + "/", with: ""), line))
            }
        }
        #expect(found.count == 1)
        #expect(found.first?.path == "App/AppClock.swift")
        #expect(found.first?.line.contains("@Entry var restNotifier") == true)
    }
}

import Foundation
import Testing

/// AC-39 (scan half): the quoted hyphenated seed names (the workout seeds, and the missed-day seeds added by m4-missed-day)
/// exist only in `App/DebugSeed/`, which is compiled out of Release. Unquoted identifiers such as `WorkoutSummary` do not
/// count. Each name must be found there, so an empty scan fails.
@Suite struct SeedNameScanTests {
    private static let names = ["\"wo-start\"", "\"wo-swipe\"", "\"wo-rpe\"", "\"wo-adjust\"", "\"wo-rest\"", "\"summary\"",
                                "\"wo-detail\"", "\"wo-swap\"", "\"wo-swap-rdl\"", "\"wo-notes\"",
                                "\"missed-several\"", "\"missed-shifted\"", "\"missed-skipped\""]

    /// `<repo>/HomeGymLog`, derived from `<repo>/HomeGymLogTests/Static/…`.
    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    /// Relative path → code with `//` comments removed, for every Swift file of the app target.
    private static func sources() throws -> [(path: String, code: String)] {
        let enumerator = try #require(FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        return try files.map { file in
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines).map { line -> String in
                if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
                return line
            }
            return (file.path.replacingOccurrences(of: appSourceRoot.path + "/", with: ""), lines.joined(separator: "\n"))
        }
    }

    @Test("quoted workout seed names appear only under App/DebugSeed/, and each appears there")
    func onlyInDebugSeed() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        let offenders = all.filter { source in
            !source.path.hasPrefix("App/DebugSeed/") && Self.names.contains { source.code.contains($0) }
        }.map(\.path)
        #expect(offenders == [])
        let debugSeed = all.filter { $0.path.hasPrefix("App/DebugSeed/") }
        for name in Self.names {
            #expect(debugSeed.contains { $0.code.contains(name) }, "\(name) is declared in App/DebugSeed/")
        }
    }

    /// m3-exercise-tools AC-29: the Bool adjust preview is gone, generalized into one nil-by-default sheet preview entry.
    @Test("no app code names workoutAdjustPreview; App/AppClock.swift declares the workoutSheetPreview @Entry on exactly one line")
    func sheetPreviewEntry() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        let oldName = all.filter { $0.code.contains("workoutAdjustPreview") }.map(\.path)
        #expect(oldName == [])
        let appClock = try #require(all.first { $0.path == "App/AppClock.swift" })
        let entryLines = appClock.code.components(separatedBy: "\n").filter { $0.contains("@Entry") && $0.contains("workoutSheetPreview") }
        #expect(entryLines.count == 1)
    }
}

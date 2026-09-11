import Foundation
import Testing

/// AC-27: no source under `Features/`, `Models/`, `Engine/` (nor `Shared/`) reads the device clock or the
/// current calendar; across the whole app target the two calls appear only in `App/AppClock.swift`.
/// Reads the checked-in sources via `#filePath`, so it runs wherever the repository is.
@Suite struct ClockUsageTests {
    private static let forbidden = ["Date()", "Calendar.current"]

    /// `<repo>/HomeGymLog`, derived from this file's location `<repo>/HomeGymLogTests/Static/…`.
    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    private static func swiftFiles(under folder: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        try #require(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) && isDirectory.boolValue,
                     "missing folder \(folder.path)")
        let enumerator = try #require(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Lines with `//` comments removed, so a doc comment mentioning `Date()` does not count.
    private static func codeLines(of file: URL) throws -> [String] {
        try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines).map { line in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
    }

    /// Relative paths of files whose code (not comments) contains one of the forbidden calls.
    private static func offenders(under folder: URL) throws -> [String] {
        var found: [String] = []
        for file in try swiftFiles(under: folder) {
            let lines = try codeLines(of: file)
            if lines.contains(where: { line in forbidden.contains { line.contains($0) } }) {
                found.append(file.path.replacingOccurrences(of: appSourceRoot.path + "/", with: ""))
            }
        }
        return found.sorted()
    }

    @Test("Features, Models, Engine and Shared never call Date() or Calendar.current", arguments: ["Features", "Models", "Engine", "Shared"])
    func noClockReads(folder: String) throws {
        let url = Self.appSourceRoot.appendingPathComponent(folder, isDirectory: true)
        #expect(try Self.swiftFiles(under: url).count > 0, "\(folder) has sources to scan")
        #expect(try Self.offenders(under: url) == [])
    }

    @Test("across the app target the only clock reader is App/AppClock.swift")
    func onlyAppClockReadsTheClock() throws {
        #expect(try Self.swiftFiles(under: Self.appSourceRoot).count > 40, "the whole app target was scanned")
        #expect(try Self.offenders(under: Self.appSourceRoot) == ["App/AppClock.swift"])
    }
}

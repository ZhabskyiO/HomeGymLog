import Foundation
import Testing

/// AC-24 (Progress source rules). A "hop" is a `.program` member access not followed by an identifier character (so
/// `.programID` does not count) and not preceded by `self`: reading a session's program costs ~330 µs per row on iOS 17.5,
/// so only `ProgressSnapshotBuilder.tops(key:` (inside the screen's task) may do it. Stable tokens only, `//` comments stripped.
@Suite struct ProgressSourceTests {
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

    private static let hop = try! NSRegularExpression(pattern: #"(?<!self)\.program(?![A-Za-z0-9_])"#)

    static func isHop(_ line: String) -> Bool {
        hop.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }

    /// Line indexes from the line holding `token` to the line closing the brace opened after it.
    private static func bodyRange(of token: String, in lines: [String]) -> ClosedRange<Int>? {
        guard let start = lines.firstIndex(where: { $0.contains(token) }) else { return nil }
        var depth = 0
        var opened = false
        for index in start..<lines.count {
            let text = index == start ? String(lines[index][lines[index].range(of: token)!.lowerBound...]) : lines[index]
            for character in text {
                if character == "{" { depth += 1; opened = true }
                if character == "}" { depth -= 1 }
                if opened && depth == 0 { return start...index }
            }
        }
        return nil
    }

    @Test("the hop pattern: .program counts; .programID, self.program and \\.programCreatedAt do not")
    func hopPattern() {
        #expect(Self.isHop("session.program?.id"))
        #expect(Self.isHop("let p = row.program"))
        #expect(!Self.isHop("$0.programID == id"))
        #expect(!Self.isHop("self.program.id"))
        #expect(!Self.isHop("\\.programCreatedAt"))
        #expect(!Self.isHop("let program = x"))
    }

    @Test("ProgressSnapshotBuilder hops to a session's program only inside tops(key:, and does so there")
    func builderHops() throws {
        let lines = try Self.codeLines(Self.appSourceRoot.appendingPathComponent("Models/ProgressSnapshotBuilder.swift"))
        let range = try #require(Self.bodyRange(of: "func tops(key:", in: lines))
        let hops = lines.indices.filter { Self.isHop(lines[$0]) }
        #expect(!hops.isEmpty, "tops(key: reads session.program")
        #expect(hops.allSatisfy { range.contains($0) }, "hop lines \(hops.map { $0 + 1 }) outside tops \(range.lowerBound + 1)...\(range.upperBound + 1)")
    }

    @Test("HomeGymLogApp parses -progressExercise on exactly one line, after DebugSeed.parse( and before its #endif")
    func parseInDebugBlock() throws {
        let lines = try Self.codeLines(Self.appSourceRoot.appendingPathComponent("App/HomeGymLogApp.swift"))
        let hits = lines.indices.filter { lines[$0].contains("DebugProgressExercise.parse(") }
        #expect(hits.count == 1)
        let seedBranch = try #require(lines.firstIndex { $0.contains("DebugSeed.parse(") })
        let endif = try #require(lines.indices.first { $0 > seedBranch && lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("#endif") })
        let hit = try #require(hits.first)
        #expect(hit > seedBranch)
        #expect(hit < endif)
    }

    @Test("AppClock declares the progressPreselection @Entry on exactly one line: String?, nil by default or no initializer")
    func entryNilByDefault() throws {
        let entries = try Self.codeLines(Self.appSourceRoot.appendingPathComponent("App/AppClock.swift"))
            .filter { $0.contains("@Entry") && $0.contains("progressPreselection") }
        #expect(entries.count == 1)
        let line = try #require(entries.first).trimmingCharacters(in: .whitespaces)
        #expect(line.contains("String?"))
        let initializer = line.components(separatedBy: "=").dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
        #expect(initializer == "" || initializer == "nil", "initializer: \(initializer)")
    }

    @Test("across the app target exactly one code line sets .environment(\\.progressPreselection, in App/HomeGymLogApp.swift")
    func environmentSetOnce() throws {
        var found: [String] = []
        let files = try Self.appFiles()
        #expect(files.count > 40, "the whole app target was scanned")
        for file in files {
            for line in try Self.codeLines(file) where line.contains(".environment(\\.progressPreselection") {
                found.append(Self.relative(file))
            }
        }
        #expect(found == ["App/HomeGymLogApp.swift"])
    }

    private static func appFiles() throws -> [URL] {
        let enumerator = try #require(FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    private static func relative(_ file: URL) -> String {
        file.path.replacingOccurrences(of: appSourceRoot.path + "/", with: "")
    }

    @Test("no file under Features/Progress/ hops to a session's program or calls finishedLogs(")
    func featuresNoHop() throws {
        let folder = Self.appSourceRoot.appendingPathComponent("Features/Progress", isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count >= 5, "the Progress feature folder was scanned")
        for file in files {
            let lines = try Self.codeLines(file)
            let offenders = lines.indices.filter { Self.isHop(lines[$0]) || lines[$0].contains("finishedLogs(") }
            #expect(offenders.isEmpty, "\(file.lastPathComponent) lines \(offenders.map { $0 + 1 })")
        }
    }

    @Test("ProgressSnapshotBuilder never calls finishedLogs(")
    func noFinishedLogs() throws {
        let lines = try Self.codeLines(Self.appSourceRoot.appendingPathComponent("Models/ProgressSnapshotBuilder.swift"))
        #expect(lines.count > 20)
        #expect(!lines.contains { $0.contains("finishedLogs(") })
    }
}

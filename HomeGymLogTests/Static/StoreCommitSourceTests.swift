import Foundation
import Testing

/// Plan Step 1 (NB3) and AC-26's "updates never rehearse": scratch contexts are opened only by `StoreCommit`, so every
/// insert rehearsal goes through the one helper. Reads the checked-in sources via `#filePath`, `//` comments stripped.
@Suite struct StoreCommitSourceTests {
    /// `<repo>/HomeGymLog/Models`, derived from `<repo>/HomeGymLogTests/Static/…`.
    private static var modelsRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog/Models", isDirectory: true)
    }

    /// Lines with `//` comments removed, so a doc comment naming a token does not count.
    private static func codeLines(_ file: URL) throws -> [String] {
        try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines).map { line in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
    }

    @Test("across Models/*.swift the token ModelContext( appears only in StoreCommit.swift")
    func scratchContextsOnlyInStoreCommit() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.modelsRoot, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(files.count > 5, "the Models folder was scanned")
        var found: [String] = []
        for file in files where try Self.codeLines(file).contains(where: { $0.contains("ModelContext(") }) {
            found.append(file.lastPathComponent)
        }
        #expect(found.sorted() == ["StoreCommit.swift"])
    }

    /// AC-26 "the second call does not rehearse": no runtime signal tells the two shapes apart (a refusing store fails
    /// both), so the order is pinned in the source: the update branch's `StoreCommit.commit(` comes before the one
    /// rehearsal call. `StoreCommit.commitInsert(` does not contain that token, so only the field-writer save counts.
    @Test("ExerciseNoteStore calls rehearseInsert( exactly once, after the update branch's StoreCommit.commit(")
    func noteUpdatesNeverRehearse() throws {
        let lines = try Self.codeLines(Self.modelsRoot.appendingPathComponent("ExerciseNoteStore.swift"))
        let rehearsals = lines.indices.filter { lines[$0].contains("rehearseInsert(") }
        #expect(rehearsals.count == 1)
        let updateCommit = try #require(lines.firstIndex { $0.contains("StoreCommit.commit(") })
        let rehearsal = try #require(rehearsals.first)
        #expect(updateCommit < rehearsal)
    }
}

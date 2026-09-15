import Foundation
import Testing

/// The failed-save policy has one home (INSIGHTS "Failed-save revert order revised"): only `StoreCommit` calls
/// `rollback()`, and only the two insert writers (`WorkoutLogStore.start`, the note insert branch) use `commitInsert`.
/// Stable tokens only (`rollback()`, `StoreCommit.commitInsert(`), `//` comments stripped, whole app target scanned.
@Suite struct FailedSavePolicySourceTests {
    /// `<repo>/HomeGymLog`, derived from `<repo>/HomeGymLogTests/Static/…`.
    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    /// Relative path → code lines with `//` comments removed, for every Swift file of the app target.
    private static func sources() throws -> [(path: String, lines: [String])] {
        let enumerator = try #require(FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        return try files.map { file in
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines).map { line -> String in
                if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
                return line
            }
            return (file.path.replacingOccurrences(of: appSourceRoot.path + "/", with: ""), lines)
        }
    }

    /// Path → number of code lines containing `token`, for the files that contain it.
    private static func occurrences(of token: String) throws -> [String: Int] {
        var result: [String: Int] = [:]
        for source in try sources() {
            let count = source.lines.filter { $0.contains(token) }.count
            if count > 0 { result[source.path] = count }
        }
        return result
    }

    @Test("rollback() is called only in Models/StoreCommit.swift, once per helper")
    func rollbackOnlyInStoreCommit() throws {
        #expect(try Self.sources().count > 40, "the whole app target was scanned")
        #expect(try Self.occurrences(of: "rollback()") == ["Models/StoreCommit.swift": 2])
    }

    /// m4-missed-day: the shift and skip writers save through the field-writer helper, so `rollbackOnlyInStoreCommit` above
    /// fails if either calls `rollback()` itself.
    @Test("Models/ProgramStore.swift has exactly two code lines calling StoreCommit.commit(: the shift and skipMissed writers")
    func programStoreWritersCommit() throws {
        #expect(try Self.occurrences(of: "StoreCommit.commit(")["Models/ProgramStore.swift"] == 2)
    }

    @Test("StoreCommit.commitInsert( is called once each by ExerciseNoteStore.swift and WorkoutLogStore.swift")
    func commitInsertOnlyForInsertWriters() throws {
        #expect(try Self.occurrences(of: "StoreCommit.commitInsert(") == ["Models/ExerciseNoteStore.swift": 1, "Models/WorkoutLogStore.swift": 1])
    }
}

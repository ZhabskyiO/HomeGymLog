import Foundation
import Testing

/// AC-19 (backup half): what the backup code must never do, scanned over the app's source with `//` comments stripped.
/// The Engine codec imports only Foundation, never uses the built-in ISO date strategy, has one sorted encoder line, and
/// types no preference-key literal (the four reader scans pin each to one line); the file-name prefix lives in one place.
@Suite struct BackupSourceTests {
    /// `<repo>/HomeGymLog`, derived from `<repo>/HomeGymLogTests/Static/…`.
    static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    static func codeLines(_ url: URL) throws -> [String] {
        try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines).map { line in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
    }

    static func codeLines(_ relativePath: String) throws -> [String] {
        try codeLines(appSourceRoot.appendingPathComponent(relativePath))
    }

    /// Every `.swift` file under `folder` (relative to the app root), as (relative path, code lines).
    static func swiftFiles(under folder: String = "") throws -> [(path: String, lines: [String])] {
        let root = appSourceRoot.standardizedFileURL.path
        let base = folder.isEmpty ? appSourceRoot : appSourceRoot.appendingPathComponent(folder, isDirectory: true)
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        var files: [(String, [String])] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let path = String(url.standardizedFileURL.path.dropFirst(root.count + 1))
            files.append((path, try codeLines(url)))
        }
        return files.sorted { $0.0 < $1.0 }
    }

    /// (path, line) for every code line under the app root containing `token`.
    static func hits(_ token: String, under folder: String = "") throws -> [(path: String, line: String)] {
        try swiftFiles(under: folder).flatMap { file in file.lines.filter { $0.contains(token) }.map { (file.path, $0) } }
    }

    @Test("Engine/Backup has three files that import only Foundation")
    func engineImportsOnlyFoundation() throws {
        let files = try Self.swiftFiles(under: "Engine/Backup")
        #expect(files.map(\.path) == ["Engine/Backup/BackupCodec.swift", "Engine/Backup/BackupDocument.swift",
                                      "Engine/Backup/BackupValidation.swift"])
        for file in files {
            let imports = file.lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("import ") }
            #expect(imports == ["import Foundation"], "\(file.path)")
        }
    }

    @Test("the built-in .iso8601 date strategy appears nowhere in the app target")
    func noBuiltInISOStrategy() throws {
        let found = try Self.hits(".iso8601")
        #expect(found.isEmpty, "\(found.map(\.path))")
        let all = try Self.swiftFiles()
        #expect(all.count > 100, "the app source was read")
    }

    @Test("exactly one outputFormatting line, in BackupCodec.swift, with .sortedKeys")
    func oneSortedEncoder() throws {
        let found = try Self.hits("outputFormatting")
        #expect(found.count == 1)
        #expect(found.first?.path == "Engine/Backup/BackupCodec.swift")
        #expect(found.first?.line.contains(".sortedKeys") == true)
    }

    @Test("BackupCodec's two date formatters use the fractional and plain options, and decoding tries fractional then plain")
    func dateFormatterOptions() throws {
        let lines = try Self.codeLines("Engine/Backup/BackupCodec.swift").map { $0.trimmingCharacters(in: .whitespaces) }
        let options = lines.filter { $0.hasPrefix("formatter.formatOptions") }
        #expect(options == ["formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]",
                            "formatter.formatOptions = [.withInternetDateTime]"])
        #expect(lines.filter { $0.contains("fractional.date(from: text) ?? plain.date(from: text)") }.count == 1)
    }

    @Test("the backup file-name prefix literal is typed once, in BackupText.swift")
    func prefixOnce() throws {
        let found = try Self.hits("\"HomeGymLog-backup-\"")
        #expect(found.count == 1)
        #expect(found.first?.path == "Shared/BackupText.swift")
    }

    @Test("no preference-key literal under Engine/Backup (CodingKeys have no raw values)")
    func noPreferenceKeyLiterals() throws {
        let files = try Self.swiftFiles(under: "Engine/Backup")
        #expect(files.count == 3)
        for key in ["appearance", "missedDayPolicy", "reminderEnabled", "reminderMinutes", "hapticsEnabled", "soundEnabled"] {
            let found = files.flatMap { file in file.lines.filter { $0.contains("\"\(key)\"") } }
            #expect(found.isEmpty, "\(key): \(found)")
        }
        let codingKeys = files.flatMap(\.lines).filter { $0.contains("CodingKey") }
        #expect(!codingKeys.isEmpty)
        #expect(codingKeys.allSatisfy { !$0.contains(": String") }, "CodingKeys are plain, never String-backed")
    }

    /// The lines of `signature`'s function: from its line to the next line declaring a function (the
    /// `FeedbackSourceTests.functionBody` shape).
    static func functionBody(_ signature: String, in lines: [String]) throws -> ArraySlice<String> {
        let start = try #require(lines.firstIndex { $0.contains(signature) }, "\(signature)")
        let end = lines.indices.first { $0 > start && lines[$0].contains(" func ") } ?? lines.endIndex
        return lines[start..<end]
    }

    @Test("the batch delete(model: appears nowhere in the app target")
    func noBatchDelete() throws {
        let found = try Self.hits("delete(model:")
        #expect(found.isEmpty, "\(found.map(\.path))")
    }

    @Test("replaceAll and replaceInScratch are synchronous and never roll back (NB2)")
    func replaceIsSynchronous() throws {
        let store = try Self.functionBody("func replaceAll(", in: Self.codeLines("Models/BackupStore.swift"))
        let commit = try Self.functionBody("func replaceInScratch(", in: Self.codeLines("Models/StoreCommit.swift"))
        #expect(store.contains { $0.contains("StoreCommit.replaceInScratch(") })
        #expect(commit.contains { $0.contains(".save()") })
        for body in [store, commit] {
            #expect(!body.contains { $0.contains("await") })
            #expect(!body.contains { $0.contains("rollback(") })
            #expect(!body.contains { $0.contains("Task") })
        }
        let helpers = try Self.codeLines("Models/BackupStore.swift")
        #expect(!helpers.contains { $0.contains("await") || $0.contains("async") }, "the delete and insert helpers are synchronous too")
    }

    @Test("Engine/AppearanceMode.swift has no UIKit and no label; the label is a Shared extension (B1)")
    func appearanceModeIsEngine() throws {
        let engine = try Self.codeLines("Engine/AppearanceMode.swift")
        #expect(engine.contains { $0.contains("enum AppearanceMode") })
        #expect(!engine.contains { $0.contains("import UIKit") })
        #expect(!engine.contains { $0.contains("label") })
        let shared = try Self.codeLines("Shared/AppearanceMode+Label.swift")
        #expect(shared.contains { $0.contains("extension AppearanceMode") })
        #expect(shared.contains { $0.contains("var label: String") })
        let elsewhere = try Self.hits("enum AppearanceMode")
        #expect(elsewhere.map(\.path) == ["Engine/AppearanceMode.swift"])
    }

    @Test("RootView's restore handler reads no @Query between replaceAll and clearing the state (B3); no context, no UserDefaults")
    func restoreHandlerRule() throws {
        let lines = try Self.codeLines("App/RootView.swift")
        let start = try #require(lines.firstIndex { $0.contains("BackupStore.replaceAll(") })
        let end = try #require(lines.indices.first { $0 > start && $0 < lines.endIndex && lines[$0].contains("restore = .idle") })
        let handler = lines[start...end]
        #expect(handler.count > 5, "the preference writes sit in the range")
        #expect(handler.contains { $0.contains("unitsRaw = ") })
        for token in ["currentPrograms", "activeLogs", ".first"] {
            #expect(!handler.contains { $0.contains(token) }, "\(token)")
        }
        #expect(!lines.contains { $0.contains("ModelContext(") })
        #expect(!lines.contains { $0.contains("UserDefaults") })
        let begin = try Self.functionBody("func beginRestore(", in: lines)
        let home = try #require(begin.firstIndex { $0.contains("selectedTab = .home") })
        let flip = try #require(begin.firstIndex { $0.contains("restore = .restoring") })
        #expect(home < flip)
    }

    @Test("no file-timestamp key anywhere (NB5); the export lists tmp/ with no resource keys")
    func noFileTimestamps() throws {
        for token in ["contentModificationDateKey", "creationDateKey", "modificationDate", "creationDate"] {
            let found = try Self.hits(token)
            #expect(found.isEmpty, "\(token): \(found.map(\.path))")
        }
        let file = try Self.codeLines("Features/Settings/BackupFile.swift")
        #expect(file.contains { $0.contains("contentsOfDirectory(at:") && $0.contains("includingPropertiesForKeys: nil") })
        #expect(file.contains { $0.contains("BackupText.isBackupFileName(") })
    }

    @Test("SettingsView builds no snapshot and runs no fetch (NB6)")
    func settingsViewHasNoFetch() throws {
        let view = try Self.codeLines("Features/Settings/SettingsView.swift")
        #expect(view.contains { $0.contains("BackupFile(") }, "the file was read")
        #expect(!view.contains { $0.contains("BackupSnapshotBuilder") })
        #expect(!view.contains { $0.contains("FetchDescriptor") })
    }

    @Test("every string literal in BackupRows.swift is outside the copy: text comes from BackupText or SettingsText (AC-10)")
    func backupRowsHaveNoLiteralCopy() throws {
        let lines = try Self.codeLines("Features/Settings/BackupRows.swift")
        #expect(lines.contains { $0.contains("BackupText.export") })
        #expect(lines.contains { $0.contains("BackupText.restore") })
        let literals = lines.filter { $0.contains("\"") && !$0.contains("systemName:") }
        #expect(literals.isEmpty, "\(literals)")
        let members = lines.flatMap { line -> [String] in
            var found: [String] = []
            var rest = Substring(line)
            while let hit = rest.range(of: "Text.") {
                let owner = rest[..<hit.lowerBound].reversed().prefix { $0.isLetter }
                found.append(String(owner.reversed()) + "Text")
                rest = rest[hit.upperBound...]
            }
            return found
        }
        #expect(!members.isEmpty)
        #expect(Set(members).isSubset(of: ["BackupText", "SettingsText"]), "\(Set(members))")
    }

    @Test("the backup preview is one nil-by-default @Entry, provided once, read only inside the seed branch")
    func previewWiring() throws {
        let entries = try Self.codeLines("App/AppClock.swift").filter { $0.contains("@Entry") && $0.contains("BackupPreview?") }
        #expect(entries.count == 1)
        #expect(entries.first?.contains("= nil") == true)
        let app = try Self.codeLines("App/HomeGymLogApp.swift")
        #expect(app.filter { $0.contains(".environment(\\.settingsBackupPreview") }.count == 1)
        let parse = try #require(app.firstIndex { $0.contains("DebugSeed.parse(") })
        let end = try #require(app.indices.first { $0 > parse && app[$0].contains("#endif") })
        let reads = app.indices.filter { app[$0].contains("seed.settingsBackupPreview") }
        #expect(reads.count == 1)
        #expect(reads.allSatisfy { $0 > parse && $0 < end })
        let seedFile = try String(contentsOf: Self.appSourceRoot.appendingPathComponent("App/DebugSeed/BackupSeed.swift"),
                                  encoding: .utf8)
        #expect(seedFile.hasPrefix("#if DEBUG"))
    }
}

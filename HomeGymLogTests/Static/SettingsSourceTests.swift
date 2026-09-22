import Foundation
import Testing

/// AC-22: the Settings slice's app-target invariants, scanned over the source. Only `.swift` files are read, so the asset
/// catalog's own `"appearance"` keys are out of scope; `//` comments are stripped, and an empty scan fails.
@Suite struct SettingsSourceTests {
    /// `<repo>/HomeGymLog`, derived from `<repo>/HomeGymLogTests/Static/…`.
    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    /// Relative path → the file's lines with `//` comments removed, for every Swift file of the app target.
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

    /// path → every code line containing `token`.
    private static func hits(_ token: String, in sources: [(path: String, lines: [String])]) -> [(path: String, line: String)] {
        sources.flatMap { source in source.lines.filter { $0.contains(token) }.map { (source.path, $0) } }
    }

    @Test("each preference key literal appears exactly once, on its own storageKey line")
    func storageKeyLiterals() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        let appearance = Self.hits("\"appearance\"", in: all)
        #expect(appearance.map(\.path) == ["Shared/AppearanceMode.swift"])
        #expect(appearance.allSatisfy { $0.line.contains("storageKey") })
        let policy = Self.hits("\"missedDayPolicy\"", in: all)
        #expect(policy.map(\.path) == ["Engine/MissedDay.swift"])
        #expect(policy.allSatisfy { $0.line.contains("storageKey") })
    }

    @Test("the appearance preference is read in exactly two files")
    func appearanceReaders() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        let readers = Self.hits("@AppStorage(AppearanceMode.storageKey)", in: all).map(\.path).sorted()
        #expect(readers == ["App/RootView.swift", "Features/Settings/SettingsView.swift"])
    }

    @Test("preferredColorScheme is used nowhere; the window override and UIKit live only in RootView")
    func appearanceMechanism() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        #expect(Self.hits("preferredColorScheme", in: all).map(\.path) == [])
        #expect(Self.hits("overrideUserInterfaceStyle", in: all).map(\.path) == ["App/RootView.swift"])
        #expect(Self.hits("import UIKit", in: all).map(\.path) == ["App/RootView.swift"])
        #expect(Self.hits("import UIKit", in: all.filter { $0.path == "Shared/AppearanceMode.swift" }).isEmpty)
    }

    @Test("the settings control is a SegmentedPicker style, and the placeholder screen is gone")
    func screenShape() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        let picker = try #require(all.first { $0.path == "Shared/SegmentedPicker.swift" })
        #expect(picker.lines.contains { $0.contains("case settings") })
        #expect(Self.hits("SettingsSegmentedControl", in: all).map(\.path) == [])
        #expect(Self.hits("PlaceholderScreen", in: all).map(\.path) == [])
        #expect(Self.hits("placeholderMilestone", in: all).map(\.path) == [])
    }

    @Test("RootView reads the archived programs through a @Query, never a FetchDescriptor")
    func rootViewHasNoFetch() throws {
        let all = try Self.sources()
        let root = try #require(all.first { $0.path == "App/RootView.swift" })
        #expect(root.lines.contains { $0.contains("FetchDescriptor") } == false)
        #expect(root.lines.contains { $0.contains("ProgressSnapshotBuilder.archivedProgramPredicate") })
    }
}

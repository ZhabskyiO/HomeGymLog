import Foundation
import Testing

/// AC-14 (reminder half): seeded runs and previews never reach the system center through the reminder notifier, the
/// system calls stay in their seam, unknown statuses fail closed, and the keys and host shape the spec pins. Reads the
/// checked-in sources via `#filePath`, `//` comments stripped; an empty scan fails.
@Suite struct ReminderSourceTests {
    /// `<repo>/HomeGymLog`, derived from `<repo>/HomeGymLogTests/Static/…`.
    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HomeGymLog", isDirectory: true)
    }

    private static func codeLines(_ file: URL) throws -> [String] {
        try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines).map { line in
            if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }
            return line
        }
    }

    private static func lines(_ relativePath: String) throws -> [String] {
        try codeLines(appSourceRoot.appendingPathComponent(relativePath))
    }

    /// Relative path → code lines, for every Swift file of the app target.
    private static func sources() throws -> [(path: String, lines: [String])] {
        let enumerator = try #require(FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        return try files.map { (($0.path.replacingOccurrences(of: appSourceRoot.path + "/", with: "")), try codeLines($0)) }
    }

    /// Sorted, de-duplicated paths of files with a code line containing `token`.
    private static func files(containing token: String, in sources: [(path: String, lines: [String])]) -> [String] {
        Array(Set(sources.filter { $0.lines.contains { $0.contains(token) } }.map(\.path))).sorted()
    }

    @Test("a .live() on a line naming the reminder notifier appears once: the reminderNotifier @Entry default")
    func liveOnlyAsEntryDefault() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        let found = all.flatMap { source in
            source.lines.filter { $0.contains(".live()") && ($0.contains("ReminderNotifier") || $0.contains("reminderNotifier")) }
                .map { (source.path, $0) }
        }
        #expect(found.count == 1)
        #expect(found.first?.0 == "App/AppClock.swift")
        #expect(found.first?.1.contains("@Entry var reminderNotifier") == true)
    }

    @Test("an unknown system status maps to denied: the line after @unknown default returns .denied")
    func unknownStatusFailsClosed() throws {
        let lines = try Self.lines("App/ReminderNotifier.swift")
        let unknown = try #require(lines.firstIndex { $0.contains("@unknown default") })
        let next = try #require(lines.indices.first { $0 > unknown && !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty })
        #expect(lines[next].contains("return .denied"))
    }

    @Test("UNUserNotificationCenter is named only by the two notifier seams, the delegate and the App's delegate assignment")
    func centerStaysInSeams() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        #expect(Self.files(containing: "UNUserNotificationCenter", in: all)
                == ["App/AppNotificationDelegate.swift", "App/HomeGymLogApp.swift", "App/ReminderNotifier.swift", "App/RestNotifier.swift"])
    }

    @Test("the delegate is assigned by the first code line of HomeGymLogApp.init")
    func delegateFirstInInit() throws {
        let lines = try Self.lines("App/HomeGymLogApp.swift")
        let initLine = try #require(lines.firstIndex { $0.contains("init()") })
        let next = try #require(lines.indices.first { $0 > initLine && !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty })
        #expect(lines[next].contains(".delegate ="))
        #expect(lines[next].contains("notificationDelegate"))
        #expect(lines.contains { $0.contains("let notificationDelegate = AppNotificationDelegate()") })
    }

    @Test("HomeGymLogApp sets .silent(status:) on exactly one line, inside the -seed branch and before its #endif")
    func silentOnlyInSeedBranch() throws {
        let lines = try Self.lines("App/HomeGymLogApp.swift")
        let silentLines = lines.indices.filter { lines[$0].contains(".silent(status:") }
        #expect(silentLines.count == 1)
        let seedBranch = try #require(lines.firstIndex { $0.contains("DebugSeed.parse(") })
        let endif = try #require(lines.indices.first { $0 > seedBranch && lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("#endif") })
        let silent = try #require(silentLines.first)
        #expect(silent > seedBranch && silent < endif)
    }

    @Test("each reminder key literal appears once, on its key line in Engine/ReminderPlan.swift")
    func keyLiterals() throws {
        let all = try Self.sources()
        #expect(all.count > 40, "the whole app target was scanned")
        for (literal, name) in [("\"reminderEnabled\"", "enabledKey"), ("\"reminderMinutes\"", "minutesKey")] {
            let hits = all.flatMap { source in source.lines.filter { $0.contains(literal) }.map { (source.path, $0) } }
            #expect(hits.map(\.0) == ["Engine/ReminderPlan.swift"], "\(literal)")
            #expect(hits.allSatisfy { $0.1.contains("static let \(name)") }, "\(literal)")
        }
    }

    @Test("both reminder preferences are read in exactly the host and the Settings screen")
    func preferenceReaders() throws {
        let all = try Self.sources()
        for token in ["@AppStorage(ReminderPlan.enabledKey)", "@AppStorage(ReminderPlan.minutesKey)"] {
            #expect(Self.files(containing: token, in: all) == ["App/ReminderHost.swift", "Features/Settings/SettingsView.swift"],
                    "\(token)")
        }
    }

    @Test("notificationSettings( is called only by the reminder seam")
    func settingsReadInSeam() throws {
        #expect(Self.files(containing: "notificationSettings(", in: try Self.sources()) == ["App/ReminderNotifier.swift"])
    }

    @Test("ReminderPlan imports only Foundation and declares no Error type (desired is total)")
    func engineIsPure() throws {
        let lines = try Self.lines("Engine/ReminderPlan.swift")
        let imports = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("import ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(imports == ["import Foundation"])
        #expect(lines.contains { $0.contains(": Error") || $0.contains("Error {") } == false)
        #expect(lines.contains { $0.contains("throws") } == false)
    }

    @Test("RootView mounts the host once as a background with .id and provides the permission; never hops to the log's session")
    func rootMount() throws {
        let lines = try Self.lines("App/RootView.swift")
        let code = lines.joined(separator: "\n")
        #expect(code.contains(".background {"))
        #expect(code.contains(".environment(permission)"))
        let host = try #require(lines.first { $0.contains("ReminderHost(") })
        #expect(host.contains(".id("))
        #expect(lines.contains { $0.contains("activeLogs.first?.session") } == false)
        let background = try #require(lines.firstIndex { $0.contains(".background {") })
        let environment = try #require(lines.firstIndex { $0.contains(".environment(permission)") })
        #expect(background < environment, "the permission reaches the host only if it is provided after it")
    }

    @Test("the host has an empty ZStack root, a keyed task, the null-UUID fallback, the notifier pass and no assert")
    func hostShape() throws {
        let code = try Self.lines("App/ReminderHost.swift").joined(separator: "\n")
        for token in ["ZStack {}", ".task(id:", "noProgramID", "notifier.reconcile("] {
            #expect(code.contains(token), "\(token)")
        }
        #expect(code.contains("assertionFailure") == false)
    }
}

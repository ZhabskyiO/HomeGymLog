import Foundation
import Testing

/// m5-live-activity AC-17, AC-18, AC-21: what the shared folder may contain and where the Live Activity's pieces may
/// live in the app target. Reads the checked-in sources via `#filePath`, `//` comments stripped (the
/// `FeedbackSourceTests` walk), plus `HomeGymLogShared/` one level above `HomeGymLog/`.
@Suite struct LiveActivitySourceTests {
    /// `<repo>`, derived from `<repo>/HomeGymLogTests/Static/…`.
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    static var sharedRoot: URL { repoRoot.appendingPathComponent("HomeGymLogShared", isDirectory: true) }

    /// Every Swift file under `root`, keyed by its path relative to `root`, as comment-stripped lines.
    static func files(under root: URL) throws -> [(path: String, lines: [String])] {
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let urls = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        return try urls.map { ($0.path.replacingOccurrences(of: root.path + "/", with: ""), try FeedbackSourceTests.codeLines($0)) }
    }

    static func sharedFiles() throws -> [(path: String, lines: [String])] { try files(under: sharedRoot) }

    static func hasWord(_ word: String, in line: String) -> Bool {
        line.range(of: "\\b\(word)\\b", options: .regularExpression) != nil
    }

    // MARK: - Step 5: the shared folder (AC-17, AC-18)

    @Test("the shared folder holds the four shared files")
    func sharedFilesPresent() throws {
        let paths = Set(try Self.sharedFiles().map(\.path))
        #expect(paths.isSuperset(of: ["RestActivityAttributes.swift", "RestActivityIntents.swift",
                                      "LiveActivityIntentHooks.swift", "RestActivityText.swift"]))
    }

    @Test("shared imports are only Foundation, ActivityKit and AppIntents")
    func sharedImports() throws {
        for file in try Self.sharedFiles() {
            let imports = file.lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("import ") }
            #expect(Set(imports).isSubset(of: ["import Foundation", "import ActivityKit", "import AppIntents"]), "\(file.path)")
        }
    }

    @Test("no UIKit, UIApplication, SwiftData or app-target type in the shared folder", arguments: [
        "UIKit", "UIApplication", "SwiftData", "WorkoutLogStore", "AppSchema", "RestNotifier", "AppClock", "Theme", "RestText",
    ])
    func sharedForbidden(token: String) throws {
        for file in try Self.sharedFiles() {
            #expect(!file.lines.contains { Self.hasWord(token, in: $0) }, "\(token) in \(file.path)")
        }
    }

    @Test("every shared type declaration is nonisolated; @MainActor only on static var lines")
    func sharedIsolation() throws {
        let declaration = "^\\s*(public |internal |private |fileprivate )?(struct|enum|final class|class|actor) "
        var declarations = 0
        for file in try Self.sharedFiles() {
            for line in file.lines {
                if line.range(of: declaration, options: .regularExpression) != nil {
                    Issue.record("not nonisolated: \(file.path): \(line)")
                }
                if line.range(of: "^\\s*nonisolated (struct|enum|final class) ", options: .regularExpression) != nil { declarations += 1 }
                if line.contains("@MainActor") {
                    #expect(line.contains("static var"), "\(file.path): \(line)")
                }
            }
        }
        #expect(declarations >= 7)   // attributes, state, action, hooks, two intents, text
    }

    // MARK: - Step 5: the "Next:" prefix lives once (AC-21)

    @Test("\"Next: \" appears on no code line of the app target")
    func nextPrefixNotInApp() throws {
        #expect(try FeedbackSourceTests.matches { $0.contains("\"Next: ") }.isEmpty)
        #expect(try Self.sharedFiles().flatMap(\.lines).filter { $0.contains("\"Next: \"") }.count == 1)
    }

    // MARK: - Step 6: Engine (AC-21)

    @Test("RestActivityPlan.swift imports only Foundation and declares no Error type and no throws")
    func planIsPure() throws {
        let lines = try FeedbackSourceTests.codeLines("Engine/RestActivityPlan.swift")
        let imports = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("import ") }
        #expect(imports == ["import Foundation"])
        #expect(!lines.contains { $0.contains(": Error") || $0.contains("Error {") || $0.contains("throws") })
        #expect(!lines.contains { $0.contains("ActivityKit") })
    }

    @Test("the \"liveActivityEnabled\" literal is on one app line, the enabledKey declaration")
    func enabledKeyLiteralOnce() throws {
        let found = try FeedbackSourceTests.matches { $0.contains("\"liveActivityEnabled\"") }
        #expect(found.count == 1)
        #expect(found.first?.path == "Engine/RestActivityPlan.swift")
        #expect(found.first?.line.contains("static let enabledKey") == true)
    }

    // MARK: - Step 8: the seam (AC-21)

    @Test("ActivityKit, Activity< and ActivityAuthorizationInfo appear only in App/RestActivityCenter.swift", arguments: [
        "import ActivityKit", "Activity<", "ActivityAuthorizationInfo",
    ])
    func activityKitConfined(token: String) throws {
        let found = try FeedbackSourceTests.matches { $0.contains(token) }
        #expect(!found.isEmpty)
        #expect(Set(found.map(\.path)) == ["App/RestActivityCenter.swift"], "\(token)")
    }

    @Test("RestActivityCenter imports SwiftUI and ActivityKit, never UIKit")
    func centerImports() throws {
        let imports = try FeedbackSourceTests.codeLines("App/RestActivityCenter.swift")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("import ") }
        #expect(imports.sorted() == ["import ActivityKit", "import SwiftUI"])
    }

    @Test("the live update and end resolve ids against .activities at call time")
    func callTimeResolution() throws {
        let text = try FeedbackSourceTests.codeLines("App/RestActivityCenter.swift").joined(separator: "\n")
        let live = try #require(text.range(of: "static func live()"))
        let body = text[live.upperBound...]
        let update = try #require(body.range(of: "update: {"))
        let end = try #require(body.range(of: "end: {"))
        let enabled = try #require(body.range(of: "areActivitiesEnabled: {"))
        #expect(body[update.upperBound..<end.lowerBound].contains(".activities"))
        #expect(body[end.upperBound..<enabled.lowerBound].contains(".activities"))
    }

    @Test("apply checks Task.isCancelled after its awaited end, before the step")
    func applyCancellationCheck() throws {
        let text = try FeedbackSourceTests.codeLines("App/RestActivityCenter.swift").joined(separator: "\n")
        let apply = try #require(text.range(of: "func apply("))
        let body = text[apply.upperBound...]
        let end = try #require(body.range(of: "await end("))
        let guardLine = try #require(body.range(of: "guard !Task.isCancelled"))
        let step = try #require(body.range(of: "switch decision.step"))
        #expect(end.lowerBound < guardLine.lowerBound && guardLine.lowerBound < step.lowerBound)
    }

    @Test("HomeGymLogApp sets .silent(activitiesEnabled:) on one line, inside the -seed branch before its #endif")
    func silentOnlyInSeedBranch() throws {
        let lines = try FeedbackSourceTests.codeLines("App/HomeGymLogApp.swift")
        let silent = lines.indices.filter { lines[$0].contains(".silent(activitiesEnabled:") }
        #expect(silent.count == 1)
        let seedBranch = try #require(lines.firstIndex { $0.contains("DebugSeed.parse(") })
        let endif = try #require(lines.indices.first { $0 > seedBranch && lines[$0].contains("#endif") })
        let line = try #require(silent.first)
        #expect(line > seedBranch && line < endif)
    }

    // MARK: - Step 9: the hook (AC-21)

    @Test("LiveActivityIntentHooks.handler is assigned on one app line, in HomeGymLogApp.swift after containerResult")
    func hookInstalledOnce() throws {
        let found = try FeedbackSourceTests.matches { $0.contains("LiveActivityIntentHooks.handler =") }
        #expect(found.count == 1)
        #expect(found.first?.path == "App/HomeGymLogApp.swift")
        let lines = try FeedbackSourceTests.codeLines("App/HomeGymLogApp.swift")
        let result = try #require(lines.firstIndex { $0.contains("containerResult = Result(") })
        let hook = try #require(lines.firstIndex { $0.contains("LiveActivityIntentHooks.handler =") })
        #expect(hook > result)
        #expect(lines[hook].contains("RestActivityHandler.makeHook("))
    }

    @Test("the two .live() lines naming the activity center: the @Entry default and the hook installation")
    func centerLiveLines() throws {
        let found = try FeedbackSourceTests.matches {
            $0.contains(".live()") && ($0.contains("restActivityCenter") || $0.contains("RestActivityCenter"))
        }
        #expect(found.count == 2)
        #expect(found.contains { $0.path == "App/HomeGymLogApp.swift" && $0.line.contains("restActivityCenter ?? .live()") })
    }

    @Test("the handler opens no container of its own and asserts nothing")
    func handlerShape() throws {
        let lines = try FeedbackSourceTests.codeLines("App/RestActivityHandler.swift")
        #expect(!lines.contains { $0.contains("ModelContainer(") })
        #expect(!lines.contains { $0.contains("assertionFailure") })
        #expect(lines.contains { $0.contains("container.mainContext") })
        #expect(lines.contains { $0.contains("as? Bool") }, "preferences read with object(forKey:) as? Bool (NB7)")
        #expect(!lines.contains { $0.contains("bool(forKey:") })
    }

    // MARK: - Step 10: the workout screen and the root host (AC-21)

    /// The function body starting at the line containing `signature`, up to the next line that starts a sibling member.
    static func body(of signature: String, in lines: [String]) throws -> [String] {
        let start = try #require(lines.firstIndex { $0.contains(signature) })
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { $0.hasPrefix("    private func ") || $0.hasPrefix("    func ") || $0.hasPrefix("    // MARK") } ?? lines.endIndex
        return Array(lines[start..<end])
    }

    @Test("the workout screen's activity key carries the Next line, reads no clock, and keys one task")
    func workoutActivityKey() throws {
        let lines = try FeedbackSourceTests.codeLines("Features/Workout/WorkoutView.swift")
        let start = try #require(lines.firstIndex { $0.contains("let activityKey") })
        let end = try #require(lines[start...].firstIndex { $0.contains("endedCount: endedCount)") })
        let statement = lines[start...end].joined(separator: " ")
        #expect(statement.contains("RestText.nextLine"))
        #expect(statement.contains("RestTimer.next("))
        #expect(!statement.contains("clock.now()"))
        #expect(lines.contains { $0.contains(".task(id: activityKey)") })
        #expect(try Self.body(of: "func observeRestEnd(", in: lines).contains { $0.contains("endedCount += 1") })
        let scene = try #require(lines.firstIndex { $0.contains(".onChange(of: scenePhase)") })
        let tick = try #require(lines.firstIndex { $0.contains("activeTick += 1") })
        #expect(tick > scene && tick < scene + 8)
    }

    @Test("RestActivityHost is an empty root with one keyed task, no query and no assert")
    func hostShape() throws {
        let lines = try FeedbackSourceTests.codeLines("App/RestActivityHost.swift")
        #expect(lines.contains { $0.contains("ZStack {}") })
        #expect(lines.contains { $0.contains(".task(id:") })
        #expect(lines.contains { $0.contains("RestStrandedKey(") })
        #expect(!lines.contains { $0.contains("@Query") })
        #expect(!lines.contains { $0.contains("assertionFailure") })
    }

    @Test("RootView mounts RestActivityHost from the scalar, with no .id")
    func rootMountsHost() throws {
        let lines = try FeedbackSourceTests.codeLines("App/RootView.swift")
        let host = try #require(lines.first { $0.contains("RestActivityHost(workoutInProgress:") })
        #expect(!host.contains(".id("))
        #expect(host.contains("activeLogs.first != nil"))
    }

    @Test("@AppStorage(RestActivityPlan.enabledKey) lives in exactly four files")
    func enabledStorageFiles() throws {
        let found = try FeedbackSourceTests.matches { $0.contains("@AppStorage(RestActivityPlan.enabledKey)") }
        #expect(Set(found.map(\.path)) == ["App/RestActivityHost.swift", "App/RootView.swift", "Features/Settings/SettingsView.swift",
                                           "Features/Workout/WorkoutView.swift"])
        #expect(found.count == 4)
    }

    // MARK: - Step 12: the Settings rows

    @Test("LiveActivityRows: its own toggle, the shared Open iOS Settings row behind one divider, no stored value, store or clock")
    func liveActivityRowsShape() throws {
        let lines = try FeedbackSourceTests.codeLines("Features/Settings/LiveActivityRows.swift")
        let toggle = try #require(lines.firstIndex { $0.contains("Toggle(isOn: $enabled)") })
        #expect(lines.contains { $0.contains("ReminderText.openSettings") })
        #expect(lines[toggle...].filter { $0.contains("SettingsDivider()") }.count == 1)
        #expect(lines.filter { $0.contains("SettingsDivider()") }.count == 1)
        for forbidden in ["@AppStorage", "modelContext", "appClock"] {
            #expect(!lines.contains { $0.contains(forbidden) }, "\(forbidden)")
        }
    }
}

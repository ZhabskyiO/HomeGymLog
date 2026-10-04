import Foundation
import Testing

/// m5-live-activity AC-13 and AC-20: the widget extension's colorset copies stay byte-equal to the app's, and its views
/// keep the review rules (buttons only on the Lock Screen and in the expanded island, no alert configuration, no
/// `widgetURL`, no hard-coded text, only the five copied colors). Reads `<repo>/HomeGymLogWidgets` via `#filePath`;
/// the target is named `HomeGymLogWidgetsExtension` by Xcode 27, its folder keeps the planned name.
@Suite struct WidgetSourceTests {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    static var widgetRoot: URL { repoRoot.appendingPathComponent("HomeGymLogWidgets", isDirectory: true) }
    static let copied = ["AccentColor", "sf", "sf2", "tx", "mu"]

    static func widgetFiles() throws -> [(path: String, lines: [String])] {
        try LiveActivitySourceTests.files(under: widgetRoot)
    }

    // MARK: AC-13 colorset copies

    @Test("each copied colorset is byte-equal to the app's", arguments: copied)
    func byteEqualCopy(name: String) throws {
        let path = "Assets.xcassets/\(name).colorset/Contents.json"
        let copy = try Data(contentsOf: Self.widgetRoot.appendingPathComponent(path))
        let original = try Data(contentsOf: Self.repoRoot.appendingPathComponent("HomeGymLog").appendingPathComponent(path))
        #expect(!copy.isEmpty)
        #expect(copy == original)
    }

    @Test("the extension catalog holds exactly the five copies, WidgetBackground and the wizard's AppIcon")
    func catalogContents() throws {
        let catalog = Self.widgetRoot.appendingPathComponent("Assets.xcassets", isDirectory: true)
        let entries = try FileManager.default.contentsOfDirectory(atPath: catalog.path).filter { $0 != "Contents.json" }
        #expect(Set(entries) == Set(Self.copied.map { "\($0).colorset" } + ["WidgetBackground.colorset", "AppIcon.appiconset"]))
    }

    // MARK: AC-20 review rules

    @Test("the extension's Swift files are the bundle, the configuration and the two view files")
    func files() throws {
        #expect(Set(try Self.widgetFiles().map(\.path)) == ["HomeGymLogWidgetsBundle.swift", "RestLiveActivity.swift",
                                                              "RestActivityLockScreenView.swift", "RestActivityIslandViews.swift"])
    }

    @Test("Button(intent: appears only in the Lock Screen view file, twice")
    func buttonsOnlyInLockScreenFile() throws {
        let hits = try Self.widgetFiles().flatMap { file in file.lines.filter { $0.contains("Button(intent:") }.map { _ in file.path } }
        #expect(hits == ["RestActivityLockScreenView.swift", "RestActivityLockScreenView.swift"])
    }

    @Test("no button between a compact or minimal label and the next region label; the buttons sit in .bottom")
    func noButtonsInCompactOrMinimal() throws {
        let lines = try #require(try Self.widgetFiles().first { $0.path == "RestActivityIslandViews.swift" }).lines
        let regionLabels = ["compactLeading:", "compactTrailing:", "minimal:", "DynamicIslandExpandedRegion(", ".keylineTint("]
        let restricted = ["compactLeading:", "compactTrailing:", "minimal:"]
        var inRestricted = false
        var checked = 0
        var bottomHasButtons = false
        var inBottom = false
        for line in lines {
            if regionLabels.contains(where: { line.contains($0) }) {
                inRestricted = restricted.contains { line.contains($0) }
                inBottom = line.contains("DynamicIslandExpandedRegion(.bottom)")
                if inRestricted { checked += 1 }
            }
            if inRestricted {
                #expect(!line.contains("Button(intent:") && !line.contains("RestActivityButtons("), "\(line)")
            }
            if inBottom && line.contains("RestActivityButtons(") { bottomHasButtons = true }
        }
        #expect(checked == 3, "all three restricted regions were found")
        #expect(bottomHasButtons)
    }

    @Test("no alert configuration, no widgetURL, no Text(\"…\") literal anywhere in the extension", arguments: [
        "AlertConfiguration", "alertConfiguration", "widgetURL", "Text(\"",
    ])
    func forbidden(token: String) throws {
        for file in try Self.widgetFiles() {
            #expect(!file.lines.contains { $0.contains(token) }, "\(token) in \(file.path)")
        }
    }

    @Test("every Color(\"…\") name is one of the five copies")
    func colorNames() throws {
        var names: Set<String> = []
        for file in try Self.widgetFiles() {
            for line in file.lines {
                var rest = Substring(line)
                while let range = rest.range(of: "Color(\"") {
                    let after = rest[range.upperBound...]
                    if let close = after.firstIndex(of: "\"") { names.insert(String(after[..<close])) }
                    rest = after
                }
            }
        }
        #expect(!names.isEmpty)
        #expect(names.isSubset(of: Set(Self.copied)), "\(names)")
    }
}

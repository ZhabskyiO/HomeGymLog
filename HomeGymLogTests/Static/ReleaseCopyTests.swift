import Foundation
import Testing
@testable import HomeGymLog

/// m5-release AC-11: the copy audit's one fix (A4 subtitle), the welcome tile as decorative artwork, and (Step 5) the
/// Settings ABOUT card's strings, URLs and link control. Reads the checked-in sources (comment-stripped unless noted).
@Suite struct ReleaseCopyTests {
    static let newSubtitle = "\"Session length sets how many exercises you do.\""

    @Test("A4's subtitle is the audited sentence, on exactly one line; the old claim is gone from the app")
    func aboutYouSubtitle() throws {
        let lines = try FeedbackSourceTests.codeLines("Features/Onboarding/AboutYouStep.swift")
        #expect(lines.filter { $0.contains(Self.newSubtitle) }.count == 1)
        let oldClaim = try FeedbackSourceTests.matches { $0.contains("Used to size") }
        #expect(oldClaim.isEmpty)
    }

    @Test("A1's tile is the WelcomeTile image, decorative, and the old letter is gone")
    func welcomeTile() throws {
        let lines = try FeedbackSourceTests.codeLines("Features/Onboarding/WelcomeStep.swift")
        #expect(!lines.contains { $0.contains("Text(\"H\")") })
        let tile = lines.filter { $0.contains("\"WelcomeTile\"") }
        #expect(tile.count == 1)
        #expect(tile.first?.contains("Image(decorative:") == true)   // skipped by VoiceOver (F6)
    }

    @Test("no other app file draws a catalog image by name")
    func noOtherNamedImages() throws {
        let hits = try FeedbackSourceTests.matches { $0.contains("Image(\"") || $0.contains("Image(decorative: \"") }
        #expect(hits.map(\.path) == ["Features/Onboarding/WelcomeStep.swift"])
    }

    // MARK: - Step 5: the Settings ABOUT card (spec §2.7, §5.9)

    static let privacyLiteral = "\"https://zhabskyio.github.io/homegymlog-site/privacy/\""
    static let supportLiteral = "\"https://zhabskyio.github.io/homegymlog-site/support/\""

    /// Every Swift file under `<repo>/<folder>`, keyed by its path relative to that folder, as **raw** lines minus the
    /// lines that are wholly a `//` comment. `FeedbackSourceTests.codeLines` cuts each line at its first `//`, which would
    /// cut `"https://…"` away, so the URL scans read raw lines.
    static func rawFiles(_ folder: String) throws -> [(path: String, lines: [String])] {
        let root = ReleaseAssetTests.repoRoot.appendingPathComponent(folder, isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        return try files.map { file in
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            return (file.path.replacingOccurrences(of: root.path + "/", with: ""), lines)
        }
    }

    @Test("each ABOUT URL literal sits on exactly one app line, in Shared/SettingsText.swift, and nowhere in the extension",
          arguments: [privacyLiteral, supportLiteral])
    func urlLiteralHome(literal: String) throws {
        var appHits: [String] = []
        for file in try Self.rawFiles("HomeGymLog") {
            for line in file.lines where line.contains(literal) { appHits.append(file.path) }
        }
        #expect(appHits == ["Shared/SettingsText.swift"])
        for folder in ["HomeGymLogShared", "HomeGymLogWidgets"] {
            let files = try Self.rawFiles(folder)
            #expect(!files.isEmpty, "\(folder) was read")
            #expect(!files.contains { file in file.lines.contains { $0.contains(literal) } }, "\(folder)")
        }
    }

    @Test("the ABOUT strings, URLs and version text match spec §2.7 / §5.9")
    @MainActor
    func aboutValues() {
        #expect(SettingsText.aboutSection == "ABOUT")
        #expect(SettingsText.privacyPolicy == "Privacy policy")
        #expect(SettingsText.support == "Support")
        #expect(SettingsText.version == "Version")
        #expect(SettingsText.privacyPolicyURL.absoluteString == "https://zhabskyio.github.io/homegymlog-site/privacy/")
        #expect(SettingsText.supportURL.absoluteString == "https://zhabskyio.github.io/homegymlog-site/support/")
        #expect(SettingsText.versionText(short: "1.0", build: "1") == "1.0 (1)")
        #expect(SettingsText.versionText(short: "2.3", build: "45") == "2.3 (45)")
        #expect(SettingsText.versionText(short: nil, build: nil) == "\u{2014}")
        #expect(SettingsText.versionText(short: "1.0", build: nil) == "\u{2014}")
        #expect(SettingsText.versionText(short: nil, build: "1") == "\u{2014}")
        #expect(SettingsText.versionText(short: "", build: "1") == "\u{2014}")
        #expect(SettingsText.versionText(short: "1.0", build: "") == "\u{2014}")
    }

    @Test("Link( as a whole token appears only in AboutRows.swift, which never opens URLs itself")
    func linkOnlyInAboutRows() throws {
        // ICU (`.regularExpression`), not Swift `Regex`: the latter throws "lookbehind is not currently supported".
        let token = #"(?<![A-Za-z])Link\("#
        let hits = try FeedbackSourceTests.matches { $0.range(of: token, options: .regularExpression) != nil }
        #expect(Set(hits.map(\.path)) == ["Features/Settings/AboutRows.swift"])
        let about = try FeedbackSourceTests.codeLines("Features/Settings/AboutRows.swift").joined(separator: "\n")
        #expect(!about.contains("UIApplication"))
        #expect(!about.contains("openURL"))
    }

    @Test("SettingsContent keeps the pill clearance under its last card (m5-export)")
    func bottomPaddingKept() throws {
        let lines = try FeedbackSourceTests.codeLines("Features/Settings/SettingsContent.swift")
        #expect(lines.filter { $0.contains("static let bottomPadding = FloatingTabBar.height + 16") }.count == 1)
        #expect(lines.filter { $0.contains(".padding(.bottom, Self.bottomPadding)") }.count == 1)
    }
}

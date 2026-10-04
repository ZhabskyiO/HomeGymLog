import Foundation
import Testing

/// m5-release AC-12, AC-13: the paste-ready App Store Connect text in `docs/release/` stays inside Apple's limits and
/// away from Apple's marks, and the two hosted pages and the checklist carry what the spec requires. Reads the files only.
@Suite struct StoreMetadataTests {
    static var releaseFolder: URL { ReleaseAssetTests.repoRoot.appendingPathComponent("docs/release", isDirectory: true) }

    static func read(_ name: String) throws -> String {
        try String(contentsOf: releaseFolder.appendingPathComponent(name), encoding: .utf8)
    }

    /// Fenced blocks by info string: a line "```<id>" opens a block, a line "```" closes it; content joined with "\n".
    /// Each id maps to every block that carries it, so a duplicate is visible.
    static func blocks(in markdown: String) -> [String: [String]] {
        var found: [String: [String]] = [:]
        var open: (id: String, lines: [String])?
        for line in markdown.components(separatedBy: "\n") {
            if let current = open {
                if line == "```" {
                    found[current.id, default: []].append(current.lines.joined(separator: "\n"))
                    open = nil
                } else {
                    open = (current.id, current.lines + [line])
                }
            } else if line.hasPrefix("```"), line.count > 3 {
                open = (String(line.dropFirst(3)), [])
            }
        }
        return found
    }

    static let fieldIDs = ["name", "subtitle", "promotional-text", "keywords", "description"]
    static let bannedInShortFields = ["iPhone", "Live Activit", "Dynamic Island", "TestFlight", "App Store", "Marcy", "HomeGymLog"]

    /// Every AC-12 rule the fields break, each as "<field>: <rule>". Characters are Unicode scalars; keywords are bytes.
    static func violations(_ fields: [String: String]) -> [String] {
        var found: [String] = []
        for id in fieldIDs where fields[id] == nil { found.append("\(id): missing") }
        if let name = fields["name"], !(2...30).contains(name.unicodeScalars.count) { found.append("name: length") }
        if let subtitle = fields["subtitle"], subtitle.unicodeScalars.count > 30 { found.append("subtitle: length") }
        if let promo = fields["promotional-text"], promo.unicodeScalars.count > 170 { found.append("promotional-text: length") }
        if let description = fields["description"], description.unicodeScalars.count > 4000 { found.append("description: length") }
        if let keywords = fields["keywords"] {
            if keywords.utf8.count > 100 { found.append("keywords: bytes") }
            for term in keywords.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where term.count < 3 {
                found.append(term.isEmpty ? "keywords: empty term" : "keywords: short term \(term)")
            }
        }
        for id in ["subtitle", "keywords"] {
            guard let text = fields[id] else { continue }
            for word in bannedInShortFields where text.range(of: word, options: .caseInsensitive) != nil {
                found.append("\(id): banned \(word)")
            }
        }
        return found
    }

    @Test("AC-12: one block per field, every limit kept, name is HomeGymLog")
    func metadataWithinLimits() throws {
        let blocks = Self.blocks(in: try Self.read("app-store-metadata.md"))
        for id in Self.fieldIDs { #expect(blocks[id]?.count == 1, "\(id)") }
        let fields = blocks.compactMapValues(\.first)
        #expect(Self.violations(fields) == [])
        #expect(fields["name"] == "HomeGymLog")
    }

    @Test("AC-12 checker control: a bad subtitle and two bad keywords yield exactly those three violations")
    func checkerCatchesViolations() {
        let markdown = """
        ```name
        HomeGymLog
        ```
        ```subtitle
        Strength program for home gyms!
        ```
        ```promotional-text
        Short and fine.
        ```
        ```keywords
        home gym,PR,iPhone
        ```
        ```description
        A description.
        ```
        """
        let fields = Self.blocks(in: markdown).compactMapValues(\.first)
        #expect(fields["subtitle"]?.unicodeScalars.count == 31)
        #expect(Self.violations(fields).sorted() == ["keywords: banned iPhone", "keywords: short term PR", "subtitle: length"])
    }

    @Test("AC-13: both pages are real copies with the contact email; the policy carries its effective date")
    func pages() throws {
        let privacy = try Self.read("privacy-policy.md")
        let support = try Self.read("support.md")
        for page in [privacy, support] {
            #expect(page.utf8.count >= 400)
            #expect(page.contains("poltavagaz@gmail.com"))
        }
        #expect(privacy.contains("2026-10-03"))
    }

    @Test("AC-13: the metadata names both live URLs; the checklist names the archive command and Validate App")
    func urlsAndChecklist() throws {
        let metadata = try Self.read("app-store-metadata.md")
        #expect(metadata.contains("https://zhabskyio.github.io/homegymlog-site/privacy/"))
        #expect(metadata.contains("https://zhabskyio.github.io/homegymlog-site/support/"))
        let checklist = try Self.read("release-checklist.md")
        #expect(checklist.contains("xcodebuild archive"))
        #expect(checklist.contains("Validate App"))
    }
}

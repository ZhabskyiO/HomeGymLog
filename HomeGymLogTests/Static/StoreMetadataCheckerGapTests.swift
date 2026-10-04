import Foundation
import Testing

/// m5-release test-writer gap pass: `StoreMetadataTests.violations` and `.blocks` at every AC-12 limit's boundary.
/// The implementer's control case covers a 31-char subtitle, a 2-char term and one ban; these pin the side of each
/// boundary that must pass, the byte-versus-character rule for keywords, empty terms, case-insensitive bans, and the
/// parser's duplicate and unterminated blocks. Pure string work; reads no file.
@Suite struct StoreMetadataCheckerGapTests {
    /// A valid field set; each case replaces (or removes, with `nil`) one field.
    static let valid: [String: String] = [
        "name": "HomeGymLog",
        "subtitle": "Strength program for home gyms",
        "promotional-text": "Short and fine.",
        "description": "A description.",
        "keywords": "home gym,dumbbell",
    ]

    struct Case: Sendable, CustomTestStringConvertible {
        let label: String
        let field: String
        let value: String?
        let expected: [String]
        var testDescription: String { label }
    }

    static func letters(_ count: Int) -> String { String(repeating: "a", count: count) }
    /// U+00E9 is one Unicode scalar and two UTF-8 bytes.
    static func eAcute(_ count: Int) -> String { String(repeating: "\u{E9}", count: count) }

    static let cases: [Case] = [
        Case(label: "the shipped subtitle is exactly 30 and passes", field: "subtitle", value: "Strength program for home gyms", expected: []),
        Case(label: "a 30-char subtitle passes", field: "subtitle", value: letters(30), expected: []),
        Case(label: "a 31-char subtitle fails", field: "subtitle", value: letters(31), expected: ["subtitle: length"]),
        Case(label: "an empty name fails", field: "name", value: "", expected: ["name: length"]),
        Case(label: "a 1-char name fails", field: "name", value: "H", expected: ["name: length"]),
        Case(label: "a 2-char name passes", field: "name", value: "HG", expected: []),
        Case(label: "a 30-char name passes", field: "name", value: letters(30), expected: []),
        Case(label: "a 31-char name fails", field: "name", value: letters(31), expected: ["name: length"]),
        Case(label: "170-char promotional text passes", field: "promotional-text", value: letters(170), expected: []),
        Case(label: "171-char promotional text fails", field: "promotional-text", value: letters(171), expected: ["promotional-text: length"]),
        Case(label: "a 4000-char description passes", field: "description", value: letters(4000), expected: []),
        Case(label: "a 4001-char description fails", field: "description", value: letters(4001), expected: ["description: length"]),
        Case(label: "100 keyword bytes pass", field: "keywords", value: letters(100), expected: []),
        Case(label: "101 keyword bytes fail", field: "keywords", value: letters(101), expected: ["keywords: bytes"]),
        Case(label: "50 two-byte scalars are 100 bytes and pass", field: "keywords", value: eAcute(50), expected: []),
        Case(label: "51 scalars of 101 bytes fail: keywords count bytes, not characters", field: "keywords",
             value: eAcute(50) + "a", expected: ["keywords: bytes"]),
        Case(label: "a 3-char term passes", field: "keywords", value: "gym,abc", expected: []),
        Case(label: "a padded 2-char term is trimmed and fails", field: "keywords", value: "gym, ab ", expected: ["keywords: short term ab"]),
        Case(label: "a trailing comma is an empty term", field: "keywords", value: "home gym,", expected: ["keywords: empty term"]),
        Case(label: "a doubled comma is an empty term", field: "keywords", value: "home,,gym", expected: ["keywords: empty term"]),
        Case(label: "a whitespace-only term is an empty term", field: "keywords", value: "home, ,gym", expected: ["keywords: empty term"]),
        Case(label: "bans are case-insensitive in the subtitle", field: "subtitle", value: "Best IPHONE gym log",
             expected: ["subtitle: banned iPhone"]),
        Case(label: "bans match inside a keyword term", field: "keywords", value: "homegymlog app,gym",
             expected: ["keywords: banned HomeGymLog"]),
        Case(label: "the Live Activit stem catches the plural", field: "keywords", value: "live activities,gym",
             expected: ["keywords: banned Live Activit"]),
        Case(label: "marks are allowed in the description (bans cover subtitle and keywords only)", field: "description",
             value: "Rest timer on the Lock Screen and in the Dynamic Island on iPhone.", expected: []),
        Case(label: "a missing field is reported", field: "keywords", value: nil, expected: ["keywords: missing"]),
    ]

    @Test("the metadata checker at each limit's boundary", arguments: cases)
    func boundary(_ testCase: Case) {
        var fields = Self.valid
        fields[testCase.field] = testCase.value
        #expect(StoreMetadataTests.violations(fields).sorted() == testCase.expected.sorted())
    }

    @Test("the valid fixture has no violations (the cases above change one field each)")
    func fixtureIsValid() {
        #expect(StoreMetadataTests.violations(Self.valid) == [])
    }

    @Test("a field written twice yields two blocks, so AC-12's one-block-per-id check can fail")
    func duplicateBlock() {
        let markdown = "```subtitle\nFirst\n```\ntext\n```subtitle\nSecond\n```"
        #expect(StoreMetadataTests.blocks(in: markdown)["subtitle"] == ["First", "Second"])
    }

    @Test("an unterminated block is not recorded, so its field reads as missing")
    func unterminatedBlock() {
        let markdown = "```name\nHomeGymLog\n```\n```keywords\nhome gym,dumbbell"
        let blocks = StoreMetadataTests.blocks(in: markdown)
        #expect(blocks["name"] == ["HomeGymLog"])
        #expect(blocks["keywords"] == nil)
    }

    @Test("a multi-line block keeps its inner lines and blank lines, joined with newlines")
    func multiLineBlock() {
        let markdown = "```description\nLine one.\n\nLine three.\n```"
        #expect(StoreMetadataTests.blocks(in: markdown)["description"] == ["Line one.\n\nLine three."])
    }
}

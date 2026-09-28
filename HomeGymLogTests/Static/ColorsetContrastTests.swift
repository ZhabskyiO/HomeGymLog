import Foundation
import Testing

/// m5-light-theme AC-11–AC-14: the asset-catalog tokens, their entry shapes, the WCAG ratios between them, and the
/// app's hard-coded color sites.
///
/// The colorset JSON is read from the source tree (`#filePath`, the `FeedbackSourceTests.appSourceRoot` walk), not from
/// `Bundle.main`: the hosted test target's `Bundle.main` is the app bundle, which holds only the compiled `Assets.car`,
/// never the `Contents.json` files. The parser is deliberately loud: any component that is not a `"0xRR"` string fails
/// through `#require` naming the file and key (Xcode's color inspector may rewrite components as decimals).
@Suite struct ColorsetContrastTests {
    /// One colorset entry: the base ("Any") appearance or the dark one.
    struct Entry: Equatable {
        let isDark: Bool
        let color: RGB
        let alpha: String
    }

    // MARK: - Decodable mirrors of Contents.json (≈ a zod schema for the file; `Decodable` fails on a missing key)

    struct ColorsetJSON: Decodable { let colors: [ColorJSON] }

    struct ColorJSON: Decodable {
        let idiom: String
        let appearances: [AppearanceJSON]?
        let color: ColorBodyJSON
    }

    struct ColorBodyJSON: Decodable {
        let colorSpace: String
        let components: [String: String]
        enum CodingKeys: String, CodingKey {
            case colorSpace = "color-space"
            case components
        }
    }

    struct AppearanceJSON: Decodable, Equatable {
        let appearance: String
        let value: String
    }

    // MARK: - Loading

    /// `<repo>/HomeGymLog/Assets.xcassets`.
    static var assetsRoot: URL {
        FeedbackSourceTests.appSourceRoot.appendingPathComponent("Assets.xcassets", isDirectory: true)
    }

    /// Every `*.colorset/Contents.json`, decoded, keyed by the directory name minus ".colorset".
    static func rawColorsets() throws -> [String: [ColorJSON]] {
        let dirs = try FileManager.default.contentsOfDirectory(at: assetsRoot, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "colorset" }
        var result: [String: [ColorJSON]] = [:]
        for dir in dirs {
            let name = dir.deletingPathExtension().lastPathComponent
            let file = dir.appendingPathComponent("Contents.json")
            let data = try #require(try? Data(contentsOf: file), "\(name): Contents.json unreadable")
            let decoded = try #require(try? JSONDecoder().decode(ColorsetJSON.self, from: data), "\(name): JSON shape")
            result[name] = decoded.colors
        }
        return result
    }

    /// `"0x15"` → 21; nil for any other shape (a decimal `"0.082"`, three digits, no prefix).
    static func hexComponent(_ string: String) -> Int? {
        guard string.count == 4, string.hasPrefix("0x") else { return nil }
        let digits = string.dropFirst(2)
        guard digits.allSatisfy(\.isHexDigit) else { return nil }
        return Int(digits, radix: 16)
    }

    /// Every colorset as parsed entries. Fails naming the set and key on any malformed component.
    static func colorsets() throws -> [String: [Entry]] {
        var result: [String: [Entry]] = [:]
        for (name, colors) in try rawColorsets() {
            result[name] = try colors.map { json in
                let components = json.color.components
                try #require(Set(components.keys) == ["red", "green", "blue", "alpha"], "\(name): component keys")
                func channel(_ key: String) throws -> Int {
                    let raw = try #require(components[key], "\(name): \(key) missing")
                    return try #require(hexComponent(raw), "\(name): \(key) = \"\(raw)\" is not 0xRR")
                }
                let alpha = try #require(components["alpha"], "\(name): alpha missing")
                return Entry(isDark: json.appearances != nil,
                             color: RGB(r: try channel("red"), g: try channel("green"), b: try channel("blue")),
                             alpha: alpha)
            }
        }
        return result
    }

    /// The one entry of `set` for the given appearance.
    static func color(_ set: String, dark: Bool) throws -> RGB {
        let entries = try #require(try colorsets()[set], "no colorset \(set)")
        let matching = entries.filter { $0.isDark == dark }
        try #require(matching.count == 1, "\(set): expected one \(dark ? "dark" : "base") entry, found \(matching.count)")
        return matching[0].color
    }

    // MARK: - AC-11: the helper against the spec's worked values

    @Test("ContrastRatio reproduces the spec's anchor ratios and blends")
    func ratioAnchors() {
        #expect(abs(ContrastRatio.ratio("FFFFFF", "17161A") - 18.01) < 0.01)
        #expect(abs(ContrastRatio.ratio("22C55E", "FFFFFF") - 2.28) < 0.01)
        #expect(abs(ContrastRatio.ratio("15803D", "FFFFFF") - 5.02) < 0.01)
        #expect(abs(ContrastRatio.ratio("FFFFFF", "000000") - 21) < 0.001)
        #expect(ContrastRatio.blend("000000", 0.55, "F4F2F3") == "6E6D6D")
        #expect(ContrastRatio.blend("15803D", 0.14, "FFFFFF") == "DEEDE4")
    }

    // MARK: - AC-12: set list and entry shape

    @Test("the catalog holds exactly the eleven colorsets")
    func elevenColorsets() throws {
        let names = Set(try Self.colorsets().keys)
        #expect(names == ["AccentColor", "bd", "bg", "mu", "phaseDeload", "phaseFoundation", "sf", "sf2", "success",
                          "tx", "warning"])
    }

    @Test("every entry is universal sRGB; alpha is 0.080 for bd and 1.000 elsewhere")
    func entryShape() throws {
        for (name, colors) in try Self.rawColorsets() {
            for json in colors {
                #expect(json.idiom == "universal", "\(name)")
                #expect(json.color.colorSpace == "srgb", "\(name)")
            }
        }
        for (name, entries) in try Self.colorsets() {
            let expected = name == "bd" ? "0.080" : "1.000"
            #expect(entries.allSatisfy { $0.alpha == expected }, "\(name): alpha \(entries.map(\.alpha))")
        }
    }

    @Test("one base entry and at most one luminosity-dark entry per set")
    func appearanceShape() throws {
        let dark = [AppearanceJSON(appearance: "luminosity", value: "dark")]
        for (name, colors) in try Self.rawColorsets() {
            #expect(colors.filter { $0.appearances == nil }.count == 1, "\(name): base entries")
            let others = colors.filter { $0.appearances != nil }
            #expect(others.count <= 1, "\(name): non-base entries")
            #expect(others.allSatisfy { $0.appearances == dark }, "\(name): appearances")
        }
    }

    @Test("constant colors have exactly one entry, the base", arguments: ["AccentColor", "phaseFoundation", "phaseDeload"])
    func singleEntrySets(_ set: String) throws {
        let entries = try #require(try Self.colorsets()[set], "no colorset \(set)")
        #expect(entries.count == 1)
        #expect(entries.first?.isDark == false)
    }

    @Test("themed colors have one base and one dark entry", arguments: themedSets)
    func themedSetsHaveDark(_ set: String) throws {
        let entries = try #require(try Self.colorsets()[set], "no colorset \(set)")
        #expect(entries.count == 2)
        #expect(entries.filter { !$0.isDark }.count == 1)
        #expect(entries.filter(\.isDark).count == 1)
    }

    @Test("tokens this slice leaves alone keep their hex (spec §2.2)", arguments: unchangedHexRows)
    func unchangedHex(_ set: String, _ dark: Bool, _ expected: RGB) throws {
        #expect(try Self.color(set, dark: dark) == expected)
    }

    // MARK: - AC-13: Theme.swift names exactly the colorsets

    @Test("Theme.swift's Color(\"…\") names equal the colorset names, and no other file uses Color(\"…\")")
    func themeNamesMatchColorsets() throws {
        let lines = try FeedbackSourceTests.codeLines("Shared/Theme.swift")
        let names = lines.compactMap { line -> String? in
            guard let open = line.range(of: "Color(\""),
                  let close = line.range(of: "\")", range: open.upperBound..<line.endIndex) else { return nil }
            return String(line[open.upperBound..<close.lowerBound])
        }
        #expect(Set(names) == Set(try Self.colorsets().keys))
        let found = try FeedbackSourceTests.matches { $0.contains("Color(\"") }
        #expect(found.count == 11)
        #expect(found.allSatisfy { $0.path == "Shared/Theme.swift" })
    }

    // MARK: - AC-14: hard-coded color sites (paths, not counts)

    @Test("hard-coded colors appear only where the audit found them", arguments: hardCodedColorSites)
    func hardCodedColorPaths(_ token: String, _ expected: [String]) throws {
        let found = try FeedbackSourceTests.matches { $0.contains(token) }
        #expect(found.map(\.path).sorted() == expected,
                "\(token): a new hit needs a Light review (a new .fontWeight(.black) also matches \".black\")")
    }

    // MARK: - AC-12: the After state of this slice (F1, F2) and the ratios it must hold

    @Test("light mu, success and warning carry the slice's new values; dark keeps today's (spec §2.2 After)",
          arguments: afterHexRows)
    func afterHex(_ set: String, _ dark: Bool, _ expected: RGB) throws {
        #expect(try Self.color(set, dark: dark) == expected)
    }

    /// Compared unrounded: light `success` on light `bg` is 4.5001 (spec issue 2).
    @Test("text tokens clear their WCAG floors on each surface (spec §5.3)", arguments: contrastFloorRows)
    func contrastFloors(_ label: String, _ fg: (set: String, dark: Bool), _ bg: (set: String, dark: Bool),
                        _ floor: Double) throws {
        let ratio = ContrastRatio.ratio(try Self.color(fg.set, dark: fg.dark), try Self.color(bg.set, dark: bg.dark))
        #expect(ratio >= floor, "\(label): \(ratio)")
    }

    @Test("white text on the accent fill and on the light success / warning fills is ≥ 4.5")
    func whiteOnFills() throws {
        let accent = try Self.color("AccentColor", dark: false)
        let success = try Self.color("success", dark: false)
        let warning = try Self.color("warning", dark: false)
        #expect(ContrastRatio.ratio("FFFFFF", accent) >= 4.5)
        #expect(ContrastRatio.ratio("FFFFFF", success) >= 4.5)
        #expect(ContrastRatio.ratio("FFFFFF", warning) >= 4.5)
    }

    /// The pill sits on the workout screen's `bg`, not a card, so its tint composites over light `bg` (measured on the
    /// simulator: `D5E2DA`). The text on it is 3.75, a recorded shortfall accepted by the user (2026-09-25).
    @Test("the progression pill's light success text on its 0.14 tint over light bg is ≥ 3.5")
    func pillOnTint() throws {
        let success = try Self.color("success", dark: false)
        let tint = ContrastRatio.blend(success, 0.14, try Self.color("bg", dark: false))
        #expect(tint == "D5E2DA")
        let ratio = ContrastRatio.ratio(success, tint)
        #expect(ratio >= 3.5, "pill text on its tint is \(ratio); the recorded shortfall is 3.75 (spec floor 4.0 not met, accepted)")
    }
}

/// Sets with a light (base) and a dark entry.
let themedSets: [String] = ["bg", "sf", "sf2", "tx", "mu", "bd", "success", "warning"]

/// (set, dark, hex) for every entry this slice does not change, copied from spec §2.2.
let unchangedHexRows: [(String, Bool, RGB)] = [
    ("bg", false, "F4F2F3"), ("bg", true, "0F0E10"),
    ("sf", false, "FFFFFF"), ("sf", true, "1A191C"),
    ("sf2", false, "EBE8EA"), ("sf2", true, "242226"),
    ("tx", false, "17161A"), ("tx", true, "F5F3F4"),
    ("mu", true, "8F8B91"),
    ("bd", false, "000000"), ("bd", true, "FFFFFF"),
    ("AccentColor", false, "E11D48"),
    ("phaseFoundation", false, "5B8DEF"),
    ("phaseDeload", false, "8F8B91"),
]

/// token → the sorted app-target paths whose code lines contain it (spec §2.3 / AC-14, one line per path).
let hardCodedColorSites: [(String, [String])] = [
    (".shadow(", ["Features/Home/MissedActionBanner.swift", "Features/Workout/RestOverlay.swift",
                  "Shared/FloatingTabBar.swift"]),
    ("Color.black", ["Features/Home/MissedPromptHost.swift"]),
    (".black", ["Features/Home/MissedActionBanner.swift", "Features/Home/MissedPromptHost.swift",
                "Features/Workout/RestOverlay.swift", "Shared/FloatingTabBar.swift"]),
    ("preferredColorScheme", []),
    ("UIColor(", []),
    (".primary", []),
    (".secondary", []),
    ("Material", []),
]

/// (set, dark, hex) for the entries this slice sets (spec §2.2 "After", F1 and F2).
let afterHexRows: [(String, Bool, RGB)] = [
    ("mu", false, "68646A"),
    ("success", false, "15803D"), ("success", true, "22C55E"),
    ("warning", false, "B45309"), ("warning", true, "F59E0B"),
]

/// One contrast floor: `fg` text on the `bg` surface, each named by colorset and appearance.
typealias ContrastFloorRow = (label: String, fg: (set: String, dark: Bool), bg: (set: String, dark: Bool), floor: Double)

/// Spec §5.3 / AC-12: `tx`, `mu` ≥ 4.5 on every surface in both appearances (12 rows); Light `success`, `warning`
/// ≥ 4.5 on `bg` / `sf` and ≥ 4.0 on `sf2` (6, the recorded shortfalls); Dark `success`, `warning` ≥ 4.5 everywhere (6).
let contrastFloorRows: [ContrastFloorRow] = {
    var rows: [ContrastFloorRow] = []
    for dark in [false, true] {
        let theme = dark ? "Dark" : "Light"
        for fg in ["tx", "mu", "success", "warning"] {
            for surface in ["bg", "sf", "sf2"] {
                let isShortfall = !dark && surface == "sf2" && (fg == "success" || fg == "warning")
                let floor = isShortfall ? 4.0 : 4.5
                rows.append(("\(theme) \(fg) on \(surface)", (fg, dark), (surface, dark), floor))
            }
        }
    }
    return rows
}()

// MARK: - Gaps closed by test-writer (AC-12)

extension ColorsetContrastTests {
    /// AC-12's loud parser: every shape but `"0xRR"` is rejected, so a colorset rewritten by Xcode's inspector
    /// fails the suite instead of reading as 0 (≈ a zod schema's negative cases).
    @Test("the component parser rejects every shape but 0xRR",
          arguments: ["0.082", "21", "0x1", "0x155", "0X15", "0xG1", "", "1x15"])
    func hexComponentRejects(_ raw: String) {
        #expect(Self.hexComponent(raw) == nil)
    }

    @Test("the component parser reads 0xRR as its byte", arguments: [("0x00", 0), ("0x15", 21), ("0xff", 255), ("0xFF", 255)])
    func hexComponentAccepts(_ raw: String, _ expected: Int) {
        #expect(Self.hexComponent(raw) == expected)
    }
}

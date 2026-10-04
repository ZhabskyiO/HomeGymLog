import Foundation
import ImageIO      // CGImageSource: pixel size and alpha with no UIKit
import Testing

/// m5-release AC-4, AC-5, AC-6 (icon and welcome tile) and the NB-2 bundle-resource surface. Reads the checked-in
/// asset catalog and `design/icon/` from the source tree; never renders anything.
@Suite struct ReleaseAssetTests {
    static var appSourceRoot: URL { FeedbackSourceTests.appSourceRoot }
    /// `<repo>`, the parent of `HomeGymLog/`.
    static var repoRoot: URL { appSourceRoot.deletingLastPathComponent() }
    static var catalog: URL { appSourceRoot.appendingPathComponent("Assets.xcassets", isDirectory: true) }
    static var iconSet: URL { catalog.appendingPathComponent("AppIcon.appiconset", isDirectory: true) }
    static var tileSet: URL { catalog.appendingPathComponent("WelcomeTile.imageset", isDirectory: true) }
    static var designIcon: URL { repoRoot.appendingPathComponent("design/icon", isDirectory: true) }

    /// The slice of `AppIcon.appiconset/Contents.json` the tests read (`Decodable` ≈ a typed `JSON.parse`).
    struct IconSet: Decodable { let images: [IconImage] }
    struct IconImage: Decodable {
        let idiom: String
        let platform: String?
        let size: String?
        let filename: String?
        let appearances: [[String: String]]?
    }

    /// The image properties ImageIO reports for a PNG (`kCGImagePropertyPixelWidth`, `…HasAlpha`, …).
    static func pixelInfo(_ url: URL) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    static func iconImages() throws -> [IconImage] {
        let data = try Data(contentsOf: iconSet.appendingPathComponent("Contents.json"))
        return try JSONDecoder().decode(IconSet.self, from: data).images
    }

    /// Paths relative to `HomeGymLog/` of every non-hidden file under it.
    static func appTreeFiles() throws -> [String] {
        let enumerator = try #require(FileManager.default.enumerator(
            at: appSourceRoot, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]))
        let prefix = appSourceRoot.resolvingSymlinksInPath().path + "/"
        return enumerator.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map { $0.resolvingSymlinksInPath().path.replacingOccurrences(of: prefix, with: "") }
    }

    // MARK: - AC-4 the icon slots

    @Test("AC-4: three universal/ios 1024 slots with fixed filenames and appearances, no mac entries")
    func iconSlots() throws {
        let images = try Self.iconImages()
        #expect(images.count == 3)
        #expect(images.filter { $0.idiom == "mac" }.isEmpty)
        for image in images {
            #expect(image.idiom == "universal" && image.platform == "ios" && image.size == "1024x1024")
        }
        let byName = Dictionary(images.compactMap { image in image.filename.map { ($0, image.appearances) } },
                                uniquingKeysWith: { first, _ in first })
        #expect(byName.keys.sorted() == ["AppIcon-Dark.png", "AppIcon-Light.png", "AppIcon-Tinted.png"])
        #expect(byName["AppIcon-Light.png"] == .some(nil))
        #expect(byName["AppIcon-Dark.png"] == [["appearance": "luminosity", "value": "dark"]])
        #expect(byName["AppIcon-Tinted.png"] == [["appearance": "luminosity", "value": "tinted"]])
    }

    // MARK: - AC-5 the three PNGs

    @Test("AC-5: each icon PNG is 1024 × 1024 and the light (App Store) one has no alpha",
          arguments: ["AppIcon-Light.png", "AppIcon-Dark.png", "AppIcon-Tinted.png"])
    func iconPixels(name: String) throws {
        let info = try Self.pixelInfo(Self.iconSet.appendingPathComponent(name))
        #expect(info[kCGImagePropertyPixelWidth] as? Int == 1024)
        #expect(info[kCGImagePropertyPixelHeight] as? Int == 1024)
        if name == "AppIcon-Light.png" {
            // RGB PNGs report nil, RGBA ones true (researcher Q9): never `== false`. ITMS-90717 rejects alpha here.
            #expect(info[kCGImagePropertyHasAlpha] as? Bool != true)
        }
    }

    // MARK: - AC-6 the welcome tile and the artwork

    @Test("AC-6: WelcomeTile.svg is a byte copy of design/icon/HomeGymLog-icon.svg")
    func tileIsByteCopy() throws {
        let tile = try Data(contentsOf: Self.tileSet.appendingPathComponent("WelcomeTile.svg"))
        let source = try Data(contentsOf: Self.designIcon.appendingPathComponent("HomeGymLog-icon.svg"))
        #expect(!tile.isEmpty)
        #expect(tile == source)
    }

    @Test("AC-6: the tile imageset has one universal SVG that preserves vector data")
    func tileImageset() throws {
        let data = try Data(contentsOf: Self.tileSet.appendingPathComponent("Contents.json"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let images = try #require(json["images"] as? [[String: Any]])
        #expect(images.count == 1)
        #expect(images.first?["filename"] as? String == "WelcomeTile.svg")
        #expect(images.first?["idiom"] as? String == "universal")
        let properties = try #require(json["properties"] as? [String: Any])
        #expect(properties["preserves-vector-representation"] as? Bool == true)
    }

    @Test("AC-6: the tile's field color is the accent colorset's hex; no <text> or <metadata>")
    func tileColorAndElements() throws {
        let data = try Data(contentsOf: Self.catalog.appendingPathComponent("AccentColor.colorset/Contents.json"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let colors = try #require(json["colors"] as? [[String: Any]])
        #expect(colors.count == 1)
        let color = try #require(colors.first?["color"] as? [String: Any])
        let components = try #require(color["components"] as? [String: String])
        let hex = try ["red", "green", "blue"].map { channel in
            try #require(components[channel]).replacingOccurrences(of: "0x", with: "")
        }.joined()
        #expect(hex == "E11D48")   // spec §5.1: the colorset's only entry
        let svg = try String(contentsOf: Self.tileSet.appendingPathComponent("WelcomeTile.svg"), encoding: .utf8)
        #expect(svg.contains("#" + hex))
        #expect(!svg.contains("<text"))
        #expect(!svg.contains("<metadata"))
    }

    @Test("AC-6: each design/icon SVG carries the §5.1 mark geometry",
          arguments: ["HomeGymLog-icon.svg", "HomeGymLog-icon-dark.svg", "HomeGymLog-icon-tinted.svg"])
    func artworkGeometry(name: String) throws {
        let svg = try String(contentsOf: Self.designIcon.appendingPathComponent(name), encoding: .utf8)
        for pin in [#"x="160" y="464""#, #"x="220" y="232""#, #"x="628" y="232""#, #"width="704" height="96""#] {
            #expect(svg.components(separatedBy: pin).count - 1 == 1, "\(name): \(pin)")
        }
    }

    // MARK: - NB-2 the bundle-resource surface (SVG half)

    @Test("NB-2: the only SVG under HomeGymLog/ is the welcome tile's")
    func onlyTileSVG() throws {
        let svgs = try Self.appTreeFiles().filter { $0.hasSuffix(".svg") }
        #expect(svgs == ["Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg"])
    }

    // MARK: - AC-7 the privacy manifest and the merged Info.plist

    static func plist(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test("AC-7: PrivacyInfo.xcprivacy declares no tracking, no collected data, and UserDefaults for CA92.1")
    func privacyManifest() throws {
        let manifest = try Self.plist(Self.appSourceRoot.appendingPathComponent("PrivacyInfo.xcprivacy"))
        #expect(manifest.keys.sorted() == ["NSPrivacyAccessedAPITypes", "NSPrivacyCollectedDataTypes",
                                           "NSPrivacyTracking", "NSPrivacyTrackingDomains"])
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(apis.count == 1)
        #expect(apis.first?["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(apis.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }

    @Test("AC-7: no privacy manifest in the widget extension or the shared folder",
          arguments: ["HomeGymLogWidgets", "HomeGymLogShared"])
    func noManifestOutsideApp(folder: String) throws {
        let root = Self.repoRoot.appendingPathComponent(folder, isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let names = enumerator.compactMap { ($0 as? URL)?.lastPathComponent }
        #expect(!names.isEmpty)   // the walk reached the folder
        #expect(!names.contains("PrivacyInfo.xcprivacy"))
    }

    @Test("AC-7: HomeGymLogSupport/Info.plist holds exactly the launch color and the encryption answer")
    func mergedInfoPlist() throws {
        let info = try Self.plist(Self.repoRoot.appendingPathComponent("HomeGymLogSupport/Info.plist"))
        #expect(info.keys.sorted() == ["ITSAppUsesNonExemptEncryption", "UILaunchScreen"])
        let launch = try #require(info["UILaunchScreen"] as? [String: Any])   // [String: Any], never [String: String] (U10)
        #expect(launch.keys.sorted() == ["UIColorName"])
        #expect(launch["UIColorName"] as? String == "bg")
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }

    @Test("AC-7 / NB-2: no Info.plist under HomeGymLog/; its non-Swift files outside the catalog are the two resources")
    func nonSwiftResources() throws {
        let files = try Self.appTreeFiles()
        #expect(!files.contains { $0.hasSuffix("Info.plist") })
        let resources = files.filter { !$0.hasSuffix(".swift") && !$0.hasPrefix("Assets.xcassets/") }
        #expect(Set(resources) == ["rest-over.caf", "PrivacyInfo.xcprivacy"])
        #expect(resources.count == 2)
    }
}

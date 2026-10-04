# m5-release — Swift concepts, for a React developer

Release plumbing (icon, manifest, Info keys, store text) with little new Swift: an ABOUT card, a constant moved into
Engine, six warning fixes, and tests that read bundles, plists and PNGs. Earlier notes cover `Bundle.main`, `nonisolated`,
closures, accessibility modifiers, `ShareLink`, `openURL`, `@Test(arguments:)` and `Decodable`; not repeated here.

## 1. `Link(destination:)`: an `<a href>` that leaves the app

`Link` is a SwiftUI control that opens a URL in Safari when tapped. Its label is any view, so it is styled like the
other action rows. React analogy: `<a href="…" target="_blank">` with a custom child. Used at
`HomeGymLog/Features/Settings/AboutRows.swift:11`:

```swift
Link(destination: url) {
    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
}
```

What surprises JavaScript developers: there is no `onClick`. The system owns the navigation and gives the control the
"link" accessibility trait, so VoiceOver says "Privacy policy, link" with no extra code.

## 2. `Image(decorative:)`: `alt=""` for an image

`Image(decorative: "WelcomeTile")` draws an asset that assistive technology skips entirely; `Image("WelcomeTile")`
would instead be read aloud with its asset name. React analogy: `<img alt="" aria-hidden>`. Used at
`HomeGymLog/Features/Onboarding/WelcomeStep.swift:10`:

```swift
Image(decorative: "WelcomeTile").resizable().scaledToFit().frame(width: 44, height: 44)
```

Surprise: an `Image` is not resizable by default; without `.resizable()` the asset keeps its 1024 pt intrinsic size and `.frame` only crops.

## 3. A forwarding `static var`: re-exporting a constant

Engine must not reference a `Features/` type, so the body-weight range moved into `ProgramGenerator`, and the draft
keeps a read-only property pointing at it so no caller changes. React analogy: `export { range } from './engine'`.
Declared at `HomeGymLog/Engine/ProgramGenerator.swift:64` and forwarded at
`HomeGymLog/Features/Onboarding/OnboardingDraft.swift:33`:

```swift
static let bodyWeightRangeLb = 50.0...500.0                       // Engine
static var bodyWeightRangeLb: ClosedRange<Double> { ProgramGenerator.bodyWeightRangeLb }   // the draft
```

Surprise: `50.0...500.0` is a value of type `ClosedRange<Double>`, with `lowerBound`, `upperBound` and `contains`.
A `static var` with only a getter is a computed property, recomputed on every read; here it just forwards.

## 4. A function reference carries its actor; a closure does not

`sets.map(SetSnapshot.init)` passes the initializer itself as a value. Under main-actor-by-default that reference is
main-actor-isolated, and `map`'s parameter is not, so the Release compiler warns. Writing `{ SetSnapshot($0) }` makes a
closure that inherits the caller's isolation and compiles clean. React analogy: `arr.map(fn)` versus
`arr.map(x => fn(x))`, which in JavaScript are equivalent, but here are not. Used at
`HomeGymLog/Models/WorkoutLogStore.swift:220`, `:288`, `:291` and `HomeGymLog/Features/Workout/WorkoutView.swift:91`:

```swift
let snapshots = ([set] + carried).map { SetSnapshot($0) }
guard !sets.contains(where: { awaitsRating($0) }) else { return false }
```

Surprise: `$0` is the closure's implicit first parameter; a bare trailing closure is not allowed inside a `guard` condition.

## 5. `Bundle.main.infoDictionary`: reading Info.plist at runtime

The built Info.plist is available as a `[String: Any]?` dictionary. The version row reads two keys from it, and the
hosted tests read the orientation, encryption and launch-screen keys the same way. React analogy: reading
`process.env` or a `manifest.json` at runtime. Used at `HomeGymLog/Features/Settings/SettingsContent.swift:119`
and `:124`, and in `HomeGymLogTests/App/ReleaseBundleTests.swift:30`:

```swift
private var info: [String: Any]? { Bundle.main.infoDictionary }
SettingsText.versionText(short: info?["CFBundleShortVersionString"] as? String, …)
```

Surprise: every value comes out as `Any` and must be cast with `as?`, and a boolean written as `<false/>` reads back
as `Bool` only through `as? Bool`; printing it shows `0`.

## 6. A total function over optional inputs: `versionText`

`versionText(short:build:)` takes two optionals and always returns a string, falling back to an em dash when either
is missing or empty. React analogy: a formatter that never throws, `short && build ? \`${short} (${build})\` : "—"`.
Defined at `HomeGymLog/Shared/SettingsText.swift:49`:

```swift
static func versionText(short: String?, build: String?) -> String {
    guard let short, !short.isEmpty, let build, !build.isEmpty else { return "\u{2014}" }
    return "\(short) (\(build))"
}
```

Surprise: `guard let short` with no `= …` is shorthand for `guard let short = short`; after the `guard`, `short`
is a plain non-optional `String` for the rest of the function.

## 7. `PropertyListSerialization`: parsing a plist like JSON

Apple's plist format (the manifest, Info.plist) parses into the same `[String: Any]` shape as JSON through
`PropertyListSerialization.propertyList(from:format:)`. React analogy: `JSON.parse`, but for XML plists. Used at
`HomeGymLogTests/Static/ReleaseAssetTests.swift:140`:

```swift
try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
```

Surprise: the result is `Any`; the dictionary cast can fail, so `#require` wraps it and stops the test with a message.

## 8. ImageIO's `CGImageSource`: image metadata without UIKit

A test can read a PNG's pixel size and whether it has an alpha channel through the C-flavoured ImageIO API,
without decoding pixels. React analogy: reading a file's header with a small library instead of loading it into an
`<img>`. Used at `HomeGymLogTests/Static/ReleaseAssetTests.swift:28` and `:71`:

```swift
let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
#expect(info[kCGImagePropertyPixelWidth] as? Int == 1024)
```

Surprise: keys are `CFString` constants and the dictionary is `[CFString: Any]`; a missing key means "not present",
so the no-alpha check is `!= true` rather than `== false` (an RGB PNG has no `HasAlpha` entry at all).

## 9. Bytes versus characters: `utf8.count` and `unicodeScalars.count`

App Store Connect limits keywords by bytes and text fields by characters, so the checker counts each the right way.
React analogy: `new TextEncoder().encode(s).length` versus `[...s].length`. Used at
`HomeGymLogTests/Static/StoreMetadataTests.swift:41` and `:45`:

```swift
if subtitle.unicodeScalars.count > 30 { found.append("subtitle: length") }
if keywords.utf8.count > 100 { found.append("keywords: bytes") }
```

Surprise: plain `String.count` counts grapheme clusters; "é" is one character, one scalar here, two UTF-8 bytes.

## 10. Two regex engines: `Regex` and ICU `range(of:options:)`

Swift's native `Regex` type does not support lookbehind at runtime, so the whole-token `Link(` scan uses the older
ICU engine through `String.range(of:options: .regularExpression)`. React analogy: the same pattern working in one
JavaScript engine and throwing in another. Used at `HomeGymLogTests/Static/ReleaseCopyTests.swift:89`:

```swift
$0.range(of: token, options: .regularExpression) != nil
```

Surprise: the ICU call returns an optional `Range<String.Index>`, not a match object; `!= nil` is the "matches" test.

## What to read next

- [Link](https://developer.apple.com/documentation/swiftui/link) and [Image.init(decorative:)](https://developer.apple.com/documentation/swiftui/image/init(decorative:bundle:)), the two SwiftUI additions of this slice.
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), what the manifest declares and the required-reason categories.
- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases), the Organizer steps the release checklist refers to.

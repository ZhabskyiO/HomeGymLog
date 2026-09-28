# m5-light-theme — Swift concepts, for a React developer

This slice changed no app Swift; the new Swift is test code. Earlier notes cover `extension`, `static func`, `try?`,
key paths, tuples and `@Test(arguments:)`; those are not repeated here.

## 1. A colorset with a dark entry: one name, two values

An asset-catalog color is a folder with a `Contents.json` listing one entry per appearance. The entry with no
`appearances` is the light value ("Any"), and the one tagged `luminosity: dark` is used in Dark mode.

```json
{ "idiom": "universal", "appearances": [{ "appearance": "luminosity", "value": "dark" }],
  "color": { "components": { "red": "0x22", "green": "0xC5", "blue": "0x5E", "alpha": "1.000" } } }
```
`HomeGymLog/Assets.xcassets/success.colorset/Contents.json:15`, read by `Color("success")` at
`HomeGymLog/Shared/Theme.swift:13`. React analogy: a CSS custom property redefined under
`@media (prefers-color-scheme: dark)`. **Surprise:** before this slice `success` had only one entry, so it was
the same in both themes. Adding a dark entry changed Light and left Dark alone, and no Swift file changed.

## 2. `Decodable`: a typed JSON schema

A struct that conforms to `Decodable` can be filled from JSON by `JSONDecoder().decode(T.self, from: data)`. A
missing key or a wrong type throws.

```swift
struct ColorJSON: Decodable {
    let idiom: String
    let appearances: [AppearanceJSON]?
```
`HomeGymLogTests/Static/ColorsetContrastTests.swift:23`. React analogy: a zod schema plus `schema.parse(JSON.parse(text))`.
**Surprise:** an optional property (`[AppearanceJSON]?`) is how you say "this key may be absent"; a non-optional one
makes the key required. You never write a parser by hand.

## 3. `CodingKeys`: renaming JSON keys

A nested `enum CodingKeys: String, CodingKey` maps Swift property names to JSON keys when they differ, such as a
key with a hyphen that can't be a Swift identifier.

```swift
enum CodingKeys: String, CodingKey {
    case colorSpace = "color-space"
    case components
}
```
`ColorsetContrastTests.swift:32`. React analogy: the key mapping in a `z.object(...).transform` that turns
`"color-space"` into `colorSpace`. **Surprise:** once you declare `CodingKeys`, every decoded property must be
listed in it, including the ones whose names don't change (`components`).

## 4. `ExpressibleByStringLiteral`: a type you can write as a string

A type that conforms to this protocol can be created from a string literal wherever that type is expected. The
compiler calls its `init(stringLiteral:)`.

```swift
struct RGB: Equatable, CustomStringConvertible, ExpressibleByStringLiteral {
    init(stringLiteral hex: String) { … }
```
`HomeGymLogTests/Support/ContrastRatio.swift:8` and `:15`; used as `ContrastRatio.ratio("FFFFFF", "17161A")` at
`ColorsetContrastTests.swift:105`. React analogy: a TypeScript template-literal type that also parses the value at
runtime. **Surprise:** it applies only to literals written in source. A `String` variable is not converted to `RGB`
automatically; it needs the explicit init.

## 5. `CustomStringConvertible`: `toString()` for your type

A type conforms by providing a `description` property, and string interpolation (`"\(color)"`) and test failure
messages then use it.

```swift
var hex: String { String(format: "%02X%02X%02X", r, g, b) }
var description: String { hex }
```
`ContrastRatio.swift:23` and `:25`. React analogy: overriding `toString()` on a class. **Surprise:** this is why a
failing `#expect(tint == "D5E2DA")` prints `DEEDE4`, not `RGB(r: 222, g: 237, b: 228)`.

## 6. `#require`: an assertion that stops the test

Swift Testing's `#expect` records a failure and keeps going. `try #require(...)` records the failure **and throws**,
so the test stops there. It also unwraps an optional.

```swift
let data = try #require(try? Data(contentsOf: file), "\(name): Contents.json unreadable")
```
`ColorsetContrastTests.swift:58`. React analogy: Jest's `expect(x).toBeDefined()` followed by a guard clause that
`return`s, in one line. **Surprise:** with `try?` in front, the underlying error (for example a JSON key path) is
dropped and only your message is shown. The swift review flagged this as an optional improvement.

## 7. `preconditionFailure`: crash on purpose

`preconditionFailure("…")` stops the program right away. Use it for a mistake the programmer made, not for bad input,
which should `throw`.

```swift
guard hex.count == 6, hex.allSatisfy(\.isHexDigit), let value = Int(hex, radix: 16) else {
    preconditionFailure("RGB literal must be six hex digits, got \"\(hex)\"")
}
```
`ContrastRatio.swift:16`. React analogy: `throw new Error("unreachable")` in an exhaustive switch that should never be
reached. **Surprise:** an `init(stringLiteral:)` can't `throw`, so a typo in a test literal traps the whole test run.
That's acceptable only because literals exist in test source; file data goes through the throwing parser instead.

## 8. Nested functions

A `func` can be declared inside another function. It can read the outer function's parameters and locals, like a
closure, but it has a name and normal function syntax.

```swift
static func luminance(_ c: RGB) -> Double {
    func linear(_ channel: Int) -> Double { … }
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
```
`ContrastRatio.swift:32`; another one at `ColorsetContrastTests.swift:80` throws and captures `name`. React analogy:
a helper `const` arrow function defined inside a component or function. **Surprise:** a nested `func` can call itself
recursively and be `throws`, which a closure assigned to a `let` does less cleanly.

## 9. A constant built by a closure called right away

`let x: T = { … }()` runs the closure once and stores its result. It is handy when building a value takes loops.

```swift
let contrastFloorRows: [ContrastFloorRow] = {
    var rows: [ContrastFloorRow] = []
    …
    return rows
}()
```
`ColorsetContrastTests.swift:272`. React analogy: an IIFE, `const rows = (() => { … })()`. **Surprise:** a global
`let` like this is lazy in Swift: it runs on first use, not at program start, and exactly once, safely across threads.

## 10. `typealias` for a labelled tuple

`typealias` gives a type a second name. Here it names a tuple with labelled parts so each test row reads like a
small record without declaring a struct.

```swift
typealias ContrastFloorRow = (label: String, fg: (set: String, dark: Bool), bg: (set: String, dark: Bool), floor: Double)
```
`ColorsetContrastTests.swift:268`, consumed by `@Test(arguments: contrastFloorRows)` at `:201`. React analogy:
`type ContrastFloorRow = { label: string; fg: {set: string; dark: boolean}; … }`. **Surprise:** Swift Testing spreads a
tuple argument into the test function's parameters, so the function takes four parameters, not one tuple.

## What to read next

The next slice, `m5-export`, writes and reads a JSON backup, so `Codable` in both directions and SwiftData schema
versioning matter:
- [Encoding and Decoding Custom Types](https://developer.apple.com/documentation/foundation/encoding-and-decoding-custom-types)
- [JSONEncoder](https://developer.apple.com/documentation/foundation/jsonencoder)
- [VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema)

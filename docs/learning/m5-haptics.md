# m5-haptics — Swift concepts, for a React developer

What is new in this slice, in the order it helps to read it. Earlier notes cover `@State`, `@AppStorage`, `.onChange`,
`.task(id:)`, `extension`, closures, `throws`/`do`/`catch`, `if case`, enums with associated values and `nonisolated`;
those are not repeated here.

## 1. `.sensoryFeedback(trigger:)`: a haptic as an effect on a value

A haptic plays when a value you pass changes, not when you call a function. The closure picks the kind at playback
time, or returns `nil` for none.

```swift
.sensoryFeedback(trigger: setLogged) { _, _ in kind(.setLogged) }
```
`HomeGymLog/Features/Workout/WorkoutFeedback.swift:20`. React analogy: `useEffect(() => buzz(), [setLogged])` where
the dependency is a counter you bump. **Surprise:** it never fires on first appearance, and a `Bool` flipped twice in
one update nets no change, so the project bumps an `Int` (gotchas SwiftUI 2026-09-24).

## 2. `ViewModifier` plus `extension View`: a reusable wrapper

A `ViewModifier` is a struct with `body(content:)` that takes the view it wraps and returns a decorated one. An
`extension View` method gives it a fluent name so callers write `.workoutFeedback(…)`.

```swift
struct WorkoutFeedback: ViewModifier {
    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: setLogged) { _, _ in kind(.setLogged) }
```
`WorkoutFeedback.swift:9` and `:39`. React analogy: a wrapper component (or HOC) that renders `children` with extra
effects attached. **Surprise:** it holds no state of its own here; the counters are passed in like props, and the
owning view keeps them in `@State`.

## 3. `static let` and a `private final class`: one instance per process

`static let` is created once, lazily, for the whole app. When it holds a class (a reference type), the `let` only
fixes *which* object it points at; the object's own `var`s still change.

```swift
private static let box = PlayerBox()
private final class PlayerBox { private var player: AVAudioPlayer? … }
```
`HomeGymLog/App/RestChime.swift:23` and `:28`. React analogy: a module-level `const cache = new Map()` that every
render shares. **Surprise:** `final` means "no subclasses", nothing like JavaScript's `Object.freeze`.

## 4. `@Entry` defaults run on every read

`@Entry var restChime: RestChime = .live()` declares an environment value with a default. The macro turns that
default into a computed getter, so `.live()` runs again each time a view reads the value without an override.

```swift
@Entry var restChime: RestChime = .live()
```
`HomeGymLog/App/AppClock.swift:31`. React analogy: `createContext(makeService())` would run once; this behaves more
like `useContext(Ctx) ?? makeService()` at every read. **Surprise:** any cache built inside `.live()` is rebuilt each
time, which is why the player lives in the static box from concept 3 (gotchas SwiftUI 2026-09-24).

## 5. Audio session categories: how your sound mixes with other apps

Every iOS app has one `AVAudioSession`. Its category tells the system whether your sound stops other audio, ducks
it or mixes with it, and whether it obeys the silent switch.

```swift
try AVAudioSession.sharedInstance().setCategory(.ambient)
```
`RestChime.swift:44`. React analogy: none in the browser; the nearest is choosing whether a `<video>` autoplays
muted. **Surprise:** the default `soloAmbient` *stops* the user's Spotify, so `.ambient` is set before the first play.

## 6. `Bundle.main`: files shipped inside the app

A non-code file under the app folder is copied into the app package (the bundle), and `Bundle.main.url(forResource:
withExtension:)` finds it at runtime. It returns an optional URL because the file might be missing.

```swift
guard let url = Bundle.main.url(forResource: "rest-over", withExtension: "caf"),
```
`RestChime.swift:48`. React analogy: `new URL('./rest-over.caf', import.meta.url)` for a static asset. **Surprise:**
in the hosted unit tests `Bundle.main` is the app, so a test can check the asset really shipped
(`HomeGymLogTests/App/RestChimeAssetTests.swift:11`).

## 7. `try?` versus `do`/`catch`: when the failure matters

`try?` turns a throwing call into an optional: `nil` on any error, and the error is gone. `do`/`catch` lets you act on
the failure.

```swift
do { try AVAudioSession.sharedInstance().setCategory(.ambient) } catch { return nil }
guard let url = …, let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
```
`RestChime.swift:43–49`. React analogy: `await p.catch(() => null)` versus a `try { } catch { }` block. **Surprise:**
`try? setCategory(...)` on its own line would compile and silently carry on, playing in the music-stopping category;
the explicit `catch` makes the early exit visible.

## 8. `catch let error as SomeType`: catch clauses in order

Several `catch` clauses can follow one `do`. Swift tries them top to bottom; `as SomeType` matches only that error
type, and a bare `catch` takes the rest.

```swift
} catch let error as DebugFeedbackError {
    …
} catch {
```
`HomeGymLog/App/HomeGymLogApp.swift:86`. React analogy: `catch (e) { if (e instanceof DebugFeedbackError) … else … }`,
written as separate clauses. **Surprise:** the typed clause must come first; a bare `catch` above it would swallow
everything.

## 9. Comma conditions: `if wrote, let cue`

An `if` or `guard` can list several conditions separated by commas. Each can be a `Bool` or an optional unwrap, all
must hold, and later ones can use names bound earlier.

```swift
let wrote = try WorkoutLogStore.skipRest(log, in: modelContext)
if wrote, let cue {
```
`HomeGymLog/Features/Workout/WorkoutView.swift:348`. React analogy: `if (wrote && cue != null)`, with `cue` narrowed to
non-null inside, as TypeScript does. **Surprise:** `let cue` alone (no `= …`) is shorthand for `let cue = cue`, the
Swift 5.7 unwrap form.

## 10. A local name hides a type's function while it is being declared

Inside `let content = content(withSound:)`, the name `content` already means the new local constant, so the call
would refer to itself and fail to compile. Writing the type name picks the static function.

```swift
let content = RestNotificationCenter.content(withSound: withSound)
```
`HomeGymLog/App/RestNotifier.swift:24`. React analogy: TypeScript's "block-scoped variable used before its
declaration" (`const x = x()`). **Surprise:** inside a type, Swift lets you call a static function without the type
name, until a local with the same name appears.

## What to read next

- [ColorScheme](https://developer.apple.com/documentation/swiftui/colorscheme) and
  [`@Environment(\.colorScheme)`](https://developer.apple.com/documentation/swiftui/environmentvalues/colorscheme), for
  m5-light-theme's audit
- [Supporting Dark Mode in your interface](https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface)
  (asset-catalog colors with light and dark variants)
- [SensoryFeedback](https://developer.apple.com/documentation/swiftui/sensoryfeedback), the full list of haptic kinds

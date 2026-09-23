# m4-settings — Swift concepts, for a React developer

What is new in this slice. Earlier notes cover `@State`, `@Binding`, `@Query`, `.task(id:)`, `.onChange`,
`FetchDescriptor`, closures, `throws`, `Equatable` and caseless enums; those are not repeated here.

## 1. `@AppStorage` — state backed by preferences, not by the database

`@AppStorage("key")` reads and writes `UserDefaults` and re-renders every view reading that key. Analogy:
`useLocalStorage`, except the subscription is app-wide, so two screens reading `"units"` cannot disagree.

```swift
@AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
@AppStorage(MissedDayPolicy.storageKey) private var policyRaw = MissedDayPolicy.ask.rawValue
```

`HomeGymLog/Features/Settings/SettingsView.swift:13-15`. Two surprises: it stores only plain types, so an
enum goes in as its raw string (hence the next two items); and *where* you read it matters — these reads
sit below the app's `.defaultAppStorage(defaults)`, so a test or a `-seed` launch can swap the whole store
underneath them (≈ reading context below the provider, never above it).

## 2. `String`-raw enums and `CaseIterable` — a string union that still type-checks

An enum can declare a raw type, so `case ask` carries the string `"ask"`; `CaseIterable` synthesises
`allCases`, an array you map over to build a control.

```swift
nonisolated enum MissedDayPolicy: String, CaseIterable, Sendable {
    case ask, shift, skip
    static func from(raw: String) -> MissedDayPolicy { MissedDayPolicy(rawValue: raw) ?? .ask }
}
```

`HomeGymLog/Engine/MissedDay.swift` (and `Shared/AppearanceMode.swift`). Analogy: `type Policy =
'ask' | 'shift' | 'skip'` plus an `ALL_POLICIES` array, but every `switch` must now handle all three. The
surprise: `init(rawValue:)` returns an **optional** — a stored `"sepia"` is not a crash and not a silent
`undefined`, it is `nil` you must answer for. `from(raw:)` is that answer, in one place.

## 3. A computed `Binding` — the adapter between raw storage and a typed control

A `Binding` is not only something you receive with `$` — you can build one from a getter and a setter, so
a `String` in preferences can drive a control that speaks in enums.

```swift
private var appearance: Binding<AppearanceMode> {
    Binding(get: { AppearanceMode.from(raw: appearanceRaw) }, set: { appearanceRaw = $0.rawValue })
}
```

`HomeGymLog/Features/Settings/SettingsView.swift:49-51`. Analogy: a controlled input with `parse` in and
`serialize` out. The surprise: this is a *computed property*, rebuilt on every render, and that is fine —
a `Binding` is two closures, not stored state, so there is nothing to memoise.

## 4. `.confirmationDialog` and `.alert` — presentation is a modifier driven by a `Bool`

Both attach to a view and are driven by a binding, never called imperatively. `role: .destructive` gives
the red button, `role: .cancel` the bottom one; the system decides placement and order.

```swift
.confirmationDialog(SettingsText.restartTitle, isPresented: $showsRestartConfirm, titleVisibility: .visible) {
    Button(SettingsText.restartConfirm, role: .destructive) { confirmRestart() }
    Button(SettingsText.cancel, role: .cancel) {}
}
```

`HomeGymLog/Features/Settings/SettingsView.swift:32-42`. Analogy: `{open && <Dialog/>}` with the styling
delegated to the platform. The surprise: you never write "close the dialog" — tapping any button flips the
binding for you. Presenting an `.alert` from a dialog button's action also works; we probed it, because two
flags on one view looks like it should not.

## 5. A `struct` as a `.task(id:)` key — "run once per situation"

`.task(id:)` restarts when the id changes, and the id must be `Equatable`. Tuples are not, so a small
struct becomes the identity of one piece of work.

```swift
nonisolated struct AutomaticActionKey: Equatable, Hashable, Sendable {
    let policy: MissedDayPolicy
    let missedIndex: Int
    let day: Date
}
```

`HomeGymLog/Engine/MissedDay.swift:150-155`. Analogy: the dependency array of `useEffect`, except you name
it and can unit-test it. The surprise: structs synthesise `==` from their fields, so two separately built
keys with equal contents *are* equal — value semantics, not reference identity. That is what makes "same
policy, same session, same day → do not write again" true with no bookkeeping. (The pass this key drives
takes an `assertOnFailure: Bool = true` parameter — a Swift default argument — and passes `false` on the
automatic path, which runs with no tap and would otherwise trap Debug builds at every launch.)

## 6. `Task.sleep`, cancellation, and a `catch` that deliberately does nothing

A `.task(id:)` is cancelled when the id changes or the view goes away, and `Task.sleep` *throws* on
cancellation — which turns "was I cancelled?" into ordinary control flow.

```swift
do { try await Task.sleep(for: .seconds(3)) } catch { return }
if banner?.token == timerToken { banner = nil }
```

`HomeGymLog/Features/Home/MissedPromptHost.swift:95-101`. The `return` in the `catch` is the whole feature:
leaving Home cancels the timer and the banner is *not* cleared, so it survives and the three seconds restart
on the way back. Analogy: an aborted `setTimeout` whose cleanup declines to fire the callback. The surprise:
`try? await Task.sleep(...)` swallows the cancellation and falls through, clearing the banner — the
tidier-looking spelling is the buggy one.

## 7. Reaching into UIKit, in exactly one file

SwiftUI sits on UIKit, and sometimes the older API is the one that works. The appearance preference is set
on the scene's windows because `.preferredColorScheme` misses alerts and dialogs on iOS 17.5 and never
updates an open sheet.

```swift
for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
    for window in scene.windows { window.overrideUserInterfaceStyle = style }
}
```

`HomeGymLog/App/RootView.swift:81-89`. Analogy: a direct DOM write where the framework's abstraction falls
short — and, as there, you keep it to one file. `AppearanceMode` stays UIKit-free; only this private
function knows `UIUserInterfaceStyle`. `compactMap { $0 as? UIWindowScene }` is the idiom for "keep the
ones of this type, already typed".

## 8. An enum with associated values as a function's return type

`RestartAction.run` returns *what happened*, not a `Bool` and not a thrown error.

```swift
enum Outcome: Equatable {
    case archived
    case alreadyArchived
    case failed(String)
}
```

`HomeGymLog/Features/Settings/RestartAction.swift:9-16`. Analogy: a discriminated union as the return type,
`{ kind: 'failed', message: string }`. The pay-off is testability — the restart decision is a function a
unit test calls three ways, not a tap only a UI test can reach — and the `switch` over it is exhaustive, so
a fourth outcome later breaks every caller at compile time.

## What to read next

- [`Menu`](https://developer.apple.com/documentation/swiftui/menu) — the pop-up used for the policy row, and
  why a `Picker` inside it keeps the check mark.
- [Task cancellation](https://developer.apple.com/documentation/swift/task) — what cancellation does and does
  not stop, the model behind item 7.
- [`UNUserNotificationCenter`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
  — authorization and scheduling, which the reminder slice is built on.

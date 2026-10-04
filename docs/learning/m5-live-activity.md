# Study note — m5-live-activity (2026-10-03)

Ten concepts that appear for the first time in this slice, each mapped to React/TypeScript. The spec
(`docs/specs/m5-live-activity.md`) says what the feature does; this says what the code is made of.

## 1. Two targets, one shared folder

A *target* is a separately compiled product with its own entry point and its own `import`s. This slice
adds a second one, the widget extension, and a folder both targets compile. Analogy: two packages in a
monorepo sharing a `common/` directory listed in both `tsconfig.json` files. Used at
`HomeGymLogShared/RestActivityAttributes.swift:8`. Surprise: a file is compiled only into the targets
that list its folder; there is no `import` between the app and the extension, so a shared type must sit
in the shared folder and reference nothing that lives in only one of them (no `UIApplication`, no
`WorkoutLogStore`).

## 2. `ActivityAttributes` and `ContentState`: serialized props

The Live Activity is drawn by the extension process from data the app sends through the system. The
fixed part is the attributes; the part each update replaces is `ContentState`, which must be `Codable`
and `Hashable` so the OS can serialize and diff it. Analogy: a props type shared between the code that
calls `setState` and the component that renders it, except the two run in different processes.
`HomeGymLogShared/RestActivityAttributes.swift:14-18`:

```swift
nonisolated struct ContentState: Codable, Hashable {
    var restStartedAt: Date
    var restEndsAt: Date
    var nextText: String
```

Surprise: the extension never calls into the app. Anything it needs pre-formatted (the "Next:" line) has
to be put into the state by the app before sending.

## 3. `@main` and `WidgetBundle`: a second entry point

Every target has exactly one `@main` type. The extension's is a `WidgetBundle` whose `body` lists the
widgets and activities it provides. Analogy: a second `index.tsx` with its own `createRoot`.
`HomeGymLogWidgets/HomeGymLogWidgetsBundle.swift:6-11`. Surprise: the OS mounts this root, not your
app; nothing in `HomeGymLogApp` refers to it.

## 4. `ActivityConfiguration`: render closures the OS calls

`ActivityConfiguration(for:)` takes two closures, one for the Lock Screen and one for the Dynamic Island,
and calls them with a `context` holding the current `state` and an `isStale` flag. Analogy: a render
function the platform calls with props on every update. `HomeGymLogWidgets/RestLiveActivity.swift:10-16`:

```swift
ActivityConfiguration(for: RestActivityAttributes.self) { context in
    RestActivityLockScreenView(state: context.state, isStale: context.isStale)
} dynamicIsland: { context in
```

Surprise: `isStale` is set by the system when the `staleDate` the app supplied passes; the app wrote
nothing to make that happen.

## 5. `Text(timerInterval:)`: a countdown that ticks by itself

A text view given a date range renders a live count down and keeps ticking without any update from your
code, even with the app killed. Analogy: a `<Countdown to={date}>` component whose interval the platform
owns. `HomeGymLogWidgets/RestActivityLockScreenView.swift:22`. Surprise: it reads the wall clock, so a
test or seed with a frozen `AppClock` draws an already-ended timer; the `-liveActivity on` seed switches
the clock to live for that reason.

## 6. App Intents: `LiveActivityIntent` and `Button(intent:)`

A button on the Lock Screen cannot run a closure (the extension process may not even be alive). It runs an
*intent*, a struct whose `perform()` the system executes in the app's process. Analogy: a server action
posted by a form button; the app owns the real work. `HomeGymLogShared/RestActivityIntents.swift:7-20`
and the buttons at `HomeGymLogWidgets/RestActivityLockScreenView.swift:65`:

```swift
Button(intent: AddRestTimeIntent()) {
```

Surprise: the build extracts metadata from the intent's source, so `static let title` must be a string
literal; a constant from another file fails the build with a message about initializers.

## 7. `@MainActor static var` and `MainActor.run { }`

The intent's `perform()` is not on the main actor, but the app's store is. The hook is declared
`@MainActor static var handler`, and the intent hops over with `await MainActor.run { … }` to read it.
Analogy: `postMessage` to the main thread, then awaiting the reply. `HomeGymLogShared/LiveActivityIntentHooks.swift:14`
and `HomeGymLogShared/RestActivityIntents.swift:17`:

```swift
let handler = await MainActor.run { LiveActivityIntentHooks.handler }
await handler?(.addRest)
```

Surprise: putting `@MainActor` on the whole intent struct breaks the App Intents conformance; only the
hop inside `perform()` is allowed (gotchas Swift language 2026-10-02).

## 8. A chain of `Task`s: serialized runs

Two quick taps create two tasks that would race. The hook keeps the last task in `inFlight`; each new
task first awaits the previous one's `value`, then does its work. Analogy: `chain = chain.then(() =>
work())`, the promise-queue idiom. `HomeGymLog/App/RestActivityHandler.swift:52-59`:

```swift
let previous = LiveActivityIntentHooks.inFlight
let run = Task { await previous?.value; await perform(action, …) }
LiveActivityIntentHooks.inFlight = run
await run.value
```

Surprise: awaiting `inFlight?.value` instead of `run.value` would await whatever a *later* tap put there,
so the closure keeps its own handle. Two tasks awaiting one actor are not first-in-first-out.

## 9. `ClosedRange<Date>` and the `...` operator

`a...b` builds a closed range; `Date` works because it is `Comparable`. The timer views take one.
Analogy: a `[start, end]` tuple with a type that knows its own bounds.
`HomeGymLogShared/RestActivityAttributes.swift:21-23`:

```swift
var interval: ClosedRange<Date> {
    restStartedAt...max(restStartedAt, restEndsAt)
}
```

Surprise: `a...b` with `b < a` is a runtime trap, not an empty range, hence the `max` clamp.

## 10. Generics with an explicit type argument: `Activity<RestActivityAttributes>.activities`

`Activity` is generic over the attributes type; to list the system's activities you name the type
argument, then translate each into an Engine value so the rest of the app never sees ActivityKit.
Analogy: `Store<RestActivityAttributes>.all()`, mapped to a plain DTO at the boundary.
`HomeGymLog/App/RestActivityCenter.swift:29-31`:

```swift
Activity<RestActivityAttributes>.activities
    .filter { $0.activityState == .active || $0.activityState == .stale }
    .map { ShownRestActivity(id: $0.id, logID: $0.attributes.logID, …) }
```

Surprise: `Activity` is not `Sendable`, so it must never be stored or passed across an `await`; the seam
looks each one up by id at call time instead.

## What to read next

The next slice is `m5-release` (icon, copy audit, privacy manifest, App Store metadata).

- Privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Configuring your app icon: https://developer.apple.com/documentation/xcode/configuring-your-app-icon
- Distributing your app for beta testing and releases: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases

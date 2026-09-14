# m3-logging: Swift concepts in the workout slice

The ten concepts this slice leans on most, each mapped to React/TypeScript. What the slice does is in
`docs/specs/m3-logging.md`.

## 1. Enums with associated values
A Swift `enum` case can carry its own data: one type says "which state, and that state's data".
React analogy: a TypeScript discriminated union (`{ kind: "logging"; exercise: number; set: number } | …`).
`HomeGymLog/Engine/WorkoutFlow.swift:48`:
```swift
nonisolated enum WorkoutState: Equatable, Sendable {
    case logging(exercise: Int, set: Int)
    case summary
```
Surprise: there is no `state.exercise`. You unpack with `switch state { case .logging(let exercise, let set): … }`
or test only the case with `if case .logging = state` (`WorkoutFlow.swift:128`). A `switch` must cover every case,
so adding a case later breaks the build wherever it matters.

## 2. Value types (struct) vs reference types (class)
A `struct` is copied on assignment; a `class` instance is shared by every holder.
React analogy: a struct is an immutable object you spread (`{...set}`); a class is a mutable object passed by
reference. `@Model` rows are classes (`HomeGymLog/Models/LoggedSet.swift:6`). The failed-save fix copies a row's
fields into a struct before writing (`HomeGymLog/Models/WorkoutLogStore.swift:17`):
```swift
private struct SetSnapshot {
    let set: LoggedSet      // a reference: the live row
    let weightLb: Double    // a copy: the value when the snapshot was taken
```
Surprise: the snapshot's `set` still points at the live row while `weightLb` is frozen, so "restore" writes the
copies back through that reference.

## 3. Closures, trailing closures and `@escaping`
A closure is an inline function value, like a JS arrow function; a last-argument closure can follow the
parentheses, so `try commit(context) { snapshot.restore() }` reads like a block (`WorkoutLogStore.swift:147`).
React analogy: a callback prop such as `onSave={(draft) => …}`. A stored closure must be marked `@escaping`
(`HomeGymLog/Features/Workout/AdjustSheet.swift:13`):
```swift
init(initial: AdjustDraft, unit: WeightUnit, onSave: @escaping (AdjustDraft) -> Void, onSkip: @escaping (AdjustDraft) -> Void) {
```
Surprise: JS callbacks may always outlive the call; Swift closures are non-escaping by default, so the compiler
knows `commit`'s `revert` runs before `commit` returns.

## 4. `throws`, `try`, `do`/`catch`, rethrow
A `throws` function can fail, and every call must say `try`, so failure points are visible.
React analogy: an async function that rejects, handled with `try { await … } catch (e) { … }`.
`HomeGymLog/Models/WorkoutLogStore.swift:50`:
```swift
private static func commit(_ context: ModelContext, revert: () -> Void) throws {
    do { try context.save() }
    catch { revert(); context.rollback(); throw error }
```
Surprise: `catch` gets an implicit `error` constant, and `throw error` passes it on. `@discardableResult`
(`WorkoutLogStore.swift:141`) silences the warning for an ignored return value; JS never warns about those.

## 5. `@Query` built in `init`, and `Optional.flatMap` in predicates
`@Query` is a live, auto-refetching database read; building it in `init` lets its filter use the view's inputs.
React analogy: `useQuery(["exercises", logID], …)` keyed on props. `HomeGymLog/Features/Workout/WorkoutView.swift:40`:
```swift
_exerciseRows = Query(filter: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id), sort: \LoggedExercise.order)
```
The underscore assigns the property wrapper itself. Two levels of `?.` in a `#Predicate` compile but crash, so
each optional is unwrapped with `flatMap` (`HomeGymLog/Models/WorkoutSnapshotBuilder.swift:23`):
`set.exercise.flatMap { exerciseIDs.contains($0.id) } == true`.
Surprise: `Optional.flatMap` means `x == null ? null : f(x)`, not array flattening; `$0` is the unnamed first argument.

## 6. `DragGesture` and `withAnimation`
A gesture is a view modifier that reports changes and the end of a drag through closures.
React analogy: `onPointerMove` / `onPointerUp` with `touch-action: pan-y`. `HomeGymLog/Features/Workout/SetSwipeRow.swift:36`:
```swift
.gesture(DragGesture(minimumDistance: 20)
    .onChanged { dragX = min(140, max(-140, $0.translation.width)) }
    .onEnded { value in
```
Surprise: you never animate an element. You change state inside `withAnimation(.spring(duration: 0.25)) { dragX = 0 }`
(`SetSwipeRow.swift:45`) and SwiftUI interpolates everything that state affects, like a CSS transition on a state change.

## 7. `TimelineView`
`TimelineView` re-runs its content on a schedule the framework owns and stops when the view disappears.
React analogy: a `setInterval` in an effect whose cleanup you never write. `HomeGymLog/Features/Workout/WorkoutHeader.swift:48`:
```swift
TimelineView(.periodic(from: startedAt, by: 1)) { _ in
    Text(WorkoutText.clock(seconds: WorkoutSummary.elapsedSeconds(from: startedAt, to: clock.now())))
```
Surprise: the tick's own date is ignored (`_ in`) in favour of the injected clock, so a frozen screenshot shows
12:34; and time is recomputed from `startedAt` each tick, never incremented, so it is right after backgrounding.

## 8. `.sheet(item:)` driven by an `Identifiable` enum
`.sheet(item:)` shows a sheet while an optional state is non-nil; dismissing sets it back to nil.
React analogy: `{modal && <Modal/>}` with one union-typed `modal` state instead of several `isOpen` flags.
The state is `enum WorkoutSheet: Identifiable` (`HomeGymLog/Features/Workout/WorkoutSheet.swift:18`), switched on at
`HomeGymLog/Features/Workout/WorkoutView.swift:63`:
```swift
.sheet(item: $sheet) { item in
    switch item {
    case .adjust(let draft):
```
Surprise: a new `id` replaces the sheet rather than updating it, like a changed React `key`; `$sheet` is a two-way
binding (value plus setter); `.presentationDetents([.height(251)])` fixes the sheet height.

## 9. Generic views and `@ViewBuilder` content
A view can be generic over the content it wraps; `@ViewBuilder` lets callers pass it as a trailing closure.
React analogy: a component rendering `props.children`. `HomeGymLog/Features/Workout/SetSwipeRow.swift:8`:
```swift
struct SetSwipeRow<Content: View>: View {
    @ViewBuilder let content: () -> Content
```
Surprise: `Content` is one concrete type fixed at the call site, not "any view"; that keeps diffing cheap, and it
is why a ternary cannot pick between two view types while an `if`/`else` inside a `@ViewBuilder` can.

## 10. Object lifetime (ARC) and `withExtendedLifetime`
Swift frees a class instance the moment its last strong reference goes away (Automatic Reference Counting).
React analogy: none in JS; think of a connection closed as soon as nothing holds it.
`HomeGymLogTests/Persistence/MissedWorkoutEndToEndTests.swift:17`:
```swift
defer { withExtendedLifetime(container) {} }   // mainContext does not retain it; 26.5 crashes on a released store
let context = container.mainContext
```
Surprise: `container.mainContext` does not keep the container alive, and an unused local may be released early.
`withExtendedLifetime` pins it, and `defer` runs that line when the scope exits, like `finally`.

## What to read next
For `m3-rest-timer` (a background-safe countdown and a local notification):
- [Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase)
- [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview)

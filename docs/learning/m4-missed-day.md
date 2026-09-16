# m4-missed-day — Swift concepts, for a React developer

What is new in this slice, in the order it helps to read it. Earlier notes cover `@Binding`, `.onChange`,
`.task(id:)`, `FetchDescriptor`, `ModelContext`, tuples and caseless enums; those are not repeated here.

## 1. `.overlay { }`, and why modifier order is z-order

`.overlay` draws a view on top of the one it is attached to, sized to it. There is no z-index: the modifier
you apply *later* wraps everything before it, so it sits above.

```swift
.safeAreaInset(edge: .bottom, spacing: 0) { FloatingTabBar(selected: $selected) }
.overlay { MissedPromptHost(program: program, selected: selected).id(program.id) }
```
`App/ShellView.swift:30`. React analogy: a modal rendered through a portal at the app root, instead of inside
the tab that opened it. **Surprise:** the same overlay one level lower (inside `HomeView`) cannot cover the tab
bar, because the bar is added by a modifier that runs after Home is built. Position in the chain *is* the rule.

## 2. A view that owns a `@Query` but often draws nothing

`MissedPromptHost` is always mounted. It fetches its own rows and decides every render whether to show a card.

```swift
ZStack(alignment: .bottom) {
    if shows, let missed { /* scrim + card */ }
}
.onAppear { now = clock.now() }
```
`Features/Home/MissedPromptHost.swift:40`. React analogy: a component that returns `null` most of the time but
still holds its own `useQuery` and effects. **Surprise:** in React a component returning `null` still runs its
effects; in SwiftUI a body that collapses to an empty view can skip `onAppear` entirely. A concrete container
(`ZStack`) as the root keeps the handlers running — `Group { if … }` does not. An empty `ZStack` has zero size,
so it blocks no taps.

## 3. Optional `Bool` and `??` as a three-state prop

`Bool?` has three values: `true`, `false` and `nil`. `??` supplies the value used when it is `nil`.

```swift
let promptAllowed = enabled ?? true   // nil = normal; false only from a DEBUG seed
```
`Features/Home/MissedPromptHost.swift:35`. React analogy: `const promptAllowed = props.enabled ?? true` for an
optional prop. **Surprise:** `enabled != false` also passes for `nil`, which reads like a bug to anyone
skimming. Naming the defaulted value is the difference between "hides only when told to" and "enabled is true".

## 4. Gestures are values: `DragGesture`, `some Gesture`, `withAnimation`

A gesture is a value you build and hand to a modifier, not a callback you register. `some Gesture` is an opaque
return type: "some concrete gesture type, and the compiler knows which one".

```swift
private var drag: some Gesture {
    DragGesture(minimumDistance: 20)
        .onChanged { dragY = max(0, $0.translation.height) }
        .onEnded { value in /* dismiss past 80 pt, else withAnimation(.spring()) { dragY = 0 } */ }
}
```
`Features/Home/MissedSessionCard.swift:53`. React analogy: `onPointerMove`/`onPointerUp` handlers, plus a spring
transition. **Surprise:** `withAnimation` animates the *state change*, not the view. You write the new value
inside the closure and SwiftUI interpolates whatever depended on it. Also: attach the gesture **after**
`.offset`, or it measures against the card it is moving and never reaches the threshold.

## 5. `.highPriorityGesture` — the capture phase

Three modifiers attach a gesture, and they differ only in who wins against child controls: `.gesture` (children
first), `.simultaneousGesture` (both), `.highPriorityGesture` (this one first).

```swift
.highPriorityGesture(drag)
```
`Features/Home/MissedSessionCard.swift:50`. React analogy: a listener registered with `{ capture: true }` that
calls `stopPropagation` once it recognises a drag. **Surprise:** a SwiftUI `Button` fires on release up to about
12 pt outside its frame, so with `.gesture` a drag that *starts* on "Skip it" ends up skipping the session too;
with `.simultaneousGesture` both happen. Only the high-priority form cancels the button, while plain taps (no
movement) still reach it.

## 6. Backgrounds take a shape, and corners can differ

`.background(_:in:)` fills a shape instead of the whole rectangle, so no clipping modifier is needed.

```swift
.background(Theme.sf, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
```
`Features/Home/MissedSessionCard.swift:44`. React analogy: `background` plus `border-top-left-radius` and
`border-top-right-radius`. **Surprise:** "leading/trailing" rather than left/right — the shape flips in a
right-to-left language, which a hardcoded `left` would not.

## 7. Accessibility is modifiers, not markup

Traits and actions attach to a view the way `aria-*` attributes attach to an element.

```swift
.accessibilityElement(children: .contain)
.accessibilityAddTraits(.isModal)                         // ≈ aria-modal="true"
.accessibilityAction(.escape) { dismiss(missed, today: today) }   // two-finger Z ≈ an Escape handler
```
`Features/Home/MissedPromptHost.swift:53`. React analogy: `role="dialog" aria-modal="true"` plus an Escape-key
handler. **Surprise:** `.isModal` excludes *siblings* of the element it is on, so where you attach it decides
what VoiceOver can still reach; and the simulator cannot prove it — that check runs on a real phone.

## 8. A dictionary is a value, and `[:]` can mean "nothing to do"

`[Int: Date]` is a struct: assigning or passing it copies. Subscripting returns an optional.

```swift
let map = MissedDay.shiftMap(slots: slots, missedIndex: missedIndex, /* … */)
guard !map.isEmpty else { return [:] }
guard let date = map[row.index] else { continue }
```
`Models/ProgramStore.swift:81`, `:83`. React analogy: a reducer returning a patch object, and the unchanged state
for an action that no longer applies. **Surprise:** because the function is total, a stale tap needs no error
type — an empty dictionary says "this session is not missed any more" and the caller writes nothing.

## 9. `nonisolated` under main-actor-by-default

This app target compiles every type as `@MainActor` unless it says otherwise. `nonisolated` opts a type out so
non-main-actor code (the plain Engine test suites) can build it.

```swift
nonisolated enum MissedDay {
    nonisolated struct PromptSilence: Equatable, Sendable { let sessionIndex: Int; let day: Date }
```
`Engine/MissedDay.swift:15`. React analogy: closest is code that must run in a worker, so it may not touch the
DOM. **Surprise:** the nesting does not inherit — the outer `nonisolated` enum does not make the nested struct
nonisolated, so it is written twice. `Equatable` and `Sendable` are synthesised: `==` comes free, which is what
makes the silence comparison in `shouldPrompt` a one-liner.

## 10. `defer` — the cleanup that cannot be skipped

`defer` runs its block when the current scope exits, whichever way it exits.

```swift
defer {
    context.rollback()
    withExtendedLifetime((writer, readOnly, setup)) {}
}
```
`HomeGymLogTests/Persistence/MissedDayRollbackTests.swift:41`. React analogy: the `finally` of a `try`, or a
cleanup function returned from `useEffect`. **Surprise:** placement is what matters. Written at the end of the
test it is skipped when an assertion throws first; right after the context is created it always runs, which is
what keeps a failing test from deleting a store file with unsaved changes and aborting the whole iOS 26.5 run.

## What to read next

- [Gestures](https://developer.apple.com/documentation/swiftui/gestures) — composing and prioritising them; the
  Progress slice adds chart interaction.
- [Swift Charts](https://developer.apple.com/documentation/charts) — the next slice's whole subject.
- [Concurrency: actors and isolation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
  — background to `nonisolated`, `@MainActor` and `Sendable`.

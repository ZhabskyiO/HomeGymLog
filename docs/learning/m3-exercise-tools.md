# m3-exercise-tools: Swift concepts in the notes, swap and pill slice

Ten concepts to read after this slice, each mapped to React/TypeScript: the ones first used here, plus ones this slice
leans on that no earlier note explains (m3-rest-timer has no note; `docs/learning/m3-logging.md` covers the rest). What
the slice does is in `docs/specs/m3-exercise-tools.md`.

## 1. Constrained extensions on a generic view
`ExerciseInfoSheet<Notes: View>` is generic over the view slotted before Done (`HomeGymLog/Shared/ExerciseInfoSheet.swift:7`).
An extension that applies only when `Notes` is `EmptyView` adds a second initializer without the slot.
React analogy: a generic component `InfoSheet<T>` with a function overload that fixes `T` when no children are passed.
`HomeGymLog/Shared/ExerciseInfoSheet.swift:55`:
```swift
extension ExerciseInfoSheet where Notes == EmptyView {
    /// The sheet with nothing slotted: the Home and Program info sheet.
    init(exercise: Exercise, onDone: @escaping () -> Void) {
```
Surprise: Home's call `ExerciseInfoSheet(exercise:onDone:)` compiles only because this extension exists, and Home's sheet
and the workout's sheet are two different types (`ExerciseInfoSheet<EmptyView>` vs one holding the notes editor).

## 2. Seeding `@State` once from `init`
`@State` is storage SwiftUI owns for a view; `_text` (with the underscore) names the wrapper itself, so `init` can give it
a first value. React analogy: `const [text, setText] = useState(initialText)`.
`HomeGymLog/Features/Workout/ExerciseDetailSheet.swift:11` and `:17`:
```swift
@State private var text: String
// …in init:
_text = State(initialValue: initialText)
```
Surprise: exactly as in React, the initial value is used only when the view is first created. That is what the editor needs:
every keystroke saves, the parent re-renders (`WorkoutView.swift:93` passes a new `noteText`), and the draft is not reset.

## 3. `@Binding` and the `$` prefix
A `Binding` is a read-write reference to state someone else owns; `$text` on a `@State` produces one.
React analogy: passing `value` and `onChange` as a single prop to a controlled input.
`HomeGymLog/Features/Workout/ExerciseDetailSheet.swift:22`, `:32` and `:40`:
```swift
NotesEditor(text: $text)          // parent passes the binding
@Binding var text: String          // child declares it
TextEditor(text: $text)            // and hands it on to the system editor
```
Surprise: there is no callback; the child assigns `text = …` and the parent's `@State` changes, re-rendering both.

## 4. `.onChange(of:)`: an effect that skips the mount
Runs a closure with the old and new value whenever a value changes. React analogy: `useEffect(fn, [text])`, minus the
first run on mount. `HomeGymLog/Features/Workout/ExerciseDetailSheet.swift:25`:
```swift
.onChange(of: text) { _, new in onChange(new) }
```
Add `initial: true` to also run on mount, as the rest timer does (`HomeGymLog/Features/Workout/WorkoutView.swift:87`).
Surprise: the mount skip is why notes save here and not in `.task(id: text)`, which does run on appear and inserted an
empty note just by opening the sheet (gotchas SwiftUI 2026-09-14).

## 5. `.task(id:)`: async work keyed on a value
Starts async work when the view appears, cancels and restarts it whenever `id` changes, and cancels it when the view
goes away. React analogy: `useEffect(() => { const ac = new AbortController(); load(ac.signal); return () => ac.abort() }, [id])`.
`HomeGymLog/Features/Workout/WorkoutView.swift:121`:
```swift
.task(id: isDiscarding ? nil : displayed?.exerciseKey) { loadPillBaseline(key: displayed?.exerciseKey) }
```
Surprise: the closure runs on the main actor here, so a slow synchronous fetch inside it still freezes the screen (why the
pill uses a ~55 ms per-key fetch). Mapping the id to `nil` is how the screen says "not now" while Exit deletes rows.

## 6. Caseless enums as namespaces
An `enum` with no cases can never be instantiated, so it is the idiomatic home for a group of `static` functions.
React analogy: a module that only exports functions (`export function commit(...)`).
`HomeGymLog/Models/StoreCommit.swift:6` and `:14`:
```swift
enum StoreCommit {
    static func commit(_ context: ModelContext, revert: () -> Void) throws {
```
Surprise: a `struct StoreCommit {}` would also work but could be created with `StoreCommit()`; the empty enum makes that
impossible. Engine namespaces add `nonisolated` (`HomeGymLog/Engine/ProgressionPill.swift:18`) so they are callable off the
main actor.

## 7. Function types, and closures that return closures
Swift writes function types as `(Input) -> Output`, so a parameter can be "a function that returns an undo function".
`StoreCommit.rehearseInsert` takes `(ModelContext) throws -> (() -> Void)?` (`HomeGymLog/Models/StoreCommit.swift:42`).
React analogy: an effect callback that returns its own cleanup function.
`HomeGymLog/Models/ExerciseNoteStore.swift:37`:
```swift
try StoreCommit.rehearseInsert(in: context.container) { scratch in
    let rehearsal = ExerciseNote(exerciseKey: key, text: text, updatedAt: updatedAt)
    scratch.insert(rehearsal)
    return { scratch.delete(rehearsal) }
```
Surprise: `(() -> Void)?` is an optional function, so returning `nil` means "nothing to undo" and the caller unwraps it
with `guard let remove = try insert(scratch) else { return }` (`StoreCommit.swift:44`).

## 8. `FetchDescriptor`: a one-shot query next to `@Query`
A `FetchDescriptor` describes a query that `context.fetch` runs once, returning an array right now.
React analogy: `await db.select().where(...).limit(1)`, next to `@Query`, which is the live `useQuery`
(`HomeGymLog/Features/Workout/WorkoutView.swift:23`). `HomeGymLog/Models/ExerciseNoteStore.swift:8`:
```swift
var descriptor = FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.exerciseKey == key })
descriptor.fetchLimit = 1
return try context.fetch(descriptor).first
```
Surprise: nothing observes the result, so the pill's per-key fetch (`WorkoutView.swift:161`) is stored in `@State` by hand.
`var` is required because setting `fetchLimit` mutates the descriptor, which is a struct.

## 9. `ModelContext` as a transaction: `save`, `rollback`, `hasChanges`
Every edit to a `@Model` object is pending in its context until `save()`; `rollback()` discards pending changes; `hasChanges`
says whether anything is pending. React analogy: a DB transaction (save = COMMIT, rollback = ROLLBACK) wrapped around an
optimistic update you must revert yourself. `HomeGymLog/Models/StoreCommit.swift:16`:
```swift
    try context.save()
} catch {
    context.rollback()
    revert()
```
Surprise: `rollback()` does not put old values back on the objects you already edited, which is why `revert()` exists, and
on iOS 26.5 the order matters: reverting before the rollback let the next fetch show the unsaved values.

## 10. Tuples: labelled groups and lexicographic comparison
A tuple is an anonymous, fixed-size group of values, optionally labelled; tuples of comparable values compare element by
element. React analogy: a TypeScript labelled tuple `[key: string, previous: PreviousTops]`, except `<` works on it.
`HomeGymLog/Features/Workout/WorkoutView.swift:38` and `HomeGymLog/Engine/ProgressionPill.swift:22`:
```swift
@State private var pillBaseline: (key: String, previous: PreviousTops)?
let latest = tops.max { ($0.finishedAt, $0.topWeightLb) < ($1.finishedAt, $1.topWeightLb) }
```
Surprise: `(date, weight) < (date, weight)` sorts by date, then weight, in one expression, where JS needs a comparator.
It works only for up to six elements, and tuples cannot conform to protocols such as `Equatable`, so structs replace them
wherever a value crosses into a view input or a test.

## What to read next
- Swift Charts, for the Progress tab: https://developer.apple.com/documentation/charts
- `UNCalendarNotificationTrigger`, for the daily reminder: https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger
- `Form`, for the Settings screen: https://developer.apple.com/documentation/swiftui/form

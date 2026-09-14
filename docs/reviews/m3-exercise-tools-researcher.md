# M3 exercise-tools slice: platform research (notes editor, save timing, notes label, swap writes, progression baseline, swap sheet height)

**Direct answer.**
- **Notes editor:** `TextEditor` with an overlay placeholder, draft in sheet `@State`, saved on every change. Focus, caret and keyboard survived each save and the 1 Hz rest ticks on both runtimes.
- **Label:** `@Query<ExerciseNote>` filtered in `body` updates the bar label at once.
- **Swap:** one save re-renders at once; an in-place array edit is detected. On a failed save, reassign the array **after** `rollback()` (26.5 quirk).
- **Pill:** a per-key fetch on `mainContext` (54 ms on 17.5, vs 0.44 s for the full traversal).
- **Swap sheet:** a height computed from the row count.

Two premises in the brief are wrong:
- `onGeometryChange` **is** available on iOS 17: it is declared iOS 16.0 and was run on 17.5.
- Swap after a done set corrupts both the pill and the records unless the spec guards it (Q4 and Q5).

## Configuration (applies to every claim unless stated)

- **Toolchain:** Xcode 26.6 (17F113).
- **Simulators:** iPhone 15 on iOS 17.5 (`3CAE4D76…`, 393×852) and iPhone 17 on iOS 26.5 (`834F0313…`, 402×874). Timings are from the simulator on a Mac, never a phone.
- **Probe copy:**
  - A throwaway copy of repo `48915c2` in the session scratchpad, bundle id `com.zhabskyi.homegymlog.probe`.
  - UI-test target added to the copy with the earlier `patch_pbxproj.py`.
  - Own DerivedData folders (`DD`, `DD26`); `build/DerivedData` was never used.
- **App target:** Debug, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency, deployment 17.0. All probe views, stores and baselines compiled there with **zero warnings in the probe files**, including `@ModelActor`.
- **Unit probes:** `HomeGymLogTests` (no default isolation), `@MainActor` suite, **on-disk** stores. Failures were forced with `allowsSave: false`.
- **UI probes:** XCUITest (Swift 5, no isolation), real taps, drags and typing.
  - `-seed wo-start` is in-memory with a frozen clock.
  - `mem-start` and `mem-rest` are in-memory with a live clock; `mem-rest` has a 675 s live rest.
  - `disk-start` is on-disk: the midProgram recipe plus session 11 started.
  - `big` is on-disk, program-end.
- **Results:** 44 UI tests and 21 unit cases per runtime passed; the marked-text pair ran on 17.5 only.
- **Clean-up:** probe app and runner uninstalled from both simulators. `git status` is clean and `project.pbxproj` has no diff.
- **Tier:** nothing here needs a capability, entitlement or Info.plist key. App Privacy stays "Data Not Collected".

---

## Q1: Notes editor inside the workout sheet

**Verdict: `TextEditor` + overlay placeholder, inside the existing ScrollView sheet (`.fraction(0.78)`).** It is iOS 17-safe. `TextField(axis: .vertical)` also works, but it has a dead tap zone.

**Layout with the keyboard up.** Frames in points:

| Check | 17.5 | 26.5 |
|---|---|---|
| Sheet before focus | y 233.7, 393×618 | inset and scaled: x 8, y 250.5, 386×615 |
| Keyboard | top 561, 233 tall | top 583, 233 tall |
| Sheet after focus (**the detent grows**) | y 69, 393×783 | y 62, 402×812, full width |
| TextEditor / Done, empty | editor 282–352, Done 366–414 | 275–345, Done 359–407 |
| After 6 lines | editor 70 → 117 pt, Done 413–461 | 70 → 117 pt, Done 406–454 |
| `TextField(axis: .vertical)`, `lineLimit(3...)`, 6 lines | 50 → 101 pt, Done 406 (26.5 run) | same |
| Done tap with the keyboard up | sheet dismissed, keyboard gone | same |
| Presenting bar (`.safeAreaInset`) | minY 764 → 466 while the keyboard is up, **behind the sheet**, back after dismiss | 786 → 485 → 786 |

- Keyboard avoidance works: the editor and Done stay above the keyboard up to 6 lines.
- The sheet returns to the 0.78 detent when the keyboard goes.
- The bar never shows above the sheet (screenshots).

**Dismissing the keyboard** (TextEditor, typed "abc"):

| Gesture | Result | Runtimes |
|---|---|---|
| 150 pt drag down on the sheet content, with `scrollDismissesKeyboard` `.interactively` or `.immediately` | keyboard dismissed, sheet stays and drops back to 0.78, text kept | both |
| Same drag with no modifier (automatic) | same | 17.5 (26.5 unverified: run filtered out) |
| 560 pt fast drag from the sheet's top edge with the keyboard up | **sheet and keyboard dismissed in one gesture** | both |
| Done | sheet and keyboard dismissed | both |

The three `scrollDismissesKeyboard` modes behaved the same here. The modifier is optional.

**TextField vs TextEditor** (focus-matrix probe, fresh launch per case):

| Tap | `TextField(axis: .vertical)` | `TextEditor` |
|---|---|---|
| Coordinate tap on the text (x 10–90 %) | focuses, both runtimes | focuses |
| Tap on the padded box below the text line | **does not focus** (both runtimes) | whole 70 pt box focuses |
| `.contentShape` + `.onTapGesture { focused = true }` fix | focuses, but then **a tap cannot place the caret** ("teh quick XY" instead of "XY…") | not needed |
| Return key | inserts a newline ("abc\ndef") | inserts a newline |
| XCUITest `element.tap()` | **fails to focus on 17.5 only** (harness quirk) | works |

- **Look:** the TextEditor placeholder overlay sits under the caret at the same inset (screenshots on both runtimes).
- **26.5 sheet style:** the sheet is drawn inset and slightly scaled until the keyboard appears.

**Sketch** (adapted from the compiled probe `ProbeDetailSheet`):

```swift
struct ExerciseDetailSheet: View {
    let exercise: Exercise
    let onChange: (String) -> Void          // saves through ExerciseNoteStore
    let onDone: () -> Void
    @State private var text: String          // ≈ useState(initialNote): seeded once; the sheet is keyed on .detail(key)
    @FocusState private var focused: Bool    // ≈ a ref you can .focus()

    init(exercise: Exercise, initialText: String, onChange: @escaping (String) -> Void, onDone: @escaping () -> Void) {
        self.exercise = exercise; self.onChange = onChange; self.onDone = onDone
        _text = State(initialValue: initialText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // muscle · equipment, name, cues as in ExerciseInfoSheet …
                Text("Notes").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.tx).padding(.top, 16)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .focused($focused)
                        .font(.system(size: 14)).foregroundStyle(Theme.tx)
                        .scrollContentBackground(.hidden)      // iOS 16
                        .frame(minHeight: 70)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                    if text.isEmpty {
                        Text("e.g. bench at incline notch 2, grip slightly wider")
                            .font(.system(size: 14)).foregroundStyle(Theme.mu)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .background(Theme.sf2, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bd, lineWidth: 1.5))
                .padding(.top, 8)
                // Done button, 48 pt, .padding(.top, 12)
            }
            .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 44)
        }
        .background(Theme.sf)
        .onChange(of: text) { _, new in onChange(new) }   // ≈ useEffect(save, [text]); does not fire on appear
    }
}
```

**Availability.** Typechecked with `swiftc -typecheck -target arm64-apple-ios17.0-simulator` against the 26.5 SDK; none needs `if #available` at the 17.0 target.

| API | Available from |
|---|---|
| `TextEditor` | iOS 14 |
| `TextField(_:text:prompt:axis:)`, `scrollContentBackground`, `scrollDismissesKeyboard` | iOS 16 |
| `presentationCornerRadius`, `presentationBackground`, `presentationContentInteraction` | iOS 16.4 |
| `Text.foregroundStyle` returning `Text` | iOS 17.0 |

**React analogy:** a controlled `<textarea>` in a modal whose `onChange` persists. The keyboard behaves like `visualViewport` resizing the modal.

---

## Q2: Note save timing vs re-render

**Verdict: (a) save on every change.** It is kill-safe and cheap. The re-render never reset focus, caret, keyboard or `@State`, on either runtime. Keep the draft in **sheet `@State`**; `WorkoutView` state also works.

**Re-render effects.** Each probe typed "teh quick ", tapped at the start, typed "X", waited, typed "Y".

| Variant | 17.5 | 26.5 |
|---|---|---|
| (a) change, sheet draft | "XY quick ", focus kept, keyboard up | same |
| (b) debounce 400 ms | "XY quick " | same |
| (c) no save (control) | "XY quick " | same |
| (a) change, draft in `WorkoutView` `@State` | "XY quick " | same |
| Sheet identity per save (17.5 change) | 11 saves → 26 `WorkoutView.body` runs, sheet `init` 23 times, **one `@State` token throughout** | same pattern |
| Save cost, `ExerciseNoteStore.save` per keystroke | first insert 1.2–1.6 ms, then 0.42–0.67 ms | first 16–18.6 ms, then 0.46–0.78 ms |

- **Autocorrect:** unverified. "teh" stayed uncorrected in the no-save control too, so the harness cannot exercise it.
- **Marked text:** unverified. `-AppleKeyboards` did not switch the keyboard to Japanese, so the input stayed Latin ("nihon").

**Live rest** (`mem-rest`, 675 s rest, 1 Hz `TimelineView`, sheet attached outside it):

| Check | 17.5 | 26.5 |
|---|---|---|
| "a", 3.5 s, "b" | "ab", focus kept, keyboard up | same |
| Sheet body runs during ~20 s of ticks, no-save control | 11 body, 1 init: **not re-evaluated per tick** | 11 body, 1 init |
| Caret: tap, X, 3.5 s of ticks, Y | XY adjacent in all 3 variants (no save, save + sheet draft, save + parent draft) | XY adjacent in **10 of 10** runs (frozen seed, live clock without rest, live rest ×3 variants, ×2 rounds) |

On 26.5 the harness's first tap sometimes put the caret at the end ("ab teh X"). Y still followed X every time, so ticks and saves never moved the caret.

**Which callback fires, and what survives `XCUIApplication.terminate()`** (on-disk store, relaunch dump):

| Action | `sheet(item:onDismiss:)` | content `onDisappear` | `scenePhase` | Saved text after kill: (a) change | (b) debounce | (c) save in `onDisappear` + non-active phase |
|---|---|---|---|---|---|---|
| Kill with the sheet up, right after typing | – | – | – | **kept** (both runtimes) | **lost**; only an empty row remains | **lost** |
| Kill 1.5 s after typing | – | – | – | kept | kept | lost |
| Done tap, then kill | fires first | +5 ms (17.5), +1 ms (26.5) | – | kept | – | kept |
| Swipe-down dismiss, then kill | fires first | +1 ms (17.5), +561 ms (26.5) | – | kept | – | kept |
| Home (background), then kill | no | no | `inactive` then `background`, in both the sheet and `WorkoutView` | kept | – | kept (saved on `inactive`) |

**Debounce hazard (both runtimes).** `.task(id: text)` also runs on appear with the initial text, so it inserted an **empty `ExerciseNote`** (`latPull=""`) before any typing.

**Where the draft lives.**
- **Sheet `@State` seeded in `init`:** the house `AdjustSheet` pattern. Verified to survive saves and ticks.
- **`WorkoutView` `@State`:** also survives, but re-runs the whole screen per keystroke even without a save.
- **Never inside the `WorkoutSheet` case:** changing the item's id re-presents the sheet (documented `sheet(item:)` behaviour; not probed).

**React analogy:** `useState` in the modal plus `useEffect(() => save(text), [text])`. SwiftUI keeps component state across parent re-renders the way React keeps it for a stable `key`.

---

## Q3: Live "Notes ·" label

**Verdict: `@Query private var notes: [ExerciseNote]` (all rows) in `WorkoutView`, filtered in `body` by the displayed key and `!text.isEmpty`.** It is correct at once on both runtimes. No cheaper shape is needed: 18 keys at most.

| Step | 17.5 | 26.5 |
|---|---|---|
| Initial | "Add note" | same |
| While the sheet is up, after the first keystroke save (bar read behind the sheet) | "Notes ·" | same |
| After Done | "Notes ·" | same |
| Text cleared to "", Done | "Add note" | same |
| Next exercise (key → lowRow) | "Add note" | same |

A child view with its own key-filtered `@Query` keyed by `.id(key)` would also follow the key. It was not probed and is unnecessary.

```swift
@Query private var notes: [ExerciseNote]   // ≈ useQuery(all notes); the owner re-renders on every save (17.5-safe)
// body:
let noteExists = displayedKey.map { key in notes.contains { $0.exerciseKey == key && !$0.text.isEmpty } } ?? false
```

---

## Q4: Swap write semantics

**(a) Re-render: immediate on both runtimes.**
- **Setup:** on-disk, set 1 done at RPE 7, **rest card showing**. Swap latPull → dbBench (42.5 lb) wrote `exerciseKey`, `swappedFromKey`, `targetWeightLb`, the pending sets' weight and the session element, in one save.
- **Within 0.15 s:** name "Dumbbell Bench Press", rows "✓ 110 … RPE 7", "42.5", "42.5".
- **After relaunch:** identical. The dump read `dbBench<-latPull@42.5[d110,p42.5,p42.5]` and session `0:dbBench@42.5`.
- **Queries:** the existing exercise and set `@Query`s needed no change.
- **Cost:** save 2.6–2.7 ms (17.5), 14.8 ms (26.5).

**(b) Codable array mutation** (on-disk; mutated in a fresh container's context or the writing context):

| Mutation | `hasChanges` | changed models | same-context refetch | fresh container | Runtimes |
|---|---|---|---|---|---|
| `session.exercises[i].exerciseKey = x` (in place) | true | 1 | new value | new value | 17.5, 26.5 |
| `var copy = …; copy[i] = …; session.exercises = copy` | true | 1 | new value | new value | 17.5, 26.5 |

**(c) Failed save** (`allowsSave: false`, Cocoa 513):

| Revert order | Writing-context objects | **Refetch in the writing context** | `hasChanges` | Fresh context |
|---|---|---|---|---|
| `rollback()` only | edited values kept (scalars and array) | edited | false | originals |
| Restore only | originals | originals | **true** | originals |
| Restore then `rollback()` (the house `commit`) | originals | 17.5: originals. **26.5: session array edited again ("goblet"); scalars stay original** | false | originals |
| `rollback()` then restore | originals | originals | true | originals |
| Restore, `rollback()`, then reassign the array snapshot | originals | originals | true | originals |

- **Without a failed save** (writable store), every order refetched correctly on both runtimes, and a later unrelated save persisted the original array.
- **What the leftover `hasChanges == true` means:** the next successful save rewrites identical values, which is harmless.

**Semantic hazards the spec must settle** (seen in the probe, not bugs in existing code):
- **Swap after a done set.** It leaves the done set's weight (110 lb, a Marcy load) under the new key `dbBench`. That set then feeds the summary records, future PR baselines and the pill, which showed **"+67.5 lb from your last Dumbbell Bench Press"** in the 17.5 screenshot.
  - The prototype rewrites *all* sets' weights.
  - Recommendation: disable Swap once any set of the displayed exercise is done or skipped, or define it otherwise explicitly.
- **Candidates exclude keys currently in the workout** (prototype `!wo.ex.includes(x)`). Session 11 (Pull: latPull, lowRow, dbRow, rdl, curl) gives:
  - **latPull → 0**, because all Back exercises are in the workout;
  - rdl → 5 (goblet, legExt, legCurl, split, lunge);
  - curl → 2.
  - The fixed `wo-swap` seed on the first exercise would show an empty sheet unless it opens on another exercise.
- **Weights:** week-3 Foundation targets from `WeightFormula.targetWeightLb(key:week:phase:startingWeightsLb:)` were dbBench 42.5, inclineDb 37.5, chestPress 100, pecDeck 80, shoulderPress 32.5.
- **Double swap:** `swappedFromKey = swappedFromKey ?? exerciseKey` keeps the planned key.

**Sketch** (the writer's revert order is the verified "restore, rollback, reassign" variant):

```swift
@discardableResult
static func swapExercise(_ exercise: LoggedExercise, to key: String, targetWeightLb: Double, in context: ModelContext) throws -> Bool {
    guard exercise.exerciseKey != key, !exercise.sets.contains(where: { $0.status != .pending }) else { return false }  // spec's guard
    let pending = exercise.sets.filter { $0.status == .pending }
    let snapshots = pending.map(SetSnapshot.init)
    let (oldKey, oldFrom, oldTarget) = (exercise.exerciseKey, exercise.swappedFromKey, exercise.targetWeightLb)
    let session = exercise.workout?.session
    let planned = session?.exercises
    exercise.swappedFromKey = oldFrom ?? oldKey
    exercise.exerciseKey = key
    exercise.targetWeightLb = targetWeightLb
    for set in pending { set.weightLb = targetWeightLb }
    if let session, let i = session.exercises.firstIndex(where: { $0.order == exercise.order }) {
        session.exercises[i].exerciseKey = key            // in place is detected and saved (both runtimes)
        session.exercises[i].targetWeightLb = targetWeightLb
    }
    do {
        try commit(context) {
            exercise.exerciseKey = oldKey; exercise.swappedFromKey = oldFrom; exercise.targetWeightLb = oldTarget
            snapshots.forEach { $0.restore() }
            if let planned { session?.exercises = planned }
        }
    } catch {
        // 26.5: after rollback a refetch shows the unsaved array again unless it is reassigned after the rollback.
        if let planned { session?.exercises = planned }
        throw error
    }
    return true
}
```

**React analogy:** an optimistic update that restores its snapshot on failure. The extra reassign is re-dispatching the old value after the store's reset.

---

## Q5: Progression-pill baseline cost

**Verdict: a per-key `FetchDescriptor<LoggedExercise>` on `mainContext` in `.task(id: displayedKey)`, returning both "best" and "last".**
- **"Best" only:** a set-level fetch is 5× cheaper.
- **Avoid on mount:** the full `bestsBefore` traversal.
- **Avoid entirely:** a `@ModelActor` created from the view, because it runs on the main thread.

**Fixture** (on-disk):
- **Current program:** 6-month 5-day 45-min, sessions 0–118 finished (the midProgram recipe), session 119 in progress.
- **Archived program:** midProgram with 10 finished logs, every weight +100 lb.
- **Totals:** 2 programs, 130 logs, 650 `LoggedExercise`, 2 275 `LoggedSet`.

| Method (ms) | 17.5 unit, cold container | 17.5 app mount | 26.5 unit | 26.5 app mount |
|---|---|---|---|---|
| (a) full `WorkoutSnapshotBuilder.bestsBefore` | 414 / 426 (warm 368–378) | **439 / 451** | 246 / 247 | 264 / 236 |
| (b) per-key: `exerciseKey == key && workout.flatMap { $0.finishedAt != nil } == true`, program filtered in Swift | 54 / 55.5 (warm 44) | 54.8 / 56.3 | 24 / 26 | 29 / 27 |
| (b′) nested 3-hop: `workout.flatMap { finishedAt != nil && session.flatMap { program.flatMap { id == pid } } == true }` | 52.8 / 51.6 | 53.9 | 23.5 / 23.3 | 27.5 |
| (b″) done sets heaviest first, `fetchLimit` 40, program filtered in Swift ("best" only) | 10.5 / 10.0 | 11.5 | 3.1 / 2.9 | 4.7 |
| (c1) per-key on a new `ModelContext(container)` on main | – | 51.7 | – | 29.7 |
| (c2) `@ModelActor` created in the task (main actor) | 53 | 58, **ran on the main thread** | 22.5 | 98.7, main thread |
| (c3) `@ModelActor` created in `Task.detached` | 52 | 55.9, off main | 23.8 | 80.1, off main |

**Correctness** (both runtimes): 17 keys, **0 mismatches** between full, per-key, nested, set-level and actor "best", and between per-key "last" and an independent walk.
- The archived program is excluded: its bests are higher for every key (legExt 180 vs 150).
- The nested 3-hop predicate compiled and fetched without a crash (47 rows vs 50 unfiltered).
- The **4-hop** set-level version (set → exercise → log → session → program) **does not compile**: "unable to type-check this expression in reasonable time".

**Blocking.**
- **Runs on the main actor, blocking the UI for its full duration:** every variant except (c3) runs synchronously. That is ~0.45 s of blocked UI (clock and swipes) for (a) on 17.5, versus ~55 ms for (b).
- **Frame-gap monitor:** it did not capture the block, because the display link's first tick came after the task. No dropped-frame count is claimed.
- **`@ModelActor` under MainActor default isolation:** it compiled with zero warnings in Swift 5 mode. For Swift 6 mode, DTS recommends `@Model nonisolated class` ([forum 788262](https://developer.apple.com/forums/thread/788262)). An actor created on the main actor gives no off-main benefit.
- **Second-context note:** (c1)/(c3) are reads of saved data, and every workout write saves immediately. The second-context gotcha concerns writes. Still, (b) needs no second context.

**Best vs last.** They differ for most keys at program end (legExt best 150 / last 130, curl 52.5 / 37.5).
- The prototype computes `prevTop` as the **max** over completed sessions ("best") but labels it "from your **last**".
- "Last" here means the most recent `finishedAt`.
- The pill's current weight must be the focus or pending set's weight (or the target), not `sets.first`; see Q4.

**Recompute on key change:** verified. After the swap the task re-ran for `dbBench` in 3 ms (17.5, small store).

```swift
struct PreviousTops: Equatable { var best: Double?; var last: Double? }

/// One-hop predicate (two `?.` hops crash); program filtered in Swift over ~25–50 rows at program end.
static func previousTops(key: String, programID: UUID, in context: ModelContext) throws -> PreviousTops {
    let rows = try context.fetch(FetchDescriptor<LoggedExercise>(predicate: #Predicate { exercise in
        exercise.exerciseKey == key && exercise.workout.flatMap { log in log.finishedAt != nil } == true
    }))
    var best: Double?; var last: (Date, Double)?
    for row in rows {
        guard let log = row.workout, let finished = log.finishedAt, log.session?.program?.id == programID,
              let top = row.sets.filter({ $0.status == .done }).map(\.weightLb).max() else { continue }
        best = max(best ?? top, top)
        if last.map({ finished > $0.0 }) ?? true { last = (finished, top) }
    }
    return PreviousTops(best: best, last: last?.1)
}

// WorkoutView: ≈ useEffect(() => load(key), [key]); re-runs on Next exercise and on swap
.task(id: displayedKey) {
    guard let key = displayedKey, let programID else { return }
    tops = (key, try? WorkoutSnapshotBuilder.previousTops(key: key, programID: programID, in: modelContext))
}
```

---

## Q6: Swap sheet height on iOS 17

**Verdict: a computed `.presentationDetents([.height(h)])` from the row count**, like `AdjustSheet`'s 251. The content heights are identical on both runtimes. It is the only shape that never showed a second height.

Also, the brief's premise is wrong: **`onGeometryChange(for:of:action:)` is iOS 16.0.** The SDK interface declares `@available(iOS 16.0, …)` with `@_alwaysEmitIntoClient`. It typechecks at iOS 17.0 and 16.0 targets, and ran on 17.5 identically to the preference measure. Only the old/new two-value overload and `presentationSizing` are iOS 18.

**Measured content height** (probe layout: top 22, horizontal 20, bottom 10, title 18 bold, subtitle 13, 14 pt gap, rows 56.33 pt, 8 pt apart):

| n | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| height, 17.5 = 26.5 | 71.33 | 141.67 | 206.0 | 270.33 | 334.67 | 399.0 |

Formula: `n == 0 ? 71.33 : 77.33 + 64.33 × n`.

| Shape | 17.5 | 26.5 |
|---|---|---|
| **Computed** `.height(h)` | one container frame at the final height, no correction (my guessed constants were 1–2 pt short; use the table) | one frame at the final height |
| Measured (preference) or `onGeometryChange` feeding `.height(measured)`, fallback 300 | first frame at 300 for ~12 ms during the presentation, then corrected | first frame 288 for 18–21 ms, then corrected |
| `.medium` | 419 pt whatever n; n = 0 is mostly empty (screenshot) | 418 (scaled) |
| `.height` meaning | container = h, ending above the 34 pt home indicator (270.33 → y 547.7–818) | sheet inset and **scaled** (386 wide at n ≥ 1; the n = 0 sheet is a small floating card); no clipping at n = 5 (screenshot) |

- **Flicker:** the measured shapes' visual flicker is unverified; it was not filmed.
- **Dynamic Type:** fonts are `.system(size:)` fixed sizes. That Dynamic Type never changes these heights is not probed (unverified).
- **Zero candidates:** a 71 pt sheet with only the title and subtitle. The spec should pick an empty-state line (add its height) or disable Swap.

```swift
/// Content height of the swap sheet (verified on 17.5 and 26.5 with the layout above).
static func swapSheetHeight(candidateCount n: Int) -> CGFloat {
    n == 0 ? 71.33 : 77.33 + 64.33 * CGFloat(n)
}
// .presentationDetents([.height(SwapSheet.height(candidateCount: candidates.count))])
```

**React analogy:** a modal whose height is set from `items.length × rowHeight` instead of a `ResizeObserver` (≈ `onGeometryChange`) that corrects it after the first paint.

---

## Facts the spec must state (binding)

1. **Notes editor.**
   - `TextEditor` + overlay placeholder + `.scrollContentBackground(.hidden)`, min height 70, in the ScrollView detail sheet `.fraction(0.78)`.
   - With the keyboard up the sheet grows to y 69 (17.5) / 62 (26.5) and Done stays visible to at least 6 lines.
   - Not `TextField(axis: .vertical)`: taps on its padding don't focus, and the tap-gesture fix breaks caret placement.
2. **Keyboard dismissal.** Dragging the sheet content dismisses the keyboard and keeps the sheet; a top-edge drag with the keyboard up dismisses the sheet; Done dismisses both. `scrollDismissesKeyboard` is optional.
3. **Saving.**
   - The draft is sheet `@State` seeded when the sheet opens, and the sheet item stays `.detail(key)`.
   - Every change saves through `ExerciseNoteStore` (0.4–0.8 ms per update).
   - Focus, caret, keyboard and `@State` survive the save re-render and the 1 Hz rest ticks.
   - A kill right after typing keeps the text.
   - Not debounced with `.task(id: text)`: it inserts an empty note on appear and loses the tail on a kill.
4. **Dismissal paths.** Done and swipe-down fire `sheet(item:onDismiss:)`, then content `onDisappear`. Backgrounding fires only `scenePhase` (`inactive`, `background`). A foreground kill fires nothing.
5. **Label.** `WorkoutView` owns `@Query<ExerciseNote>`. The label is "Notes ·" iff the displayed key's note has non-empty text, and it flips on the first keystroke save and on key change.
6. **Swap write.**
   - One save: key, `swappedFromKey ?? oldKey`, target, pending sets' weight, and the in-place `PlannedSession.exercises[i]` element.
   - The screen re-renders immediately; no query change.
   - On a failed save: restore fields, `rollback()`, then **reassign the array snapshot after the rollback**, or 26.5 refetches the unsaved array.
7. **Swap guard.** The spec decides what happens once a set is done or skipped. Recommended: Swap disabled; otherwise the done weight is attributed to the new key and pollutes records and the pill.
8. **Candidates.**
   - Same `muscle`, key not currently in the log, weight from `WeightFormula.targetWeightLb` with the program's starting weights, session week and phase.
   - Session 11's first exercise (latPull) has 0 candidates, so the `wo-swap` seed must say which exercise it opens on.
9. **Pill baseline.**
   - Per-key one-hop fetch on `mainContext` in `.task(id: displayedKey)`, program filtered in Swift, finished logs only.
   - 17.5 program end: ~55 ms (set-level "best" ~11 ms); never the full traversal at mount (~0.45 s).
   - No `@ModelActor` created from the view (it runs on the main thread).
   - The spec picks "best" (the prototype's math) or "last" (its wording). They differ after a deload.
10. **Pill numbers.** Current weight = focus or pending set weight; shown only when a previous top exists and current > previous.
11. **Swap sheet height.** `.height(n == 0 ? 71.33 : 77.33 + 64.33·n)` for the probed layout; recompute if the layout changes. Not `.medium`. `onGeometryChange` is iOS 16 if a measured shape is ever wanted.
12. **Tests.**
    - Put `.accessibilityIdentifier` on leaf controls only: on a plain container it overwrites every descendant's identifier.
    - Tap a vertical `TextField` by coordinate, not with `element.tap()` (17.5).
    - Failed-save tests for the swap writer must refetch in the writing context, not just read the objects.

## Unverified

- **Autocorrect and marked-text (IME) input with per-keystroke saves.** XCUITest could not exercise either. Probe: a manual device check typing Japanese kana or accepting an autocorrection in the notes field.
- **Text longer than 6 lines:** whether the ScrollView keeps the caret above the keyboard.
- **The automatic `scrollDismissesKeyboard` mode on 26.5** (filtered out of that run).
- **Visual flicker of measured-height swap sheets** (logged 12–21 ms at the fallback height; not filmed).
- **Dynamic Type effect on the computed swap height.**
- **The first `ExerciseNoteStore.save` is an insert.** A failed save leaves it pending, and per gotchas 26.5 cannot undo a failed insert in place. No failed-save probe for notes was run.
- **Per-keystroke save and the 1 Hz timeline hitch on the iPhone 14 Pro Max.**
- **Whether a later successful save persists the 26.5 refetched edited array** after restore then rollback. Not testable with a read-only store; avoided by the reassign order.

## Suggested `insights/gotchas.md` entries

- **SwiftData, 2026-09-14.** **On 26.5, after a failed save, restore-then-`rollback()` lets a refetch bring back an unsaved Codable array.** The swap probe (`allowsSave: false`) restored `PlannedSession.exercises` and then rolled back. The object read the original, but a `FetchDescriptor` refetch in the same context returned the edited array; scalar fields stayed restored and 17.5 was correct. Fix: reassign the array snapshot after `rollback()`, or roll back first then restore; both refetch correctly on both runtimes and leave `hasChanges == true`. Recognize it: a failed-save test that passes on object reads but fails once it refetches.
- **SwiftData, 2026-09-14.** **`@ModelActor` created from the main actor runs its methods on the main thread** (17.5 and 26.5: `Thread.isMainThread == true`); created inside `Task.detached` it runs off main. It compiled with zero warnings under MainActor default isolation in Swift 5 mode (DTS suggests `@Model nonisolated class` for Swift 6, forum 788262). Also, a four-hop nested-`flatMap` predicate fails with "unable to type-check this expression in reasonable time"; three hops compile and fetch.
- **SwiftUI, 2026-09-14.** **`.task(id: text)` as a debounced save runs on appear** and saved the initial text, inserting an empty `ExerciseNote` before any typing (both runtimes). Recognize it: a row appears when a sheet merely opens.
- **SwiftUI / XCUITest, 2026-09-14.** **`.accessibilityIdentifier` on a plain container (a `VStack`, not a ScrollView) overwrites every descendant's identifier.** The swap rows all reported `swapSheet`, so an `identifier BEGINSWITH 'swap-'` query found nothing (both runtimes). Also, `element.tap()` on a `TextField(axis: .vertical)` in a sheet did not focus it on 17.5 while a coordinate tap did. And on 26.5 partial-detent sheets are inset and scaled (frames 386 wide on a 402 pt screen), so don't assert sheet widths.
- **SwiftUI, 2026-09-14.** **A keyboard inside a `.fraction(0.78)` sheet grows the sheet to nearly full height** (17.5 top 233.7 → 69; 26.5 → 62), and it returns to the detent when the keyboard goes. The presenting screen's `.safeAreaInset` bar moves up behind the sheet (764 → 466) and is never visible above it.

## Suggested `insights/INSIGHTS.md` entry (Patterns)

- **2026-09-14 — Per-key history reads: fetch the key's rows, filter the program in Swift, never traverse the log history.** A `FetchDescriptor<LoggedExercise>` with `exerciseKey == key && workout.flatMap { $0.finishedAt != nil } == true`, then `workout?.session?.program?.id == programID` per row. It costs ~55 ms at program end on 17.5, versus ~0.44 s for the full `bestsBefore` traversal, with identical results over 17 keys. Run it in `.task(id: key)` on `mainContext` (≈ `useEffect` keyed on the id). Source: `docs/reviews/m3-exercise-tools-researcher.md` Q5.

## Sources

- [sheet(item:onDismiss:content:)](https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:))
- [TextEditor](https://developer.apple.com/documentation/swiftui/texteditor)
- [TextField init(_:text:prompt:axis:)](https://developer.apple.com/documentation/swiftui/textfield/init(_:text:prompt:axis:)-8rujz)
- [scrollDismissesKeyboard(_:)](https://developer.apple.com/documentation/swiftui/view/scrolldismisseskeyboard(_:))
- [presentationDetents(_:)](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:))
- [onGeometryChange(for:of:action:)](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)). The page did not render for me; availability was taken from the iOS 26.5 SDK `SwiftUICore` swiftinterface and a typecheck at iOS 17.0.
- [presentationSizing(_:)](https://developer.apple.com/documentation/swiftui/view/presentationsizing(_:)). Availability was taken from the SDK interface and the typecheck error "only available in iOS 18.0".
- [ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor)
- [Forum 788262: @ModelActor with default actor isolation = MainActor (DTS reply)](https://developer.apple.com/forums/thread/788262)
- [Forum 770405: Ongoing issues with ModelActor in SwiftData](https://developer.apple.com/forums/thread/770405)
- [Matt Massicotte, "ModelActor is Just Weird" (community; used only to find the main-thread behaviour, then probed)](https://www.massicotte.org/model-actor/)

---

## Addendum 2026-09-14: P1–P3

**Answer:** keep the rehearsal. A failed first note insert does not undo cleanly in place:
- **Doing nothing:** the unsaved row drives the label ("Notes ·") and fills the reopened editor on both runtimes.
- **Deleting it in place:** the label stays clean on both, but on 26.5 an immediate fetch of all notes still returns the unsaved row.
- **The rehearsal:** the only variant that is clean everywhere.

The empty-state height constant is **101.0**. The rehearsal never flashes a row into the label, and never leaves a duplicate.

### Configuration

- **Scratch copy:** the same one as above, repo `48915c2`, bundle id `com.zhabskyi.homegymlog.probe`, own DerivedData (`DD`, `DD26`).
- **App target settings:** Debug, Swift 5, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, deployment 17.0.
- **Simulators:** iPhone 15 on iOS 17.5 and iPhone 17 on iOS 26.5; everything below ran on both.
- **Unit probe:** `ProbeNoteInsertTests`, a `@MainActor` suite in `HomeGymLogTests`.
  - On-disk store holding one existing note (`dbBench`), reopened with `allowsSave: false`.
  - The writing context is `readOnly.mainContext`.
  - Log lines were flushed before every read, so a trap would have been visible.
- **App probes:** the refusing store is on disk (`disk-note-ro`: written, then reopened with `allowsSave: false` as the app's container). The P3 store is on disk, writable, and reset per launch.
  - The live `WorkoutView` `@Query<ExerciseNote>` (all rows) logs its rows on every `body` run.
  - XCUITest typed "ghost" into the detail sheet for `latPull` and read the bar label.
- **Results:** 5 unit cases and 5 UI tests passed on each runtime, with no traps. The probe bundles are uninstalled from both simulators; the repo's source, test and `project.pbxproj` files show no diff.

### P1: a failed insert of one relationship-free row, undone in place

The first save for a new key throws Cocoa 513. After the catch, the probe refetched in the same context and read `text` on every row.

| Variant (catch) | 17.5: same-context fetch of all notes | 26.5: same-context fetch of all notes | Fetch by key / `fetchCount` | `hasChanges` | App: `@Query` rows and label; reopened editor | Read `text` |
|---|---|---|---|---|---|---|
| (b) nothing (`ExerciseNoteStore.save` as shipped) | 2 rows: the unsaved row is included | **3 rows: the unsaved row is returned twice**, while `fetchCount` = 2 | finds "ghost", count 2 | true | 17.5 and 26.5: label **"Notes ·"**, editor reopens with **"ghost"** | no trap |
| (a) `context.delete(note)` on the inserted reference, no `rollback()` | **1 row, clean** | **2 rows: the unsaved row still returned** (`isDeleted == false`) | nil, count 1 | true (1 inserted + 1 deleted pending) | 17.5 and 26.5: `@Query` 0 rows on every `body` run, label "Add note", editor reopens "" | no trap |
| (a′) fetch the pending row by key, then delete it | 1 row, clean | 1 row, clean | nil, count 1 | true | not run in the app | no trap |
| Rehearsal: insert and save in `ModelContext(container)`; the store refuses, so the real insert is skipped | 1 row, `hasChanges == false`, nothing inserted | same | nil, count 1 | **false** | 17.5 and 26.5: `@Query` 0 rows, label "Add note" through all 5 keystrokes, editor reopens "" | no trap |

**What these results mean.**
- **Variant (a):** the delete keeps the label clean because the `@Query` re-fetch lands in a later run-loop turn. An immediate fetch of all notes in the same turn still returns the unsaved row on 26.5. Two pending changes (the insert and its delete) stay in the context.
- **The second keystroke:** after (a), (a′) or the unit rehearsal, a plain `ExerciseNoteStore.save` inserts a fresh unsaved row (26.5 fetch-all count 3). So an in-place fix would have to run on every keystroke while the store refuses.
- **The rehearsal in the app:** it runs on every keystroke while the store refuses (no row exists yet), and each run leaves the writing context untouched.
- **No ghost reaches the store through another context.** An edit saved later from a writable context on the same file left the file with exactly one row (the `dbBench` note) for every variant, on both runtimes.

### P2: swap sheet height with 0 candidates and the empty-state line

The empty-state line is "Every \<Muscle\> exercise is already in this workout.", 13 pt, `mu`, 14 pt below the subtitle, in the same probe layout as Q6.

| | 17.5 | 26.5 |
|---|---|---|
| Content height, "Back" | **101.0** (a transient pre-layout reading of 85.33 first) | **101.0** |
| Content height, "Shoulders" (the longest muscle name) | 101.0 | 101.0 |
| Line frame | one line, 15.67 pt tall; 278 pt wide (Back), 309 pt (Shoulders) | one line (scaled by the 26.5 inset sheet) |

The constant is `.presentationDetents([.height(101.0)])`, which is 71.33 + 14 + 15.67. It replaces 71.33 whenever the line is shown.

### P3: does the rehearsal flash a row into the bar label?

Writable on-disk store, rehearsal on the insert branch only, fresh key `latPull`, two runs per runtime.

| Check | 17.5 | 26.5 |
|---|---|---|
| Order in the log | rehearsal insert saved → rehearsal delete saved → real save, within 2 ms | same, within 2 ms |
| First `WorkoutView.body` run after the keystroke | 3 ms after the real save, already showing the real row (1 row, text length 1) | 18 ms after, same |
| Any `body` run with a row before the real save, or with more than 1 row | none | none |
| Label read right after the first keystroke | "Notes ·" (from the real row) | same |
| Relaunch dump | exactly 1 row (`latPull="ghost"`) | exactly 1 row |
| First keystroke, all three saves | 2.8–3.5 ms | 20.4–20.5 ms |
| Later keystrokes (updates, no rehearsal) | – | 0.7–1.2 ms |

All three saves run synchronously in one handler, so `body` cannot run between them. XCUITest cannot sample below one frame, so the `body` log is the evidence.

### Facts the spec must state (addendum)

1. **The first note save rehearses.**
   - When the fetch finds no row for the key, `ExerciseNoteStore.save` first inserts and saves, then deletes and saves, in `ModelContext(context.container)`.
   - Only then does it insert in the writing context. Updates never rehearse.
   - If the rehearsal throws, the writing context is untouched (`hasChanges == false`, 0 rows): verified on 17.5 and 26.5.
2. **No undo in place.**
   - Doing nothing in the catch shows "Notes ·" and reopens the editor on text that was never saved (both runtimes).
   - Deleting the inserted row in place keeps the `@Query` label clean on both runtimes, but on 26.5 an immediate fetch of all notes still returns it, and two pending changes remain.
   - Neither shape may replace the rehearsal.
3. **Cost.** The rehearsal's three saves on the first keystroke per key take about 3 ms on 17.5 and 20 ms on the 26.5 simulator. Updates stay under 1.2 ms.
4. **No flash.** The rehearsal never shows a row in `WorkoutView`'s `@Query<ExerciseNote>` before the real save, and leaves exactly one row (both runtimes).
5. **Swap sheet with 0 candidates.** With the empty-state line, `.height(101.0)` (one line for every muscle name, both runtimes). The Q6 formula `77.33 + 64.33 × n` stays for n ≥ 1.
6. **Test note.** A failed-save test for notes must fetch all notes (not only by key) in the same run-loop turn: the 26.5 leftover row appears only there.

### Still unverified

- **A later successful save in the same context that refused.** Could it persist the pending pair from (a) or (b)? A store opened with `allowsSave: false` can never save, so I only checked a different, writable context. Probe: a failure that clears in place, for example a store file that becomes writable again.
- **The rehearsal's accepted edge case:** the insert is saved but the delete is refused. It cannot be produced with `allowsSave: false`.
- **Dynamic Type** on the 101.0 constant.
- **Whether a user sees a frame of the row between the rehearsal saves.** Inferred as impossible, because all saves run in one synchronous handler; not frame-sampled.

### Suggested `insights/gotchas.md` entry (SwiftData)

- 2026-09-14 — **A failed insert does not undo in place even for a relationship-free row.** Probe: `ExerciseNote` on a store reopened with `allowsSave: false`, writing context `mainContext`.
  - **Nothing in the catch:** the unsaved row stays in fetches and in `@Query` (bar label "Notes ·", editor reopens with the text). On 26.5 a fetch of all notes returns it **twice** while `fetchCount` says 2.
  - **`context.delete(note)` without `rollback()`:** no trap, and `@Query` shows 0 rows on both runtimes. But on 26.5 an immediate fetch of all notes in the same run-loop turn still returns the row, and `hasChanges` stays true.
  - **Fix:** rehearse the insert in a scratch `ModelContext` first; this was clean on 17.5 and 26.5.
  - **Recognize it:** a fetch count that disagrees with the fetched array's count after a failed save.

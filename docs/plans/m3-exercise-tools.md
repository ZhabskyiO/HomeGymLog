# M3 slice 3 — Exercise tools (detail sheet with notes, swap, progression pill): implementation plan

**Status: implemented 2026-09-14 on branch `m3-exercise-tools`.** Verified by plan-verifier round 3 (`docs/reviews/m3-exercise-tools-verifier-1.md`…`-3.md`). Steps 0–13 ran on Xcode 27.0 (27A266a), which replaced 26.6 mid-slice.
- **Tests (after ship-check):** iPhone 15 / iOS 17.5 634/634; iPhone 17 / iOS 26.5 634/634; Release build green; Step 12 scratch-copy XCUITests 8/8 passed on 17.5 (test1_notes, test2_keyboard, test3_swapEnabled, test4_pick, test5_swapMidRest, test6_exitAfterSwap, test7_pill, test8_a11y). Seeded screenshots `wo-start`, `wo-detail`, `wo-swap`, `wo-swap-rdl` match the prototype with the spec's §8 deviations. Swift review: ship (`docs/reviews/m3-exercise-tools-swift-review.md`).
- **Pending the user:** VoiceOver hints and reading order (AC-16) in the MVP pass; AC-17–AC-19 on the iPhone 14 Pro Max.
- **Swift-review fixes applied:**
  - `swapExercise` comments now describe the rollback-then-restore order.
  - The vacuous `StoreCommitTests` assertions are removed.
  - The detail sheet opens only for a library key.
  - `StoreCommitSourceTests` anchors on `StoreCommit.commit(` before `rehearseInsert(`.
- **Failed-save revert order (user decision, researcher addendum P4):**
  - `StoreCommit.commit` now rolls back first, then restores (all 11 field writers).
  - The new `StoreCommit.commitInsert` removes the inserts, then rolls back (`start`, note insert).
  - Every field-writer failed-save suite reads the written row with a first same-context fetch by id. Before the fix that fetch was red on 26.5 for every writer.
  - Those suites discard the pending restored originals before deleting their temporary store. Otherwise a SwiftData timer faults the missing file and aborts the 26.5 test process.
- **Deviations:**
  - `SwapSheet` uses `.topLeading` instead of `.top`: with no rows, `.top` centred the texts.
  - `SwapCandidates` also excludes the displayed key by name. The list is unchanged in the app, because that key is always among the log's keys.
  - The pill's `.task(id:)` skips the fetch when the held baseline is already for that key. This only happens when a failed Exit → Discard flips the id back.
  - `swapExercise` snapshots its sets with a closure instead of `SetSnapshot.init`, which triggers an Xcode 27 isolation warning.
- **Regression screenshots:** the `cmp` differences against the Xcode 26 baselines are status-bar pixels only (38,711 px in (0,0)–(259,48) pt). HEAD built on Xcode 27 renders byte-identically to the slice.

For `docs/specs/m3-exercise-tools.md` (review B1–B4, NB1–NB13 applied; researcher facts 1–12 and addendum P1–P3
binding); spec §2–6 and §8 are the contract (`AC-1`…`AC-30`); shorthands follow `docs/plans/m3-rest-timer.md`; executed by `implementer`, one step per build.

## 1. Goal and scope
Land exercise tools in dependency order: the shared commit/rehearsal helper (a behaviour-identical move), Engine rules, Shared text, the model writers and reads
(note save with rehearsal, `swapExercise`, `finishedTops` / `swapContext`), the `workoutSheetPreview` generalization and four seeds, then the pill, the detail sheet
with notes, and the swap sheet. Every step ends with a green build and named suites on iPhone 15 / iOS 17.5.

Out of scope (spec §7): exercise images; notes on the Home/Program info sheets; swapping from Home or Program; swapping a non-pending exercise or rewriting done
sets; swap history or badge; editing finished workouts; schema versioning (M5); haptics; autocorrect/IME verification; Settings. **No AC is excluded.** Taps are
refused in the repo's simulator session, so AC-9–AC-16 are the user's (MVP pass) unless optional Step 12 verifies them in a scratch copy; AC-17–AC-19 are
device-only. **No new dependency, entitlement, capability or Info.plist key; no schema change.**

## 2. Decisions this plan relies on
- INSIGHTS "2026-09-14 — M3 exercise-tools decisions" (incl. the architecture review): Swap only while every set of the displayed exercise is pending; one save
  for log + plan element; "last" pill on the focus set's weight; one note per key saved per keystroke, "" kept, "Notes ·" / "Add note"; **insert writers rehearse,
  field writers restore**; total Engine functions; `WorkoutSheetContent` + `openPreview` + shared `displayedExercise`; string sheet ids; pill baseline in screen
  `@State` via `.task(id: isDiscarding ? nil : key)`; bar a11y "Notes" / "Add note"; pick closes the sheet first; `workoutSheetPreview` replaces `workoutAdjustPreview`.
- INSIGHTS M3 rest-timer and logging decisions: guarded one-save writers, `clock.now()` at the action, failed-save policy, row ids, `isDiscarding`, the rest card in the inset.
- Patterns: per-key history reads; failed save via `allowsSave: false`; snapshot-restore writers; nil-by-default `@Entry`; real-touch probes; seeded screenshots.
- **Researcher addendum (binding, supersedes spec text):** P1 keep the rehearsal on the insert branch, no in-place undo; cost ~3 ms on 17.5 / ~20 ms on 26.5 for the
  first keystroke per key; **P2 the n = 0 swap sheet is `.height(101.0)`** on both runtimes for every muscle (Step 11 only confirms it by screenshot); P3 no flash, so
  U2 needs no UI check; a failed-save note test must fetch **all** notes in the same run-loop turn.
- Gotchas: SwiftData (container lifetime on 26.5; `rollback()` keeps values, never with a pending insert; 26.5 failed insert stays in fetches; 26.5 refetch returns an
  unsaved Codable array after restore-then-rollback; nested `flatMap` predicates), SwiftUI (`.task(id: text)` runs on appear; keyboard grows a 0.78 sheet; identifiers
  on leaf controls; hidden `Text` listed by XCUITest), Xcode (OS in destination, stale result bundle, `-only-testing` parentheses, clone stuck, `BOOT`, curl poll, sips).

Plan-level choices (challengeable):
- **`WorkoutSheetContent` takes two parameters the spec signature omits:** `noteText: String` (the detail case's seed text, read by the screen from its `notes`
  query rows, NB1) and `onClose: () -> Void` (Done). The sheet case never carries the text.
- **`Features/Workout/ExerciseDetailSheet.swift`** is a thin state owner (the draft `@State`, `.onChange` save) around the shared `ExerciseInfoSheet` layout with
  its Notes slot; it adds no second layout (NB2). `ExerciseInfoSheet` becomes generic over the slot; Done keeps 16 pt above without notes and 12 pt with them (prototype 386).
- **The existing `WorkoutFlow.displayedExercise(_ state:) -> Int?` stays** (the line and progress segments need the index); the new value lookup is an overload.
- **`finishedTops` returns one entry per finished log**: top = the maximum done weight over that log's rows for the key (spec AC-27 "duplicate key → one entry"). Group with a loop keyed on `workout?.id` or `Dictionary(grouping:)`, never `Dictionary(uniqueKeysWithValues:)`, which traps on the duplicate-key fixture (gotchas Swift language; verifier F10).
- **`swapContext(of:)` is total like `sessionInfo`**: no session → week 1, Foundation, `[:]`, keys from the log (the writer then does a log-only swap, NB8).
- **A static test pins "updates never rehearse"** (token order in `ExerciseNoteStore.swift`), because no probed runtime signal distinguishes it (see §5, spec gap 1).
- **Geometry helper** `build/sheettop.swift` measures a bottom sheet's top edge from a screenshot, so AC-3's 399 pt and the 101.0 constant are checked, not eyeballed.

Open questions (planned around the stated default; the main session may ask the user): (1) unknown displayed key in the swap sheet: `emptySwap` needs a muscle →
**default: omit the line, keep `.height(101.0)`** (not producible: keys are stable library keys). (2) AC-4's regression frames: `wo-rpe`, `wo-adjust`, `wo-rest` now
draw Swap **dimmed 40 %** (a set is done), which the prototype frames do not → **default: a listed deviation**, per decision Q1.

## 3. Steps
**Step 0 — shorthands and baselines.** Write `build/tools-env.sh` (gitignored; every command below starts `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/tools-env.sh`):
```
DEST='platform=iOS Simulator,name=iPhone 15,OS=17.5'; DEST26='platform=iOS Simulator,name=iPhone 17,OS=26.5'; BID=com.zhabskyi.homegymlog.ios
UDID=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-5"][] | select(.name=="iPhone 15") | .udid')
UDID26=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-26-5"][] | select(.name=="iPhone 17") | .udid')
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app
BUILD() { xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; }
TEST() { rm -rf build/tests.xcresult; xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult "$@" test 2>&1 | tee build/last-test.log | grep -E "✘|TEST (SUCCEEDED|FAILED)"; }
ONLY() { local a=(); for s in "$@"; do a+=("-only-testing:HomeGymLogTests/$s"); done; TEST -parallel-testing-enabled NO "${a[@]}"; }
COUNT() { xcrun xcresulttool get test-results summary --path build/tests.xcresult; }
RELEASE() { xcodebuild -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; }
BOOT() { xcrun simctl boot "$1" 2>/dev/null; xcrun simctl bootstatus "$1" -b >/dev/null; xcrun simctl status_bar "$1" override --time 9:41; }
LAUNCH() { local u=$1; shift; xcrun simctl terminate "$u" $BID 2>/dev/null; xcrun simctl install "$u" "$APP" && xcrun simctl launch "$u" $BID "$@"; }
SHOT() { sleep 3; xcrun simctl io "$1" screenshot "build/shot-$2.png"; }
APPEAR() { xcrun simctl ui "$1" appearance "$2"; }
PROTO() { (cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &); until curl -sf -o /dev/null http://127.0.0.1:8765/; do sleep 0.2; done
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=3000,5600 --virtual-time-budget=20000 \
    --screenshot=build/proto-all.png "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
  c() { sips -c "$2" "$3" --cropOffset "$4" "$5" build/proto-all.png --out "build/proto-$1.png" >/dev/null; }
  c wo-detail 570 300 1890 350; c wo-swap 570 300 1890 640; c wo-start 600 300 930 740; c wo-swipe 600 300 930 1045; c wo-rpe 700 310 930 1345
  c wo-rest 600 300 930 1665; c wo-adjust 570 300 1890 40; c summary 640 330 930 1975; }
```
Test runs print CoreData `error:` lines from the forced-failure suites; judge by `TEST SUCCEEDED` and `COUNT`. Clone-stuck failures retry with `-parallel-testing-enabled NO`.
One `xcodebuild` at a time. Undo = restore by hand (new files have no commit; never `git checkout`/`stash`/`clean`). Also write `build/sheettop.swift` (ImageIO):
`swift build/sheettop.swift <png> <screenHeightPt>` samples the colour at (14 pt, height − 60 pt), walks the x = 14 pt column upward while each pixel stays within ±6 per
channel, and prints `top=<pt>` = (first differing row + 1) / scale − 3.75 (the 28 pt corner at x = 14; scale = pixel height / points). On HEAD: `BUILD && TEST; COUNT`
(expect 515 passed); `BOOT $UDID; APPEAR $UDID dark; for s in wo-start wo-swipe wo-rpe wo-adjust wo-rest summary midProgram restDay freshProgram; do LAUNCH $UDID -seed $s;
SHOT $UDID base-$s; done; LAUNCH $UDID -seed missed -tab program -programWeek 2 -programDay 2; SHOT $UDID base-missed`; `swift build/sheettop.swift build/shot-base-wo-adjust.png 852`
→ `top=567` ± 1 (calibrates the helper on the verified 251 pt sheet: 818 − 251); `PROTO`, then read `build/proto-wo-detail.png` and `build/proto-wo-swap.png` once.
`/design-compare <snapshot> "<args>"` follows the skill (dark, status bar pinned by `BOOT`, crop from `PROTO`) and writes `build/compare-<snapshot>.png`.

### Step 1 — Models: `StoreCommit` (move, behaviour identical)
File `Models/StoreCommit.swift` (new): `enum StoreCommit` (≈ shared transaction helpers) with `static func commit(_ context: ModelContext, revert: () -> Void) throws`
(moved verbatim with its doc) and `static func rehearseInsert(in container: ModelContainer, _ insert: (ModelContext) throws -> (() -> Void)?) throws`: `let scratch =
ModelContext(container)`; `guard let remove = try insert(scratch) else { return }` (nothing to rehearse); `try scratch.save(); remove(); try scratch.save()`.
`Models/WorkoutLogStore.swift`: delete the private `commit`; every `try commit(context)` becomes `try StoreCommit.commit(context)`; `rehearseStart` becomes
`StoreCommit.rehearseInsert(in: container) { scratch in guard let stored = try scratch.fetch(…sessionID…).first else { return nil }; let rehearsal = insertLog(for: stored,
at: at, in: scratch); return { delete(rehearsal, in: scratch) } }`. Doc comments updated to name the helper; no behaviour change.
Tests: `Persistence/StoreCommitTests.swift` (`@MainActor`, holds `TestStore`): a closure returning nil → called once (the only clause here that can fail; name the test for it, e.g. `rehearseInsertCallsBodyOnce`, and add no further vacuous clauses; verifier F3), no save (`hasChanges` of a fresh context false,
0 notes); an `ExerciseNote` inserted and removed → a fresh context counts 0 notes and the closure's remove ran (fails if the second save is dropped: count 1); on an
on-disk store reopened `allowsSave: false` (both containers bound) → throws and a fresh writer context counts 0 notes. `Static/StoreCommitSourceTests.swift` (plain,
`#filePath`, comments stripped): across `HomeGymLog/Models/*.swift` the token `ModelContext(` appears only in `StoreCommit.swift` (fails if a store opens its own scratch context).
Verify: `BUILD && ONLY StoreCommitTests StoreCommitSourceTests WorkoutCommitRollbackTests RestCommitRollbackTests RestWriterRollbackTests WorkoutStartTests WorkoutStartEdgeTests && TEST; COUNT`
(515 + new, none failing). Discharges no AC (enables AC-26); NB3.

### Step 2 — Engine: `SwapCandidates`, `ProgressionPill`, `WorkoutFlow.canSwap` / `displayedExercise(exercises:state:)`
Files (new, `nonisolated`, no SwiftUI/SwiftData/text):
```swift
// Engine/SwapCandidates.swift
nonisolated struct SwapCandidate: Equatable, Sendable { let exerciseKey: String; let targetWeightLb: Double }
nonisolated enum SwapCandidates {
    /// Same muscle as `key`, not in `keysInWorkout`, library order, weight from WeightFormula (week < 2 computes as week 1; unknown key → []).
    static func candidates(for key: String, keysInWorkout: [String], week: Int, phase: Phase, startingWeightsLb: [String: Double]) -> [SwapCandidate]
}
// Engine/ProgressionPill.swift
nonisolated struct FinishedExerciseTop: Equatable, Sendable { let finishedAt: Date; let topWeightLb: Double }
nonisolated struct PreviousTops: Equatable, Sendable { let best: Double?; let last: Double? }
nonisolated enum ProgressionPill {
    static func previousTops(_ tops: [FinishedExerciseTop]) -> PreviousTops   // last = top of the latest finishedAt, ties → larger weight
    static func delta(currentLb: Double, previousLb: Double?) -> Double?     // current − previous iff previous exists and current > previous
}
```
`Engine/WorkoutFlow.swift` gains `static func canSwap(_ exercise: WorkoutExerciseValue) -> Bool` (every set pending; no sets → true) and `static func displayedExercise(exercises:
[WorkoutExerciseValue], state: WorkoutState) -> WorkoutExerciseValue?` (the focus position's exercise from `sorted(exercises)`; nil in summary or out of range).
Tests (plain; expected values typed from the spec, never from `WeightFormula`):
- `Engine/SwapCandidatesTests.swift` — session 11 keys `[latPull, lowRow, dbRow, rdl, curl]`, week 3 Foundation, `[:]`: latPull, lowRow, dbRow → `[]`; rdl → goblet 52.5, legExt 80,
  legCurl 60, split 32.5, lunge 32.5 (literal array, order matters); curl → pushdown 70, skull 27.5. dbBench with Push keys `[dbBench, inclineDb, shoulderPress, pecDeck, latRaise]`
  → `[chestPress 100]`. Displayed goblet with keys `[latPull, lowRow, dbRow, goblet, curl]` → rdl 52.5, legExt 80, legCurl 60, split 32.5, lunge 32.5 (fails if planned keys are
  used). `["goblet": 40]` → goblet 42.5 (fails if the map is ignored). rdl week 2 Foundation → 50, 70, 50, 30, 30; week 4 Deload → 37.5, 60, 40, 22.5, 22.5; week 0 and −1 →
  50, 70, 50, 30, 30 (before the first week; no trap); `"mystery"` → `[]`.
- `Engine/ProgressionPillTests.swift` — the 5.2 appearances as literal tops (latPull 90@s1, 100@s6 → best 100, last 100; lowRow 80/90; dbRow 42.5, 42.5, 45, 45; rdl 47.5,
  47.5, 50; curl 22.5, 25), each also passed reversed; divergent 90@s1, 80@s6 → best 90, last 80 (fails if last = max); equal `finishedAt` 90 and 95 → last 95; `[]` → (nil, nil).
  `delta`: 110 vs 100 → 10; 52.5 vs 52.5 → nil; 45 vs 50 → nil; 110 vs nil → nil; 52.5 vs 50 → 2.5.
- `Engine/WorkoutFlowToolsTests.swift` — `canSwap` over the 5.3 rows on `WorkoutFixtures.exercises(session11)` + `editing`: all pending → true; E1S1 done RPE nil, RPE 7, and
  `rpeSkipped` → false; E1S1 skipped → false; E1S1–S3 done with S3 unrated → false; an exercise with `sets: []` → true; `"mystery"` all pending → true. `displayedExercise`:
  logging(0, 0) → fixture[0]; logging(3, 0) → fixture[3]; rpePending(0, 2) → fixture[0]; summary → nil; logging(5, 0) and logging(−1, 0) → nil; each repeated on
  `WorkoutFixtures.shuffled` → the unshuffled fixture element (fails if the input order is used).
Verify: `BUILD && ONLY SwapCandidatesTests ProgressionPillTests WorkoutFlowToolsTests WorkoutFlowTests WorkoutFlowEdgeTests`. AC-20, AC-21, AC-22.

### Step 3 — Shared: `ExerciseToolsText`
File `Shared/ExerciseToolsText.swift` (new, `enum ExerciseToolsText`): constants `swapSubtitle = "Same muscle group, your equipment."`, `notesTitle = "Notes"`,
`notePlaceholder = "e.g. bench at incline notch 2, grip slightly wider"`, `noteAccessibilityHint = "Edit your note"`, `nameHint = "Shows form cues and notes"`, `pillArrow = "↑"`;
functions `pill(deltaLb:unit:name:)` ("+" + `WeightDisplay.text` + " unit from your last " + name), `pillSpoken(deltaLb:unit:name:)` ("Up 10 lb from your last …"),
`swapTitle(name:)`, `emptySwap(muscle: MuscleGroup)`, `noteLabel(hasNote:)`, `noteAccessibilityLabel(hasNote:)`, `candidateWeight(lb:unit:)`,
`candidateAccessibilityLabel(name:equipment:lb:unit:)` ("Goblet Squat, Dumbbell, 52.5 lb"). Tests `Shared/ExerciseToolsTextTests.swift` (`@MainActor`), literals from spec AC-23:
pill (10, lb, Lat Pulldown) "+10 lb from your last Lat Pulldown", (2.5, lb) "+2.5 lb …", (10, kg) "+4.5 kg …", (2.5, kg) "+1.1 kg …", (20, kg) "+9.1 kg …"; pillSpoken
"Up 10 lb from your last Lat Pulldown", "Up 1.1 kg from your last Dumbbell Curl"; "Swap Lat Pulldown"; subtitle; `emptySwap(.back)` "Every Back exercise is already in this
workout.", `(.shoulders)` "Every Shoulders exercise …"; `noteLabel(true/false)` "Notes ·" / "Add note" (the middle dot U+00B7 compared by scalar); a11y "Notes" / "Add note";
hint, name hint, placeholder, arrow; candidateWeight (52.5, lb) "52.5 lb", (52.5, kg) "23.8 kg", (80, lb) "80 lb", (80, kg) "36.3 kg"; the accessibility label above and
"Leg Extension, Marcy · leg developer, 36.3 kg". Verify: `BUILD && ONLY ExerciseToolsTextTests ClockUsageTests`. AC-23.

### Step 4 — Models: note save rehearses its insert, restores its update
`Models/ExerciseNoteStore.swift`, signature unchanged (`save(text:forExerciseKey:updatedAt:in:) throws -> ExerciseNote`):
```swift
if let existing = try note(forExerciseKey: key, in: context) {        // field writer: restore, then rollback (INSIGHTS failed-save policy)
    let (oldText, oldUpdatedAt) = (existing.text, existing.updatedAt)
    existing.text = text; existing.updatedAt = updatedAt
    try StoreCommit.commit(context) { existing.text = oldText; existing.updatedAt = oldUpdatedAt }
    return existing
}
try StoreCommit.rehearseInsert(in: context.container) { scratch in       // insert writer: a refusing store throws here, before this context changes
    let rehearsal = ExerciseNote(exerciseKey: key, text: text, updatedAt: updatedAt); scratch.insert(rehearsal); return { scratch.delete(rehearsal) }
}
let note = ExerciseNote(exerciseKey: key, text: text, updatedAt: updatedAt); context.insert(note)
try StoreCommit.commit(context) { context.delete(note) }                // last resort only, as in `start`; the delete stays inside the revert closure, which runs before rollback(); never move it after (verifier F9)
return note
```
Doc comment: the two branches, the three-save first keystroke (~3 ms 17.5, ~20 ms 26.5, addendum), the accepted edge. Tests `Persistence/ExerciseNoteSaveTests.swift`
(`@MainActor`; read back through `ModelContext(container)`): two saves for latPull → one row, last text and `updatedAt`; `""` stored and read back as `""`; latPull + lowRow →
two rows. Failed saves (on-disk store with one saved `dbBench` note, reopened `allowsSave: false`, both containers bound; writing context `ModelContext(readOnly)`):
**update** `dbBench` → throws; the object reads the old text and `updatedAt`; a same-context `FetchDescriptor<ExerciseNote>()` refetch reads them; `hasChanges == false`; a
fresh writer context reads them (fails without the restore: rollback keeps values). **Insert** latPull → throws; **in the same run-loop turn** a fetch of **all** notes in the
writing context returns exactly 1 row (`dbBench`) and `fetchCount` 1, `insertedModelsArray` empty, `hasChanges == false`, reading every row's `text` does not trap; a fresh writer
context counts 1 (fails on 26.5 for an in-place insert, addendum P1). `Static/StoreCommitSourceTests.swift` gains: in `ExerciseNoteStore.swift` code lines, `rehearseInsert(`
occurs exactly once and after the first line containing `return existing` (fails if the update branch rehearses). Verify: `BUILD && ONLY ExerciseNoteSaveTests
ExerciseNoteStoreTests StoreCommitSourceTests ModelRoundTripTests`. AC-26.

### Step 5 — Models: `WorkoutLogStore.swapExercise`
```swift
/// Swap pick: guarded field writer, one save (spec 4.2). Returns false and writes nothing unless `key` is in the library, differs from the current key, no other
/// exercise of the log has it, and every set of the exercise is pending.
@discardableResult
static func swapExercise(_ exercise: LoggedExercise, to key: String, targetWeightLb: Double, in context: ModelContext) throws -> Bool
```
Body: guards first; snapshot `exerciseKey`, `swappedFromKey`, `targetWeightLb`, the pending sets (`SetSnapshot`), `session.exercises` (whole array); `let planned =
exercise.swappedFromKey ?? exercise.exerciseKey`; write key, `swappedFromKey = key == planned ? nil : planned`, target, each pending set's `weightLb`; if the session has
an element with `order == exercise.order`, set its `exerciseKey` and `targetWeightLb` in place (none → log-only, still true, NB8); `do { try StoreCommit.commit(context) {
restore all } } catch { if let session, let plannedSnapshot { session.exercises = plannedSnapshot }; throw error }` (reassign after rollback: 26.5 gotcha). Doc comment states
the one-save property (NB12: code review, not a test).
Tests `Persistence/SwapExerciseTests.swift` (`@MainActor`, holds `TestStore`; `WorkoutStoreFixtures.sixMonthRows` + `start(session: rows[11])`, the `wo-swap-rdl` exercise rows;
read back through a fresh context): rdl → goblet 52.5 returns true; E4 key goblet, `swappedFromKey == "rdl"`, target 52.5, its three sets 52.5 × 12 pending; session 11
`exercises[3] == PlannedExercise(order: 3, exerciseKey: "goblet", targetWeightLb: 52.5)`, elements 0–2 and 4 equal the pre-swap literals, every other session's array equals its
snapshot. Then goblet → legExt 80: `swappedFromKey` still `"rdl"`, sets 80, element legExt@80. Then legExt → rdl 52.5: `swappedFromKey == nil`, element rdl@52.5. Session 11
saved without order 3 first → swap E4 returns true, E4 changes, the four-element array is unchanged. Returns false with `hasChanges == false` and unchanged rows for: E4S1
done (`logSet`), E4S1 skipped (`skipSet`), same key `rdl`, `lowRow` (in the log), `"mystery"`.
`Persistence/SwapCommitRollbackTests.swift` (the `allowsSave: false` pattern, containers bound, temp dir removed after release): on the read-only context, `swapExercise(E4, to:
"legExt", targetWeightLb: 80)` throws; the objects read rdl / nil / 52.5 / sets 52.5 / element rdl@52.5; **a refetch in the writing context** (`LoggedExercise` by id,
`LoggedSet` by the exercise, `PlannedSession` with index 11) reads the same (fails on 26.5 without the post-rollback reassign); a fresh writer context reads the same.
Verify: `BUILD && ONLY SwapExerciseTests SwapCommitRollbackTests WorkoutCommitRollbackTests`. AC-24, AC-25.

### Step 6 — Models: `finishedTops`, `swapContext`
`Models/WorkoutSnapshotBuilder.swift`:
```swift
struct SwapContext: Equatable { let week: Int; let phase: Phase; let startingWeightsLb: [String: Double]; let keysInWorkout: [String] }
/// Per-key history read (Patterns): one-hop predicate, program filtered in Swift; one entry per finished log, top = max done weight of its rows for the key; no done set → dropped.
static func finishedTops(key: String, programID: UUID, in context: ModelContext) throws -> [FinishedExerciseTop]
    // #Predicate<LoggedExercise> { $0.exerciseKey == key && $0.workout.flatMap { log in log.finishedAt != nil } == true }
static func swapContext(of log: WorkoutLog) -> SwapContext   // session week/phase, program starting weights, log.sortedExercises keys; no session → (1, .foundation, [:], keys)
```
Tests (iPhone 15 / iOS 17.5; the predicate is new): `Persistence/FinishedTopsTests.swift` (`#if DEBUG`, `@MainActor`, container bound): program A = `MidProgramSeed.populate`,
every done set +100 lb, `archivedAt` set, saved; program B = `MidProgramSeed.populate` again; B's session 11 started at noon 09-15 with E1S1 logged at 110. `finishedTops(latPull, B)`
sorted by `finishedAt` == `[(day(2026,9,1) + 7 h 41 min 13 s, 90), (day(2026,9,8) + 7 h 41 min 28 s, 100)]` (fails if the in-progress log or program A leaks: 110 or 190/200);
`rdl` → tops 47.5, 47.5, 50 at 09-01, 09-02, 09-08; `pushdown` → `[]`; with a second latPull `LoggedExercise` (one done set at 95) appended to B's session-1 log → still two
entries, the first 95. `Persistence/SwapContextTests.swift` (`@MainActor`): session 11 started from `sixMonthRows` → week 3, `.foundation`, keys `[latPull, lowRow, dbRow,
rdl, curl]`, `startingWeightsLb["latPull"] == 100`; after `swapExercise(E4 → goblet)` keys end `[…, goblet, curl]`; program map `["goblet"] = 40` saved → context reads 40 and
`SwapCandidates.candidates(for: "rdl", …context…)` on the pre-swap log starts with goblet 42.5 (40 + 2.5, slow regime, week 3 Foundation; end to end, proves the saved map flows through; verifier F2); a hand-inserted log with no session → (1, .foundation, [:], its keys).
Verify: `BUILD && ONLY FinishedTopsTests SwapContextTests WorkoutSnapshotBuilderTests WorkoutQueriesTests`. AC-27.

### Step 7 — App: `workoutSheetPreview` replaces `workoutAdjustPreview`
`Features/Workout/WorkoutSheet.swift`: `enum WorkoutSheetPreview: Equatable { case adjust, detail, swap }` (production; doc: DEBUG previews only, nil = normal).
`App/AppClock.swift` line 36: `@Entry var workoutSheetPreview: WorkoutSheetPreview? = nil` replaces the Bool entry. `App/HomeGymLogApp.swift` lines 17, 32, 44, 61, 81:
`sheetPreview: WorkoutSheetPreview?`, `sheetPreview = seed.workoutSheetPreview`, `.environment(\.workoutSheetPreview, sheetPreview)`. `App/DebugSeed/DebugSeed.swift`:
`var workoutSheetPreview: WorkoutSheetPreview? { self == .woAdjust ? .adjust : nil }` replaces `workoutAdjustPreview`. `Features/Workout/WorkoutView.swift` line 39:
`@Environment(\.workoutSheetPreview) private var sheetPreview`; line 98: `if sheetPreview == .adjust, …` (detail/swap arrive in Steps 10–11).
Tests: `Seed/DebugSeedTests.swift` `previews` (lines 68–69) → for every seed in `allCases`, `workoutSheetPreview == (seed == .woAdjust ? .adjust : nil)`.
`Static/SeedNameScanTests.swift` gains `sheetPreviewEntry`: no app-target code line contains `workoutAdjustPreview`; exactly one code line of `App/AppClock.swift` contains both
`@Entry` and `workoutSheetPreview`. Verify: `BUILD && ONLY DebugSeedTests SeedNameScanTests RestNotifierSourceTests && RELEASE`; `BOOT $UDID; LAUNCH $UDID -seed wo-adjust;
SHOT $UDID s7-wo-adjust; cmp build/shot-base-wo-adjust.png build/shot-s7-wo-adjust.png` (identical). AC-28 (preview half), AC-29 (scan), AC-30 (App.init changed).

### Step 8 — Seeds `wo-detail`, `wo-swap`, `wo-swap-rdl`, `wo-notes`
`App/DebugSeed/DebugSeed.swift`: cases `woDetail = "wo-detail"`, `woSwap = "wo-swap"`, `woSwapRDL = "wo-swap-rdl"`, `woNotes = "wo-notes"` (doc each per spec 4.4), joining
`referenceDate`'s 09-15 group, `initialDraft`'s nil group, `makeContainer`'s workout group; `workoutStage`: woDetail, woSwap → `.started`, woNotes → `.noted`, woSwapRDL →
`.legsNext`; `workoutSheetPreview`: woAdjust `.adjust`, woDetail `.detail`, woSwap and woSwapRDL `.swap`. `App/DebugSeed/WorkoutSeed.swift`: `Stage` gains `legsNext` (sets
k = 1…9 of E1–E3: `logSet` then `setRPE(7)` both at `startedAt + 70·k`; last rest 11:57:56 → 11:59:11, stale) and `noted` (`ExerciseNoteStore.save(text: "Seat notch 3, grip just
outside the bend.", forExerciseKey: "latPull", updatedAt: now − 86 400, in:)`).
Tests: `Seed/DebugSeedTests.swift` — the four join the 09-15 case of `parses`, `workoutNames` and the `drafts` loop; `previews` expects the five-way mapping. `Seed/WorkoutSeedTests.swift`
— `seed` arguments gain woDetail, woSwap, woNotes (754, logging(0, 0), pending rows) and woSwapRDL (754, logging(3, 0); `expectedRows` rows 0–8 done RPE 7 at their targets with
`loggedOffset` 70·(k + 1)); `restInstants` gains the three (nil, nil) and woSwapRDL (−124, −49) with `display` nil. New `Seed/ToolsSeedTests.swift` (`#if DEBUG`, `@MainActor`, containers
bound): wo-notes → exactly one note (latPull, the text, `updatedAt == noon − 86 400`); wo-start, wo-detail, wo-swap, wo-swap-rdl → 0 notes; wo-swap-rdl → `canSwap` true for the
displayed exercise and `SwapCandidates.candidates` over `swapContext` equals the literal AC-20 rdl list; wo-swap → `[]` for latPull. `Seed/SeedHomeStatsTests.swift` — rows for
`.woSwapRDL` and `.woNotes` with `midProgram`'s numbers. `Static/SeedNameScanTests.swift` — the four quoted names join `names`.
Verify: `BUILD && ONLY DebugSeedTests WorkoutSeedTests ToolsSeedTests SeedHomeStatsTests SeedNameScanTests ExerciseNoteSaveTests`. AC-28, AC-29 (names).

### Step 9 — Views: progression pill
`Features/Workout/ProgressionPillView.swift` (new): `ProgressionPillView(text: String, spoken: String)`: `HStack(spacing: 6) { Text(ExerciseToolsText.pillArrow); Text(text) }`, 12
semibold `success`, padding 6/10, `Theme.success.opacity(0.14)` in a radius-8 rounded rectangle, `.fixedSize()`, `.accessibilityElement(children: .ignore)`, label `spoken`,
`.accessibilityAddTraits(.isStaticText)`. `Features/Workout/WorkoutLoggingContent.swift`: `let previousTopLb: Double?` after `rest`; `exercise` comes from
`WorkoutFlow.displayedExercise(exercises:state:)` (the index form stays for the line and segments); `pillDeltaLb = WorkoutFlow.focusSet(…).flatMap { ProgressionPill.delta(currentLb:
$0.weightLb, previousLb: previousTopLb) }`; `ExerciseBlock` gains `pillDeltaLb: Double?`, `unit`, and under the equipment line `if let pillDeltaLb { ProgressionPillView(…).padding(.top, 12) }`.
`Features/Workout/WorkoutView.swift`:
```swift
@State private var pillBaseline: (key: String, previous: PreviousTops)?   // ≈ a memo keyed on the exercise, filled by an effect
// body: let displayed = WorkoutFlow.displayedExercise(exercises: exercises, state: state); … WorkoutLoggingContent(…, previousTopLb: previousTop(for: displayed), …)
.task(id: isDiscarding ? nil : displayed?.exerciseKey) { loadPillBaseline(key: displayed?.exerciseKey) }   // ≈ useEffect(load, [key]); nil while Exit deletes rows (NB5)
private func previousTop(for exercise: WorkoutExerciseValue?) -> Double?   // pillBaseline.previous.last only when pillBaseline.key == exercise?.exerciseKey
private func loadPillBaseline(key: String?)                               // guard key, programID, !isDiscarding; finishedTops on modelContext; catch → assertionFailure, baseline unchanged
```
Verify: `BUILD && TEST`; `BOOT $UDID; APPEAR $UDID dark`; `/design-compare wo-start "-seed wo-start"` → pill "↑ +10 lb from your last Lat Pulldown" under "Marcy · high pulley", rows 16 pt
below; deviations to skip: "+10 lb" (prototype "+5 lb"), Swap still inert (Step 11). Regression with the pill added and the earlier deviations otherwise: `/design-compare wo-swipe
"-seed wo-swipe"`, `wo-rpe "-seed wo-rpe"`, `wo-adjust "-seed wo-adjust"`, `wo-rest "-seed wo-rest"` (each shows the latPull pill); `LAUNCH $UDID -seed summary; SHOT $UDID s9-summary;
cmp build/shot-base-summary.png build/shot-s9-summary.png`. `LAUNCH $UDID -seed wo-start -units kg; SHOT $UDID s9-kg` → "↑ +4.5 kg from your last Lat Pulldown". AC-4, AC-6 (wo-start half).

### Step 10 — Views: detail sheet with notes, `WorkoutSheetContent`, name button, bar button
`Shared/ExerciseInfoSheet.swift`: `struct ExerciseInfoSheet<Notes: View>: View` with `init(exercise:onDone:@ViewBuilder notes: () -> Notes)` (Done 12 pt above) and
`extension ExerciseInfoSheet where Notes == EmptyView { init(exercise:onDone:) }` (Done 16 pt above, today's layout); body inserts `notes` between the cues and Done; the
`exerciseInfoSheet(item:)` extension calls `ExerciseInfoSheet(exercise: exercise, onDone: { item.wrappedValue = nil })` with the label spelled out. Home and Program files unchanged.
`Features/Workout/ExerciseDetailSheet.swift` (new): `ExerciseDetailSheet(exercise:initialText:onChange:onDone:)`, `@State private var text` seeded in `init` (≈ `useState(initial)`),
body `ExerciseInfoSheet(exercise:onDone:) { NotesEditor(text: $text) }.onChange(of: text) { _, new in onChange(new) }` (≈ `useEffect(save, [text])`; not on appear, gotcha);
private `NotesEditor`: "Notes" 13 bold 16 pt above; `ZStack(alignment: .topLeading) { TextEditor(text: $text).font(14).foregroundStyle(tx).scrollContentBackground(.hidden)
.frame(minHeight: 70).padding(.horizontal, 7).padding(.vertical, 2).accessibilityLabel(notesTitle); if text.isEmpty { Text(notePlaceholder)…padding 10/12
.allowsHitTesting(false).accessibilityHidden(true) } }`, `sf2` fill, 1.5 pt `bd` border, radius 12, 8 pt above (researcher sketch).
`Features/Workout/WorkoutSheet.swift`: `case detail(exerciseKey: String)`; `var id: String` (`"adjust-\(setID)"`, `"detail-\(key)"`); new `WorkoutSheetContent(item:unit:noteText:
onSaveAndLog:onSkipSet:onNoteChange:onClose:)` whose `body` switches: `.adjust` → `AdjustSheet(…).workoutSheetChrome(.height(251))`; `.detail(let key)` → `if let exercise =
ExerciseLibrary.exercise(for: key) { ExerciseDetailSheet(…, onChange: { onNoteChange(key, $0) }, onDone: onClose).workoutSheetChrome(.fraction(0.78)) }`; private `View.workoutSheetChrome(_
detent: PresentationDetent)` = detents, corner 28, drag indicator hidden, `sf` background. `WorkoutLoggingContent`: `let hasNote: Bool`, `let onDetail: (String) -> Void`;
`ExerciseBlock`'s name + " ⓘ" becomes one `Button { onDetail(key) }` (plain style, `.accessibilityLabel(name)`, `.accessibilityHint(ExerciseToolsText.nameHint)`); the bar gets
`hasNote`, `onNote`. `WorkoutBottomBar`: `Button(action: onNote) { BarLabel(title: noteLabel(hasNote:)) }`, `.accessibilityLabel(noteAccessibilityLabel(hasNote:))`,
`.accessibilityHint(hasNote ? noteAccessibilityHint : "")`. `WorkoutView`: `@Query private var notes: [ExerciseNote]` (≈ useQuery of all notes, ≤ 18 rows); the sheet closure is
one `WorkoutSheetContent(item: item, unit: unit, noteText: noteText(for: item), onSaveAndLog: saveAndLog, onSkipSet: skipSet, onNoteChange: saveNote, onClose: { sheet = nil })`;
`hasNote(_ key: String?) -> Bool` (a row with the key and non-empty text), `noteText(for:)` (scalar read of the rows, NB1), `openDetail(_ key: String)` (`sheet = .detail(exerciseKey:)`),
`saveNote(_ key: String, _ text: String)` (`ExerciseNoteStore.save(…, updatedAt: clock.now(), …)`, catch → `assertionFailure`); `onAppear` becomes `if let sheetPreview {
openPreview(sheetPreview, exercises: exercises, state: state) }` with `openPreview(_:exercises:state:)` handling `.adjust` (as today) and `.detail` (displayed key); `.swap: break`
until Step 11. Body length: `sed -n '/var body: some View {/,/^    }$/p' HomeGymLog/Features/Workout/WorkoutView.swift | wc -l` ≤ 80 (estimate 74; if above, move `hasNote`/`previousTop` calls into one `private func loggingContent(…)`).
Verify: `BUILD && TEST`; `git diff --quiet -- HomeGymLog/Features/Home HomeGymLog/Features/Program && echo home-program-untouched`; `BOOT $UDID; APPEAR $UDID dark`; `/design-compare wo-detail
"-seed wo-detail"` → "Back · Marcy · high pulley", "Lat Pulldown", "Form cues" 1–3 verbatim, "Notes", placeholder, Done visible; deviations: no image slots or captions, the pill above
the dim. `/design-compare wo-adjust "-seed wo-adjust"` (unchanged by the extraction) and `swift build/sheettop.swift build/compare-wo-adjust.png 852` → `top=567` ± 1. `LAUNCH $UDID -seed wo-notes;
SHOT $UDID ac5-notes` → bar "Notes ·" · "Next exercise ›", rest as `wo-start` (AC-5). `LAUNCH $UDID -seed wo-start; SHOT $UDID s10-start` → bar "Add note". `APPEAR $UDID light; LAUNCH $UDID
-seed wo-detail; SHOT $UDID ac7-detail-light; APPEAR $UDID dark` → `sf` sheet, `sf2` editor with `bd` border in light tokens. AC-1, AC-5, AC-7 (detail half).

### Step 11 — Views: swap sheet and header Swap
`Features/Workout/WorkoutSheet.swift`: `struct SwapDraft: Equatable { let exerciseID: UUID; let exerciseKey: String; let candidates: [SwapCandidate] }`; `case swap(SwapDraft)` with id
`"swap-\(exerciseID)"`; `WorkoutSheetContent` gains `onPick: (SwapDraft, SwapCandidate) -> Void` and `.swap(let draft)` → `SwapSheet(draft: draft, unit: unit, onPick: { onPick(draft, $0)
}).workoutSheetChrome(.height(SwapSheet.height(candidateCount: draft.candidates.count)))`. `Features/Workout/SwapSheet.swift` (new): `static func height(candidateCount n: Int) -> CGFloat {
n == 0 ? 101.0 : 77.33 + 64.33 * CGFloat(n) }` (doc: researcher Q6 + addendum P2; recompute if the layout changes); body `VStack(alignment: .leading, spacing: 0)`: `swapTitle` 18 bold; subtitle 13
`mu` 2 pt below; `if draft.candidates.isEmpty { if let muscle { Text(emptySwap(muscle:)) 13 mu .padding(.top, 14) } } else { VStack(spacing: 8) { ForEach(draft.candidates, id: \.exerciseKey)
{ candidate row Button } }.padding(.top, 14) }`; padding top 22, horizontal 20, bottom 10; `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`, `sf`. Row: name 15
semibold `tx` over equipment 12 `mu` (leading, wraps), `Spacer(minLength: 12)`, `candidateWeight(lb:unit:)` 14 semibold (`.fixedSize()`), padding 12/14, `sf2` radius 12, plain style,
`.accessibilityLabel(candidateAccessibilityLabel(…))`. `WorkoutHeader`: `let swapEnabled: Bool`, `let onSwap: () -> Void`; `Button(action: onSwap) { HeaderPill(title: "Swap") }.buttonStyle(.plain)
.disabled(!swapEnabled).opacity(swapEnabled ? 1 : 0.4)`. `WorkoutLoggingContent`: `let onSwap: (UUID) -> Void`; header gets `swapEnabled: exercise.map(WorkoutFlow.canSwap) ?? false` and
`onSwap: { if let exercise { onSwap(exercise.id) } }`. `WorkoutView`: `openSwap(_ exerciseID: UUID, in exercises: [WorkoutExerciseValue])` (value by id, guard `canSwap`, `swapContext(of:
log)`, candidates, `sheet = .swap(…)`); `pick(_ draft: SwapDraft, _ candidate: SwapCandidate)` (`sheet = nil` first, NB4; exercise row by id; `swapExercise`; catch → `assertionFailure`);
`openPreview` `.swap` → `openSwap(displayed.id, in:)`.
Verify: `BUILD && TEST`; `BOOT $UDID; APPEAR $UDID dark`; `/design-compare wo-swap "-seed wo-swap"` → "Swap Lat Pulldown", subtitle, no rows; deviations: the empty-state line "Every Back exercise
is already in this workout.", pill "+10 lb"; `swift build/sheettop.swift build/compare-wo-swap.png 852` → `top=717` ± 1 (818 − 101.0; confirmation only, addendum P2). `LAUNCH $UDID -seed
wo-swap-rdl; SHOT $UDID ac3-rdl` → read AC-3's list (header, segments 3 `success` + accent + `sf2`, name, "Dumbbells", pill "↑ +2.5 lb from your last Dumbbell Romanian Deadlift", rows, the five
candidates in order with weights); `swift build/sheettop.swift build/shot-ac3-rdl.png 852` → `top=419` ± 1 (399 pt). `LAUNCH $UDID -seed wo-swap-rdl -units kg; SHOT $UDID ac6-kg` → rows "23.8 kg ×
12 reps", pill "↑ +1.1 kg …", candidates 23.8 · 36.3 · 27.2 · 14.7 · 14.7 kg. `APPEAR $UDID light; LAUNCH $UDID -seed wo-swap-rdl; SHOT $UDID ac7-rdl-light; APPEAR $UDID dark` → `sf2` rows on `sf`.
Regression: `/design-compare wo-start "-seed wo-start"` (Swap full opacity); `wo-rpe`, `wo-adjust`, `wo-rest` with the added deviation "Swap dimmed 40 %" (open question 2); `wo-swipe`
unchanged from Step 9. AC-2, AC-3, AC-6 (rdl half), AC-7 (swap half).

### Step 12 (optional) — Behaviour checks in a scratch copy (repo untouched)
Only if `R=/private/tmp/claude-501/-Users-zhabskyi-AppleApps-HomeGymLog/67072f25-4807-4607-a0c7-1e6110ff144d/scratchpad/probe` (the researcher's copy of `48915c2` with a UI-test target)
still exists and the repo's pbxproj is unchanged since `48915c2`; otherwise skip and hand AC-9–AC-16 to the user. `SP` = the implementer's scratchpad.
```
source build/tools-env.sh; test -f "$R/HomeGymLog.xcodeproj/project.pbxproj" && git diff --quiet 48915c2 HEAD -- HomeGymLog.xcodeproj || { echo "skip Step 12"; exit 0; }
rm -rf "$SP/tools" && rsync -a --exclude build --exclude .git ./ "$SP/tools/" && mkdir -p "$SP/tools/HomeGymLogUITests"
diff -u HomeGymLog.xcodeproj/project.pbxproj "$R/HomeGymLog.xcodeproj/project.pbxproj" > "$SP/uitest-target.patch"; patch "$SP/tools/HomeGymLog.xcodeproj/project.pbxproj" < "$SP/uitest-target.patch"
```
In the copy only: `HomeGymLog/App/DebugSeed/LiveToolsProbe.swift` (`#if DEBUG`, `static func prepare(arguments: [String], in: ModelContext, now: Date, calendar: Calendar) throws`, called from the
copy's `HomeGymLogApp.init` on the success branch with `live.now()`; on-disk store, live clock, live notifier, no `-seed`): `-liveReset` deletes every program (`ProgramStore.delete`) and note, saves,
then `MidProgramSeed.populate(completedIndexes: hasHistory ? MidProgramSeed.completedIndexes : [])` (`-liveHistory`); `-liveDiscard` discards in-progress logs; `-liveSession <i>` (default 11 after a
reset) moves any other session dated today one day back, dates session *i* today, applies `-liveRest <s>` to its `restSeconds`, saves and `WorkoutLogStore.start(session:at: now)`; `-liveStage
rdlRated` logs and rates sets 1–8 of E1–E3 and logs E3S3 unrated. `HomeGymLogUITests/ToolsLiveUITests.swift` (XCTest; coordinate taps for the editor, fact 12; queries by label, `.firstMatch`
where a hidden `Text` may duplicate):
`test1_notes` (`-liveReset`: "Add note" → `textViews["Notes"]` empty; type "Seat notch 3"; Done → `buttons["Notes"]`; name → value kept; clear, Done → "Add note"; type "Grip wi", `terminate`,
`launch` → name → "Grip wi"; Next exercise → "Add note"; relaunch `-liveDiscard -liveSession 16` → `buttons["Notes"]`) → AC-9. `test2_keyboard` (six lines → Done `maxY` ≤ keyboard `minY`; 150 pt
content drag → no keyboard, Done present; 560 pt fast drag from the sheet top edge → no Done; relaunch → text intact) → AC-10. `test3_swapEnabled` (`-liveReset`: Swap enabled → the empty line,
no candidate button; dismiss; drag set 1 right → Swap `isEnabled` false; tap "7" → still false with the card; "Skip rest"; Next exercise ×3 → five buttons labelled as AC-3 in ascending `minY`) →
AC-11. `test4_pick` (`-liveReset`, Next ×3, Swap, "Goblet Squat, Dumbbell, 52.5 lb" → `buttons["Goblet Squat"]`, "Dumbbell", "Add note" (the pick's "no pill" clause runs in `test7_pill`, which has history; verifier F1); Swap lists "Dumbbell
Romanian Deadlift, Dumbbells, 52.5 lb" and no Goblet row; dismiss; relaunch keeps Goblet Squat; log and rate its three sets skipping rests, Next exercise → summary "Legs" and a "Goblet
Squat" record, no deadlift; Done → Home lists Goblet Squat; Program tab card shows "Goblet Squat") → AC-12. `test5_swapMidRest` (`-liveReset -liveStage rdlRated -liveRest 60`: tap "7" →
Swap → Leg Extension → "Next: Leg Extension · set 1" within 1 s; the "Rest" element's value still counting) → AC-13. `test6_exitAfterSwap` (`-liveReset`: Next ×4 → Swap lists Triceps
Pushdown and Dumbbell Skullcrusher; pick Pushdown; Exit → Discard → Home "Triceps Pushdown"; Start workout, Next ×4 → name "Triceps Pushdown", Swap lists "Dumbbell Curl, Dumbbells, 27.5 lb")
→ AC-14. `test7_pill` (`-liveReset -liveHistory`: label "Up 10 lb from your last Lat Pulldown"; left drag set 1 → weight − twice → pill still; "Save & log set", "7" → no label `BEGINSWITH "Up "`; then, same launch (AC-12 pill clause, verifier F1): "Skip rest" (the rating started a 75 s rest whose card hides the bar; as in `test3_swapEnabled`; verifier round 2 finding 1) → Next exercise ×3 → label "Up 2.5 lb from your last Dumbbell Romanian Deadlift" present → Swap → `buttons["Goblet Squat, Dumbbell, 52.5 lb"]` (the candidate row's full accessibility label, as in `test4_pick`; round 2 finding 2) → no label `BEGINSWITH "Up "` (goblet's last top 52.5 equals the new target, spec 5.2; if `-liveHistory` rows differ from the `midProgram` recipe, recompute both expected labels from spec 5.2 before asserting))
→ AC-15. `test8_a11y` (`-liveReset -liveHistory`: `buttons["Lat Pulldown"]`, `buttons["Swap"]`, `buttons["Add note"]`, `textViews["Notes"]` in the sheet, the empty line as a static text; during a
rest no "Next exercise ›" and no "Add note") → AC-16 (hints and spoken order stay manual).
```
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe 2>/dev/null; rm -rf "$SP/tools.xcresult"
xcodebuild test -project "$SP/tools/HomeGymLog.xcodeproj" -scheme HomeGymLog -destination "$DEST" -derivedDataPath "$SP/tools-dd" -parallel-testing-enabled NO \
  -resultBundlePath "$SP/tools.xcresult" -only-testing:HomeGymLogUITests/ToolsLiveUITests 2>&1 | grep -E "✘|error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)"
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe; xcrun simctl uninstall "$UDID" com.zhabskyi.probe.uitests.xctrunner; git diff --quiet -- HomeGymLog.xcodeproj && echo pbxproj-untouched
```
Run in the foreground (timeout 600000) and poll to completion. A failing check is reported with its log line, not fixed in the copy.

### Step 13 — Acceptance sweep
```
source build/tools-env.sh
grep -rn 'workoutAdjustPreview' HomeGymLog; grep -rn 'ModelContext(' HomeGymLog/Models | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//';   # code lines only (verifier F4); expect StoreCommit.swift only
 grep -rn 'TextField(' HomeGymLog/Features/Workout; grep -rniI benchmark HomeGymLog/; head -1 HomeGymLog/App/DebugSeed/*.swift
RELEASE; TEST; COUNT
xcodebuild -scheme HomeGymLog -destination "$DEST26" -derivedDataPath build/DerivedData test 2>&1 | grep -E "✘|TEST (SUCCEEDED|FAILED)"
BOOT $UDID; APPEAR $UDID dark; for s in midProgram restDay freshProgram; do LAUNCH $UDID -seed $s; SHOT $UDID now-$s; cmp build/shot-base-$s.png build/shot-now-$s.png; done
LAUNCH $UDID -seed missed -tab program -programWeek 2 -programDay 2; SHOT $UDID now-missed; cmp build/shot-base-missed.png build/shot-now-missed.png
BOOT $UDID26; APPEAR $UDID26 dark; LAUNCH $UDID26 -seed wo-detail; SHOT $UDID26 detail-26; LAUNCH $UDID26 -seed wo-swap-rdl; SHOT $UDID26 rdl-26; BOOT $UDID
```
Expected: the first grep prints nothing; the second prints only `HomeGymLog/Models/StoreCommit.swift`; no `TextField(` in the workout feature; no "benchmark"; every `DebugSeed` file starts `#if DEBUG`;
Release and both test runs succeed; the four `cmp`s identical (a byte difference is read side by side; only a visible one fails); the 26.5 shots read (inset, scaled sheets; never assert widths).
Then set this plan's and the spec's status lines (with Step 12's per-test results). **Skill:** `wo-detail 570×300 @ (1890, 350)` and `wo-swap 570×300 @ (1890, 640)` join row C in
`.claude/skills/design-compare/SKILL.md`, and the workout-seed list gains the four names; the implementer lists this in its report and the main session edits the skill. New bites go to
`insights/gotchas.md` (implementer rule 7); the addendum's suggested gotcha entry is the doc-writer's.

## 4. Data model changes
**None.** `ExerciseNote` (`exerciseKey`, `text`, `updatedAt: Date`), `LoggedExercise.swappedFromKey: String?`, `LoggedExercise.targetWeightLb` (lb), `LoggedSet.weightLb` (lb) and
`PlannedSession.exercises: [PlannedExercise]` (embedded Codable; `targetWeightLb` lb) all exist; the slice writes them only. No relationship, delete rule or migration. New `#Predicate`:
`finishedTops`' one-hop `flatMap` (researcher-verified), covered by `FinishedTopsTests` on iPhone 15 / iOS 17.5 (Step 6) and on 26.5 (Step 13); every writer's persistence and failed-save tests
run on both. Invariant kept: one `ExerciseNote` per key (fetch-then-insert; the rehearsal row is deleted before the real insert). `SchemaSourceTests` unchanged.

## 5. Risks and gotchas
- **26.5 failed insert stays in same-context fetches** (gotcha 2026-09-13, addendum P1) → the rehearsal on the insert branch; `ExerciseNoteSaveTests` fetch all notes in the same turn on both runtimes.
- **26.5 refetch returns an unsaved array after restore-then-rollback** (gotcha 2026-09-14) → reassign after rollback; `SwapCommitRollbackTests` refetches in the writing context (fact 12).
- **Container released early crashes 26.5** → every new suite holds its containers (`withExtendedLifetime`, `TestStore`, `defer`).
- **"Updates never rehearse" has no runtime signal** (a refusing store fails both shapes identically; `didSave` hooks unprobed, NB12) → the Step 4 static token-order test plus review.
- **`.task(id:)` pill fetch on a stale or deleted row** → id nil while `isDiscarding`, guard inside, drawn only when the held key equals the displayed key; ~55 ms at program end (Patterns).
- **Sheet closure re-runs every body pass (every keystroke)** → `noteText` is a scalar read of query rows; `@State(initialValue:)` is honoured once (NB1); the draft never lives in the enum case.
- **Generic `ExerciseInfoSheet` trailing-closure ambiguity** → labelled `onDone:` in the extension; Step 10 build and `git diff --quiet` on Home/Program prove the callers are untouched.
- **`WorkoutView.body` past 80 lines** → Step 10 measures it; named fallback. **Overload confusion** (`displayedExercise(_:)` vs `(exercises:state:)`) → doc comments; both tested.
- **XCUITest lists hidden `Text`s and ignores hints** (gotchas SwiftUI) → Step 12 queries by label with `.firstMatch`; hints, spoken strings and VoiceOver order stay manual (U3).
- **Sheet geometry helper** misreads a corner or shadow → calibrated on the verified 251 pt adjust sheet in Step 0 before any new assertion; shots are read before trusting `top=`.
- **Unverified (carried, spec 4.5 / addendum):** IME and autocorrect with per-keystroke saves (AC-17, device); caret beyond six lines; Dynamic Type on 101.0 and the row formula; the rehearsal's
  saved-insert-refused-delete edge; a later successful save in a context that refused; the keystroke hitch on the phone (AC-19).
- **Tooling:** `OS=` everywhere, `BOOT` after 26.5, stale bundles removed, one `xcodebuild` at a time, clone-stuck retry, curl poll, sips crops read, no pbxproj edit, foreground builds.

## 6. Definition of done
- [ ] Steps 1–11 and 13 green on iPhone 15 / iOS 17.5; full suite green on iPhone 17 / iOS 26.5; Release builds; Step 13 greps clean; `project.pbxproj` untouched; no dependency or entitlement.
- [ ] `wo-start`, `wo-detail`, `wo-swap` match the prototype with the listed deviations; `wo-swap-rdl` reads AC-3 with the sheet top at 419 pt; `wo-swap` top at 717 pt; `wo-notes` reads "Notes ·";
      kg and light shots read; `wo-swipe`, `wo-rpe`, `wo-adjust`, `wo-rest` match with the pill (and dimmed Swap where a set is done); `summary`, `midProgram`, `missed`, `restDay`, `freshProgram` unchanged.
- [ ] Step 12 results recorded per test (or "skipped"); the skill carries the two crops (main session); plan and spec status lines set.
- [ ] **User, MVP pass (simulator or phone, production launch):** AC-9–AC-16 as written, at least every check Step 12 skipped or failed, plus AC-16's hints and VoiceOver reading order.
- [ ] **User, iPhone 14 Pro Max:** AC-17 typing feel (autocorrect, kana or emoji), AC-18 swap mid-rest, AC-19 no countdown stutter while typing.

## 7. Traceability, files, test estimate
| AC | Step | Check that fails when the AC breaks |
|---|---|---|
| 1 · 2 · 3 | 10 · 11 · 11 | `/design-compare wo-detail` · `/design-compare wo-swap` + `sheettop` 717 · `ac3-rdl` read + `sheettop` 419 |
| 4 | 9 (+11) | `/design-compare wo-start`; regression compares of wo-swipe, wo-rpe, wo-adjust, wo-rest; `cmp` summary |
| 5 · 6 · 7 | 10 · 9, 11 · 10, 11 | `ac5-notes` · `s9-kg`, `ac6-kg` · `ac7-detail-light`, `ac7-rdl-light` |
| 8 | 13 | `cmp` base vs now for midProgram, missed (Program args), restDay, freshProgram |
| 9–16 | 12 (optional), 13 (user) | `ToolsLiveUITests` test1 · test2 · test3 · test4 · test5 · test6 · test7 · test8; manual remainder in §6 |
| 17 · 18 · 19 | user, device | the spec's device checks |
| 20 · 21 · 22 | 2 | `SwapCandidatesTests` · `WorkoutFlowToolsTests` · `ProgressionPillTests` |
| 23 | 3 | `ExerciseToolsTextTests` |
| 24 · 25 | 5 | `SwapExerciseTests` · `SwapCommitRollbackTests` (writing-context refetch) |
| 26 | 1, 4 | `StoreCommitTests`, `ExerciseNoteSaveTests` (fetch all notes), `StoreCommitSourceTests` |
| 27 | 6 | `FinishedTopsTests`, `SwapContextTests` |
| 28 | 7, 8 | `DebugSeedTests.previews`, `WorkoutSeedTests`, `ToolsSeedTests`, `SeedHomeStatsTests` |
| 29 · 30 | 7, 8, 13 · 7, 13 | `SeedNameScanTests` (names + `sheetPreviewEntry`), `ClockUsageTests`, `SchemaSourceTests` unchanged · `RELEASE` |

**Files.** New app: `Models/StoreCommit`, `Engine/{SwapCandidates, ProgressionPill}`, `Shared/ExerciseToolsText`, `Features/Workout/{ProgressionPillView, ExerciseDetailSheet, SwapSheet}`.
Changed app: `Models/{WorkoutLogStore, ExerciseNoteStore, WorkoutSnapshotBuilder}`, `Engine/WorkoutFlow`, `Shared/ExerciseInfoSheet`, `App/{AppClock, HomeGymLogApp}`,
`App/DebugSeed/{DebugSeed, WorkoutSeed}`, `Features/Workout/{WorkoutView, WorkoutLoggingContent, WorkoutSheet, WorkoutHeader, WorkoutBottomBar}`. New tests: `Engine/{SwapCandidatesTests,
ProgressionPillTests, WorkoutFlowToolsTests}`, `Shared/ExerciseToolsTextTests`, `Persistence/{StoreCommitTests, ExerciseNoteSaveTests, SwapExerciseTests, SwapCommitRollbackTests,
FinishedTopsTests, SwapContextTests}`, `Seed/ToolsSeedTests`, `Static/StoreCommitSourceTests`. Changed tests: `Seed/{DebugSeedTests, WorkoutSeedTests, SeedHomeStatsTests}`,
`Static/SeedNameScanTests`. Other: plan and spec status lines, the design-compare skill (main session); `build/tools-env.sh`, `build/sheettop.swift` (gitignored). **Test estimate:** about
+50 test functions (515 → ~565) before test-writer, plus new arguments on `DebugSeedTests.parses`, `WorkoutSeedTests.seed` / `restInstants` and `SeedHomeStatsTests.stats`.

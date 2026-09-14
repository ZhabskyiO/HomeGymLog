# M3 slice 3 — Exercise tools (detail sheet with notes, swap, progression pill)

**Status: agreed 2026-09-14 (the user chose every proposed default in section 9); architecture review applied (B1–B4, NB1–NB13; `docs/reviews/m3-exercise-tools-architecture.md`); researcher addendum P1–P3 folded in; plan `docs/plans/m3-exercise-tools.md` verified (round 3 PASS). Not yet implemented.** Depends on m3-logging and m3-rest-timer (merged).
Sources: prototype markup 316–323 (header Swap, name + ⓘ button, pill), 347 (notes button), 372–399 (detail and swap sheets);
script 552–565 (`snapshot`: `wo-detail`, `wo-swap`), 712–734 (`woHasProgression`, `woProgression`, `busy`, `notesLabel`, `onNote`,
`swapOpts` and its pick); `CLAUDE.md` (no images until real assets exist); INSIGHTS ("PlannedExercise is an embedded Codable value"
2026-09-09, "Swap candidates" rule, M3 decisions 2026-09-13 and 2026-09-14, failed-save policy, Engine/Model boundary, nil-by-default
`@Entry`, "Per-key history reads"); gotchas (SwiftData, SwiftUI, 2026-09-14 entries); `docs/reviews/m3-exercise-tools-researcher.md`
("Facts the spec must state" 1–12, **binding**; its "Unverified" list is carried in 4.5). Milestone-wide decisions are in
`docs/specs/m3-logging.md` §1.1 and are not restated. Flow labels: **C2 `wo-detail`, C3 `wo-swap`**, plus the pill drawn in **B2 `wo-start`**.

**Supersedes:** m3-logging §2.10 (all four rows: Swap, "Add note", ⓘ, pill) and decision 11; the "Swap, Add note and ⓘ inert" / "no pill"
deviations in m3-logging AC-1–AC-4 and AC-23's "Swap, Add note and ⓘ are not announced as enabled"; m3-rest-timer §2.7's "Swap / Add note / ⓘ
inert, pill hidden" and AC-1's "no progression pill (slice 3); Swap and ⓘ inert". m3-rest-timer §6 "Swapped exercise" and AC-11 ("Add note"
absent while resting) stand.

---

## 1. Purpose

The exercise name (with ⓘ) and "Add note" open the exercise detail sheet: muscle · equipment, name, form cues, a Notes editor and Done,
with one persistent note per exercise key (C2 `wo-detail`). Header "Swap" opens the swap sheet listing same-muscle exercises not in this
workout, each at its computed weight; a pick rewrites the exercise and its pending sets in one save (C3 `wo-swap`). A green
"↑ +X lb from your last <name>" pill under the exercise name shows the progression over the previous top (B2 `wo-start`).

---

## 2. User-facing behavior

Styles are the prototype's CSS; a rendered snapshot wins over CSS (M2 rule). Colors are Theme tokens. All texts below are verbatim.

### 2.1 Exercise block and pill (prototype 321–323)

| Element | Content | Style |
|---|---|---|
| Name + ⓘ | The name followed by " ⓘ" is **one button** (prototype `openDetail`), wrapping, left-aligned | unchanged: 24 pt bold tracking −0.6, ⓘ 16 pt medium `mu` |
| Pill (12 pt below the equipment line, rows 16 pt below the pill) | "↑ +`delta` `unit` from your last `Name`" (5.2); shown only when 5.2 yields a delta | inline, self-sized to its text, padding 6/10, radius 8, background `success` at 14 %, text `success` 12 pt semibold, gap 6 between arrow and text |

`wo-start` reads "↑ +10 lb from your last Lat Pulldown" (the prototype's "+5 lb" is its +5/week formula; deviation, AC-4).

### 2.2 Exercise detail sheet (C2; prototype 372–388; facts 1–4)

Opened by the name/ⓘ button and by the bar's "Add note" / "Notes ·" button (prototype `openNotes = openDetail`). Same presentation as the
Home/Program info sheet (78 % detent, top radius 28, `sf`, no drag indicator, dim behind), scrolling, padding 22/20/44. It **is** the shared
info sheet's layout with a Notes section slotted in before Done (NB2: one layout, one place for the cue styling); Home and Program pass nothing
and stay unchanged.

| Element (top to bottom) | Content | Style |
|---|---|---|
| Line | "`Muscle` · `Equipment`" ("Back · Marcy · high pulley") | 12 pt `mu` |
| Name | "Lat Pulldown" | 22 pt bold, tracking −0.5, 2 pt below |
| Image slots | **Not shown** (product decision: no images until real assets exist). The prototype's three 130 pt slots with "Front / Side / Angle" captions are a listed deviation | — |
| "Form cues" | three numbered cues from the library, number in accent | 13 pt bold, 16 pt above; cues 14 pt, line height 1.4, gap 8, 8 pt below the title |
| "Notes" | title, then the editor | 13 pt bold, 16 pt above |
| Editor | multi-line text editor, min height 70, grows with content; placeholder "e.g. bench at incline notch 2, grip slightly wider" while empty; `sf2` fill, 1.5 pt `bd` border, radius 12, padding 10/12, 14 pt `tx`, 8 pt above | fact 1: a text editor with an overlay placeholder, never a vertical text field (its padding does not focus) |
| "Done" | closes the sheet | 48 pt, radius 12, accent, 15 pt bold white, 12 pt above |

**Editing.** The editor opens with the stored note for the displayed exercise key, or empty. **Every change is saved at once** as the note
for that key (fact 3: 0.4–0.8 ms per update, focus and caret survive; not debounced, because a debounce inserts an empty row on open and
loses the tail on a kill). Done, a swipe-down and a top-edge drag with the keyboard up close the sheet (fact 2); a drag on the sheet
content dismisses only the keyboard. With the keyboard up the sheet grows to nearly full height (y 69 on the iPhone 15, 62 on the iPhone
17) and Done stays visible to at least six lines (fact 1). Nothing is lost on any dismissal: the last keystroke was already saved. The
prototype's detail sheet has no Done in its `wo-detail` crop because it sits below the fold; ours scrolls the same way.

### 2.3 Bottom bar label (prototype 731; fact 5)

The bar's left button reads **"Add note"** when the displayed key has no note or its text is empty, and **"Notes ·"** (verbatim, with the
trailing middle dot) when it has non-empty text. It flips on the first keystroke's save (visible when the sheet closes) and whenever the
displayed key changes (Next exercise, swap, RPE-pending display). Both states open the detail sheet. Absent while resting (the rest card
replaces the bar, m3-rest-timer 2.2).

### 2.4 Swap (C3; prototype 317, 390–399, 734; facts 6–8, 11)

**Header "Swap"** is a button (34 pt pill, unchanged look). It is **enabled only while every set of the displayed exercise is pending**
(5.3; decision Q1 default). Disabled: 40 % opacity, not activatable, announced as dimmed. So it is enabled at the first set of each
exercise, including during the rest before that exercise's first set, and disabled once a set is done or skipped, hence always during RPE
pending. Tapping it opens the swap sheet: `sf`, top radius 28, padding 22/20 and 10 above the home indicator, height from the row count
(5.4; fact 11), dim behind.

| Element | Content | Style |
|---|---|---|
| Title | "Swap `Name`" ("Swap Lat Pulldown") | 18 pt bold |
| Subtitle | "Same muscle group, your equipment." | 13 pt `mu`, 2 pt below |
| Candidate rows (14 pt below, gap 8) | one button per candidate (5.1), library order: name (15 pt semibold) over equipment (12 pt `mu`) left; "`w` `unit`" right (14 pt semibold) | `sf2`, radius 12, padding 12/14 |
| Empty state (no candidate) | "Every `Muscle` exercise is already in this workout." (Q5 default; **not in the prototype**, whose `wo-swap` frame shows only the title and subtitle) | 13 pt `mu`, 14 pt below the subtitle |

**Pick** (one save, 4.2): the exercise's key becomes the candidate's, `swappedFromKey` records the planned key (kept across a second
swap), the target and every pending set's weight become the candidate's computed weight (reps unchanged), and the session's planned
element with the same `order` takes the new key and target (Q2 default). **The sheet closes first, then the write runs** (NB4, as Save & log
does), so a failed save never leaves the list open over unchanged rows; the block, rows, pill (recomputed for the new key), bar label and,
while resting, the card's "Next:" all show the new exercise at once (fact 6). Sets are never rewritten unless
pending (the prototype rewrites all sets; excluded by the guard). Dim tap or swipe down: nothing written. Candidates that are also in the
program's other sessions are unaffected: **only this session changes**.

### 2.5 Interplay with existing states

| Situation | Behaviour |
|---|---|
| Logging, no sheet | name/ⓘ, "Add note", Swap (if all sets pending) all work; the Active row loses its accent while any sheet is open (m3-logging 5.2 `sheetOpen`) |
| Resting (card in the inset) | name/ⓘ and Swap work above the card; the countdown keeps running behind the sheet (fact 3: no re-render disturbs the editor); a swap at set 1 updates "Next: `Name` · set 1"; "Add note" is unreachable (bar out of the tree) |
| RPE pending | name/ⓘ and "Add note" work; Swap disabled (a set is done); "Next exercise ›" stays disabled |
| Adjust sheet open | nothing else is tappable (one sheet at a time, 4.4); Swap, ⓘ and the bar are under the sheet |
| Next exercise | as before; the new displayed key drives the label, pill and Swap state |
| Exit → Discard after a swap | the log goes; the planned element stays swapped (Q2 default): Home's Today card and the Program card show the new exercise at its new target; a fresh start creates the log from the swapped plan with `swappedFromKey` nil. **Never stale** (NB9): the shell is unmounted while the workout shows, and both cards read `session.exercises` in their body from query rows that re-fetch on every save; only Home's finished-log values hang on the fingerprint, which stays log-only by design |
| Summary and Done after a swap | volume, muscle chip, record row and Home's PR credit the **stored key** (the new exercise); `swappedFromKey` is informational (M4 history) |
| Kill while typing | the text up to the last keystroke is stored (fact 3); the relaunch opens the workout with the sheet closed (presentation is not stored) |
| Kill right after a pick | the swap was one save: the relaunch shows the new exercise |
| Unit kg | candidate weights and the pill delta use the kg one-decimal text ("23.8 kg", "+4.5 kg") |

---

## 3. States and transitions

| Presentation (one optional sheet, 4.4) | Opened by | Closed by |
|---|---|---|
| `.adjust` (existing) | left swipe / "Adjust set" | Save & log, Skip set, dismiss |
| **`.detail(key)`** | name/ⓘ button, "Add note" / "Notes ·" | Done, swipe down, top-edge drag with keyboard up |
| **`.swap`** | header Swap (enabled) | a pick (the sheet closes, then the save runs; NB4), dismiss |

| From | Trigger | Write (one save) | To |
|---|---|---|---|
| Logging / RPE pending | name/ⓘ or bar button | — (the stored note is read) | detail sheet |
| Detail sheet | each text change | note `text`, `updatedAt = clock.now()` (insert on the first change for a key) | detail sheet (open) |
| Detail sheet | Done / dismiss | — | previous state, label per 2.3 |
| Logging (all sets of the displayed exercise pending) | Swap | — (candidates computed) | swap sheet |
| Swap sheet | pick | exercise key, `swappedFromKey`, target, pending sets' weight, planned element | Logging, same position, new key |
| Swap sheet | dismiss | — | Logging, unchanged |

**Resume after kill:** as m3-logging §3; the note text is whatever was last saved; a swap is either fully stored or not at all. **First run,
empty states:** a workout is unreachable without a program; an exercise with no note shows the placeholder and "Add note"; a key with no
candidates shows the empty-state line; a key with no previous top shows no pill. **Backgrounded with the editor open:** nothing to do; the
text is already saved; on return the sheet and keyboard are where they were.

---

## 4. Data

### 4.1 Read

| Reader | Source |
|---|---|
| Workout screen (existing) | its `LoggedExercise` / `LoggedSet` queries (`exerciseKey`, `targetWeightLb`, set `weightLb` lb, `status`); the log's session read at the action for `week`, `phase`, and its program's `startingWeightsLb` (lb) for candidates |
| Bar label | **the screen owns a query on every `ExerciseNote`** (`exerciseKey`, `text`; ≤ 18 rows), filtered in the body by the displayed key and non-empty text (fact 5) |
| Detail sheet | the displayed key's note text taken from the screen's `ExerciseNote` query rows (`notes.first { key }?.text ?? ""`, a scalar read; not a store fetch, which the sheet closure would repeat per keystroke, NB1), seeding the sheet's draft once when it opens (fact 3) |
| Pill baseline | **per-key fetch on the main context** in a task keyed on `isDiscarding ? nil : displayedKey` (fact 9; NB5: no fetch starts while Exit deletes rows, the notifier task's shape): `LoggedExercise` rows with `exerciseKey == key` whose workout is finished, then kept only when the workout's session's program id is the current program's (filtered in Swift); each row → (`finishedAt`, top done weight lb). ~55 ms at program end on 17.5, never the full `bestsBefore` traversal, never a model actor made from the view. The screen holds (key, tops) and draws the pill only when the held key equals the displayed key, so a key change never shows the previous key's pill |
| Candidates | `ExerciseLibrary` (muscle, kind, default weight), the log's current keys, session week and phase, `Program.startingWeightsLb` |
| Static | library names, equipment strings, cues; `units`; `clock.now()` |

### 4.2 Written (one guarded function per action, one save each; timestamps = `clock.now()` at the action)

| Action | Function and guard | Fields |
|---|---|---|
| Note change | `ExerciseNoteStore.save(text:forExerciseKey:updatedAt:in:)` (existing signature): update the key's row, else insert (the insert branch rehearses first, below) | `text` (the full editor text, including ""), `updatedAt` |
| Swap pick | **new** `WorkoutLogStore.swapExercise(_ exercise:, to key:, targetWeightLb:, in:) -> Bool`: returns false and writes nothing unless the key is in the library, differs from the current key, no other exercise of the log has it, and every set of the exercise is pending | `exerciseKey = key`; `swappedFromKey = swappedFromKey ?? oldKey` (cleared to nil when `key` equals the planned key, Q3 default); `targetWeightLb`; each pending set's `weightLb = targetWeightLb`; the session's `exercises[i]` with `order == exercise.order`: `exerciseKey`, `targetWeightLb` (in place; detected and saved, fact 6); **no element with that `order` (or no session) → a log-only swap that still returns true** (NB8). The target is passed in from the candidate (NB13: always loadable, no Engine call inside a writer). No timestamp field exists for a swap |

**Failed-save policy** (INSIGHTS 2026-09-13 as generalized by the review, B1: **insert writers rehearse; field writers restore their snapshot
then `rollback()`**). `swapExercise` is a field writer: it snapshots the exercise's three fields, the pending sets' weights and the whole
planned array; on a failed save it restores them, calls `rollback()`, **then reassigns the planned array snapshot again after the rollback**
(on 26.5 a refetch in the writing context otherwise returns the unsaved array), then rethrows; the screen asserts in Debug and stays derived
from rows. The note **update** branch is a field writer: restore `text` and `updatedAt`, `rollback()`, rethrow. The note **insert** branch
(the fetch found no row for the key) **rehearses in a scratch `ModelContext` on the same container** (insert + save, delete + save), then
inserts for real in the writing context: a refusing store throws in the scratch context before the writing context changes, so the screen's
`ExerciseNote` query never holds a ghost row (on 26.5 an in-place undo of a failed insert leaves the row in that context's fetches, and on
17.5 `rollback()` with an insert pending crashes; gotchas 2026-09-13). Updates never rehearse. **Cost:** the first keystroke per key performs
three saves (two rehearsal, one real): measured 2.8–3.5 ms on 17.5 and 20.4–20.5 ms on the 26.5 simulator (researcher addendum P3), once per
key; every later keystroke is one update under 1.2 ms. The rehearsal never shows a row in the screen's query before the real save and leaves
exactly one row (P3, both runtimes). **Accepted edge**, as for `start`: a rehearsal insert saved but its delete refused leaves the typed text stored, which the
next keystroke's fetch-then-update absorbs. `commit(_:revert:)` and the rehearsal helper move out of `WorkoutLogStore` into
`Models/StoreCommit.swift` (NB3), two callers each (`start` / the note insert; the set writers / the note update and swap). **U1 answered
(researcher addendum P1): no in-place undo is acceptable**: with nothing in the catch the unsaved row drives "Notes ·" and reopens in the
editor (both runtimes); an in-place `delete` keeps the query clean but on 26.5 a same-turn fetch of all notes still returns it. The rehearsal
stays; with a refusing store it runs on every keystroke and leaves the writing context untouched each time. **Schema: no change** (`ExerciseNote`,
`LoggedExercise.swappedFromKey`, `PlannedExercise` all exist); no `-units`/preferences change.

**Stored:** note text and `updatedAt`; the swapped key, `swappedFromKey`, target, pending weights, the planned element. **Derived, never
stored:** candidates and their weights, the pill (baseline, delta, text), the bar label, Swap enabled, sheet heights, kg text.

### 4.3 Engine values and seams (plain values; text in Shared; nothing traps)

| Item | Shape |
|---|---|
| `SwapCandidate` | `exerciseKey: String`, `targetWeightLb: Double` |
| `SwapCandidates.candidates(for key:, keysInWorkout: [String], week:, phase:, startingWeightsLb:) -> [SwapCandidate]` | 5.1; **non-throwing** (B2: Engine rules over stored rows are total; `week` was validated at generation): `week < 2` computes as week 1 because `WeightFormula.baseTenths` returns the start for it; unknown `key` → `[]`; library order |
| `WorkoutFlow.canSwap(_ exercise: WorkoutExerciseValue) -> Bool` | true iff every set is pending (an exercise with no sets → true) |
| `WorkoutFlow.displayedExercise(exercises:state:) -> WorkoutExerciseValue?` | the focus set's exercise value from the sorted input (nil in summary or out of range), beside `focusSet`; the one lookup the screen (label, pill, preview, Swap state) and the logging content share (B3) |
| `FinishedExerciseTop` | `finishedAt: Date`, `topWeightLb: Double` (one per finished appearance of a key in the current program) |
| `ProgressionPill.previousTops(_ tops: [FinishedExerciseTop]) -> PreviousTops` | `best` = max `topWeightLb`, `last` = the `topWeightLb` of the latest `finishedAt` (ties: the larger weight); both nil for `[]` |
| `ProgressionPill.delta(currentLb:, previousLb:) -> Double?` | `current − previous` when previous exists and current > previous, else nil |
| Shared `ExerciseToolsText` | `pill(deltaLb:unit:name:)` → "+10 lb from your last Lat Pulldown" (the "↑" is drawn beside it); `pillSpoken(deltaLb:unit:name:)` → "Up 10 lb from your last Lat Pulldown"; `swapTitle(name:)` → "Swap Lat Pulldown"; `swapSubtitle`; `emptySwap(muscle:)`; `noteLabel(hasNote:)` → "Add note" / "Notes ·"; `noteAccessibilityLabel(hasNote:)` → "Add note" / "Notes" (the dot is decoration; matches the visible text for Voice Control, B4); `noteAccessibilityHint = "Edit your note"`; `nameHint = "Shows form cues and notes"`; `notePlaceholder`; `candidateWeight(lb:unit:)` → "52.5 lb" / "23.8 kg" |
| Model-side mapping (`WorkoutSnapshotBuilder`) | `finishedTops(key:programID:in:) throws -> [FinishedExerciseTop]` (the per-key fetch, 4.1); `swapContext(of log:)` → (week, phase, startingWeightsLb, keys in the log) read at the tap |

Proposed files: `Engine/SwapCandidates.swift`, `Engine/ProgressionPill.swift` (+ `canSwap`, `displayedExercise` in `WorkoutFlow`),
`Shared/ExerciseToolsText.swift`; `Shared/ExerciseInfoSheet.swift` gains an optional trailing view-builder slot (default empty) that the workout
fills with the Notes section (NB2; no separate detail-sheet layout); `Features/Workout/SwapSheet.swift`, `ProgressionPillView.swift`, and
`WorkoutSheetContent` in `WorkoutSheet.swift` (4.4); `Models/StoreCommit.swift` (NB3); the store and builder additions; the seed stages.

### 4.4 Presentation and DEBUG delivery

`WorkoutSheet` gains `.detail(exerciseKey: String)` and `.swap(SwapDraft)` (`exerciseID`, `exerciseKey`, `candidates`, computed at the tap);
ids: `"adjust-<setID>"`, `"detail-<key>"`, `"swap-<exerciseID>"` (the id type becomes `String`). The note draft is state inside the detail
sheet, seeded once (never inside the enum case: a changing item re-presents the sheet, fact 3). The exit dialog flag is unchanged.
**What leaves the screen (B3, small-views rule):** the whole sheet content becomes `WorkoutSheetContent(item:unit:onSaveAndLog:onSkipSet:
onNoteChange:onPick:)` in `WorkoutSheet.swift`, carrying each case's presentation modifiers (adjust `.height(251)`, detail `.fraction(0.78)`,
swap `.height(n)` per 5.4), so the screen keeps one line; the preview open is one `openPreview(_:exercises:state:)` handler; the displayed
exercise comes from `WorkoutFlow.displayedExercise(exercises:state:)`, shared with the logging content. The pill baseline stays on the screen.

**DEBUG:** the Bool `workoutAdjustPreview` is **generalized** into one nil-by-default `@Entry` `workoutSheetPreview: WorkoutSheetPreview?`
(production enum `adjust`, `detail`, `swap` beside `WorkoutSheet`; nil = normal), set only in the root's `#if DEBUG` seed branch (NB11: the
`@Entry` in `App/AppClock.swift` line 36 is replaced; `App/HomeGymLogApp.swift` lines 17, 32, 44, 61, 81, `App/DebugSeed/DebugSeed.swift`'s
`workoutAdjustPreview` property and `HomeGymLogTests/Seed/DebugSeedTests.swift` lines 68–69 change with it); on first appearance the screen opens
the matching sheet on the displayed exercise (adjust: the Active set, as today). `-seed wo-adjust` keeps working. Seeds (all on `midProgram`,
frozen Tue 2026-09-15 12:00, in-memory, store functions only, silent notifier, no `-tab`):

| Seed | Rows (session 11 started at now − 754 = 11:47:26) | Preview | Shows |
|---|---|---|---|
| **`wo-detail`** | as `wo-start` (15 pending); no note | `.detail` | detail sheet on Lat Pulldown, placeholder in the editor |
| **`wo-swap`** | as `wo-start` | `.swap` | "Swap Lat Pulldown", **0 candidates**, empty-state line (the prototype's own frame is empty) |
| **`wo-swap-rdl`** | E1–E3 done RPE 7: set *k* (1…9) logged and rated at `startedAt + 70·k`; last rating 11:57:56 → rest ended 11:59:11, 49 s before now (stale) | `.swap` | "Exercise 4 of 5 · Legs", "Dumbbell Romanian Deadlift", pill "↑ +2.5 lb from your last Dumbbell Romanian Deadlift", sheet with the 5 rows of 5.1 |
| **`wo-notes`** | as `wo-start` + `ExerciseNote(latPull, "Seat notch 3, grip just outside the bend.", updatedAt: now − 86 400)` | nil | bar "Notes ·"; no snapshot (spot check) |

Names `"wo-detail"`, `"wo-swap"`, `"wo-swap-rdl"`, `"wo-notes"` join `SeedNameScanTests` (the quoted `"wo-swap"` scan does not match `"wo-swap-rdl"`).

### 4.5 Platform facts (researcher, binding) and what stays unverified

Facts 1–12 are stated in 2.2 (1, 2), 2.2/4.2 (3), 2.5 (4), 2.3/4.1 (5), 2.4/4.2 (6), 2.4/5.3 (7), 5.1/4.4 (8), 4.1/5.2 (9), 5.2 (10),
5.4 (11), AC-27/AC-29 (12: identifiers on leaf controls only; failed-save tests refetch in the writing context; coordinate taps for text
fields). **Unverified** (from the report, plus this spec's): autocorrect and IME input with per-keystroke saves (probe: manual device typing);
text beyond six lines keeping the caret above the keyboard; the automatic keyboard-dismiss mode on 26.5; Dynamic Type on the computed
sheet heights (including the 101.0 constant); the rehearsal's accepted edge (insert saved, delete refused; not producible with
`allowsSave: false`); the per-keystroke save hitch on the phone (AC-19); every spoken string (U3, device). **Resolved by the researcher
addendum (P1–P3, 17.5 and 26.5):** U1 (no in-place undo; the rehearsal stays, 4.2), U2 (the rehearsal never flashes a row into the query;
no XCUITest check required), NB10 (the 0-candidate height with the empty-state line is 101.0, 5.4).

---

## 5. Rules and formulas

### 5.1 Swap candidates (INSIGHTS "Swap candidates"; prototype `swapOpts`)

Candidates for the displayed key *k* = library exercises with the same `muscle` as *k*, in library order, excluding every key currently in
the log (all exercises' **current** keys, so a swapped-in key is excluded and the planned key of a swapped exercise becomes available). Each
weight = `WeightFormula.targetWeightLb(key:week:phase:startingWeightsLb:)` with the session's stored week and phase and the program's
starting weights (a key absent from the map, e.g. one the program never used, takes the library default; the map holds only used keys).

Muscle groups (library order): Chest dbBench, inclineDb, chestPress, pecDeck · Back latPull, lowRow, dbRow · Shoulders shoulderPress, latRaise ·
Arms curl, pushdown, skull · Legs goblet, rdl, legExt, legCurl, split, lunge. Session 11 (Pull) holds latPull, lowRow, dbRow, rdl, curl.

| Displayed key | Same muscle minus keys in the log | Count |
|---|---|---|
| latPull, lowRow, dbRow | Back = {latPull, lowRow, dbRow}, all in the log | **0** |
| rdl | goblet, legExt, legCurl, split, lunge | **5** |
| curl | pushdown, skull | **2** |

Week 3, Foundation (×100 %), starting weights = library defaults (`midProgram` passes `[:]`). Threshold test `start·10 < max·3` in tenths
(dumbbell 1575, Marcy 4500): every default below is at or above it, so the slow regime applies from week 1: no step in week 2, one step in
week 3. Rounding steps = ⌊(2·base·100 + step·100) / (2·step·100)⌋, then clamp.

| Candidate · kind (step/max tenths) | Start tenths → test | base(3) | Steps | Target lb | kg |
|---|---|---|---|---|---|
| goblet · dumbbell 25/525 | 500·10 = 5000 ≥ 1575 | 525 | (105000+2500)/5000 = 21 → 525 | **52.5** (= max) | 23.8 |
| legExt · marcy 100/1500 | 700·10 ≥ 4500 | 800 | (160000+10000)/20000 = 8 → 800 | **80** | 36.3 |
| legCurl · marcy | 500·10 ≥ 4500 | 600 | (120000+10000)/20000 = 6 → 600 | **60** | 27.2 |
| split · dumbbell | 300·10 ≥ 1575 | 325 | (65000+2500)/5000 = 13 → 325 | **32.5** | 14.7 |
| lunge · dumbbell | 300·10 ≥ 1575 | 325 | 13 → 325 | **32.5** | 14.7 |
| pushdown · marcy (for curl) | 600·10 ≥ 4500 | 700 | (140000+10000)/20000 = 7 → 700 | **70** | 31.8 |
| skull · dumbbell (for curl) | 250·10 ≥ 1575 | 275 | (55000+2500)/5000 = 11 → 275 | **27.5** | 12.5 |

The researcher's Chest check (dbBench 42.5, inclineDb 37.5, chestPress 100, pecDeck 80, shoulderPress 32.5) follows the same walk.
A `week` below 2 computes as week 1 (no throw, B2); an unknown displayed key yields `[]` (its muscle is unknown), and the sheet shows the
empty state for it (5.3).

### 5.2 Progression pill (prototype 714–715; facts 9, 10)

Baseline = the displayed key's finished appearances in the **current program** (finished logs only; the in-progress log never counts;
archived programs excluded as for Home's PRs), each reduced to its top done weight (skipped and pending sets ignored; an appearance with no
done set is dropped). `best` = the maximum top; `last` = the top of the latest `finishedAt`. **Current** = the focus set's stored weight
(Q4 default: the pending set in Logging, the set being rated in RPE pending), so an adjust with carry moves the pill. Shown iff a previous
top exists and current > it, with `delta = current − previous`; the number is the equipment-grid difference formatted like a weight
("+10 lb", "+2.5 lb", kg "+4.5 kg", "+1.1 kg"). Which previous (best or last) is Q4 (decided: last); both are computed. **kg converts the lb
difference** (NB6): 27.5 lb shows "12.5 kg" and 25 lb "11.3 kg", a visible 1.2, while the pill reads "+1.1 kg" (2.5 × 0.4536 = 1.13);
intended, since kg is display-only rounding, not a bug.

`midProgram` recipe: sessions 0–10 except 7 finished; top = target − step for index ≤ 4, target + step for index 9, else target; weeks 1–2
targets = defaults. Session *i*: day *i* % 5 (Push, Pull, Legs, Upper, Lower), date Mon 08-31 + 7·(week − 1) + weekday. Pull = sessions 1
(Tue 09-01) and 6 (Tue 09-08); Legs 2 (Wed 09-02); Upper 3 (Thu 09-03), 8 (Thu 09-10); Lower 4 (Fri 09-04), 9 (Fri 09-11).

| Key | Appearances → tops | best | last (`finishedAt` order) | Current (session 11 target) | Pill (lb) | kg |
|---|---|---|---|---|---|---|
| latPull | s1 100−10 = 90; s6 100 | 100 | 100 (s6) | 110 | "↑ +10 lb from your last Lat Pulldown" | "+4.5 kg" |
| lowRow | s1 90−10 = 80; s6 90 | 90 | 90 (s6) | 100 | "+10 lb … Seated Low Row" | "+4.5 kg" |
| dbRow | s1 42.5; s3 42.5; s6 45; s8 45 | 45 | 45 (s8) | 47.5 | "+2.5 lb … One-arm Dumbbell Row" | "+1.1 kg" |
| rdl | s1 47.5; s2 47.5; s6 50 (s7 missed) | 50 | 50 (s6) | 52.5 | "+2.5 lb … Dumbbell Romanian Deadlift" | "+1.1 kg" |
| curl | s1 22.5; s6 25 | 25 | 25 (s6) | 27.5 | "+2.5 lb … Dumbbell Curl" | "+1.1 kg" |

Best and last coincide for every session-11 key, so the user's Q4 choice does not change any seeded screen. They differ after a lighter
later session: latPull tops s1 90, s6 adjusted to 80 → best 90, last 80; at 110 the pill reads "+20 lb" (best) or "+30 lb" (last).
**After a swap in `wo-swap-rdl`:** goblet tops s2 47.5, s4 47.5, s9 52.5 → 52.5; new target 52.5 → not greater → **no pill** (likewise
legExt 60/60/80 vs 80, legCurl 40/40/60 vs 60, split 27.5/27.5/32.5 vs 32.5, lunge 27.5/32.5 vs 32.5). Curl → skull: s3 22.5, s8 25 → 25;
target 27.5 → "↑ +2.5 lb from your last Dumbbell Skullcrusher". Curl → pushdown: never trained → no pill. `wo-rpe` (focus = the done set
at 110) and `wo-adjust` / `wo-rest` (focus = set 2 at 110) all show the latPull pill.

### 5.3 Swap enabled — `WorkoutFlow.canSwap`

| Rows of the displayed exercise | canSwap |
|---|---|
| all pending (`wo-start`, exercise 4 in `wo-swap-rdl`, the exercise shown during a rest before its set 1) | **true** |
| E1S1 done (RPE nil, rated or skipped) | false |
| E1S1 skipped from the sheet | false |
| displayed exercise fully done (RPE pending on its last set) | false |
| unknown key (no muscle) | true by rows, but 0 candidates; the button is still enabled and the sheet shows the title and subtitle only (no muscle to name, so the empty-state line is omitted; the height stays 101.0). Not producible with library keys |

### 5.4 Swap sheet height (fact 11; the probed layout of 2.4)

`height(n) = n == 0 ? 101.0 : 77.33 + 64.33·n` pt: n = 0 → **101.0** with the empty-state line (71.33 + 14 + 15.67; one line for every
muscle name including "Shoulders", both runtimes; researcher addendum P2, NB10),
1 → 141.67, 2 → 206.0 (curl), 3 → 270.33, 4 → 334.67, 5 → 399.0 (rdl). A fixed detent from the count, never `.medium` (419 pt whatever n)
and never a measured detent (a 12–21 ms frame at the fallback height). Recompute the constants if the row layout changes.

---

## 6. Edge cases

| Case | Behaviour |
|---|---|
| Swap after a set is done or skipped | Button disabled; the store guard also refuses (double-tap, stale sheet), so a done weight is never credited to another key |
| Second swap of the same exercise | Allowed while all sets pending; `swappedFromKey` keeps the planned key; candidates now include the planned key (not in the log) |
| Swap back to the planned key | `swappedFromKey` → nil, planned element restored (Q3 default) |
| Swap while resting at set 1 | Rest unchanged (key-independent `restSeconds`); "Next: `New name` · set 1" at once; the notification is untouched |
| Swap, then Next exercise | Skips the swapped exercise's pending sets as usual |
| Swap, then Exit → Discard | Log deleted; planned element stays swapped (Q2); Home Today card and Program card show the new exercise and target (never stale: shell unmounted, cards read the session rows in body, NB9); a new start has `swappedFromKey` nil |
| No planned element with the exercise's `order` (not producible) | Log-only swap, returns true (NB8) |
| Swap, then Done | Summary and Home credit the stored key; the muscle chip is the same group by construction |
| Candidate's target above the equipment max | Clamped by the formula (goblet 52.5) |
| Starting weight for a candidate never used by the program | Library default (the map holds used keys only) |
| Missed session started (week 2 stored) | Candidates use the stored week 2 and phase, never today's week |
| Empty note text after typing | Stored as "" (Q6 default: the row stays; label "Add note") |
| Whitespace-only note | Non-empty → "Notes ·" (prototype truthiness; no trimming) |
| Note for a swapped-in key | Keyed by the displayed (new) key; the planned key's note is untouched |
| Same note key across workouts and programs | One row per key, program-independent, survives restart (archive) |
| Kill mid-typing / after a pick | 2.5 |
| Pill while the baseline loads (~55 ms) | Hidden; never the previous key's pill |
| Pill after adjust below the previous top | Hidden (current ≤ previous); reappears when a later set's focus weight exceeds it |
| Pill with an unknown key, no program, no history | Hidden |
| Failed save on a note update / swap | Fields restored (swap: array reassigned after rollback), Debug asserts, rows unchanged on screen |
| Failed save on the first note insert | The rehearsal throws first; nothing changes in the writing context, no ghost row in the notes query (4.2, B1) |
| Long candidate name (Dumbbell Romanian Deadlift) | Wraps inside the row; the weight keeps its width |
| Week / month boundary, unit switching | Nothing date-based; kg is display-only everywhere |
| Detail sheet on 26.5 | Inset and scaled until the keyboard shows (fact 1); never assert sheet widths |

---

## 7. Out of scope

Exercise images (no assets); notes on the Home/Program info sheets (Q7 default: unchanged); swapping from the Program tab or Home; swapping a
non-pending exercise or rewriting done sets; a swap history screen or "swapped" badge (M4 history may read `swappedFromKey`); editing
finished workouts; schema versioning (M5); haptics; autocorrect/IME verification (device, unverified); Settings.

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, dark; workout seeds need no `-tab`; crops from the fresh render: `wo-detail` 570×300 @ (1890, 350),
`wo-swap` 570×300 @ (1890, 640), `wo-start` 600×300 @ (930, 740); record the two new offsets in the skill):

1. **`wo-detail` (C2)**, `-seed wo-detail`: matches by `/design-compare`. Must show the sheet over the dimmed rows: "Back · Marcy · high pulley", "Lat Pulldown", "Form cues" 1–3 verbatim, "Notes", the placeholder, Done (scrolled into view). Deviations to skip: the three image slots and "Front / Side / Angle" (no assets); the pill visible above the sheet.
2. **`wo-swap` (C3)**, `-seed wo-swap`: matches. "Swap Lat Pulldown", "Same muscle group, your equipment.", no rows. Deviations: the empty-state line (Q5); the pill reads "+10 lb" not "+5 lb"; row 1 without accent (sheet open) as in the prototype.
3. **`wo-swap-rdl`** (no snapshot; spot check): "Exercise 4 of 5 · Legs", segments 3 `success` + accent + `sf2`, "Dumbbell Romanian Deadlift ⓘ", "Dumbbells", pill "↑ +2.5 lb from your last Dumbbell Romanian Deadlift", rows "52.5 lb × 12 reps"; sheet "Swap Dumbbell Romanian Deadlift" with Goblet Squat · Dumbbell · 52.5 lb, Leg Extension · Marcy · leg developer · 80 lb, Leg Curl · Marcy · leg developer · 60 lb, Bulgarian Split Squat · Dumbbells + bench · 32.5 lb, Dumbbell Walking Lunge · Dumbbells · 32.5 lb; sheet height 399 pt.
4. **`wo-start` (B2)**, `-seed wo-start`: matches, now **with** the pill; deviation: "+10 lb" where the prototype shows "+5 lb"; Swap is an enabled button (same look). Regression: `wo-swipe`, `wo-rpe`, `wo-adjust`, `wo-rest` match their earlier ACs plus the same pill (its deviation replaces "no pill"); on `wo-rpe`, `wo-adjust` and `wo-rest` the header Swap is drawn at 40 % because a set of exercise 1 is done (5.3; a deviation, the prototype draws it at full opacity); `summary` unchanged.
5. **`wo-notes`** (spot check): bar "Notes ·" · "Next exercise ›"; everything else as `wo-start`.
6. **kg:** `-seed wo-swap-rdl -units kg`: rows "23.8 kg × 12 reps", pill "↑ +1.1 kg …", candidates 23.8 · 36.3 · 27.2 · 14.7 · 14.7 kg. `-seed wo-start -units kg`: "↑ +4.5 kg from your last Lat Pulldown".
7. **Light appearance** on `wo-detail` and `wo-swap-rdl`: light tokens (editor `sf2` on `sf`, rows `sf2`); spot check.
8. **Regression:** `-seed midProgram`, `missed -tab program -programWeek 2 -programDay 2`, `restDay`, `freshProgram` unchanged.

**Behaviour** (production launch, on-disk store, live clock; the user runs these in the MVP pass; a scratch-copy XCUITest step in the plan
may cover them, as in m3-rest-timer):

9. **Notes round trip.** Start today's workout; tap "Add note" → sheet with the placeholder; type "Seat notch 3"; Done → bar reads "Notes ·"; tap the name → the text is there; clear it → Done → "Add note"; type again, kill the app mid-word, relaunch → the name opens the sheet with the text up to the last keystroke; Next exercise → "Add note"; back on Lat Pulldown in a later workout of the program → "Notes ·" with the text.
10. **Keyboard.** With the keyboard up the sheet grows and Done stays visible after six lines; a drag on the content hides only the keyboard; a top-edge drag closes the sheet; nothing typed is lost.
11. **Swap enabled state.** On exercise 1 Swap opens the empty sheet ("Every Back exercise is already in this workout."); after logging set 1, Swap is dimmed and inert (also while the RPE card shows and during the rest before set 2); on exercise 4 (after Next exercise ×3) Swap lists AC-3's five rows.
12. **Pick.** Pick Goblet Squat: header "Goblet Squat ⓘ", "Dumbbell", rows "52.5 lb × 12 reps" ×3, no pill (5.2), "Add note"; Swap again lists Dumbbell Romanian Deadlift (now a candidate) and not Goblet Squat; a kill and relaunch keep Goblet Squat. Log all three sets, finish the workout → the summary's Legs chip counts Goblet Squat and no row or record ever names the deadlift; a Goblet Squat record appears in the summary and on Home only when 52.5 lb beats its previous top (run on a program with no Goblet Squat history to see it; on `midProgram`-like data its best is already 52.5, so no record); the Program card for today shows Goblet Squat · 52.5 lb.
13. **Swap during a rest before set 1.** Rate the last set of exercise 3; while the card counts, Swap on exercise 4 → pick Leg Extension → the card reads "Next: Leg Extension · set 1" with the countdown unbroken.
14. **Exit after a swap.** In a fresh production workout, Next exercise ×4 to exercise 5 (Dumbbell Curl, all sets pending); Swap lists Triceps Pushdown and Dumbbell Skullcrusher; pick Triceps Pushdown, then Exit → Discard: Home's Today card lists Triceps Pushdown at its target (Q2); Start again shows Triceps Pushdown with Dumbbell Curl now among its candidates and no swap history.
15. **Pill.** On a workout whose exercise has a previous top: the pill shows; open the adjust sheet on set 1 and set its weight below that top: the pill is unchanged while the sheet is open (nothing stored yet), and after "Save & log set" and the rating, when the carried set 2 becomes the focus, the pill is gone; on an exercise never trained before, no pill.
16. **Accessibility** (Inspector or VoiceOver): the name/ⓘ is one button labelled "Lat Pulldown" with hint "Shows form cues and notes"; "Swap" is a button, dimmed when disabled; each candidate row is a button labelled "`Name`, `equipment`, `w` `unit`"; the empty-state line is static text; the editor is labelled "Notes" and its placeholder is not a separate element; the bar button is labelled "Add note", or "Notes" with hint "Edit your note" when a note exists (visible text "Notes ·"; the dot is decoration, so Voice Control's "Tap Notes" works, B4); the pill is one static text "Up 10 lb from your last Lat Pulldown"; "Next exercise ›" and the bar stay absent while resting (m3-rest-timer AC-11).

**Device** (the user, iPhone 14 Pro Max):

17. **Typing feel:** a 6-line note typed at speed with per-keystroke saves shows no dropped characters or caret jumps; autocorrect accepts a suggestion; kana or emoji input works (unverified on the simulator).
18. **Swap mid-rest on device:** AC-13 with a real countdown; no hitch.
19. **Per-keystroke save and the 1 Hz timeline:** typing during a live rest shows no stutter in the countdown behind the sheet.

**Unit tests** (Engine suites plain; persistence suites `@MainActor`, read back through a fresh context; forced failures on an on-disk store
reopened with `allowsSave: false`, containers bound):

20. `SwapCandidates`: the three session-11 rows of 5.1 (latPull → [], rdl → the five keys in library order with 52.5, 80, 60, 32.5, 32.5; curl → pushdown 70, skull 27.5); Chest check for dbBench with keysInWorkout = Push's five keys (dbBench, inclineDb, shoulderPress, pecDeck, latRaise) → [chestPress 100] (inclineDb and pecDeck are in the workout); a swapped-in key is excluded and the planned key offered; a starting weight in the map overrides the default; week 2 Foundation and week 4 Deload weights; `week 0` yields week 1's weights (no throw); unknown key → [].
21. `WorkoutFlow.canSwap`: the 5.3 rows; an exercise with no sets → true. `WorkoutFlow.displayedExercise`: logging(0, 0) → exercise 1's value, logging(3, 0) → exercise 4's, rpePending(0, 2) → exercise 1's, summary → nil, an out-of-range position → nil, identical with the input shuffled.
22. `ProgressionPill`: `previousTops` over the 5.2 appearances for the five keys (best = last), the divergent example (90/80), ties on `finishedAt`, `[]` → nils; `delta` for 110 vs 100 → 10, 52.5 vs 52.5 → nil, 45 vs 50 → nil, previous nil → nil.
23. `ExerciseToolsText`: pill text lb and kg (10, 2.5); `pillSpoken` "Up 10 lb from your last Lat Pulldown" and "Up 1.1 kg …"; "Swap Lat Pulldown", subtitle, `emptySwap(.back)`; `noteLabel(true/false)` → "Notes ·" / "Add note"; `noteAccessibilityLabel(true/false)` → "Notes" / "Add note"; `noteAccessibilityHint` "Edit your note"; `nameHint` "Shows form cues and notes"; candidate weight "52.5 lb" / "23.8 kg" / "80 lb" / "36.3 kg".
24. `swapExercise` on the `wo-swap-rdl` rows: rdl → goblet writes key, `swappedFromKey == "rdl"`, target 52.5, three pending weights 52.5, reps 12, the session's element 3 = goblet @ 52.5, other elements and sessions untouched (that it is one save is a code-review property of the writer, not a test expectation, NB12); a second swap goblet → legExt keeps `swappedFromKey == "rdl"`; swap back to rdl → nil and element restored; a session whose `exercises` array lacks an element with the exercise's `order` → the log changes, the array does not, returns true (NB8); returns false without writing for: a done or skipped set present (`wo-start` after `logSet`), the same key, a key already in the log (lowRow), an unknown key.
25. `swapExercise` failed save: throws; the exercise, its sets and the planned array read the originals **both on the objects and through a refetch in the writing context** (fact 12), `hasChanges` may be true; a fresh context reads the originals.
26. Note store: `save` twice for one key yields one row with the last text and `updatedAt` (the second call does not rehearse: the scratch context sees no extra save); "" is stored; two keys → two rows; failed **update** throws with `text`/`updatedAt` restored and `hasChanges == false`; failed **insert** throws from the rehearsal with zero new `ExerciseNote` rows in a same-turn fetch of **all** notes in the writing context (not only by key: the 26.5 leftover appears only there; addendum fact 6), `hasChanges == false` and no trap on both runtimes. This tests the rehearsal only (U1 was answered by the addendum).
27. `finishedTops(key:programID:)` on a fixture with the `midProgram` recipe plus an archived program at +100 lb: latPull → [(09-01, 90), (09-08, 100)]; the in-progress log excluded; the archived program excluded; pushdown → []; a duplicate key inside one log yields one entry whose top is the heaviest done set across that log's rows for the key.
28. Seeds: `wo-detail`, `wo-swap`, `wo-notes` rows equal `wo-start`'s (state logging(0, 0)); `wo-swap-rdl` → logging(3, 0), nine done sets at RPE 7 stamped 11:48:36 … 11:57:56, `restEndsAt` 11:59:11 (not resting at 12:00), `canSwap` true for exercise 4, candidates = AC-20's rdl list; `wo-notes` holds one note (latPull, the text, updatedAt Mon 09-14 12:00); `workoutSheetPreview` = `.detail` / `.swap` / `.swap` / nil / `.adjust` for `wo-adjust`, nil for every other seed; `midProgram` Home numbers unchanged.
29. Static: `SeedNameScanTests` covers the four new names (found only under `App/DebugSeed/`); `ClockUsageTests` green with the new files; `SchemaSourceTests` unchanged (no schema edit); a scan that `workoutAdjustPreview` no longer exists (replaced by `workoutSheetPreview`).
30. Release build compiles.

---

## 9. Decisions (user, 2026-09-14; recorded in INSIGHTS "2026-09-14 — M3 exercise-tools decisions")

The user chose the proposed default for every question below: 1 (a), 2 (a), 3 (a), 4 (a)(i), 5 (a), 6 all defaults, 8 (a).
Question 7 is an implementation policy, not a product choice: the architecture review decided it (B1; AC-26 tests the rehearsal; U1 was answered by the researcher addendum: keep it). Every
"Q*n* default" reference in sections 2–7 is therefore the decided behaviour.

1. **Swap after a set is done or skipped.** (a) **Disabled** (researcher; a done weight would be credited to the new key and pollute records and the pill); (b) allowed, only pending sets rewritten (done sets keep the old key's weight under the new key); (c) prototype: allowed, all sets' weights rewritten. **Default (a).**
2. **Swap scope.** (a) **Log + the planned session element** (INSIGHTS 2026-09-09; Exit keeps the plan swapped, Home/Program show it, a restart of the session has no swap history; future sessions untouched); (b) log only (Exit reverts to the plan; the Program card of a completed session shows the planned exercise while the summary credits the swapped one); (c) log + element, and Exit → Discard also restores the element. **Default (a).**
3. **Swapping back to the planned key.** (a) **Clear `swappedFromKey` and restore the element**; (b) keep `swappedFromKey` (the row is marked swapped although it matches the plan). **Default (a).**
4. **Pill baseline and wording.** (a) **"last" = most recent finished top, text "from your last <name>"** (prototype wording; the summary's records already cover bests); (b) "best" with "from your best <name>"; (c) prototype: best math with "last" wording. Current weight: (i) **the focus set's stored weight**; (ii) the exercise target; (iii) the first set (prototype). **Default (a)(i).** Current program only, hidden when no previous top or current ≤ previous.
5. **Empty candidate list.** (a) **Empty-state line "Every <Muscle> exercise is already in this workout."** (the `wo-swap` snapshot stays on Lat Pulldown; one listed deviation); (b) Swap disabled when there are no candidates (`wo-swap` then cannot match its frame); (c) prototype: an empty sheet with title and subtitle only. **Default (a).**
6. **Notes.** Empty text: (a) **store ""** (no delete path, label by non-empty text, verified); (b) delete the row. Auto-focus when opened from "Add note": (a) **no** (one tap away; auto-focus on appear is unverified on 17.5); (b) yes from "Add note" only; (c) always. Home/Program info sheets: (a) **unchanged**; (b) show the note read-only. Label: (a) **"Notes ·" verbatim**; (b) "Notes"; (c) "Edit note". **Defaults: store "", no auto-focus, sheets unchanged, verbatim.**
7. **Note-insert failure policy** (4.2). (a) **Rehearse in a scratch context (the `start` shape)**; (b) insert in place and delete before rethrow, pending the probe; (c) accept a ghost row until the next successful save. **Decided (a) by the architecture review (B1)**, stated as the general rule "insert writers rehearse; field writers restore their snapshot then `rollback()`"; the researcher addendum (P1) confirmed that no in-place undo is clean, so the rehearsal stays.
8. **Candidate order.** (a) **Library order** (prototype `Object.keys(LIB)`); (b) alphabetical by name; (c) dumbbell before Marcy. **Default (a).**

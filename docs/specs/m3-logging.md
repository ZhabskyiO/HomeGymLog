# M3 slice 1 — Workout logging (start, swipe, RPE, adjust, next exercise, exit, summary, resume)

**Status: implemented 2026-09-13 on branch `m3-logging` (plan `docs/plans/m3-logging.md`, Steps 1–14 plus ship-check fixes): 425 tests on iOS 17.5 and 26.5, Release build green, AC-1–AC-12 and AC-28–AC-41 checked. The 2.8 discarding flag is applied up front, and the 4.2 failure policy was revised at ship-check. Pending the user: AC-13–AC-23 on the simulator (including the AC-20 Exit-flash recording) and AC-24–AC-27 on the device.** Agreed 2026-09-13; architecture review applied; plan verified (round 2 PASS). Depends on M2 (merged). Sources:
prototype markup `isWorkout` / `isSummary` and script `buildWo`, `snapshot()`, `startWorkout`, `logSet`, `advance`, `pickRpe`,
`finishState`, `renderVals` workout/summary values; `CLAUDE.md`; INSIGHTS ("2026-09-13 — M3 decisions", Engine/Model boundary,
status invariants, every set written immediately, explicit deletes, nil-by-default `@Entry`, M2 Home/Program decisions); gotchas
(SwiftData, SwiftUI, Swift language, 2026-09-13); `docs/reviews/m3-logging-researcher.md` (facts 1–10 in 4.5, `rpeSkipped` addendum
in 4.6; binding); `docs/reviews/m3-logging-architecture.md` (B1–B3 and items 1–12, applied). M2 decisions (unit display, clock,
seeds, PR rule) are referenced, not restated. Flow labels: B1 `home`, **B2 `wo-start`, B3 `wo-swipe`, B4 `wo-rpe`, B6 `summary`,
C1 `wo-adjust`**, D1 `program` (new start button); B5 `wo-rest`, C2 `wo-detail`, C3 `wo-swap` belong to later slices.

---

## 1. Purpose

Start a workout from Home's Today card (today's session) or the Program tab's session card (today's or a missed session). The
full-screen workout logs set by set (swipe right → RPE or Skip → next set; swipe left → adjust sheet; "Next exercise ›"; Exit),
then a session summary whose Done completes the session. Every write is saved immediately, and everything on screen after a kill
is derived from stored rows. Covers B2, B3, B4, B6, C1 and a button added to D1.

### 1.1 Milestone-wide decisions (M3; this is the first slice)

| Decision | Detail |
|---|---|
| Slicing | Three slices, each merged before the next: **m3-logging** (this), **m3-rest-timer** (rest overlay, ring, +30s, Skip, survives background, local notification; `wo-rest`), **m3-exercise-tools** (detail sheet with notes via `ExerciseNoteStore`, swap sheet and persistence incl. `swappedFromKey`, "↑ +X from your last" pill; `wo-detail`, `wo-swap`). |
| Workout route | The workout replaces the shell at the root while the current program has an in-progress log (4.5 facts 3–5). Not a cover or overlay; seeded workout screenshots need no `-tab`. **Invariant:** while the shell is visible, no in-progress log exists on the current program (M4's missed prompt, shift and restart may rely on it). |
| Startable sessions | Pending and dated today (Home Today card, Program card), or pending and dated before today (Program card only), through one shared start function (2.1). Future, completed and skipped sessions cannot be started. |
| State from rows | Workout sub-state (logging / RPE pending / summary) is a pure function of the log's set rows (5.1). Later slices add overlays, never a stored cursor. The rest timer (slice 2) sits between an RPE pick or skip (or Skip set) and the next active set. |
| Writers | Each workout action is one `WorkoutLogStore` function that takes rows, is a guarded no-op when the row is not in the expected state, ends in one save, and never leaves an unsaved change on screen after a failed save (4.2 failure policy). `start`, `finish` and `discard`/`delete` stay the only creators, finishers and deleters of logs. Rows are found by id, never by array position (4.3). |
| Timestamps | **Every stored timestamp comes from `clock.now()` read at the moment of the action, never from a screen's cached `now`:** start (`startedAt`), log set, Save & log set, Skip set, Next exercise (`loggedAt`). Done writes the end instant (5.6), which is built from those timestamps. |
| Schema | One addition: `LoggedSet.rpeSkipped: Bool = false`, migrated automatically with no schema versioning (4.6). Versioning is deferred to M5. |
| Tab ownership | The root owns the selected tab. Done → Home, always (decision 13). Exit → tab unchanged (4.4). |
| Later-slice controls | Swap, "Add note" and ⓘ present but inert; progression pill hidden; no rest overlay (2.10). |

---

## 2. User-facing behavior

Workout and summary are full screen with no tab pill and no navigation bar. Side padding is 18 pt (summary 22 pt). Sizes are
the prototype's CSS; where a rendered snapshot disagrees, the snapshot wins (M2 rule). Colors are Theme tokens.

### 2.1 Start (decision 1)

| Entry | Shown when | Placement and style |
|---|---|---|
| Home Today card "Start workout" | Today's pending session exists (`HomeStats.todaySession`) | Existing button (m2-home 2.4), now active; **m2-home AC-8 is superseded** |
| Program tab session card "Start workout" | The selected session's `HomeStats.sessionState` (on the Program screen's `now`) is `.today` or `.missed`; never `.scheduled`, `.completed` or `.skipped`, never on the rest card | 14 pt below the last exercise row, full card width inside the card's 16 pt side padding; the card's 14 pt bottom padding follows. Home's button style: 50 pt high, radius 13, accent, "Start workout" 16 pt bold white. **Not in the prototype**: a deviation from `program`; supersedes m2-program-tab "writes nothing" (1, 4.1, 7) and amends its AC-1, AC-4 and AC-5 (AC-10, AC-11 here) |

**Tap (shared path, B3).** The card reports the session's index up to the screen that owns the session query (Home or Program),
which calls `WorkoutLogStore.start(sessionIndex:rows:at: clock.now(), in:)`. It finds the row among the query rows by index (the
first on a duplicate, via `uniquingKeysWith`), returns nil without writing when no row matches or the status is not pending, and
otherwise calls the existing `start(session:at:in:)`: log, exercises and pending sets in one save, or the session's existing log.
The root then switches to the workout with no navigation; a thrown error follows the failure policy (4.2) and the shell stays. A
**missed** session keeps its `scheduledDate`, stored `week` and `phase`; its summary meta shows the day trained with the stored week
and phase ("Tue, Sep 15 · Week 2 · Foundation"); Done does not re-date it (M4 owns shift); completing it counts toward the streak
(decision 14; 5.7).

### 2.2 Workout screen (top to bottom)

| Element | Content | Style |
|---|---|---|
| Header row | "Exit" pill left, "Swap" pill right. Center: session name, then elapsed "mm:ss" (5.5) | Pills 34 pt high, padding 0/14, radius 17, `sf`, 13 pt semibold `tx`. Name 12 pt `mu`; clock 15 pt bold, tabular digits |
| Progress bar (14 pt below) | One segment per exercise: before the displayed exercise `success`, the displayed one accent, after `sf2` | Height 3, radius 2, gap 4 |
| Exercise block (22 pt below) | "Exercise `n` of `N` · `Muscle`"; the name followed by " ⓘ"; the equipment string | 12 pt `mu`; name 24 pt bold, tracking −0.6, 4 pt below; ⓘ 16 pt `mu` medium; equipment 12.5 pt `mu`, 6 pt below |
| Progression pill | Hidden in this slice (slice 3) | — |
| Set rows (16 pt below, gap 8) | One row per set of the displayed exercise (2.3) | Radius 14, padding 14/16, gap 12, `sf`, 1.5 pt border |
| Hint (14 pt below) | "Swipe right to log · swipe left to adjust", only in Logging at exercise 1, set 1, with no sheet (5.2) | 12 pt `mu`, centered |
| RPE card (16 pt below) | Only while RPE is pending (2.5) | `sf`, radius 14, padding 14/16, 1.5 pt accent border |
| Bottom bar (pinned, 14 pt top padding) | "Add note" (inert, 2.10) and "Next exercise ›" (2.7), equal widths, gap 8 | 46 pt, radius 12, `sf`, 14 pt semibold |

The area between the header and the bottom bar scrolls vertically when taller than the screen; a vertical drag that starts on a
set row scrolls it (fact 7). Bad-data fallbacks are in section 6.

### 2.3 Set rows (prototype `woSets`)

Each row: a 26 pt number circle (12 pt bold), weight (22 pt bold, tabular), unit (12 pt `mu`), "×" (14 pt `mu`), reps (22 pt bold),
"reps" (12 pt `mu`), and a right label (12 pt `mu` medium). Weight text is `WeightDisplay.text` in the display unit.

| Row state (5.2) | Mark | Circle fill / mark color | Border | Right label |
|---|---|---|---|---|
| Done | "✓" | `success` / white | none | "RPE `n`"; "logged" while its RPE is nil (awaiting a rating or rating skipped) |
| Skipped | "–" | `sf2` / `mu` | none | "skipped" |
| Active | set number | accent / white | accent | "← →" |
| Waiting | set number | `sf2` / `mu` | none | "" |

Rows after the focus set (5.1) are drawn at 45 % opacity; all other rows at 100 %.

### 2.4 Swipe and the accessible path

Only the Active row responds. Dragging moves it horizontally, clamped to ±140 pt. Behind it a track shows `success` with
"✓ Logged" (left, opacity min(1, x/90)) while x > 0, or `warning` with "Adjust / skip" (right, opacity min(1, −x/90)) while x < 0;
both labels 13 pt bold white, padding 18. On release: past +90 the set is logged; past −90 the adjust sheet opens; otherwise the
row springs back and nothing is written. **Log set** writes the row's stored weight and reps as done, stamps logged-at and saves;
the state becomes RPE pending. **Accessibility:** the active row is one element (label "Set `n`, `w` `unit` × `r` reps") with the
custom actions "Log set" and "Adjust set", identical to the two swipes (fact 7); every other control is a plain button.

### 2.5 RPE card (B4; decision 4)

Title line: "How hard was that set?" (14 pt semibold) left and a "Skip" text button right (13 pt semibold `mu`, first-baseline
aligned, accessibility label "Skip rating"). **"Skip" is not in the prototype**: a deviation from `wo-rpe`. Below (10 pt), five equal
buttons, gap 6, padding 10/0, radius 10, `sf2`: 6 "easy", 7 "solid", 8 "hard", 9 "grind", 10 "max" (number 15 pt bold, label 9.5 pt
`mu`). A pick writes that RPE on the pending set; "Skip" stores `rpeSkipped = true`; either saves and moves on identically (5.1):
the next set becomes Active (same or next exercise), or the summary shows. Both writers do nothing unless the set is done,
`rpe == nil` and not skipped (B1), so a second tap before the redraw, or a rating after Skip, writes nothing. No rest overlay in this
slice. "Skip" is the only dismissal; while the card shows, no row is Active, the hint is hidden, and "Next exercise ›" is disabled at
40 % opacity. An unanswered card (done, RPE nil, not skipped) reappears after a kill (4.6 fact 3).

### 2.6 Adjust sheet (C1)

A bottom sheet over a 50 % black dim: `sf`, top radius 28, padding 22/20/44. Title "Adjust set `n`" (18 pt bold). Two tiles (16 pt
below, gap 10; each `sf2`, radius 14, padding 14, centered): caption "Weight · lb" (or "Weight · kg") / "Reps" (11 pt `mu`), and 8 pt
below a − button (36 pt circle on `sf`, 18 pt), the value (26 pt bold), a + button. Buttons 14 pt below, gap 8: "Skip set" (flex 1,
48 pt, radius 12, `sf2`, 15 pt semibold `tx`) and "Save & log set" (flex 2, accent, 15 pt bold white). The sheet edits a draft (set
id, weight, reps; 4.4); nothing is stored until a button is tapped.

| Control | Effect |
|---|---|
| Opening | Draft = the Active set's id, stored weight and reps |
| Weight − / + | `EquipmentKind.stepped(lb:by: ∓1)`: one equipment step in pounds whatever the display unit; nil at the equipment minimum or maximum → no change (5.3). In kg the value is the one-decimal kg text of the pound value |
| Reps − / + | − is `max(1, reps − 1)`; + has no upper bound (prototype) |
| Save & log set (decision 5) | Writes the draft's weight and reps to this set (done, logged-at) **and to the sets of this exercise with `order` greater than this set's and status pending** (weight and reps only; they stay pending), in the same single save → RPE pending. Sets already done or skipped, and other exercises, are never touched |
| Skip set | Writes the draft's weight and reps to this set only, as skipped, logged-at, no RPE (prototype `logSet(adj.w, adj.r, true)`); save → next state (5.1), no RPE card |
| Dim tap / swipe down | Closes without writing; the set stays Active with unchanged values |

**Worked example (`wo-start`):** a latPull sheet on set 1, + weight (110 → 120), − reps (12 → 11), "Save & log set". Row 1 becomes
"120 lb × 11 reps" ✓ "logged" with the RPE card; rows 2–3 read "120 lb × 11 reps", still pending. A later sheet on set 2 opens at
120 × 11. A swipe-right log never carries anything.

### 2.7 Next exercise ›

Marks every still-pending set of the displayed exercise skipped with logged-at, in one save. The next exercise's first set becomes
Active; on the last exercise the summary shows (prototype `skipExercise`; decision 3). Disabled while RPE is pending; the store
function also does nothing while any set of that exercise is done with `rpe == nil` and not skipped.

### 2.8 Exit

Calls `WorkoutLogStore.discard(_:in:)` (delete the log with its exercises and sets, then save). The session stays pending, and the
root shows the shell on the tab that was selected: Home, or Program for a start from the Program card, where the M2 selection
reset shows today's week, not the missed card. When at least one set is done or skipped, a confirmation comes first (decision 2):
title "Discard workout?", message "Logged sets will be deleted.", buttons "Discard" (destructive) and "Cancel"; with no set logged,
Exit is immediate. **Summary-flash check:** after the delete the screen's queries return no rows, which 5.1 maps to Summary, so one
frame of "SESSION COMPLETE" could render before the root removes the screen. The plan records an Exit on iOS 17.5 (AC-20); if a
summary frame appears, the screen marks itself discarding before the store call and renders only the background while set.

### 2.9 Summary screen (B6)

Shown in the Summary state (5.1). It scrolls; "Done" is pinned at the bottom (52 pt, radius 14, accent, 16 pt bold white,
padding 18/40).

| Element | Content (5.4, 5.6) | Style |
|---|---|---|
| Kicker | "SESSION COMPLETE" | 12 pt accent bold, uppercase, tracking 0.6 |
| Title | Session name | 34 pt bold, tracking −1.2, 6 pt below |
| Meta | "`EEE, MMM d` · Week `w` · `Phase`": the day of the log's start (decision 12), plus the session's stored week and phase | 14 pt `mu` |
| Tiles (22 pt below, 2 columns, gap 8) | Volume as an integer with grouping ("12,270"), caption "lb total volume" / "kg total volume". Duration "mm:ss", caption "duration" | `sf`, radius 16, padding 16; value 30 pt bold, tracking −1; caption 12 pt `mu` |
| Muscles card (10 pt below) | "Muscles worked", then chips in exercise order, wrapping | `sf`, radius 16, padding 16; chips `sf2`, radius 8, padding 6/10, 13 pt semibold, gap 6 |
| Records card (at least one record) | "PERSONAL RECORDS", then one row per record: name left; "`prev` `unit` → **`w` `unit`**" right ("—" when there is no previous best) | 135° gradient accent 28 %→8 %, 1.5 pt accent-50 % border; rows 14 pt, tabular |
| No-records card (no record) | "No new records today." (decision 7) | `sf`, radius 16, padding 14/16, 13 pt `mu` |

Neither records card shows until the PR baseline is built (4.1), so "No new records today." never flashes. **Done** is a handler the
root passes in (item 2): it sets the selected tab to Home first, then calls `WorkoutLogStore.finish(log, at: end instant)` (5.6). The
session becomes completed and the root shows the shell already on Home with the updated tiles (AC-21, AC-22).

### 2.10 Controls owned by later slices (decision 11)

| Control | This slice | Owner |
|---|---|---|
| Header "Swap" | Present, tap inert, not announced as an enabled button | m3-exercise-tools |
| "Add note" | Present, inert, label always "Add note" (the "Notes ·" variant comes later) | m3-exercise-tools |
| ⓘ after the exercise name | Glyph shown, name tap inert | m3-exercise-tools (`wo-detail`) |
| "↑ +X from your last …" pill | Hidden | m3-exercise-tools |
| Rest overlay between sets | Absent: an RPE pick, RPE skip or Skip set goes straight to the next set | m3-rest-timer |

---

## 3. States and transitions

| Root route | Shown when |
|---|---|
| Onboarding | no current program (M2) |
| Shell | current program, and no in-progress log attached to one of its sessions |
| **Workout** | an in-progress log attached to a current-program session exists; the earliest `startedAt` wins; the screen is keyed on the log id |
| Store error | the on-disk store fails to open (existing: `fatalError` in Debug, `StoreErrorView` in Release; 4.6 fact 1) |

| Workout state (derived, 5.1) | Presentation possible (4.4) |
|---|---|
| Logging(exercise, set) | drag on the Active row; adjust sheet; exit confirmation |
| RPE pending(exercise, set) | exit confirmation |
| Summary | none |

| From | Trigger | Write (one save) | To |
|---|---|---|---|
| Shell · Home Today card | Start workout | shared start: log + exercises + pending sets (nil, no write, unless pending) | Workout · Logging(0, 0) |
| Shell · Program card (today or missed) | Start workout | same shared start | Workout · Logging(0, 0) |
| Logging | swipe right past 90 / "Log set" action | set done, logged-at | RPE pending |
| Logging | swipe left past 90 / "Adjust set" action | — | adjust sheet (draft) |
| Adjust sheet | Save & log set | this set: weight, reps, done, logged-at; pending sets of this exercise with greater `order`: weight, reps | RPE pending |
| Adjust sheet | Skip set | this set only: weight, reps, skipped, logged-at | Logging(next) or Summary |
| Adjust sheet | dim tap / swipe down | — | Logging (same set) |
| RPE pending | pick 6–10 | set RPE | Logging(next) or Summary |
| RPE pending | Skip | set `rpeSkipped` | Logging(next) or Summary |
| Logging | Next exercise › | pending sets of the exercise → skipped | Logging(next exercise, first set) or Summary |
| Logging / RPE pending | Exit (confirmed if anything was logged) | `discard`: delete log, exercises, sets | Shell, tab unchanged |
| Summary | Done | tab := Home, then `finish`: `finishedAt`, session completed | Shell · Home |

**Resume after kill** (on-disk store): the relaunch opens the workout directly with no shell frame (fact 3), in the state 5.1
derives from the rows. An unanswered RPE card reappears; a skipped rating stays skipped. Presentation is gone: an open sheet is closed
with the set still Active, a mid-drag wrote nothing, a pending confirmation disappears. The clock shows real time since `startedAt`.
A kill on the summary reopens the summary with identical numbers (fact 6), and Done still lands on Home; a kill after Done opens the
shell. **Background:** nothing is written; the clock is correct on return. **First run:** a workout is never reachable without a
program. **Empty log** (a session with no exercises, not producible by the generator) → Summary.

---

## 4. Data

### 4.1 Read

| Reader | Source and fields |
|---|---|
| Root | Existing current-program query. **In-progress log query** (fact 3): `finishedAt == nil`, has a session, that session's program has `archivedAt == nil`; sorted by `startedAt`; first row wins |
| Home and Program (start) | Their existing `PlannedSession` query rows (sorted by index) and `now` (display only). The card passes `onStart(index)` up to the query owner, which calls the shared start (2.1) with `clock.now()`. The doc comments in `ProgramView.swift` and `ProgramContent.swift` saying the Program tab never writes must change (it writes only through the shared start), as must the "inert until M3" comment on Home's button |
| Workout screen | The log: `id`, `startedAt`. Immutable session fields read once: `name`, `week`, `phaseRaw` (fallbacks in 6). **Own live queries** (fact 1): `LoggedExercise` of this log sorted by `order` (`id`, `order`, `exerciseKey`, `targetWeightLb` lb); `LoggedSet` of those exercises sorted by `order` (`id`, `order`, `weightLb` lb, `reps`, `statusRaw`, `rpe` 6–10 or nil, `rpeSkipped`, `loggedAt`, owning exercise id). Rows map to Engine values while rendering, safe because the query owner re-renders on every save (gotcha 2026-09-13); rows for writes are looked up by id (4.3) |
| PR baseline (summary) | The current program's completed sessions and finished logs (`HomeSnapshotBuilder.sessionSummaries` / `finishedLogs`) → `HomeStats.personalRecords` → key → weight. **Built lazily** in a task keyed on "state is summary", the first time the state becomes Summary, and held as an optional; never at mount (≈ 0.4 s of traversal at program end on 17.5, exactly when swiping starts), never per render. No `HomeStatsInput` validation: `personalRecords` already tolerates duplicate indexes, so no Release fallback is needed. **Invariant:** the baseline cannot change while a workout is open (the shell and every start button are hidden, finished sets are never edited in v1, archive is unreachable, no sync); CloudKit sync or editing a finished workout would break it |
| Static / preferences / clock | `ExerciseLibrary` (name, muscle, equipment, `kind`); `units`; app clock `now()`, `calendar` |

### 4.2 Written (model layer)

Every function takes rows, performs its writes and ends in `try context.save()`; timestamps are the `at:` argument, always
`clock.now()` read at the action (1.1). **Failure policy (item 6, revised at ship-check 2026-09-13):** no unsaved change is ever shown as
logged. Field writers (log, save & log, skip set, set/skip RPE, next exercise, finish) snapshot the fields they change, restore
them on a failed save, then `rollback()` and rethrow (rollback alone keeps edited values). `discard` deletes and saves in the
writing context and rethrows; on failure its deletes stay pending, the root already shows the shell, and the next successful save
completes the discard. `start` first saves and removes the same graph in a scratch `ModelContext` on the same container, so a
store that refuses the write throws before the writing context changes (on iOS 26.5 a failed insert cannot be undone in place;
the one exception to "all writers on `mainContext`", INSIGHTS). `rollback()` is never called with an insert or delete pending. The
view calls `assertionFailure` (as `OnboardingView.startProgram` does); the screen stays derived from rows and is never blank in
Release.

| Action | Rows and fields | Function and guard |
|---|---|---|
| Start (shared) | Finds the `PlannedSession` in the query rows by `index`; then the existing `start`: `WorkoutLog(startedAt:)` linked to the session, per planned exercise a `LoggedExercise(order, exerciseKey, targetWeightLb)`, `session.sets` × `LoggedSet(order, weightLb: target, reps: session.reps, pending)` (`rpeSkipped` false by default). `scheduledDate`, `week`, `phaseRaw`, `statusRaw` untouched | new `WorkoutLogStore.start(sessionIndex:rows:at:in:) -> WorkoutLog?`: nil, no write, when no row matches or the status is not pending; else the existing `start(session:at:in:)`, which returns the session's existing log if any |
| Log set (swipe / action) | `status = done`, `loggedAt` (weight, reps, RPE fields unchanged) | new; no-op unless the set is pending (a double commit cannot overwrite) |
| Save & log set | this set: draft `weightLb`, `reps`, `status = done`, `loggedAt`; the sets of this exercise with `order` greater than this set's and status pending: draft `weightLb`, `reps` | new; no-op unless the set is pending |
| Skip set | this set only: draft `weightLb`, `reps`, `status = skipped`, `loggedAt` | new; no-op unless the set is pending |
| Set RPE | `rpe` only | new; throws `invalidRPE(Int)` outside 6…10 without writing; **no-op unless `status == done && rpe == nil && !rpeSkipped`** (B1) |
| Skip RPE | `rpeSkipped = true` | new; **same guard as Set RPE** (B1): a second Skip writes and saves nothing |
| Next exercise | every pending set of the `LoggedExercise` → `skipped`, `loggedAt` | new; no-op while any set of that exercise is done with `rpe == nil` and not skipped (keeps the prefix invariant in the store) |
| Exit | delete sets, exercises, log | new `WorkoutLogStore.discard(_:in:)`: the existing `delete`, then save |
| Done | `finishedAt = end instant`; `session.status = completed` (`scheduledDate` untouched) | existing `WorkoutLogStore.finish` |

**Stored:** `startedAt`, `finishedAt`, and each set's weight (lb), reps, status, RPE, `rpeSkipped` and logged-at. **Derived, never
stored:** state and position, row states, progress bar, hint, start-button visibility, elapsed, volume, duration, muscles, records,
end instant, kg text. **Schema:** one addition, `LoggedSet.rpeSkipped: Bool = false`, migrated automatically (4.6).

### 4.3 Engine values and file layout (plain, no SwiftData/SwiftUI; text lives in Shared)

| Value | Fields |
|---|---|
| `WorkoutSetValue` | `id: UUID`, `order`, `weightLb`, `reps`, `status: SetStatus`, `rpe: Int?`, `rpeSkipped: Bool`, `loggedAt: Date?` |
| `WorkoutExerciseValue` | `id: UUID`, `order`, `exerciseKey`, `targetWeightLb`, `sets: [WorkoutSetValue]` |
| `WorkoutState` | `.logging(exercise: Int, set: Int)`, `.rpePending(exercise: Int, set: Int)`, `.summary`; 0-based positions in the Engine's sorted arrays |
| `SetRowState` | `.done(rpe: Int?)` (nil when awaiting or skipped), `.skipped`, `.active`, `.waiting`, plus `dimmed: Bool` |
| `WorkoutSummaryValue` | `volumeLb`, `endedAt: Date`, `durationSeconds`, `muscles: [MuscleGroup]`, `records: [SummaryRecord]` |
| `SummaryRecord` | `exerciseKey`, `previousBestLb: Double?`, `weightLb` |

**Row identity (B2).** The Engine sorts exercises and sets by `order`, then `id.uuidString`, so ties are deterministic. A position from
`WorkoutState` is used only to read the value's `id`; the screen finds the row in a map built from its query rows with
`Dictionary(_, uniquingKeysWith:)` (never `uniqueKeysWithValues`, which traps on duplicates). The adjust draft carries the set's id;
store functions receive the row. `UUID` is Foundation, so the Engine stays free of SwiftData. React analogy: key by id, never by index.

**Engine functions.** `WorkoutFlow.isStartable(_ state: WeekStripState) -> Bool` is true only for `.today` and `.missed` (applied to
`HomeStats.sessionState`). The weight stepper is `EquipmentKind.stepped(lb:by:)` itself; only the reps floor `max(1, reps − 1)` needs a
home in `WorkoutFlow`. Engine functions never throw or trap; every dictionary built from data (sets by exercise, rows by id,
`bestsBefore`) uses `uniquingKeysWith` or `Dictionary(grouping:)`; no validator is needed because 5.1 is total.

**Proposed files (item 12).** `Engine/WorkoutFlow.swift` (state, row states, hint, reps floor, `isStartable`) and
`Engine/WorkoutSummary.swift`; a row-mapping helper in `Models/` (maps, never validates) plus the `WorkoutLogStore` additions;
`Shared/WorkoutText.swift` (clock, volume grouping, record row, RPE labels, accessibility label) and a small wrapping-chip `Layout` in
`Shared/` (one caller is acceptable). `Features/Workout/`: `WorkoutView` (owns queries, presentation state, the baseline task and the
handlers; switches between logging and summary), `WorkoutLoggingContent`, `WorkoutHeader` (with `WorkoutElapsedClock` and the progress
segments), `SetSwipeRow` and `SetRow`, `RPECard`, `AdjustSheet`, `WorkoutBottomBar`, `WorkoutSummaryView` (tiles, muscles, records cards).

### 4.4 Tab selection, presentation state and DEBUG delivery

**Tabs.** Selection moves from the shell into the root and is passed down as a binding (fact 4); the shell remounts after every
workout, so Home and Program `@State` reset and re-derive on appear (Program re-applies `-programWeek`/`-programDay`, else follows
today). **`initialTab` (item 1)** is applied by the root behind a one-time `@State` flag (≈ a `useRef` "has run" flag): a modifier on
the root's `if`/`else` would run again on every route switch, and `-seed summary -tab program` would then land on Program after
Done. `ShellView`'s own `onAppear` application of `initialTab` is removed. **Done (item 2):** the root passes the workout screen an
`onDone` handler that writes `selectedTab = .home` before calling `finish`, so the shell never mounts on the old tab for a frame. The
`@Query<Program>` router and the `.id(program.id)` keys stay. **M4 note:** restart → onboarding would reopen the new shell on the old
tab, so the restart path must reset the tab to Home.

**Presentation (item 4).** The workout screen holds one optional `WorkoutSheet`, an `Identifiable` enum (≈ one modal union instead
of several `isOpen` booleans): `.adjust(AdjustDraft)` with `setID`, `weightLb`, `reps` in this slice; `.detail` and `.swap` join it in
m3-exercise-tools. The exit confirmation is a separate `isConfirmingExit` flag (a dialog, not a sheet; Exit cannot be tapped while the
sheet covers it). The drag offset is state inside the swipe row. The discarding flag (2.8) exists only if AC-20 shows a flash.

**DEBUG.** The Program start button needs no new path: `-seed midProgram -tab program` shows the today card,
`-seed missed -tab program -programWeek 2 -programDay 2` the missed card. Seed-only workout states use two new nil-by-default
environment values, set only inside the app root's existing `#if DEBUG` block from the parsed seed (views contain no `#if`; Release
never sets them): `workoutDragPreview: CGFloat?` (72 for `wo-swipe`, applied to the Active row as `drag ?? preview ?? 0`) and
`workoutAdjustPreview: Bool?` (true for `wo-adjust`: on first appearance the screen sets `sheet = .adjust(draft of the Active set)`).

### 4.5 Platform facts (researcher, binding; verified on iOS 17.5 and 26.5)

1. The workout screen owns `@Query<LoggedExercise>` (`$0.workout?.id == logID`) and `@Query<LoggedSet>` (`set.exercise.flatMap { exerciseIDs.contains($0.id) } == true`), both sorted by `order`. It never re-renders from rows it only traversed and turned into values (shape a0 is stale on 17.5).
2. No predicate uses two `?.` hops: they compile, then crash at fetch on 17.5 and 26.5. Two-level conditions use nested `flatMap`.
3. Routing: the root switches on `@Query<WorkoutLog>` with the nested-`flatMap` predicate (in progress, has a session, program not archived). The workout replaces the shell and is not a cover, because `fullScreenCover` shows about 50 ms of shell at launch.
4. `selectedTab` moves from the shell into the root and is passed down as a `Binding`; otherwise it resets to Home after every workout. Home and Program `@State` still reset, because the shell is unmounted.
5. Orphan and archived-program in-progress logs are ignored by routing and left in the store (decision 9).
6. The summary shows whenever the log has no pending set, derived from rows (5.1 adds: and the last logged set is not awaiting RPE). A kill on the summary reopens the workout route, because `finish` has not been written yet.
7. Swipe: `DragGesture(minimumDistance: 20)` via `.gesture`, clamp ±140, commit past ±90, `spring(duration: 0.25)` back, plus `accessibilityAction(named:)` for "Log set" and "Adjust set". A minimum below 15 breaks scrolling on iOS 18 and later.
8. `-seed wo-swipe` uses a nil-by-default `@Entry var workoutDragPreview: CGFloat?`, applied as `dragX ?? preview ?? 0`, checked by screenshot because accessibility frames ignore `.offset`.
9. Clock: `TimelineView(.periodic(from: startedAt, by: 1))` reading `clock.now()`, formatted `%02d:%02d` with minutes allowed past 59. Seeds set `startedAt = frozenNow − 754` to render 12:34.
10. Each commit calls `try context.save()` synchronously in the gesture handler. A device hitch check is in the manual acceptance steps (AC-24).

### 4.6 Schema change and migration (researcher addendum, binding; iOS 17.5 and 26.5, real on-disk store, builds installed over each other)

1. **The field** is exactly `var rpeSkipped: Bool = false` on `LoggedSet`, doc comment "True when the RPE prompt was dismissed without choosing a value." **The default is mandatory:** without it, opening the existing store throws `SwiftDataError.loadIssueModelContainer` ("SwiftDataError error 1") and leaves the store intact; the app turns that into its existing `fatalError` in Debug and `StoreErrorView` in Release. `LoggedSet.rpe`'s doc comment ("nil until chosen or if skipped") becomes: 6–10; nil until chosen, when the rating was skipped (`rpeSkipped`), or when the set was skipped.
2. **No `VersionedSchema` or `SchemaMigrationPlan` in M3**; `AppSchema.makeContainer` is unchanged. Automatic lightweight migration of the unversioned on-disk store was verified: every existing row reads `false`, in-progress sets stay intact and writable, writes survive a relaunch. Versioning (an `AppSchemaV1` frozen copy of the shipped models plus a plan; **the copy must include `rpeSkipped`**, since that is what ships) is deferred to M5 or the first change that cannot migrate automatically (INSIGHTS; section 7); that shape was verified to open both an old and an already-upgraded unversioned store. The field meets the CloudKit rules (a default, no unique attribute, not a relationship).
3. **Three RPE states per done set:** `rpe` set → "RPE `n`"; `rpeSkipped == true` → "logged", no card; neither → "logged" with the RPE card. "Neither" on relaunch means the app was killed on the prompt, so the card reappears on resume (decision 4, 5.1). Both set is not producible, because both RPE writers require `rpe == nil` and not skipped (B1); if found, `rpe` wins and no card shows.
4. **Predicates** such as `$0.rpeSkipped == false`, alone or combined with `statusRaw` (compared to a local `let doneRaw`), compile and fetch correctly on both runtimes. The workout needs none (its state is derived in the Engine); stores may use them.
5. Persistence test: AC-41. Device install over M2: AC-27.

---

## 5. Rules and formulas

### 5.1 Workout state — `WorkoutFlow.state(exercises:) -> WorkoutState`

Sort exercises and their sets by (`order`, `id.uuidString`). **S** = all sets in (exercise, set) order; **p** = the first set in S
with status pending; **q** = the set immediately before p in S, or the last set of S when p is nil (no q when p is S's first set or S
is empty). Result: `.rpePending(q)` if q exists, is done, has `rpe == nil` and **`rpeSkipped == false`**; else `.logging(p)` if p
exists; else `.summary`. The **focus set** is q in RPE pending and p in Logging; the **displayed exercise** is the focus set's
exercise. The guarded writers keep non-pending sets a prefix of S, with only its last set possibly awaiting RPE; the rule is total,
so rows that break that invariant still yield exactly one state and never trap. Positions come from sequence order, not `loggedAt`
(seeds use a frozen clock, so timestamps tie).

Worked walks (`midProgram` session 11: 5 exercises × 3 sets; E*e*S*s* is 1-based; "nil" = RPE nil and not skipped):

| Rows | p | q | State |
|---|---|---|---|
| all pending (`wo-start`, `wo-swipe`) | E1S1 | — | logging(0, 0) |
| E1S1 done, RPE nil (`wo-rpe`) | E1S2 | E1S1 done nil | rpePending(0, 0) |
| E1S1 done RPE 7 (`wo-adjust`) | E1S2 | E1S1 done 7 | logging(0, 1) |
| **E1S1 done, RPE skipped** | E1S2 | E1S1 done, skipped rating | logging(0, 1) |
| E1S1–S3 done, S3 RPE nil | E2S1 | E1S3 done nil | rpePending(0, 2): exercise 1 still shown |
| E1S1 done 7, then Next exercise (S2, S3 skipped) | E2S1 | E1S3 skipped | logging(1, 0) |
| E1–E4 done 7; E5S1 done 7; E5S2 skipped | E5S3 | E5S2 skipped | logging(4, 2) |
| all 15 done RPE 7 (`summary`) | — | E5S3 done 7 | summary |
| all done, E5S3 RPE nil | — | E5S3 done nil | rpePending(4, 2) |
| **all done 7 except E5S3 done, RPE skipped** | — | E5S3 done, skipped rating | summary |
| E5S3 skipped by Next exercise, rest done 7 | — | E5S3 skipped | summary |
| no exercises | — | — | summary |

### 5.2 Row states, hint, progress

For the displayed exercise's set *i*: done → `.done(rpe)` (label "RPE `n`", or "logged" when `rpe` is nil, awaiting or skipped);
skipped → `.skipped`; *i* is the focus set in Logging and no sheet is open → `.active`; otherwise `.waiting`. `dimmed` = *i* > focus
set index. Hint iff logging(0, 0) and no sheet. Progress segment *k*: *k* < displayed → `success`; *k* = displayed → accent; else `sf2`.

| State | Row 1 | Row 2 | Row 3 | Hint |
|---|---|---|---|---|
| `wo-start` | active | waiting, dimmed | waiting, dimmed | yes |
| `wo-rpe` | done(nil) "logged" | waiting, dimmed | waiting, dimmed | no |
| `wo-adjust` (sheet open) | done(7) "RPE 7" | waiting (sheet removes active) | waiting, dimmed | no |
| E1S1 RPE skipped | done(nil) "logged" | active | waiting, dimmed | no |

### 5.3 Today's session on `midProgram`, and the adjust stepper

Session 11 from the code: frequency 5 → week = 11 / 5 + 1 = **3**; `PhaseSplit.phaseOf(3, 24)`: remaining 23, Foundation =
(23·35 + 99)/100 = 9 weeks → **Foundation** (3 × 12, rest 75 s, ×100 %); split day 11 % 5 = 1 → **Pull**; 45 min → first 5 keys;
date = Mon 08-31 + 7·2 + weekday 1 = **Tue 2026-09-15**. Targets from `WeightFormula.baseTenths`: threshold test `start×10 < max×3`
in tenths (Marcy 1500·3 = 4500, dumbbell 525·3 = 1575); every start below is at or above its threshold, so the slow regime applies
from week 1 and the base walk adds nothing in week 2 ((2−1) % 2 = 1) and one step in week 3 ((3−1) % 2 = 0). Rounding: steps =
⌊(2·base·100 + step·100) / (2·step·100)⌋.

| # | Key · name · muscle · equipment | Kind (step/min/max lb) | Start tenths → test | base(3) | Round | Target | kg |
|---|---|---|---|---|---|---|---|
| 1 | latPull · Lat Pulldown · Back · Marcy · high pulley | marcy 10/10/150 | 1000·10 = 10000 ≥ 4500 | 1100 | (220000+10000)/20000 = 11 | **110** | 49.9 |
| 2 | lowRow · Seated Low Row · Back · Marcy · low pulley | marcy | 900·10 ≥ 4500 | 1000 | (200000+10000)/20000 = 10 | **100** | 45.4 |
| 3 | dbRow · One-arm Dumbbell Row · Back · Dumbbell + bench | dumbbell 2.5/5/52.5 | 450·10 = 4500 ≥ 1575 | 475 | (95000+2500)/5000 = 19 | **47.5** | 21.5 |
| 4 | rdl · Dumbbell Romanian Deadlift · Legs · Dumbbells | dumbbell | 500·10 ≥ 1575 | 525 | (105000+2500)/5000 = 21 | **52.5** (= max) | 23.8 |
| 5 | curl · Dumbbell Curl · Arms · Dumbbells | dumbbell | 250·10 = 2500 ≥ 1575 | 275 | (55000+2500)/5000 = 11 | **27.5** | 12.5 |

Each exercise has 3 rows of target × 12 reps; the header reads "Pull" and "Exercise 1 of 5 · Back". **Stepper**
(`EquipmentKind.stepped(lb:by:)`, nil at a bound = no change; reps floor `max(1, reps − 1)`). Values move the draft only; a save
carries them per 2.6:

| Sheet on | − | + | Bound case | kg text of −/value/+ |
|---|---|---|---|---|
| latPull 110 | 100 | 120 | 150 then + no-op; 10 then − no-op | 45.4 / 49.9 / 54.4; 150 → "68" |
| dbRow 47.5 | 45 | 50 | + twice → 52.5, then no-op | 20.4 / 21.5 / 22.7 |
| rdl 52.5 | 50 | no-op (max) | — | 22.7 / 23.8 / 23.8 |
| curl 5 (after 9 −) | no-op (min) | 7.5 | — | "2.3" at 5 |
| reps 12 / 1 | 11 / no-op | 13 / 2 | no maximum | — |

### 5.4 Volume, muscles, records — `WorkoutSummary.make(exercises:startedAt:bestsBefore:)`

Volume = Σ weight × reps over done sets (as `HomeStats.volumeLb`; a skipped rating does not affect it). Top = the maximum done
weight per exercise (nil when none is done). Muscles = the library muscle of each exercise with a top and a known key, first
appearance, exercise order. `bestsBefore` = key → weight from `HomeStats.personalRecords` over the current program's completed
sessions and finished logs, including sessions dated after this one (this log is unfinished, so excluded), built with
`uniquingKeysWith`. **Record** (decision 8): for each exercise with a top, in order, no prior best or top > prior best (strict; a tie
is not a record). A key appearing twice in one log yields one record at its first position with the larger top.

`summary` seed. Prior bests from the seed recipe (top = target − step for index ≤ 4, target otherwise; weeks 1–2 targets =
defaults), matching m2-home 5.9:

| # | Key | Done sets (lb × reps) | Volume | Top | Prior best (sessions) | Record row |
|---|---|---|---|---|---|---|
| 1 | latPull | 120×12 + 110×12 + 110×12 | 1 440+1 320+1 320 = 4 080 | 120 | s1 90, s6 100 → 100 | Lat Pulldown · 100 lb → **120 lb** |
| 2 | lowRow | 100×12 ×3 | 3 600 | 100 | s1 80, s6 90 → 90 | Seated Low Row · 90 lb → **100 lb** |
| 3 | dbRow | 47.5×12 ×3 | 1 710 | 47.5 | s1 42.5, s3 42.5, s6 45, s8 45 → 45 | One-arm Dumbbell Row · 45 lb → **47.5 lb** |
| 4 | rdl | 52.5×12 ×3 | 1 890 | 52.5 | s1 47.5, s2 47.5, s6 50 → 50 | Dumbbell Romanian Deadlift · 50 lb → **52.5 lb** |
| 5 | curl | 27.5×12 ×3 | 990 | 27.5 | s1 22.5, s6 25 → 25 | Dumbbell Curl · 25 lb → **27.5 lb** |

Total **12 270 lb** → "12,270"; kg round(12 270 × 0.45359237 = 5 565.58) = **5 566** → "5,566". Muscles **Back, Legs, Arms**.
kg record rows: 45.4 → 54.4; 40.8 → 45.4; 20.4 → 21.5; 22.7 → 23.8; 11.3 → 12.5.

### 5.5 Elapsed clock (fact 9)

s = max(0, ⌊now − `startedAt`⌋), shown as "%02d:%02d" of (s / 60, s % 60), minutes uncapped: 0 → "00:00"; 59 → "00:59";
754 → "12:34"; 2 520 → "42:00"; 3 600 → "60:00"; 4 503 → "75:03"; now before `startedAt` → "00:00". Ticks every second on the
live clock; fixed on a frozen one.

### 5.6 End instant and duration (decision 6)

End instant = the latest `loggedAt` over non-pending sets, or `startedAt` if there is none. Duration = max(0, ⌊end − `startedAt`⌋),
formatted as in 5.5. Done passes the end instant as `finishedAt`, so stored and shown durations agree and neither drifts while the
summary is open or after a kill. Worked: the `summary` seed stamps set *k* (1…15) at `startedAt` + 168·*k* s with `startedAt` =
12:00 − 2 520 s = 11:18:00, so end = 12:00:00 and the duration is **"42:00"**. The prototype's duration is `elapsed` at the last RPE
pick or next-exercise tap, within seconds of this; the RPE pick time is not stored.

### 5.7 Starting a missed session (`missed` seed, session 7; decisions 1 and 14)

Session 7: 7 / 5 + 1 = week **2**, Foundation (≤ 9); 7 % 5 = 2 → **Legs**; date = Mon 08-31 + 7·1 + weekday 2 = **Wed 2026-09-09**;
pending and before Tue 09-15 → `.missed` → startable. Week 2 target = start (slow regime for every start, (2−1) % 2 = 1, no step),
already on the grid at ×100 %.

| # | Key · name · equipment | Start tenths → test | Target | Volume if every set at target × 12 | Prior best (m2-home 5.9) | Record |
|---|---|---|---|---|---|---|
| 1 | goblet · Goblet Squat · Dumbbell | 500·10 ≥ 1575 | 50 | 1 800 | 52.5 (s9, 09-11) | no |
| 2 | rdl · Dumbbell Romanian Deadlift · Dumbbells | 500·10 ≥ 1575 | 50 | 1 800 | 50 (s6, 09-08) | no (tie) |
| 3 | legExt · Leg Extension · Marcy · leg developer | 700·10 ≥ 4500 | 70 | 2 520 | 80 (s9) | no |
| 4 | legCurl · Leg Curl · Marcy · leg developer | 500·10 ≥ 4500 | 50 | 1 800 | 60 (s9) | no |
| 5 | split · Bulgarian Split Squat · Dumbbells + bench | 300·10 ≥ 1575 | 30 | 1 080 | 32.5 (s9) | no |

**Summary** with every set logged at target: "Legs"; "Tue, Sep 15 · Week 2 · Foundation"; **9,000** lb (kg round(4 082.33) →
"4,082"); chips **Legs**; "No new records today.". Done leaves `scheduledDate` at Wed 09-09. **Home afterwards** (still Tue 09-15):

| Home value | Before | After | Why |
|---|---|---|---|
| Streak | 3 | **11** | walk back from today: 11 (today, pending) stepped over; 10, 9, 8, **7**, 6 … 0 all completed (decision 14) |
| Sessions | 10/120 | **11/120** | one more completed |
| Week volume | 7.6k | **7.6k** | attributed by `scheduledDate`; 09-09 lies in the previous calendar week (m2-home 5.6) |
| Week strip · Today card | M ✓ · T 15 …; Pull | unchanged | 09-09 is not in this week; session 11 is still pending |
| Recent records | four from Sep 14 | unchanged | no new best; session 7's tops only move intermediate best dates |

A missed session dated in the current calendar week would add its volume to this week's tile and show ✓ in the strip. The Program
card for WK 2 · W 9 reads "Legs" · "Completed" (`success`), with a `success` dot and no button.

---

## 6. Edge cases

| Case | Behavior |
|---|---|
| Workout crosses midnight, or resumes days later | The route still shows it; the clock keeps counting ("1452:10"); the summary date is `startedAt`'s day; Home attributes volume to the session's `scheduledDate`. Week and phase are the stored ones, never recomputed. |
| Missed session started | Keeps `scheduledDate`, week and phase; the summary shows the day trained; Done counts toward the streak (5.7) and never re-dates it. Today's pending session is unaffected and stays startable. Only one workout can run: the shell, and so every start button, is hidden during a workout. |
| Stale card (screen open for hours, or a status changed underneath) | Visibility follows the screen's cached `now` (m2-program-tab 3), but the write never does: `startedAt` is `clock.now()` at the tap, and the shared start writes nothing unless the row is still pending. A "Today" card that became missed after midnight is startable either way. |
| Week / month boundary | Nothing in this slice counts weeks; the summary meta uses the stored `week` (a re-slotted or missed session keeps its program week). |
| Caps and rounding | `EquipmentKind.stepped` only produces loadable weights; a target at the maximum (rdl 52.5) makes + a no-op; a stored weight off the grid (not producible in v1) makes both weight buttons no-ops. kg text one decimal, halves away from zero; kg volume an integer; duration floored to whole seconds. |
| Carry forward | Only the sets of this exercise with `order` greater than this set's and status pending; on an exercise's last set nothing is carried; after Skip set nothing is carried; a Next-exercise skip overwrites nothing. |
| Skipped sets / skipped ratings | Skipped sets add 0 to volume and give no top; an exercise with only skipped sets gets no muscle chip and no record but still counts as passed in the progress bar (`success`). A skipped rating affects only the row label ("logged") and the RPE card. |
| Every set skipped | Summary with "0", no muscle chips (the card shows only its title), the no-records card; Done completes the session (decision 10). |
| Double commit (two swipes, a swipe and an accessibility action, two RPE taps, a rating after Skip, a second Skip) | Every writer is guarded (4.2): the second call finds the row no longer eligible and neither writes nor saves. |
| Duplicate `order` values (not producible by `start`) | The Engine breaks ties on `id.uuidString`, so state and summary are identical across fetches; writes find rows by id, so a tie never redirects a swipe to another set; carry skips a tied sibling (its `order` is not greater); no map built from rows traps. |
| Save fails | Per the 4.2 failure policy (fields restored; a failed Exit leaves its deletes pending; a failed Start changes nothing), the view asserts in Debug; in Release the screen shows the unchanged rows (the row springs back; the RPE card follows from rows); never blank. |
| Unknown exercise key (not producible by the generator) | The name shows the key; the "Exercise `n` of `N`" line omits " · `Muscle`"; the equipment line is empty; the weight steppers do nothing; the summary counts its volume but gives no muscle chip; a record row shows the key as its name. No trap, no assertion-only path. |
| `log.session == nil` (routing excludes it; defensive) | Header name empty; summary meta week 1, phase from the `phaseRaw` fallback (Foundation); Done writes `finishedAt` with no session to complete. No trap. |
| PR baseline | Cannot change while a workout is open (invariant, 4.1), so it is built lazily once when Summary first shows; neither records card renders before it exists. CloudKit sync or finished-set editing would break the invariant. |
| Exit, queries empty out | Possible one-frame "SESSION COMPLETE" flash; checked by AC-20, with the discarding-flag fallback (2.8). |
| Swapped exercise | Slice 3. This slice logs and credits the stored `exerciseKey`; `swappedFromKey` stays nil. |
| Future, completed, skipped sessions | No start button anywhere; the shared start writes nothing for a non-pending row. |
| Unit switching | Settings is unreachable during a workout. `-units kg` shows kg on every workout and summary number; storage and steps stay pounds. |
| Backgrounded | No writes, no timers to restore; on return the clock re-reads the app clock; an open sheet and its unsaved draft survive while the process lives. |
| Killed | Section 3 "Resume after kill". An unsaved draft is lost; saved sets and ratings never are (fact 10). |
| Install over an M2 build | Automatic lightweight migration (4.6): every row intact, every existing set reads `rpeSkipped` false. An M2 store holds no in-progress log (M2 had no workout UI); the in-progress case was verified on the simulator. Reinstalling an older build over the upgraded store also opens it (Xcode reinstalls only). |
| Field declared without its default (regression) | The existing store fails to open: `fatalError` in Debug, `StoreErrorView` in Release, store left intact (4.6 fact 1); caught by AC-41's source check. |
| Two in-progress logs in the current program (bug only) | The earlier `startedAt` shows; after its Done or Exit the other appears. |
| Orphan / archived-program in-progress log | Not routed, left in the store (fact 5); does not block starting a session. |
| Clock earlier than `startedAt` or `loggedAt` | Elapsed and duration clamp to 0. |
| Long exercise name / 3-digit reps | The name wraps (24 pt, line height 1.15); "100 reps" must not truncate the row. |

---

## 7. Out of scope

Slice 2: rest overlay, ring, +30s / Skip, background survival, rest notification. Slice 3: exercise detail sheet and notes, swap
sheet and swap persistence, progression pill. Starting a future, completed or skipped session; re-dating a missed session on start
or Done (M4 shift); editing a finished workout. M4: workout history on Progress, missed-day prompt and its shift/skip UI, Settings
(units, haptics, appearance), daily reminder, resetting the tab to Home on restart (4.4). M5: haptics, Live Activity, and **schema
versioning** (`AppSchemaV1` frozen copy of the shipped models including `rpeSkipped`, plus a `SchemaMigrationPlan`), unless an
earlier change cannot migrate automatically (4.6 fact 2). Not planned: HealthKit, cleanup of stray in-progress logs (decision 9).

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, dark; check = matches by `/design-compare`; workout seeds need no `-tab` because the workout
replaces the shell at the root; Program screens name their `-tab program`; workout seeds in the table after AC-41):

1. **`wo-start` (B2)**, `-seed wo-start`: matches. Deviations to skip: no "↑ +5 lb from your last Lat Pulldown" pill (slice 3); Swap, Add note and ⓘ inert (not visible). Must show: "Exit" · "Pull" / "12:34" · "Swap"; five segments (first accent); "Exercise 1 of 5 · Back"; "Lat Pulldown ⓘ"; "Marcy · high pulley"; three rows "110 lb × 12 reps", row 1 with accent border, accent "1" and "← →", rows 2–3 dimmed; the hint; "Add note" · "Next exercise ›"; no RPE card.
2. **`wo-swipe` (B3)**, `-seed wo-swipe`: matches. Row 1 shifted 72 pt right over the `success` track with "✓ Logged" at 80 % opacity; otherwise AC-1, same deviations. Checked by screenshot (fact 8).
3. **`wo-rpe` (B4)**, `-seed wo-rpe`: matches. Row 1 "✓" on `success`, no border, "logged"; rows 2–3 dimmed; no hint; RPE card 6 easy · 7 solid · 8 hard · 9 grind · 10 max. Deviations: the pill; the "Skip" text button on the card's title line (decision 4); "Next exercise ›" at 40 % opacity.
4. **`wo-adjust` (C1)**, `-seed wo-adjust`: matches. Under the dim: row 1 "RPE 7"; row 2 "2", no accent border, full opacity; row 3 dimmed. Sheet "Adjust set 2", "Weight · lb" 110, "Reps" 12, "Skip set" · "Save & log set". Deviation: the pill.
5. **`summary` (B6)**, `-seed summary`: matches. "SESSION COMPLETE"; "Pull"; "Tue, Sep 15 · Week 3 · Foundation"; "12,270" / "lb total volume"; "42:00" / "duration"; chips Back · Legs · Arms; "PERSONAL RECORDS" with the five rows of 5.4; "Done". Deviations (prototype formula): the prototype shows "12,840" and four rows (105 → 115, 95 → 100, 50 → 55, 30 → 35 lb).
6. **kg path.** `-seed wo-adjust -units kg`: rows "49.9 kg × 12 reps", sheet "Weight · kg" 49.9. `-seed summary -units kg`: "5,566" / "kg total volume" and the kg record rows of 5.4.
7. **Light appearance** on `wo-start` and `summary`: light tokens throughout (spot check, no snapshot).
8. **Home regression.** `-seed midProgram` matches m2-home AC-1 ("Start workout" looks unchanged).
9. **No shell frame.** A cold launch of `-seed wo-start` recorded with `simctl io recordVideo` shows no frame of the shell or tab pill (fact 3).
10. **`program` (D1)**, `-seed midProgram -tab program`: matches; **amends m2-program-tab AC-1**. Deviations to skip: those listed in m2-program-tab AC-1 plus the new "Start workout" button under row 5 of "Pull" · "Today" (2.1 placement). `-seed freshProgram -tab program` shows m2-program-tab AC-4 plus the button under "Upper A" · "Today" (**amends AC-4**).
11. **Missed card**, `-seed missed -tab program -programWeek 2 -programDay 2` (no snapshot; spot check): m2-program-tab AC-5's content ("Legs" · "Missed" in `warning`, rows 50 / 50 / 70 / 50 / 30 lb) plus the "Start workout" button under the Bulgarian Split Squat row (**amends AC-5**).
12. **No button** on `-seed midProgram -tab program -programWeek 3 -programDay 0` ("Push" · "Completed"), `-programDay 2` ("Legs" · "Sep 16") or `-programDay 5` (rest card). m2-program-tab AC-7, AC-8 and AC-10 stand unchanged (future or completed cards).

**Behavior** (taps are refused on this machine; the user runs AC-13–23 on the simulator or phone):

13. **Start from Home.** From `-seed midProgram`, "Start workout" opens AC-1's screen with the clock counting from 00:00; a kill and relaunch reopens it.
14. **Log and RPE.** A right swipe past 90 on row 1 shows the RPE card; tapping 7 gives row 1 "RPE 7", row 2 active, hint gone. A 60 pt swipe springs back with no change. A vertical drag starting on a row scrolls (when scrollable) and never logs, on 17.5 and 26.5.
15. **RPE skip.** On `-seed wo-rpe`, "Next exercise ›" does nothing; "Skip" gives row 1 "✓" "logged", row 2 active, no card, and a relaunch keeps that state. Skipping the rating of the last set of exercise 5 shows the summary.
16. **Adjust with carry.** On `-seed wo-start`, a left swipe opens the sheet; + weight → 120, − reps → 11, "Save & log set" → row 1 "120 lb × 11 reps" ✓ with the RPE card, rows 2–3 "120 lb × 11 reps"; after an RPE pick a sheet on set 2 opens at 120 × 11. On the rdl sheet + is a no-op; at reps 1 − is a no-op. A dim tap closes the sheet with nothing written.
17. **Skip set.** On `-seed wo-start`, a sheet set to 120 × 11 then "Skip set" → row 1 "–" "skipped" "120 lb × 11 reps", row 2 active at "110 lb × 12 reps", no RPE card.
18. **Next exercise.** After one logged set on exercise 1: rows 2–3 skipped, then "Exercise 2 of 5 · Back" / "Seated Low Row" with segment 1 `success`. On exercise 5 it shows the summary.
19. **Exit.** With nothing logged, Exit returns to Home immediately (Today card "Pull", session 11 pending). After a logged set the confirmation appears; "Cancel" keeps the workout; "Discard" returns to Home with the log gone. After a start from a missed Program card in a production launch (no `-programWeek`/`-programDay`), Exit lands on the Program tab showing **today's week** (M2 decision: selection resets on every return); with AC-11's arguments the preselection re-selects WK 2 · W 9.
20. **Exit flash** (plan-time check; the user runs it because taps are refused here). On the iPhone 15 / iOS 17.5 simulator with `xcrun simctl io <udid> recordVideo` running: from `-seed wo-start`, log one set, Exit → Discard; sampled frames show no "SESSION COMPLETE" between the workout and Home. If one appears, the discarding-flag fallback (2.8) is required and this check is repeated until it passes.
21. **Done** from `-seed summary` shows Home: tiles **4 · 11/120 · 19.8k** (streak 11, 10, 9, 8, then pending 7 stops; week volume 7 560 + 12 270 = 19 830); strip T ✓ with accent border; rest card "Recover. Next up: Legs" / "Wed, Sep 16 · 5 exercises · 3 × 12"; records 120 lb Lat Pulldown · 100 lb Seated Low Row · 47.5 lb One-arm Dumbbell Row · 52.5 lb Dumbbell Romanian Deadlift, all Sep 15. With `-seed summary -tab program`, Done still lands on Home with no frame of the Program tab (decision 13).
22. **Missed session from Program.** From AC-11's launch, "Start workout" → "Legs", "Exercise 1 of 5 · Legs", "Goblet Squat", "Dumbbell", rows "50 lb × 12 reps". Log all 15 sets at target (any RPE) → summary "Legs", "Tue, Sep 15 · Week 2 · Foundation", "9,000", chip "Legs", "No new records today." → Done → Home tiles **11 · 11/120 · 7.6k** (streak counts it, decision 14), Today card still "Pull" → Program (the launch arguments re-select WK 2 · W 9) → "Legs" · "Completed" in `success`, `success` dot, no button.
23. **Accessibility.** In the Accessibility Inspector (simulator) or with VoiceOver (device) the active row offers "Log set" and "Adjust set", each behaving as the matching swipe; "Skip rating", the RPE buttons, steppers, sheet buttons, Next exercise, Exit, Done and both "Start workout" buttons are buttons; Swap, Add note and ⓘ are not announced as enabled.

**Device** (the user, iPhone 14 Pro Max, on-disk store):

24. **Swipe feel and hitch** (fact 10): log a full 15-set workout; commits show no visible hitch, scrolling from a row works, and the summary appears without a stall while the PR baseline builds.
25. **Kill mid-workout** (a) after set 2's RPE, (b) with the RPE card showing, (c) after skipping a rating, (d) with the sheet open: each relaunch opens the workout directly on the same exercise and set; the card is back in (b) and stays gone in (c); the sheet is closed with nothing written in (d); the clock shows real elapsed time.
26. **Kill on the summary:** the relaunch shows the same numbers and duration; Done lands on Home with the session completed.
27. **Install over M2** (4.6 facts 1–2). Install this build from Xcode over the M2 build already on the phone (on-disk store): the app opens without the store error; the program, sessions, completed statuses, Home tiles and Program card are unchanged. An M2 store cannot hold an in-progress workout (the simulator verified that case); starting one afterwards, logging a set with a skipped rating, and relaunching keeps it intact.

**Unit tests** (Engine suites plain with `TestCalendar`; persistence suites `@MainActor`, in-memory, read back through a fresh `ModelContext`):

28. `WorkoutFlow.state`: the twelve walks of 5.1, identical with exercises and sets shuffled; two sets with equal `order` sort by `id.uuidString` in every input order; a broken prefix (a pending set before a done one) returns a state without trapping; a done set with both `rpe` 7 and `rpeSkipped` true is not RPE pending.
29. Row states, dimming, hint, progress: the four rows of 5.2; an open sheet removes `.active`; rpePending(0, 2) dims nothing.
30. `WorkoutSummary`: the 5.4 table (volume 12 270, tops, muscles [back, legs, arms], five records with previous bests, duration 2 520, `endedAt` = last `loggedAt`); the 5.7 table (9 000, [legs], no records); a tie is not a record; no prior best → `previousBestLb` nil; skipped and pending sets add 0; a skipped rating changes no summary value; all skipped → 0, [], []; no non-pending set → `endedAt` = `startedAt`; a `loggedAt` before `startedAt` → duration 0; an unknown key counts its volume, gives no muscle, and records under the key; duplicate keys in the `bestsBefore` input do not trap.
31. Stepper: the 5.3 stepper table through `EquipmentKind.stepped`, both kinds, both bounds; the reps floor `max(1, reps − 1)` at 12 and 1.
32. Text and fallbacks: the clock strings of 5.5; volume "12,270", "9,000", "5,566", "4,082", "0", "999"; record rows in lb, kg and with "—"; RPE labels; "logged" for a done set with a nil or skipped rating; the row accessibility label; unknown key → the key as the name and no " · `Muscle`" suffix; a mapped log with `session == nil` → empty name, "Week 1 · Foundation".
33. Stores (each change persists after one save, visible from a fresh context): Log set writes, and on a non-pending set writes nothing. Save & log set on a Build-phase fixture (4 sets), set 1 done, draft 120 × 11 on set 2 → set 2 done at 120 × 11, sets 3–4 pending at 120 × 11, set 1 and other exercises untouched; set 1 done, set 2 skipped, draft on set 3 → only set 3 changes; last set → nothing else changes; a sibling with the same `order` is not carried to. Skip set writes the draft to that set only. Set RPE writes `rpe` only; 5 and 11 throw `invalidRPE` and write nothing; **`setRPE(8)` after `setRPE(7)` writes nothing; `setRPE(7)` after `skipRPE` writes nothing** (B1). Skip RPE sets `rpeSkipped` on a done set with nil RPE; a second Skip, a pending set, a skipped set, and a done set with RPE 7 all write nothing. Next exercise touches only that exercise's pending sets and writes nothing while a set of the exercise is done with nil RPE and not skipped. `discard` deletes exactly 1 log, 5 exercises and 15 sets, saves, and leaves the session pending. Writes resolved through the id map reach the intended row with shuffled query order.
34. Start (`midProgram` data, Tue 09-15): `WorkoutFlow.isStartable(HomeStats.sessionState(…))` is true for session 11 (today) and 7 (missed), false for 10 (completed), 12 (scheduled), 7 marked skipped, 11 marked skipped, and `.rest`. `WorkoutLogStore.start(sessionIndex:rows:at:in:)` returns a log with `startedAt` = the passed date for 11 and 7; returns nil and writes nothing for 10, a skipped session, and index 999; twice for 11 returns the same log.
35. Missed session end to end (persistence, `missed` seed data, frozen Tue 09-15 12:00): shared start of session 7, log all 15 sets at target with RPE 7, finish at the end instant → session 7 completed, `scheduledDate` still Wed 2026-09-09, `week` 2; summary values per 5.7 with start date Tue 09-15; `HomeStats` streak 11, completed 11, week volume 7 560, today session 11, recent records unchanged; session 7 no longer startable.
36. Routing predicate (facts 2, 3, 5) on 17.5 and 26.5: in progress on the current program → 1; finished, orphan, archived program → 0; after `finish` → 0; after `discard` → 0; two in-progress logs → 2 sorted by `startedAt`; the fetch does not crash.
37. Workout queries: among 10 finished logs plus the in-progress one, the exercise predicate returns 5 rows and the set predicate 15, both sorted by `order`; another log's ids return 0.
38. Seeds: the five names parse, use the `midProgram` data and reference day, and hold exactly the rows of the seed table, every set with `rpeSkipped` false; `WorkoutFlow.state` on their rows gives logging(0, 0), logging(0, 0), rpePending(0, 0), logging(0, 1), summary; drag preview 72 only for `wo-swipe`; adjust preview only for `wo-adjust`; `midProgram` Home numbers unchanged (in-progress logs are not mapped).
39. Release safety: the Release build compiles, and a static scan finds the quoted strings `"wo-start"`, `"wo-swipe"`, `"wo-rpe"`, `"wo-adjust"` and `"summary"` only in files under `App/DebugSeed/` (unquoted identifiers such as `SessionSummary` or `WorkoutSummary` do not count).
40. `ClockUsageTests` passes with the new `Features/Workout`, Engine, Models and Shared files.
41. **`rpeSkipped` default** (4.6 facts 1, 5): a `LoggedSet` created with the existing initializer (no `rpeSkipped` argument), inserted and saved, reads `rpeSkipped == false` from a fresh `ModelContext`; after setting `true` and saving, a fresh context reads `true`. Plus a static source check (like `ClockUsageTests`) that `Models/LoggedSet.swift` declares `var rpeSkipped: Bool = false`, because an in-memory test cannot detect a missing default (which only breaks opening an existing on-disk store).

**Seed catalogue additions** (DEBUG only; each on `MidProgramSeed.populate` with its default completed indexes; frozen Tue
2026-09-15 12:00; in-memory store; rows written through store functions only; `rpeSkipped` false everywhere):

| Seed | On top of `midProgram` | Preview values |
|---|---|---|
| `wo-start` | `WorkoutLogStore.start(session 11, at: now − 754 s)`; 15 pending sets | — |
| `wo-swipe` | same as `wo-start` | drag 72 |
| `wo-rpe` | + E1S1 done, RPE nil, `loggedAt` = `startedAt` + 168 s | — |
| `wo-adjust` | + E1S1 done, RPE 7, `loggedAt` = `startedAt` + 168 s | adjust sheet on the Active set (E1S2) |
| `summary` | start at now − 2 520 s; all 15 sets done, reps 12, RPE 7, weight = target except E1S1 = one step above (120 lb); set *k* `loggedAt` = `startedAt` + 168·*k* s | — |

The prototype's `summary` adds "+5 lb" to the first set; on the Marcy grid that is one step (+10 lb), as
`MidProgramSeed.topWeightLb` already translates ±5. The `summary` seed starts 2 520 s back (not 754) so the duration reads the
snapshot's "42:00". The Program start button reuses the existing `midProgram`, `freshProgram` and `missed` seeds (AC-10–12).

---

## 9. Decisions (user, 2026-09-13; recorded in INSIGHTS "2026-09-13 — M3 decisions")

1. **Startable sessions:** today's pending session (Home Today card, Program card) and any missed session (Program card only), through one shared start function; the Program card button is a deviation from `program`. → 1.1, 2.1, 4.2, 5.7, 6, 7, AC-10–12, AC-22, AC-34, AC-35.
2. **Exit** confirms when at least one set is done or skipped; immediate otherwise; `WorkoutLogStore.discard`. → 2.8, 4.2, AC-19, AC-20.
3. **Next exercise** marks the exercise's remaining pending sets skipped. → 2.7, 4.2, 5.1, AC-18, AC-33.
4. **RPE skip is stored** (`LoggedSet.rpeSkipped: Bool = false`, the slice's one schema addition, migrated automatically and unversioned per the researcher addendum): "Skip" on the card is the only dismissal, "Next exercise" stays disabled, an unanswered card reappears after a kill. → 2.5, 4.2, 4.6, 5.1, 6, 7, AC-3, AC-15, AC-25, AC-27, AC-28, AC-33, AC-41.
5. **Save & log set carries** the draft's weight and reps to the sets of this exercise with `order` greater than this set's and status pending; Skip set does not. → 2.6, 3, 4.2, AC-16, AC-17, AC-33.
6. **End instant** = the latest `loggedAt`; duration and `finishedAt` both use it. → 5.6.
7. **No-records text** is "No new records today.". → 2.9.
8. **Records** use Home's rule (current program, strict, first appearance counts with "—"). → 5.4.
9. **Stray in-progress logs** (orphaned or archived program) are ignored and left in the store. → 4.5, 6.
10. **All-skipped workout** completes with 0 volume. → 6.
11. **Later-slice controls:** Swap, Add note and ⓘ present but inert; progression pill hidden; no rest overlay. → 2.10.
12. **Summary date** is the day trained (`startedAt`), with the stored week and phase. → 2.9, 5.7.
13. **Done always lands on Home**, also for a workout started from the Program card (confirmed; survives a kill on the summary); the root's `onDone` writes the tab before `finish`. Exit keeps the current tab. → 1.1, 2.9, 4.4, AC-21, AC-22, AC-26.
14. **A completed missed session counts toward the streak** (confirmed; M2 streak rule unchanged, `scheduledDate` never rewritten). → 5.7, 6, AC-22, AC-35.

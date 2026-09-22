# M4 slice 2 — Progress tab (top-weight chart, best / since start, month calendar)

**Status: done 2026-09-16, 807 tests** (807 tests on iOS 17.5 and 26.5, Release green; scratch-copy XCUITests AC-9–AC-14 6/6; swift review "ship"; VoiceOver order (AC-13) and a real finger chip scroll pending the user's device pass). Agreed 2026-09-16 (user answers §9; researcher report `docs/reviews/m4-progress-researcher.md` folded into 4.4 and 5.8, facts
binding; architecture review `docs/reviews/m4-progress-architecture.md` applied, B1–B5 and NB1–NB10, and the researcher's 2026-09-16 addendum (predicates verified, `program` hop cost, `.task` per tab return) folded into 4.1; both listed in §9). Branch `m4-progress`.
Depends on `m4-missed-day` (merged 2026-09-16); milestone-wide decisions live in `docs/specs/m4-missed-day.md` §1.1. Sources: prototype
markup `tabProgress` (216–243), script "// progress tab" (690–702) and the Home "Progress ›" link (180, `goProgress`); `CLAUDE.md`; INSIGHTS
"M2 Home architecture" (current-program scoping, `FinishedLogValue` cost), "M2 milestone-wide decisions" (restart archives, "logs and PRs
stay for Progress"), "Program.archivedAt reserved", M3 decisions (`rpeSkipped`, `restEndsAt` never read as history), "Per-key history reads",
"Date and weekday conventions", the M4 decisions; gotchas SwiftData (17.5 retention, traversal cost, predicates) and SwiftUI (`scrollTo`
deferral, tab `onAppear`). Engine and model code read for every table: `Engine/HomeStats.swift`, `ProgressionPill.swift`, `ProgramTabStats.swift`,
`CalendarRules.swift`, `WeightFormula.swift`, `Equipment.swift`, `SplitPlans.swift`, `ExerciseLibrary.swift`, `App/DebugSeed/MidProgramSeed.swift`,
`FreshProgramSeed.swift`, `Models/WorkoutSnapshotBuilder.finishedTops`, `HomeSnapshotBuilder`, `Features/Home/HomeView.swift` (the link is
already wired). Flow label: **D2 `progress`** ("Progress chart & calendar").

---

## 1. Purpose

Replace `PlaceholderScreen(tab: .progress)` with the prototype's Progress tab: exercise chips, a card with the selected exercise's best
done weight, its change since the first logged session and a line of top weights per finished workout, and a calendar of the current
month. Read-only. Covers D2 `progress`, the empty-history state (no snapshot) and the Home "Progress ›" link (already wired; AC-14).

---

## 2. User-facing behavior

Screen padding 18 pt sides, top 8, content scrolls under the tab pill; no navigation bar; Theme tokens; prototype copy verbatim. Where the
rendered `progress` snapshot disagrees with its CSS, the snapshot wins (Home rule); the frame renders far wider than a phone, so compare content.

### 2.1 Header and exercise chips (markup 217–220; 5.1)

| Element | Content | Style |
|---|---|---|
| Title | "Progress" | 28 pt bold, tracking −0.8 |
| Chip row | one chip per exercise key of 5.1, library name ("Dumbbell Bench Press" …); horizontal scroll bleeding to both edges (margin −18, padding 0 18 4), 16 pt below the title; the selected chip scrolls minimally into view on appear (`WeekChipRow` rule) | gap 6; pill radius 20, padding 8 / 12, 12.5 pt semibold, `white-space: nowrap`; selected: accent bg, white text; others: `sf` bg, `tx` text |
| Chip tap | selects that exercise: the chart card re-derives (5.2–5.4); nothing written | |

Default selection = the first chip (5.1; `dbBench` in every split, the prototype's `chartEx`). Selection is screen state only: it persists across tab switches while the shell is mounted and resets on relaunch and after a workout (§9 D1).

### 2.2 Chart card (markup 221–232; 5.2–5.4)

`sf` card, radius 16, padding 14 / 16, 14 pt below the chips.

| Element | Content | Style |
|---|---|---|
| "Best" | label, then the best top weight in the display unit + unit suffix (5.3); empty history: the planned target of the key's first session, or "—" (5.4) | 12 pt `mu`; 26 pt bold tracking −0.5, unit 12 pt `mu` medium |
| "Since start" (right, right-aligned) | last point − first point (5.3): "+5 lb", "0 lb", "−2.5 lb"; empty: "—" | 12 pt `mu`; 16 pt bold; `success` when > 0, `mu` when 0 or "—", `warning` when < 0 (prototype: always green with "+"; 5.3) |
| Chart | 120 pt tall, 10 pt below, full card width; three horizontal grid lines in `bd` (bottom solid at y 110/120, dashed 3–4 at 60 and 10); an accent 2.5 pt line through the points, round joins; a dot per point r 4, `sf` fill, accent stroke 2.5; points evenly spaced by **order** (x = 10 + i·300/(n−1) of 320; a single point sits at x 160), y from the lb domain [min − 5, max + 5] (5.2); no axis labels, no legend | |
| From / to | first and last point's day as "Aug 31" / "Sep 14" (`HomeText.shortDate`); both empty when no points | 11 pt `mu`, space-between |
| Empty line | "No sessions logged yet — your first workout starts the line." only when no points; the grid lines still draw | 13 pt `mu`, 8 pt below |

### 2.3 Calendar card (markup 233–242; 5.5)

`sf` card, radius 16, padding 14 / 16, 14 pt below the chart card. Month = the calendar month containing today; no month navigation
(the prototype has none). A cell is not a control.

| Element | Content | Style |
|---|---|---|
| Title row | "September 2026" (long month + year) left; "`N` completed" right (5.5) | 15 pt bold; 12 pt `mu` |
| Letters | M T W T F S S (`HomeText.weekStripLetters`), 12 pt below | 10.5 pt `mu`, centered |
| Grid | 7 columns, gap 4, 6 pt below the letters; `lead` blank cells (Monday-first weekday of the 1st) then one cell per day; no trailing blanks | square cells, radius 8, 12 pt; weight 700 today, else 500 |

| Cell state (5.5) | bg | text | border 1.5 |
|---|---|---|---|
| completed | `success` | white | none (today: accent) |
| today, not completed | `sf2` if a session, else clear | accent | accent |
| scheduled (pending, after today) | `sf2` | `tx` | none |
| missed (pending, before today) | `sf2` | **`warning`** (prototype: `tx`; §9 D3, recorded as a deviation on `progress`) | none |
| skipped | `sf2` | **`mu`** (prototype: `tx`; §9 D3) | none |
| no session | clear | `mu` | none |

### 2.4 Home link (markup 180; `HomeView` already passes `onProgress: { selectedTab = .progress }`)

"Progress ›" on Home's "Recent records" row selects the Progress tab (root-owned `selectedTab`; the pill highlights Progress).
Nothing else on Home changes. No new wiring; AC-14 verifies it.

### 2.5 Interplay

| Situation | Behaviour |
|---|---|
| Missed-session prompt | Never on this tab (m4-missed-day decision 1); a `-tab progress` launch may show one Home overlay frame (NB6 there) |
| Workout finished (Done → Home) | The shell remounts: chips, points and calendar re-derive from rows; the selection resets (D1) |
| Shift / skip on Home or Program | Sessions re-fetch: calendar cells follow the new dates and statuses; points never change (finished logs are never re-dated) |
| Midnight / foreground | `now` refreshes on appear, on scene-active and when the tab becomes selected (Program-tab rule): the month, "today" cell and missed states follow |

---

## 3. States and transitions

| State | Shown | Leaves by |
|---|---|---|
| Populated (`midProgram`) | chips; Best 42.5 lb · +5 lb; 3 points Aug 31 → Sep 14; September 2026 · 9 completed | chip tap → same state, other key; a finish / shift / skip → re-derive |
| Empty for the key (`freshProgram` = first run, any chip; or a key not yet trained) | Best = planned target ("40 lb") or "—"; Since start "—"; grid lines only; no from/to; the empty line | first finished log with a done set of the key |
| Resume after kill | nothing stored: chips, points, calendar and `now` re-derive; selection = the first chip (D1) | |

---

## 4. Data

### 4.1 Read (nothing is written by this screen)

| Value | Source | Derived or stored |
|---|---|---|
| Sessions (current) | the screen's `@Query` on `PlannedSession` with the existing `HomeSnapshotBuilder.sessionPredicate(programID:)`, sorted `(scheduledDate, index)` (NB7); rows map to `ProgressSession` with `programID` / `programCreatedAt` from the passed `Program` and `isArchived = false` — scalar reads, no `program` hop | stored → values |
| Archived programs | a second `@Query`, on **`Program`** with `archivedAt != nil` (≤ 1 row in v1): `id`, `createdAt`, `archivedAt` read directly. **`body` never traverses `PlannedSession.program`** (researcher addendum Q3: 322–347 µs per row on 17.5, uncached across passes, ≈ 41 ms per `body` for 120 archived rows, paid on every save while the shell is mounted; the "every `Program` pre-fetched" cheap path is unexplained and not designed on) | stored |
| Sessions (archived, completed) | fetched **inside the task below**, one `FetchDescriptor` per archived program id: the existing `sessionPredicate(programID:)` (composing it with a status clause needs `#Predicate.evaluate`, iOS 17.4), `status == .completed` filtered in Swift, sorted `(scheduledDate, index)`; program fields come from the loop's `Program` row, so the rows are scalar reads (7 µs/row). Verified predicate shapes (addendum Q1, 17.5 and 26.5): one-hop `?.` with `!= nil`, its `flatMap` twin and a one-query `\|\|` all fetch correctly and exclude orphans; only `== nil` admits orphans. Kept as a **note**: `$0.program?.archivedAt != nil && $0.statusRaw == completedRaw` is a correct single archived query if the per-id loop is ever dropped, but it puts the hop back in `body` | stored → values |
| Chip keys | `ProgressStats.exerciseKeys` over current rows + the held archived sessions (5.1), **in `body`** every render (B4: no chip task, no `@State keys`) | derived |
| The task: tops of the effective key + archived sessions | the screen's **one** `.task(id: "\(effectiveKey)\|\(fingerprint)")` on `mainContext`, `fingerprint` = `HomeSnapshotBuilder.fingerprint(of: currentRows)` + the sorted archived program ids (so an added archived program re-runs it). It (1) fetches the archived completed sessions (row above) and (2) the tops: `ProgressSnapshotBuilder.tops(key:programCreatedAt:in:)` (`programCreatedAt: [UUID: Date]` from the `Program` query) runs the **shared** `WorkoutSnapshotBuilder.finishedExercisePredicate(key:)` (extracted from `finishedTops`, no program clause; addendum Q2: returns both programs' finished logs for all 17 keys), reads `log.session` (`index`, `scheduledDate`) and `session.program?.id` **only** (159–178 µs/row, ≤ ~60 rows per key, off the render path), looks `createdAt` up by id from the archived-programs query and the current `Program`, drops rows whose log has no session or program (total), maps the sets to `LoggedExerciseValue` and calls **`HomeStats.topWeightLb`** (5.2); one entry per log (a duplicate key keeps the larger top). Result held as `@State held: (key, fingerprint, tops, archivedSessions)?`: the chart draws `tops` only while `held.key == effectiveKey`; chips and the calendar use `held.archivedSessions` whatever the key; never cleared before a re-fetch; the assignment is guarded by `Task.isCancelled` (B3). **Verified (addendum Q4, 17.5 and 26.5): `.task(id:)` restarts on every return to the tab (cancelled on disappear, `@State` kept) and not on re-tapping the selected tab**, so the fetch runs once per return (~55 ms worst on 17.5) and the held value keeps the line up. A failed fetch asserts in Debug and holds empty results. **Never** the full `finishedLogs` traversal (~0.4 s) | stored → values |
| Best, delta, labels, calendar | `ProgressStats` (4.3) over the values above, `today` = the screen's `@State now`, `calendar` = `clock.calendar` | derived |
| Unit | `@AppStorage("units")`. Never read: `restStartedAt` / `restEndsAt` (M3 invariant), `rpe`, `rpeSkipped`, in-progress logs | stored preference |

### 4.2 Written

Nothing by the screen, not even the selected chip (D1). The `progress-history` seed introduces **`ProgramStore.archive(_:at:in:)`**, the single writer of `Program.archivedAt` (NB4, the `finish` precedent): a field writer through `StoreCommit.commit` (snapshot `archivedAt`), one save, a no-op when already archived; m4-settings' restart reuses it and adds the tab reset.

### 4.3 Engine seams and text (plain values; explicit `calendar` and `today`; total: nothing throws or traps, no text)

| Item | Shape |
|---|---|
| `ProgressSession` | `programID: UUID`, `programCreatedAt: Date`, `isArchived: Bool`, `summary: SessionSummary` (B1: wraps the existing value, so `HomeStats.sessionState` and the `exercises: [PlannedExercise]` targets are there; keys = `summary.exercises.map(\.exerciseKey)`) |
| `ProgressTop` | `programID`, `programCreatedAt`, `sessionIndex`, `scheduledDate: Date` (D4), `topWeightLb: Double`. **Identity in the chart is the point's position after ordering, never `sessionIndex`** (indexes restart per program: `progress-history` has two s0; B2). No separate `ProgressPoint` (NB3) |
| `ProgressStats.exerciseKeys(sessions:) -> [String]` | 5.1 |
| `ProgressStats.points(tops:) -> [ProgressTop]` | sorted by `(scheduledDate, programCreatedAt, sessionIndex)` (5.2) |
| `ProgressStats.bestLb(points:) -> Double?` · `sinceStartLb(points:) -> Double?` | 5.3; nil for no points |
| `ProgressStats.plannedFallbackLb(key:sessions:) -> Double?` | 5.4: `summary.exercises.first { $0.exerciseKey == key }?.targetWeightLb` of the current program's lowest-index planning session |
| `ProgressStats.month(sessions:today:calendar:) -> ProgressMonth` | `year`, `month`, `leadingBlanks: Int`, `cells: [ProgressDayCell]` (`date`, `dayNumber`, `state: WeekStripState`, `isToday`), `completedCount` (5.5) |
| `ProgressStats.chartGeometry(weights:) -> ChartGeometry` | numbers only (researcher Q1): `xDomain`, `yDomain`, `baselineLb`, `midLb`, `topLb` (5.8) |
| `ProgressStats.effectiveKey(selected: String?, keys:) -> String?` | `selected` when it is in `keys`, else `keys.first`; nil for no keys; computed in `body` as `effectiveKey(selected: selectedKey ?? preselection, keys:)` (NB2) |
| `HomeStats.session(on:in:calendar:)` (NB1) | the one "which session is on this day" rule shared by `weekStrip`, `dayCells` and `month`: a completed session wins, else the lowest index (a completed + pending pair on one day is unreachable inside one program, so the strip and cells are unchanged) |
| Shared `ProgressText` (all spoken strings; labels = visible text) | `title = "Progress"`; chip label = `ExerciseLibrary` name; `best = "Best"`; `sinceStart = "Since start"`; `delta(lb:unit:)` → "+5 lb" / "0 lb" / "−2.5 lb" (U+2212) in the display unit (5.7); `none = "—"`; `empty = "No sessions logged yet — your first workout starts the line."`; `monthTitle(year:month:calendar:)` → "September 2026"; `completed(n:)` → "9 completed"; from/to = `HomeText.shortDate`; `cellValue(state:)` → "Completed" / "Today" / "Missed" / "Skipped" (the Program card's words, `ProgramTabText.status`) and "Scheduled" (D5), nil for no session; `chartSummary(name:count:minLb:maxLb:unit:)` → "Dumbbell Bench Press, 3 sessions, 37.5 to 42.5 lb" (D5: the lowest to the highest top weight, not first → last; the user chose "range"; `progress-history` reads "… 7 sessions, 30 to 45 lb"; the display unit; with no points → "Dumbbell Bench Press, no sessions logged"); `pointLabel(date:calendar:)` = `HomeText.shortDate` ("Aug 31") and `pointValue(lb:unit:)` → "37.5 lb" for each dot (4.4) |

Proposed files: `Engine/ProgressStats.swift` (+ types), `Shared/ProgressText.swift`, `Models/ProgressSnapshotBuilder.swift` (mapping, per-program
archived fetch, per-key tops), `ProgramStore.archive`, `Features/Progress/` (`ProgressTabView`, named so it never shadows SwiftUI's `ProgressView`: session + `Program` queries, `now`, selection, one task,
`selectedTab` by value; `ProgressContent`, `ExerciseChipRow`, `TopWeightChart`, `MonthCalendar`); `ShellView` routes `.progress` to it.

### 4.4 Presentation and DEBUG

**Chart (researcher Q1–Q3, verified on 17.5 and 26.5; the planner copies this recipe).** Swift Charts: one `LineMark` per point and one
`PointMark` per point plotted by **point position** `i` (`.value("Session", i)`, never by `Date`: that would space by elapsed days; `ForEach` identity is `i` too, never `sessionIndex`, B2), three
`RuleMark`s (`baselineLb` solid 1 pt, `midLb` and `topLb` dashed 3–4, all `bd`), both axes and the legend hidden, explicit
`chartXScale` / `chartYScale` domains from `ProgressStats.chartGeometry` (5.8), `.frame(height: 120)`; line accent 2.5 pt with round caps
and joins, linear interpolation; dots are a custom `symbol { }` view: `Circle` filled `sf` with an accent 2.5 pt stroke, 8 pt (hollow, r 4).
With hidden axes the plot area equals the frame on both runtimes, so the domains alone reproduce the SVG (rules at 10 / 60 / 110 of 120,
first dot 10 pt in, a single dot centred on the middle rule). Marks are **not clipped**: dots overflow like the prototype's `overflow: visible`,
and a rule outside the y domain draws outside the chart frame (80 pt in the probe), so the domain must always contain the three rules (5.8
guarantees it; tested). **Always pass explicit domains**, also for the empty chart (rules only, the empty line beneath). No `withAnimation`
(the prototype does not animate; a point-count change under animation is unprobed), no `.id` on the chart, no iOS 18 vectorized `Chart(data)` modifiers.

**Chart accessibility (researcher Q2; reconciled with D5).** Every `LineMark` and `RuleMark` carries `.accessibilityHidden(true)`;
otherwise a `PointMark`'s label is swallowed into "0 to 0.5, 40 to 40, 2 values". Each `PointMark` gets `accessibilityLabel` =
`pointLabel` ("Aug 31") and `accessibilityValue` = `pointValue` ("37.5 lb"). The chart view is a **container** (`.accessibilityElement(children:
.contain)`) labelled `chartSummary` (D5): VoiceOver reads the summary, then each dot. `children: .ignore` is not used (unverifiable by XCUITest);
whether VoiceOver stops on the container first is a device check only (AC-13, NB9). Spoken strings: the summary and the per-point pairs, all
from `ProgressText`. The Audio Graph descriptor is optional.

**Chip row (researcher Q4).** Copy `WeekChipRow`'s shape: `ScrollViewReader`, `.id(key)` per chip, `Task { @MainActor in
proxy.scrollTo(effectiveKey, anchor: nil) }` from `onAppear` only (no scroll token: the selection persists and the `ScrollView` keeps its offset while mounted, NB2); **not** `scrollPosition(id:)` (on 17.5 it scrolls an
already-visible chip to the leading edge and rewrites its binding while the user scrolls). A visible chip never moves; an off-screen one
lands flush with the trailing edge.

**Calendar (researcher Q5).** `LazyVGrid` with seven `.flexible()` columns, spacing 4, every cell `.aspectRatio(1, contentMode: .fit)`;
lead blanks = `CalendarRules.appWeekday(of: monthStart)` as `Color.clear` cells with `.accessibilityHidden(true)`; months with 6 rows
(Nov 2026, Mar 2026: 42 cells) make the card taller (the prototype's 35 is a placeholder count, not a rule). A cell is one element: label = the day number, value = `cellValue`.

**Screen state.** `@State now` (appear, scene-active, `.onChange(of: selectedTab)` → this tab; `selectedTab` arrives as a value, the
screen writes nothing, NB5), `@State selectedKey: String?`, `@State held` (key, fingerprint, tops, archived sessions) filled by the one
task of 4.1; `.id(program.id)` on the screen. Everything else is derived in `body` from scalar reads (never `row.program`): sessions → keys → `effectiveKey` → fallback, calendar,
geometry; a stale selection (a key gone after a restart or swap) falls back to the first chip without a write, and the task follows the
**effective** key, so `-progressExercise nope` shows dbBench's three points, never an empty card under a populated chip (B3).

**DEBUG.** `-progressExercise <key>` preselects a chip on a seeded launch (the `-programWeek` shape: a nil-by-default `@Entry
progressPreselection: String?`, parsed only in the root's `#if DEBUG` block, works without `-seed` like `-programWeek`, **read in `body`**
as `selectedKey ?? preselection`, no `onAppear` write (NB2); an unknown key falls back through `effectiveKey`). Seeds (in-memory, written only through store functions):

| Seed + arguments | Shows |
|---|---|
| `-seed midProgram -tab progress` (existing) | D2 `progress`: 17 chips, dbBench 37.5 · 40 · 42.5, Best 42.5 lb, +5 lb, Aug 31 → Sep 14, September 2026 · 9 completed (Sep 9 missed, 15 today) |
| `-seed freshProgram -tab progress` (existing) | empty state: 16 chips, Best 40 lb (planned), "—", grid only, empty line, August 2026 · 0 completed, today 31 |
| `-seed midProgram -tab progress -progressExercise goblet` | chip 11 selected and scrolled into view: 47.5 · 47.5 · 52.5, Best 52.5, +5 lb, Sep 2 → Sep 11 |
| `-seed midProgram -tab progress -units kg` | Best 19.3 kg, +2.3 kg |
| `-seed missed-skipped -tab progress` / `-seed missed-shifted -tab progress` (existing) | Sep 9 skipped (`mu`) / Sep 9 a rest cell; 9 completed both |
| **`progress-history`** (new; D2) | an archived 1-month 3-day (Mon/Wed/Fri) 45-min program of library defaults via `ProgramStore.start` Mon 2026-08-03 06:00, all 12 sessions completed at target through `WorkoutLogStore.start` / `finish` (12 reps, RPE 7), `ProgramStore.archive` at Mon 08-31 05:00 (so `start`'s guard passes next); then `MidProgramSeed`; Tue 09-15 12:00. dbBench: 40 · 40 · 45 · 30 · 37.5 · 40 · 42.5, Best 45, +2.5 lb, Aug 3 → Sep 14; calendar = `midProgram`'s |

---

## 5. Rules and formulas

### 5.1 Chip list — `exerciseKeys(sessions:)` (prototype `used`: every session's exercises, first-seen, session order)

Walk the current program's sessions in index order and each session's `exerciseKeys` in plan order, appending unseen keys; then, for
archived programs newest `programCreatedAt` first, their **completed** sessions the same way (5.6). A swap rewrites the session's plan
element (M3), so every finished log's key is in its own session's plan and the union needs no log read; a hand-built log key absent
from every plan is not a chip (its points are unreachable, tested). Unswapped programs equal `SplitPlans.exerciseKeys(frequency:sessionLengthMinutes:)`.

| Program | Walk (5 keys per session, 45 min) | Chips |
|---|---|---|
| `midProgram` (5-day) | Push dbBench inclineDb shoulderPress pecDeck latRaise · Pull latPull lowRow dbRow rdl curl · Legs goblet (rdl) legExt legCurl split · Upper chestPress (dbRow shoulderPress pecDeck) skull · Lower (split legExt legCurl) lunge (goblet) | **17**: dbBench, inclineDb, shoulderPress, pecDeck, latRaise, latPull, lowRow, dbRow, rdl, curl, goblet, legExt, legCurl, split, chestPress, skull, lunge (pushdown is 6th in Push: never planned) |
| `freshProgram` (4-day) | Upper A dbBench latPull shoulderPress lowRow curl · Lower A goblet rdl legExt legCurl lunge · Upper B inclineDb dbRow pecDeck latRaise skull · Lower B split (rdl legExt legCurl goblet) | **16**: dbBench, latPull, shoulderPress, lowRow, curl, goblet, rdl, legExt, legCurl, lunge, inclineDb, dbRow, pecDeck, latRaise, skull, split |

### 5.2 Points — `points(tops:)`; top weight = `HomeStats.topWeightLb` (Home's PR definition)

Top of one finished log for the key = the maximum `weightLb` over its sets with `status == .done`; skipped and pending sets never
count; a log whose sets for the key are all skipped yields **no point** (as `personalRecords` and `finishedTops`); a key twice in one
log gives one point with the larger top. `date` = the session's `scheduledDate` (D4: the day Home's records and volume use, never `finishedAt`). Order: `(scheduledDate,
programCreatedAt, sessionIndex)` ascending, so two programs' points interleave by day; a point's identity is its position 0…n−1 (B2).

`midProgram` derivation (`MidProgramSeed`: completed 0–6, 8–10; session i → week i/5 + 1; top = target one equipment step **below** for
i ≤ 4, one **above** for i = 9, else = target; Foundation ×1.0; targets from `WeightFormula`: a start ≥ the 30 % threshold is in the
slow regime from week 1, so week 1 = week 2 = start, week 3 = start + step; latRaise 15 < 15.75 is fast to 17.5 in week 2, then slow):

| Key (kind, start) | Sessions → (week, target, top) | Points | Best | Since start |
|---|---|---|---|---|
| dbBench (db 40) | s0 Push (1, 40, −1 → 37.5) · s5 Push (2, 40, 40) · s10 Push (3, 42.5, 42.5) | Aug 31 37.5 · Sep 7 40 · Sep 14 42.5 | 42.5 | +5 |
| inclineDb (db 35) | s0 (1, 35, 32.5) · s5 (2, 35, 35) · s10 (3, 37.5, 37.5) | 32.5 · 35 · 37.5 | 37.5 | +5 |
| shoulderPress (db 30) | s0 Push (1, 30, 27.5) · s3 Upper (1, 30, 27.5) · s5 (2, 30, 30) · s8 Upper (2, 30, 30) · s10 (3, 32.5, 32.5) | Aug 31 27.5 · Sep 3 27.5 · Sep 7 30 · Sep 10 30 · Sep 14 32.5 | 32.5 | +5 |
| pecDeck (marcy 70) | s0 (1, 70, −10 → 60) · s3 (1, 70, 60) · s5 (2, 70, 70) · s8 (2, 70, 70) · s10 (3, 80, 80) | 60 · 60 · 70 · 70 · 80 | 80 | +20 |
| latRaise (db 15) | s0 (1, 15, 12.5) · s5 (2, 17.5, 17.5) · s10 (3, 17.5, 17.5) | 12.5 · 17.5 · 17.5 | 17.5 | +5 |
| latPull (marcy 100) | s1 Pull (1, 100, 90) · s6 Pull (2, 100, 100); s11 pending | Sep 1 90 · Sep 8 100 | 100 | +10 |
| rdl (db 50) | s1 Pull (1, 50, 47.5) · s2 Legs (1, 50, 47.5) · s6 Pull (2, 50, 50); s7 Legs pending | Sep 1 47.5 · Sep 2 47.5 · Sep 8 50 | 50 | +2.5 |
| goblet (db 50) | s2 Legs (1, 50, 47.5) · s4 Lower (1, 50, 47.5) · s9 Lower (2, 50, **+1 → 52.5**) | Sep 2 47.5 · Sep 4 47.5 · Sep 11 52.5 | 52.5 | +5 |
| legExt (marcy 70) | s2 (1, 70, 60) · s4 (1, 70, 60) · s9 (2, 70, +10 → 80) | 60 · 60 · 80 | 80 | +20 |
| lunge (db 30) | s4 Lower (1, 30, 27.5) · s9 Lower (2, 30, 32.5) | Sep 4 27.5 · Sep 11 32.5 | 32.5 | +5 |
| chestPress (marcy 90) | s3 Upper (1, 90, 80) · s8 Upper (2, 90, 90) | Sep 3 80 · Sep 10 90 | 90 | +10 |

Remaining keys the same way: lowRow 80 · 90 (+10); dbRow 42.5 · 42.5 · 45 · 45 (+2.5); curl 22.5 · 22.5 · 25 · 25 (+2.5); legCurl 40 · 40 · 60
(+20); split 27.5 · 27.5 · 32.5 (+5); skull 22.5 · 25 (+2.5). Cross-check: Home's four most recent records (`SeedHomeStatsTests`) are
dbBench, inclineDb, shoulderPress, pecDeck, all first reached on s10 (Sep 14); latRaise's 17.5 dates from s5, so it is not among them.
`restDay` (s11–s14 done at target) adds shoulderPress s13 Upper (3, 32.5) → 6 points, Best 32.5, +5; dbBench unchanged.

### 5.3 Best, since start, labels

`best = max(weightLb)`; `sinceStart = last − first` (prototype `ws[n−1] − ws[0]`, **not** best − first); one point → 0. Text: > 0 "+5 lb"
(`success`), = 0 "0 lb" (`mu`), < 0 "−2.5 lb" (`warning`; the prototype always prints "+", which would read "+-5"). From/to = the first and
last point's day, "Aug 31" / "Sep 14". Worked: dbBench 42.5 · +5 · Aug 31 → Sep 14; 50 · 47.5 → Best 50, "−2.5 lb"; 40 alone → 40, "0 lb", from = to.

### 5.4 Empty state — `plannedFallbackLb(key:sessions:)` (prototype: the first session holding the key, its planned `w`)

No point for the key → Best = `targetWeightLb` of the key's element in the **current** program's lowest-index session that plans it
(`freshProgram` dbBench: s0 Upper A week 1 → 40; all 16 chips fall back to week-1 targets, latRaise 15, goblet 50, …); nil ("—") when no
session plans it; Since start "—"; from/to empty; the empty line shows.

### 5.5 Calendar — `month(sessions:today:calendar:)` (prototype 697–701; Monday-first `lead = (getDay() + 6) % 7`)

Month = `today`'s; `leadingBlanks = CalendarRules.appWeekday(of: first of month)`; one cell per day 1…`range(of: .day)`. Cell session =
`HomeStats.session(on:)` (4.3; completed wins, else lowest index, deliberately a superset of the strip's rule); `state = HomeStats.sessionState(_, today:, calendar:)`
(`.rest` for none); `isToday` = same day; `completedCount` = cells whose state is `.completed`.

| Data, today | lead | Cells | completed |
|---|---|---|---|
| `midProgram`, Tue 09-15 | Sep 1 2026 = Tue → **1** | 1–4 ✓ (s1–s4) · 5 6 rest · 7 8 ✓ (s5 s6) · **9 missed** (s7) · 10 11 ✓ (s8 s9) · 12 13 rest · 14 ✓ (s10) · **15 today** (s11) · 16 17 18 scheduled · 19 20 rest · 21–25 scheduled · 26 27 rest · 28–30 scheduled; 31 cells, 5 rows | **9** |
| `missed-skipped` | 1 | as above with 9 **skipped** | 9 |
| `missed-shifted` | 1 | 9 is a rest cell; 15 today (s7); the pending set shifts one training slot each, so 16–18, 21–25, 28–30 stay scheduled | 9 |
| `freshProgram`, Mon 08-31 | Aug 1 2026 = Sat → **5** | 1–30 rest; **31 today** (s0 pending); 36 cells, 6 rows | **0** |
| `restDay` data, Sat 09-19 | 1 | 1–4, 7, 8, 10, 11, 14–18 ✓; 9 missed; 19 today (rest, accent number, accent border, clear bg) | 13 |
| Nov 2026 (any) | Nov 1 2026 = Sun → **6** | 30 cells; the DST fall-back day (Nov 1) is a plain cell: day arithmetic is calendar-based | — |
| Feb 2027 (`midProgram` data, today Mon 2027-02-01 12:00) | Feb 1 2027 = Mon → **0** | 28 cells; 1 today, 2–5 and 8–12 scheduled; after a shift s109 on 1 (today), s110–s113 on 2–5, s114–s118 on 8–12, s119 on 15 | 0 |

### 5.6 Which programs count (D2; INSIGHTS: "restart archives … its logs and PRs stay for Progress")

Sessions = the current program's (all statuses) plus every archived program's **completed** sessions (an abandoned program's pending and
skipped sessions are never chips, cells or points); tops = every finished log of the key across all programs. Best and Since start
therefore span programs; the calendar shows an archived program's completed days beside the current schedule; a day holding a completed
archived session and a current pending one reads completed. The Engine is program-agnostic; the builder's session predicate admits
exactly these rows. `progress-history` (4.4): the archived 1-month program is W = 4, R = 3, Foundation ⌈1.05⌉ = 2, Peak ⌈0.75⌉ = 1, Build 0,
Deload week 4; dbBench targets 40 · 40 · 45 (42.5 × 1.05 = 44.625 → 45) · 30 (42.5 × 0.7 = 29.75 → 30) on Mon Aug 3 · 10 · 17 · 24, then
`midProgram`'s 37.5 · 40 · 42.5 → Best 45, since start 42.5 − 40 = +2.5, "Aug 3" → "Sep 14".

### 5.8 Chart geometry — `chartGeometry(weights:)` (researcher Q1; numbers only, no drawing)

`n = weights.count`. y: `lo = min − 5`, `hi = max + 5`, `ext = (hi − lo) / 10`, `yDomain = (lo − ext)…(hi + ext)`, rules at `lo`, `(lo + hi) / 2`, `hi`
(`lo` → 110/120, `hi` → 10/120; every rule inside the domain). x: `n ≥ 2` → `pad = (n − 1) / 30`, `xDomain = −pad…(n − 1) + pad` (10 pt insets of
320); `n ≤ 1` → `−1…1` (a single point at 0 is centred). Empty → bounds of `[0, 10]`: `lo = −5`, `hi = 15`, rules still drawn. Worked, dbBench 37.5 ·
40 · 42.5: `lo` 32.5, `hi` 47.5, `ext` 1.5, `yDomain` 31…49, rules 32.5 / 40 / 47.5, `xDomain` −0.0667…2.0667. Single 40: `yDomain` 34…46, rules 35 / 40 / 45.

### 5.7 Unit text (Shared, never Engine)

Weights via `WeightDisplay.text(lb:unit:)` (kg one decimal): Best 42.5 lb → "42.5" / "19.3"; the delta is converted **as a difference**
(5 lb → "2.3 kg", never kg(last) − kg(first), which can differ by a rounding tenth); the planned fallback 40 lb → "18.1". Chart geometry
stays in lb. Suffix = the unit's raw value.

---

## 6. Edge cases

| Case | Behaviour |
|---|---|
| Month boundaries | s0 (Aug 31) is not a September cell; Feb 2027 has 28 cells, lead 0; a month starting Sunday has 6 blanks (Nov 2026); DST days are ordinary cells |
| Two sessions on one day | Completed wins, else lowest index (`dayCells` rule); unreachable for pending pairs (Reslot invariant) |
| Skipped sets | Never a top; a workout with every set of the key skipped adds no point and no "Since start" movement; `rpeSkipped` irrelevant |
| Swapped exercise | Counts under the key performed (its chip); the swapped-out key keeps its other sessions' points; a key planned only through a swap is a chip once the plan element exists |
| Missed session started from Program without a shift (M3) | Its log's point and completed cell sit on the **scheduled** day, like Home's records and volume (D4) |
| A drop in weight | "−2.5 lb" in `warning`; Best keeps the earlier maximum |
| Backgrounded / killed | Nothing stored; `now` refreshes on foreground (a new month re-derives); the selection is state only (D1) |
| Failed per-key fetch | Debug asserts; the card shows the empty state for that key; sessions and calendar unaffected |
| Stale selected key | `effectiveKey` falls back to the first chip (no write, no assert); the task fetches the effective key, and a held result for another key is not drawn (a fast chip tap never shows the previous line under the new chip); until the effective key's fetch completes the card draws the rules only, Best "—", no fallback and no empty line |
| Unit switch (`-units kg` now, Settings later) | Best, Since start and the planned fallback convert per 5.7 (delta as a difference: 5 lb → 2.3 kg); the chart's lb domain and shape are unchanged |
| Prototype snapshot numbers | The prototype's +5 lb/week formula gives 35 · 45 · 50 (Best 50, +15 lb); the app's step formula gives 37.5 · 40 · 42.5 (AC-1 deviation) |

---

## 7. Out of scope

Month navigation or a year view; tapping a cell or a point; volume, reps, RPE or streak charts; PR lists beyond Home's cards; editing finished
sets; export, haptics and the light-theme audit (M5); Settings, units and restart (m4-settings); reminders (m4-reminder); a persisted chip selection (D1); CloudKit.

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, dark unless stated; wait ≥ 2 s; check = matches by `/design-compare`). The `progress` frame is off the
3000-px render's right edge: render with `--window-size=4400,5600` and crop ≈ 2340 × 2330 @ (2540, 1620); the frame is ~2300 px wide, so
compare content only (record both in the skill). Every Progress screenshot launches with `-tab progress`.

1. **`progress` (D2)**, `-seed midProgram -tab progress`: matches. "Progress"; 17 chips in 5.1's order, "Dumbbell Bench Press" selected;
   "Best" 42.5 lb · "Since start" +5 lb in `success`; three dots on a rising line, grid lines; "Aug 31" · "Sep 14"; "September 2026" ·
   "9 completed"; letters M T W T F S S; one lead blank; cells per 5.5 (1–4, 7, 8, 10, 11, 14 green; 15 accent-bordered accent "15";
   16–18, 21–25, 28–30 `sf2`; weekends `mu`). Deviations to skip: weights 37.5 · 40 · 42.5 / 42.5 / +5 (prototype 35 · 45 · 50 / 50 / +15);
   Sep 9 in `warning` (prototype `tx`; D3); the phone-width layout (cells ~44 pt, chips beyond the 5th scroll off); the tab pill from M1.
2. **Empty state** (no snapshot; spot check), `-seed freshProgram -tab progress`: 16 chips (5.1), first selected; Best "40 lb"; Since start
   "—"; grid lines and no dots; no from/to; the empty line verbatim; "August 2026" · "0 completed"; five lead blanks; 31 accent-bordered.
3. `-seed midProgram -tab progress -progressExercise goblet`: "Goblet Squat" selected and visible (row scrolled), Best 52.5 lb, +5 lb, dots
   47.5 · 47.5 · 52.5 (first two level), "Sep 2" · "Sep 11"; calendar as AC-1.
4. **kg**, `-seed midProgram -tab progress -units kg`: "19.3 kg", "+2.3 kg"; `-seed freshProgram -tab progress -units kg`: "18.1 kg".
5. `-seed missed-skipped -tab progress`: Sep 9 `sf2` with `mu` "9"; `-seed missed-shifted -tab progress`: Sep 9 a rest cell; both "9 completed".
6. **Light** (spot check, audit M5), `-seed midProgram -tab progress` + appearance light: light tokens; green, accent and `warning` unchanged.
7. `-seed progress-history -tab progress` (D2): **seven distinct dots** 40 · 40 · 45 · 30 · 37.5 · 40 · 42.5 (the B2 regression: two programs' s0 both draw), Best 45 lb,
   +2.5 lb, "Aug 3" · "Sep 14"; calendar identical to AC-1.
8. **Regression:** `home`, `home-light`, `program`, `missed`, every workout and missed-day seed unchanged; Settings still the placeholder.

**Behaviour** (taps are refused here: an optional scratch-copy XCUITest step in the plan, else the user's MVP pass):

9. Chip tap: "Lat Pulldown" → Best 100 lb, +10 lb, two dots, "Sep 1" · "Sep 8"; back to "Dumbbell Bench Press" → AC-1's card; nothing written.
10. Selection lifetime (D1): Program tab → back → the tapped chip is still selected; relaunch → first chip.
11. Done on `summary` (s11 Pull, set 1 of Lat Pulldown at 120 lb): Progress "Lat Pulldown" → 90 · 100 · 120, Best 120, +30, "Sep 15" cell green, "10 completed".
12. From `-seed missed`: Home shift → Progress shows Sep 9 rest, 15 today; Home skip → Sep 9 `mu`.
13. **VoiceOver** (Inspector / user's device): order title → chips (each a button labelled the exercise name; the selected one reads
    "selected") → "Best" and its value → "Since start" and its value → the chart container reading "Dumbbell Bench Press, 3 sessions,
    37.5 to 42.5 lb", then its dots "Aug 31, 37.5 lb" · "Sep 7, 40 lb" · "Sep 14, 42.5 lb" (no line or rule element) → from/to → month
    title → "N completed" → cells (label = day number, value per `cellValue`; lead blanks silent). No hints, no third string. The XCUITest
    half asserts **only** the absence of line/rule elements and the three dot label/value pairs, never the container's presence or order
    (NB9: `.contain` + label is unprobed); whether VoiceOver stops on the container first is the user's device check.
14. **Home link**: `-seed midProgram`, tap "Progress ›" → the Progress tab (pill highlights Progress), AC-1's screen.

**Unit tests** (Engine suites plain with `TestCalendar`; persistence and seed suites `@MainActor`, fresh in-memory store per test. Planner:
`xcodebuild -only-testing:Target/Suite/function` silently runs 0 Swift Testing tests; select the suite, `Target/Suite`):

15. `exerciseKeys`: the two rows of 5.1 exactly; a swapped plan element moves the key's chip position accordingly; a log-only key is absent;
    empty sessions → `[]`; archived programs' completed sessions append after the current program's, newest first, pending ones ignored.
16. `points` / `ProgressStats.logTopLb(_ rows: [LoggedExerciseValue]) -> Double?` (the per-log rule the builder calls, wrapping `HomeStats.topWeightLb`; skipped sets and a duplicate key in one log are Engine-tested here): the 11 rows of 5.2 (dates and weights, in order); a log with the key's sets all skipped adds no point; a skipped
    heavier set does not raise the top; a duplicated key in one log gives one point with the larger top; two programs' points interleave
    by `(scheduledDate, programCreatedAt, index)` with positions 0…n−1 unique although both hold a session index 0; input order does not matter.
17. `bestLb` / `sinceStartLb`: dbBench 42.5 / +5; goblet 52.5 / +5; latRaise 17.5 / +5; hand inputs 50 · 47.5 → 50 / −2.5; 40 → 40 / 0; `[]` → nil / nil.
18. `plannedFallbackLb` over `ProgressSession`s whose `summary.exercises` carry `PlannedExercise` targets: `freshProgram` dbBench 40, latRaise 15, goblet 50; an unplanned key → nil; an archived-only planning session → nil; the lowest index wins when two sessions plan it at different targets (weeks 1 and 3).
19. `month`: the seven rows of 5.5 (lead, cell count, every state, `isToday`, `completedCount`); Aug 31 excluded from September; a completed
    archived session and a current pending one on the same day → completed (D2); the Nov 2026 and Feb 2027 rows.
20. `effectiveKey`: a listed key stays; an unlisted or nil key → first; no keys → nil.
21. `ProgressText`: "+5 lb", "0 lb", "−2.5 lb" (U+2212), "+2.3 kg" from 5 lb, "September 2026", "August 2026", "9 completed", "0 completed", the
    fixed strings verbatim, `cellValue` for all six states, `chartSummary` → "Dumbbell Bench Press, 3 sessions, 37.5 to 42.5 lb" (and
    "…, 1 session, 40 to 40 lb", kg variant), `pointLabel` / `pointValue` → "Aug 31" / "37.5 lb". `chartGeometry`: the two worked cases of
    5.8, the empty case, and for every input of AC-16/17 all three rules lie inside `yDomain` and `xDomain` contains 0…n−1.
22. Builder (**regression test for the verified predicates**, both runtimes): fixture = a current program with pending and completed sessions,
    an archived program with pending, completed and skipped sessions, and one orphan session (`program == nil`, completed); the per-id
    archived fetch returns exactly the archived program's completed rows (orphans and pending excluded), the current query exactly the
    current program's, and the archived-`Program` query exactly the one archived row; the fingerprint changes when a second archived
    program is added. The per-key fetch on `midProgram` rows returns 5.2's dbBench / shoulderPress / goblet tops
    with the sessions' `scheduledDate`s through the shared `finishedExercisePredicate`; an in-progress log (`wo-start` rows) is excluded;
    an archived program's finished logs are included; a log with no session is dropped, not trapped.
23. Seeds: `SeedProgressStatsTests` end to end for `midProgram` (17 keys, dbBench 3 points 37.5 · 40 · 42.5, Sep 9 missed, 9 completed),
    `freshProgram` (16 keys, no points, fallback 40, Aug lead 5, 0 completed), `restDay` (shoulderPress 6 points, 13 completed),
    `missed-skipped` / `missed-shifted` (Sep 9 skipped / rest), and `progress-history` (7 points, Best 45, +2.5; `archivedAt` set,
    `ProgramStore.current` still `midProgram`'s). `ProgramStore.archive`: `current` is nil and the routing predicate no longer matches after
    it; a second call writes nothing (`hasChanges == false`); failed save restores `archivedAt` (`allowsSave: false`, same-context fetch by id first). `DebugProgressExercise.parse` (the `-progressExercise` parser): value, missing, trailing flag.
24. Static: `SeedNameScanTests` covers `"progress-history"` and the `-progressExercise` string lives only under `App/DebugSeed/`; a scan
    mirroring `MissedPromptSourceTests`: `progressPreselection` `@Entry` declared nil-by-default on one line in `AppClock.swift` and set on
    exactly one line of `HomeGymLogApp.swift` inside the root's `#if DEBUG` block, between `DebugSeed.parse(` and its `#endif`, like `preselection`
    (NB2); `ClockUsageTests` green; `FailedSavePolicySourceTests` covers `archive` (calls `StoreCommit.commit`); **no `.program` member access
    under `Features/Progress/`** (the addendum-Q3 rule: `body` never hops session → program), and in `ProgressSnapshotBuilder.swift` the
    a `.program` member access (not followed by an identifier character, not preceded by `self`) appears only inside `tops(key:`; none under `Features/Progress/`; no `finishedLogs(` call under either.
25. Release build compiles; the suites are green on iOS 17.5 and 26.5.

---

## 9. Decisions (user-answered 2026-09-16)

| # | Decision |
|---|---|
| D1 | **Chip selection is screen state only**: persists across tab switches while the shell is mounted; resets to the first chip on relaunch and after a workout (the shell remounts). Nothing is written. |
| D2 | **Archived history across all programs now**: chart points, Best, Since start and the calendar include archived programs' completed sessions and finished logs; chips append archived keys after the current program's (5.1, 5.6); the `progress-history` seed and AC-7 ship in this slice. |
| D3 | **Missed → `warning` number, skipped → `mu` number, both on `sf2`** (the Home strip's and Program card's tones); recorded as a one-cell deviation from the prototype's `progress` frame (Sep 9). |
| D4 | **A finished log belongs to its session's `scheduledDate`** (chart order and calendar cell), matching Home's records, week volume and strip; taken as the default without asking. |
| D5 | **Spoken strings**: chart summary "Dumbbell Bench Press, 3 sessions, 37.5 to 42.5 lb" on the chart container, dots "Aug 31, 37.5 lb"; a future session cell's value is "Scheduled". |

Researcher facts are in 4.4 and 5.8. **Architecture review (2026-09-16, approve with changes), applied:** B1 `ProgressSession` wraps
`SessionSummary`; B2 point identity = position, order `(scheduledDate, programCreatedAt, index)`; B3 one task on the effective key, held as
`(key, tops)`; B4 chips in `body`; B5 as revised by the researcher addendum: current sessions by `@Query`, archived programs by a `Program`
`@Query`, archived completed sessions fetched per program id inside the task, no `program` hop in `body`, predicates verified, AC-22 the regression. NB1
shared `topWeightLb` / predicate / day helper; NB2 preselection in `body`, no scroll token; NB3 no `ProgressPoint`; NB4 `ProgramStore.archive`;
NB5 `selectedTab` by value; NB6 `.task` per tab return (verified); NB7 `(scheduledDate, index)` sort; NB9 container a11y device-only; NB10
superseded (no hop in `body` at all). Unverified (device pass): whether VoiceOver stops on the chart container before its dots (AC-13).

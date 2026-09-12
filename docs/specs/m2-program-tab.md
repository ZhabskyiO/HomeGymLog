# M2 slice 3 — Program tab (week chips, day row, session card)

**Status: implemented 2026-09-11 on branch `m2-program-tab` (plan `docs/plans/m2-program-tab.md`); revised
2026-09-11 after the architecture review (`docs/reviews/m2-program-tab-architecture.md`; decisions in section 9).
AC-1 … AC-8 and AC-10a verified by seeded screenshot, AC-13 … AC-23 by the test suite (292 tests / 473 runs green on
iPhone 15 / iOS 17.5 and iPhone 17 / iOS 26.5, Release build green; swift-reviewer findings 1, 2 and 4 applied,
`docs/reviews/m2-program-tab-swift-review.md`); the tap-driven AC-9, AC-9a,
AC-10, AC-11 and AC-12 are left for the user (scripted taps are refused on this machine).** Depends on `m2-onboarding` and `m2-home` (merged). Source: the prototype's
`tabProgram` markup and the script feeding it (`programTitle`, `splitName`, `weekChips`, `phaseOfWeek`, `selPhase*`,
`selWeekDays`, `selDayIdx`, `selHasSession`, `selIsRest`, `selName`, `selStatus`, `selExercises`, `detailEx`); `CLAUDE.md`;
INSIGHTS ("M2 Home architecture/decisions", "Mid-week program start", "Date and weekday conventions", "Engine/Model
boundary"). Milestone-wide decisions live in `docs/specs/m2-onboarding.md` §10 and `docs/specs/m2-home.md` §3–4 and are
not restated. Flow label: row D, first frame, snapshot `program` ("D1 · Program week strip").

---

## 1. Purpose

Replace `PlaceholderScreen(tab: .program)` with the prototype's Program tab (snapshot `program`): title and subtitle,
a horizontally scrolling row of week chips, the selected week's phase line, its seven day buttons, and either the
selected day's session card (with the existing exercise info sheet) or the rest-day card. Read-only: it writes nothing
and navigates nowhere except the sheet. Every derived value is a pure Engine function over `[SessionSummary]`, unit-tested
against the `midProgram`, `restDay` and `freshProgram` seeds.

---

## 2. User-facing behavior

Screen padding 18 pt sides, top 8, content scrolls under the tab pill; no navigation bar; colors are Theme tokens.
Sizes are the prototype's CSS; where the rendered `program` snapshot disagrees, the snapshot wins (the Home slice's rule).

### 2.1 Header

| Element | Copy / rule | Style |
|---|---|---|
| Title | "Program" | 28 pt bold, tracking −0.8 |
| Subtitle | "`N`-month program · `split name`" from `ProgramSummaryText.title(months:)` and `SplitPlans.info(frequency:).name`. `midProgram`: "6-month program · Push / Pull / Legs + Upper / Lower"; `freshProgram`: "1-month program · Upper / Lower" | 13 pt `mu`, 2 pt below the title |

### 2.2 Week chips (horizontal scroll, one chip per week; 5.2)

Row bleeds to the screen edges (content inset 18), 18 pt below the subtitle, gap 6, 6 pt bottom padding. Chip:
58 pt wide, padding 9 top / 8 bottom, radius 12, `sf` background, 1.5 pt border (accent when selected, transparent
otherwise, so the size never changes), text `tx`. Column, gap 6: "WK" (10 pt `mu`), the week number (17 pt bold),
a 26 × 3 pt bar (radius 2) in the week's phase color (`Theme.phaseColor`). Tap: selects that week and resets the
selected day to the week's default (5.4). On every appear (first show, every return to the tab, program change)
the row scrolls **the minimum needed to make the selected chip wholly visible, and not at all when it already is**
(decision 3): weeks 1–5 are visible on an iPhone 15, so the `program` snapshot (WK 1 first, WK 3 selected) is matched
exactly; a chip beyond the edge lands flush with that edge, never centered. Visuals confirmed against the rendered
prototype: "WK" label, bold number, phase-colored bar, selected chip outlined in accent.

### 2.3 Phase line (14 pt below the chips)

8 × 8 pt square (radius 2) in the phase color, the phase name (13 pt semibold), then "· `sets` × `reps`" in `mu`
(`ProgramSummaryText.scheme`); Deload appends " · −30% load" (prototype copy, U+2212 minus). Examples:
"Foundation · 3 × 12", "Peak · 4 × 8", "Deload · 2 × 12 · −30% load".

### 2.4 Day row (12 pt below the phase line; 5.5)

Seven equal buttons, gap 4, padding 8 / 0, radius 12, column gap 6: letter (11 pt; M T W T F S S from
`HomeText.weekStripLetters`), day-of-month (15 pt bold), 6 pt dot (radius 3). Tap selects the day. No "today"
marker exists in this row (prototype); "Today" appears only as the card status.

| Day | Fill | Text | Dot |
|---|---|---|---|
| Selected | accent | white | session completed → `success`; any other session → white; no session → transparent |
| Not selected | `sf` | `tx` | session completed → `success`; any other session → `mu`; no session → transparent |

### 2.5 Session card (16 pt below the day row; shown when the selected day holds a session)

`sf`, radius 16, padding 14 / 16. Header row, baseline-aligned: session name (19 pt bold) left, status (12 pt
semibold, color per 5.6) right. Then one row per planned exercise (column gap 9, 12 pt below the header), 13.5 pt,
gap 10: index (20 pt wide, `mu`), a two-line block that fills (name, weight 500; equipment string 11 pt `mu`
below it, e.g. "Marcy · high pulley"), scheme "`sets`×`reps`" (`mu`, no spaces), target weight "`w` `unit`"
(semibold, ≥ 52 pt, right-aligned; `WeightDisplay.text` in the display unit), and a 24 pt "i" circle (`sf2`, `mu`
12 pt bold) that opens the info sheet (2.7). Weights are the planned targets for every status, including
Completed (prototype; logged weights are Progress/M4). The `midProgram` card (session 11, Pull, week 3, Foundation):

| # | Name | Equipment | Scheme | lb | kg |
|---|---|---|---|---|---|
| 1 | Lat Pulldown | Marcy · high pulley | 3×12 | 110 lb | 49.9 kg |
| 2 | Seated Low Row | Marcy · low pulley | 3×12 | 100 lb | 45.4 kg |
| 3 | One-arm Dumbbell Row | Dumbbell + bench | 3×12 | 47.5 lb | 21.5 kg |
| 4 | Dumbbell Romanian Deadlift | Dumbbells | 3×12 | 52.5 lb | 23.8 kg |
| 5 | Dumbbell Curl | Dumbbells | 3×12 | 27.5 lb | 12.5 kg |

Header: "Pull" · "Today" (`mu`). Week-3 targets: every default is ≥ its threshold (Marcy 45, dumbbell 15.75) so
the slow regime applies from week 1 and base(3) = start + one step (INSIGHTS formula); Foundation ×1.0.

### 2.6 Rest card (shown when the selected day holds no session)

`sf`, radius 16, padding 18 / 16, 14 pt `mu`: "Rest day. Light walk, stretch, eat." (verbatim).

### 2.7 Exercise info sheet

The Home slice's `ExerciseInfoSheet`, content unchanged (m2-home 2.7), **moved to `Shared/`** (git mv; features never
reach into each other) with its four presentation modifiers (detent 0.78, corner radius 28, drag indicator hidden, `sf`
background) extracted into one Shared view extension Home and Program both apply. Presented from the Program tab's own
single optional sheet item; dismissing it leaves the week/day selection untouched.

---

## 3. States and transitions

| State | Shown when | Leaves via |
|---|---|---|
| `.followToday` | **every appear** of the tab (first show, each return from another tab, relaunch, program change) without a DEBUG preselection: week = `initialWeek`, day = `defaultDay` for the current `now` (5.3, 5.4); also whatever a selection is invalid (below) | chip tap or day tap |
| `.week(w)` | chip tapped, or appear with `-programWeek` alone: day = that week's default | another chip; day tap; leaving the tab |
| `.day(week: w, day: d)` | day tapped (w = the week on screen), or appear with `-programDay` (w = `-programWeek` if given, else `initialWeek`) | chip tap (back to `.week`); leaving the tab |
| Session card / rest card | the selected day holds a session / does not | any selection change |
| Info sheet | "i" tapped; holds the row's `Exercise` | Done, scrim tap, swipe down (selection unchanged) |
| Empty | no sessions for the program (never after generation) | data change |

State held: `now` (written on appear and on scene-active, never read while rendering), one `selection:
ProgramSelection` (`enum { followToday, week(Int), day(week: Int, day: Int) }`, the prototype's `selWeek`/`selDay` as one
value), and the presented exercise. **One validity rule, no clamping** (decision 6): a week outside 1…`weekCount` or a
day outside 0…6 — tapped, stale after a data change, or from a DEBUG argument — makes the whole selection behave as
`.followToday`. Effective (week, day): `.followToday` → (`initialWeek`, `defaultDay`); `.week(w)` → (w, `defaultDay(w)`);
`.day(w, d)` → (w, d). **Decision 4: the selection resets on every appear.** The tab view keeps the screen mounted, so
each return fires appear, whose handler does exactly two writes: `now = clock.now()` and `selection =
preselection-derived ?? .followToday` (4.1). Taps persist only while the tab stays visible. The screen is keyed on the
program id; relaunch shows the following-today state; a sheet is not restored. A foreground refresh of `now` never
touches `selection`. **Plan-time risk (not an AC):** the reset relies on `.onAppear` firing on every tab return in this
shell; the plan must probe it on iOS 17.5 and 26.5 first and otherwise react to the shell's selected-tab change.

---

## 4. Data

### 4.1 Read (the Program tab writes nothing)

| Source | Fields used |
|---|---|
| `Program` (prop from the shell, immutable fields only) | `id` (query filter and screen key), `months` and `frequency` (subtitle). `weeks` / `totalSessions` are not used: chip count comes from the sessions (5.2). |
| `PlannedSession` via the tab's **own live query** (`HomeSnapshotBuilder.sessionPredicate(programID:)`, sorted by `index`, built in the screen's init exactly like Home) | `index`, `week`, `phaseRaw`, `name`, `scheduledDate` (local midnight), `statusRaw`, `sets`, `reps`, `exercises` (`order`, `exerciseKey`, `targetWeightLb` in lb). `workoutLog` is never traversed: no logs, no `.task` fingerprint, nothing expensive on iOS 17.5. |
| Preferences | `units` (`WeightUnit` raw, default lb) |
| App clock | `now()`, `calendar` |
| DEBUG preselection (decisions 5, 8) | Launch arguments `-programWeek <n>` (1-based) and `-programDay <d>` (0 = Monday … 6 = Sunday). Delivery follows the seed-draft pattern: a production value type `ProgramTabPreselection { week: Int?; day: Int? }` in `Features/Program/`, an environment value `programTabPreselection` defaulting to nil next to the app clock, set at the root **only inside the existing `#if DEBUG` block** from a DEBUG-only parser `DebugProgramSelection` (sibling of `DebugSeed` in `App/DebugSeed/`, whole file under `#if DEBUG`). The parser turns each present integer into a raw value (no range check; a missing, trailing or non-integer value yields nil for that argument, never a throw or trap). The view has no `#if`: on every appear it derives `(w, d)` → `.day(w, d)`, `(w, nil)` → `.week(w)`, `(nil, d)` → `.day(initialWeek, d)`, nothing → `.followToday`, and the use-time validity rule of section 3 rejects out-of-range values (so `-programWeek 99` shows today's week). Taps override until the next appear. Release builds never see the arguments: the parser and the root assignment do not exist there. |
| Static | `ExerciseLibrary` (name, equipment, muscle, cues), `SplitPlans.info`, `Phase` (sets, reps), `Theme.phaseColor` |

Rows map through `HomeSnapshotBuilder.sessionSummaries(from:)` **straight into `ProgramTabStats`** (decision 7): no
`HomeStatsInput`, no validation step and no Release fallback, because no function below needs unique indexes (ties
resolve to the lowest index). The shell switches `.program` to the new screen with `.id(program.id)`, as for Home.

### 4.2 Derived (never stored)

Week anchor and count, chips with phases, initial week, default day, the seven day cells, the selected session, its
status, subtitle and status text, kg text.

### 4.3 Engine value types (new file `Engine/ProgramTabStats.swift`; plain, no SwiftData, no text)

| Value | Fields | Notes |
|---|---|---|
| `WeekChip` | `week: Int` (1-based), `phase: Phase?` | nil phase only for a window with no session (view draws no bar) |
| `ProgramDayCell` | `date: Date`, `dayNumber: Int`, `session: SessionSummary?` | seven per week, Monday first; the lowest-index session dated that day |
| `WeekStripState` (existing) | `completed`, `skipped`, `today`, `missed`, `scheduled`, `rest` | card status reuses it via `HomeStats.sessionState` (5.6); `.rest` is never returned for a session |

A new file rather than `HomeStats`: these are the Program tab's selectors and share only `SessionSummary` and
`CalendarRules` with Home. Two Engine additions outside it (decisions 11, 12): the switch inside `HomeStats.weekStrip`
becomes `HomeStats.sessionState(_:today:calendar:) -> WeekStripState`, shared by strip and card (the one exception to
"no `HomeStats` changes"); and `CalendarRules.days(from:to:)` counts calendar days between two start-of-day values with
`dateComponents([.day])` (5.1, 5.3). Text lives in a new `Shared/ProgramTabText.swift` (subtitle, phase line, status,
"WK"); `HomeText.shortDate` / `weekStripLetters` and `ProgramSummaryText.title` / `scheme` are reused.

---

## 5. Rules and formulas

All functions take `sessions: [SessionSummary]`, an explicit `calendar: Calendar` and, where needed, `today: Date`;
they return plain values and never throw or trap; none requires unique indexes. Empty `sessions` yields nil / 0 /
empty. Day comparisons use `CalendarRules.startOfDay` / `isSameDay`; day arithmetic uses `CalendarRules.day`; day
counts use `CalendarRules.days(from:to:)`, never `/ 86 400`.

### 5.1 Week windows — `weekAnchor(sessions:calendar:) -> Date?`, `weekCount(sessions:calendar:) -> Int`

Verified from the code: `ProgramGenerator` sets `startDate = CalendarRules.monday(ofWeekContaining: generatedOn)`,
`week = index / frequency + 1` (index-based, never changed by re-slotting) and base date = `startDate + 7 (week − 1) +
weekday`; sessions whose base date precedes `generatedOn` slide forward with every later session (`Reslot`). When no
week-1 base date precedes the generation day (a Monday generation, or a generation weekday no later than the first
training weekday), program week *w* is exactly the calendar week `startDate + 7 (w − 1)`. **Any non-Monday generation
whose first training weekday precedes the generation weekday spills**: the schedule spans one extra calendar week and
the stored `week` lags the calendar by one after the spill (6). Rule (decision 1): **anchor = Monday of the week
containing the earliest `scheduledDate`**; window *w* = anchor + 7 (w − 1) through the following Sunday; **weekCount =
days(anchor, latest `scheduledDate`) / 7 + 1**. Not `Program.startDate`: for a weekend generation (`startDate` Mon
09-07, first session Mon 09-14) it would leave window 1 empty and the last week's sessions outside every window.

| Seed / example | Earliest | Latest | Days | weekCount |
|---|---|---|---|---|
| `midProgram`, `restDay` | Mon 2026-08-31 | Fri 2027-02-12 (session 119: 08-31 + 7·23 + 4) | 165 | 165/7 + 1 = **24** |
| `freshProgram` | Mon 2026-08-31 | Fri 2026-09-25 (session 15: + 7·3 + 4) | 25 | **4** |
| Example E (Example A generated Wed 09-09) | Wed 09-09 → anchor Mon 09-07 | Mon 10-05 (session 11) | 28 | **5** for a 4-week program |

### 5.2 Chips — `weekChips(sessions:calendar:) -> [WeekChip]`

One chip per window 1…weekCount. Phase = the recorded `phase` of the **highest-index** session dated in the window
(decision 1: in a spill window the later program week holds the majority of the sessions; for Monday-anchored
programs every session in a window shares the phase, so the choice is moot); nil when the window holds no session.
Phases are read from the rows, never recomputed. The seeds' recorded phases (`PhaseSplit.phaseOf`, integer ceilings):
`midProgram` 24 weeks → remaining 23, Foundation (23·35 + 99)/100 = 9, Peak (23·25 + 99)/100 = 6 → 18–23, Build 10–17,
Deload 24; `freshProgram` 4 weeks → remaining 3, Foundation (105 + 99)/100 = 2, Peak (75 + 99)/100 = 1 → week 3, Deload 4.

| Seed | Chips (week → phase, bar color) |
|---|---|
| `midProgram` | 1–9 Foundation (`phaseFoundation`), 10–17 Build (accent), 18–23 Peak (`warning`), 24 Deload (`phaseDeload`) |
| `freshProgram` | 1–2 Foundation, 3 Peak, 4 Deload |
| Example E | windows {0,1} {2,3,4} {5,6,7} {8,9,10} {11}; highest index 1, 4, 7, 10, 11 → weeks 1, 2, 3, 4, 4 → Foundation, Foundation, Peak, Deload, Deload |

### 5.3 Initial week — `initialWeek(sessions:today:calendar:) -> Int?`

The window containing today: `days(from: anchor, to: today) / 7 + 1`, bounded to 1…weekCount (today before the
anchor → 1; after the last window → weekCount): the prototype's `curWeek = min(W, days/7 + 1)`. Deliberately **not**
`HomeStats.currentWeek` (stored week of today's/next session): on `restDay` (Sat 09-19) that rule gives week 4 (next
pending session 15, Mon 09-21) and would open Monday's Push card; the prototype opens week 3 on Saturday's rest card.

| Today | Days from anchor | Week |
|---|---|---|
| `midProgram` Tue 09-15 | 15 | 15/7 + 1 = **3** |
| `restDay` Sat 09-19 | 19 | **3** |
| `freshProgram` Mon 08-31 | 0 | **1** |
| `midProgram` data, Sun 08-30 (before start) | −1 | **1** |
| `midProgram` data, Mon 2027-03-01 (program over) | 182 → 27 | bounded **24** |
| Example E, Wed 09-23 | 16 | **3** |

### 5.4 Default day — `defaultDay(sessions:week:today:calendar:) -> Int` (0 = Monday)

If today lies in window *week* → `CalendarRules.appWeekday(of: today)`; else the weekday of the earliest-dated session
in the window; else 0 (prototype `selDayIdx`). `midProgram` week 3 → 1 (Tue); `restDay` week 3 → 5 (Sat); `freshProgram`
week 1 → 0; `midProgram` week 2 (not today's) → session 5, Mon 09-07 → 0; a window with no session → 0.

### 5.5 Day cells — `dayCells(sessions:week:calendar:) -> [ProgramDayCell]` (always 7)

Cell *d* = window start + *d* days; `session` = the lowest-index session dated that day (two on one day is M4's open
question). A week outside 1…weekCount yields seven dated cells with no sessions (no trap). Selected session = `dayCells[day].session`.

| Seed, week | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
|---|---|---|---|---|---|---|---|
| `midProgram`, 3 (09-14) | 14 · s10 Push ✓ | **15 · s11 Pull** (selected, white dot) | 16 · s12 Legs | 17 · s13 Upper | 18 · s14 Lower | 19 · — | 20 · — |
| `restDay`, 3 | 14 ✓ | 15 ✓ | 16 ✓ | 17 ✓ | 18 ✓ | **19 · —** (selected, no dot) | 20 · — |
| `freshProgram`, 1 (08-31) | **31 · s0 Upper A** (selected) | 1 · s1 Lower A | 2 · — | 3 · s2 Upper B | 4 · s3 Lower B | 5 · — | 6 · — |
| `missed`, 2 (09-07) | **7 · s5 Push ✓** (default day) | 8 · s6 Pull ✓ | 9 · s7 Legs (pending) | 10 · s8 Upper ✓ | 11 · s9 Lower ✓ | 12 · — | 13 · — |
| Example E, 2 (09-14) | 14 · s2 (week 1) | 15 · — | 16 · s3 | 17 · — | 18 · s4 | 19 · — | 20 · — |

### 5.6 Card status — `HomeStats.sessionState(_:today:calendar:) -> WeekStripState` (decision 11)

The switch inside `HomeStats.weekStrip`, promoted to a function strip and card share (`weekStrip` output unchanged).
Checked in order; `.rest` is never returned for a session. The prototype has no skipped state; "Skipped" is decision 2.

| Condition | Value | Text (Shared) | Color |
|---|---|---|---|
| `status == completed` | `.completed` | "Completed" | `success` |
| `status == skipped` | `.skipped` | "Skipped" | `mu` |
| pending, dated today | `.today` | "Today" | `mu` |
| pending, dated before today | `.missed` | "Missed" | `warning` |
| pending, dated after today | `.scheduled` | `HomeText.shortDate`: "Sep 16" | `mu` |

### 5.7 Cards reachable from the seeds (targets from the stored rows; INSIGHTS step formula; Peak/Deload rows agree with the generator's Example A tests)

| Seed, tap | Card | Status | Rows (name · equipment · lb) |
|---|---|---|---|
| `midProgram`, none | Pull | Today | 2.5 table |
| `midProgram`, M 14 | Push | Completed | Dumbbell Bench Press · Dumbbells + bench · 42.5; Incline Dumbbell Press · Dumbbells + bench (incline) · 37.5; Seated Shoulder Press · Dumbbells + bench (upright) · 32.5; Pec Deck Fly · Marcy · butterfly arms · 80; Dumbbell Lateral Raise · Dumbbells · 17.5 (15 < 15.75: fast to 17.5 in week 2, then slow: week 3 = 17.5) |
| `midProgram`, W 16 | Legs | Sep 16 | Goblet Squat · Dumbbell · 52.5; Dumbbell Romanian Deadlift · Dumbbells · 52.5; Leg Extension · Marcy · leg developer · 80; Leg Curl · Marcy · leg developer · 60; Bulgarian Split Squat · Dumbbells + bench · 32.5 |
| `missed`, WK 2 then W 9 | Legs | Missed | week 2 = defaults (slow regime, floor(1/2) = 0): 50; 50; 70; 50; 30 |
| `freshProgram`, none | Upper A | Today | Dumbbell Bench Press 40; Lat Pulldown 100; Seated Shoulder Press 30; Seated Low Row 90; Dumbbell Curl 25 (week 1 = defaults) |
| `freshProgram`, WK 3 | Upper A (s8, Mon 09-14) | Sep 14 | base(3) = start + step: 42.5, 110, 32.5, 100, 27.5; ×1.05 rounded to step, halves up: 44.625 → 45; 115.5 → 120; 34.125 → 35; 105 → 110; 28.875 → 30 |
| `freshProgram`, WK 4 | Upper A (s12, Mon 09-21) | Sep 21 | base(4) = start + step·floor(3/2) = same bases; ×0.7: 29.75 → 30; 77 → 80; 22.75 → 22.5; 70 → 70; 19.25 → 20; phase line "Deload · 2 × 12 · −30% load", scheme "2×12" |

### 5.8 Text (Shared, not Engine)

Subtitle 2.1; phase line 2.3; scheme "3×12" (rows) vs "3 × 12" (phase line), as in the prototype; status 5.6; weights
`WeightDisplay.text(lb:unit:)` + " lb"/" kg" (kg one decimal: 110 → 49.9, 100 → 45.4, 47.5 → 21.5, 52.5 → 23.8, 27.5 → 12.5, 40 → 18.1).

---

## 6. Edge cases

| Case | Behavior |
|---|---|
| Month / year boundary | Windows are pure day arithmetic from the anchor; `midProgram` chips 18–24 span Jan–Feb 2027 (WK 24 = Mon 2027-02-08 … Sun 02-14, Fri 12 holds session 119). Day numbers restart at 1 inside a row (`freshProgram` WK 1: 31 · 1 · 2 · 3 · 4 · 5 · 6). |
| DST | 2026-11-01 (America/New_York, fall back) lies in `midProgram` WK 9's window (10-26 … 11-01); cells stay at local midnight through `CalendarRules.day`, and day counts go through `days(from:to:)` (a naive `/ 86 400` counts 2027-03-14 → 03-15, spring forward, as 0 days; AC-18a). |
| Mid-week start (Example E) | 5 chips for 4 program weeks; session 2 (stored week 1) is shown under WK 2; chip phases per 5.2. The Home pill on Mon 09-14 says "Week 1 · Foundation" while the Program tab shows it under "WK 2 · Foundation" — accepted (decision 1). |
| Today outside every window | Before the first session: WK 1, default day = the first session's weekday (a future date status). After the last: WK `weekCount`, default day = its first session's weekday, status "Completed" / "Missed" / "Skipped". |
| Skipped session (M4 writes it) | Dot `mu` (white when selected) like any pending session; card status "Skipped" in `mu` whatever its date. |
| Missed session | Dot `mu`; card "Missed" in `warning`. The `missed` seed shows it with `-programWeek 2 -programDay 2` (or two taps: WK 2, then W 9). |
| DEBUG preselection | `-programWeek 99` on `midProgram` (24 windows) → `.week(99)` invalid → follow today (WK 3, Tue 15); `-programWeek 2 -programDay 7` → `.day(2, 7)` invalid → follow today; `-programWeek x -programDay 2` → week nil → `.day(initialWeek, 2)` = WK 3 · W 16; `-programWeek 2` alone → `.week(2)`: Mon 7, "Push" · "Completed"; `-programDay 5` alone → WK 3, Sat 19, rest card. Returning to the tab re-applies the arguments, not today. A Release build has no parser, so the arguments are inert. |
| Leaving and returning to the tab | Any tapped week/day is discarded; the screen shows today's week and default day again (decision 4), or the DEBUG preselection. |
| Shift (M4) | The moved session's `scheduledDate` changes; the query re-fetches, cells and (if the end crosses a Sunday) `weekCount` follow. A selection left beyond the new count behaves as `.followToday` (section 3; nothing is clamped). |
| Two sessions on one day (M4 open question) | The cell and the card take the lowest index. |
| Swapped exercise (M3) | The row shows the library name and equipment of the stored `exerciseKey` and its recomputed `targetWeightLb`. |
| Unit switching (M4 Settings) | Row weights re-render in kg (5.8); nothing else changes; storage untouched. |
| Backgrounded / killed | `now` refreshes on scene-active only (midnight while foregrounded is caught at the next appear/active, as on Home). Kill → following-today state, no sheet. Seeds: frozen clock, `-units kg` overrides the unit. |
| Long names | "Dumbbell Romanian Deadlift" and "Incline Dumbbell Press" must not truncate: the name block fills the row and wraps to a second line before the equipment line (prototype `flex:1`); the rendered snapshot decides. |

---

## 7. Out of scope

Any write: shift, skip, swap, adjust, notes, starting a workout (M3/M4). Logged weights or PRs on the card (Progress,
M4). Progress and Settings tabs (placeholders remain). Exercise images. A "today" marker in the day row (the prototype
has none). Persisting the selection across tab switches or launches (decision 4). Changes to `HomeStats` or Home beyond
the `sessionState` promotion and the sheet move (Home stays pixel-identical). Release-build use of the DEBUG arguments.

---

## 8. Acceptance criteria

Screens (iPhone 15 / iOS 17.5, dark unless stated; check = matches by `/design-compare`):

1. `program` via `-seed midProgram`: matches. Deviations to skip: rows 3–5 weights 47.5 / 52.5 / 27.5 lb (the
   prototype's cap-first formula shows 55 / 55 / 35); the M1 tab pill. Everything else verbatim: subtitle, WK 1… with
   WK 3 accent-bordered, "Foundation · 3 × 12", day row 14 ✓ · **15** · 16 · 17 · 18 · 19 · 20, "Pull" · "Today", five
   rows with equipment sub-lines, "3×12", "i" buttons.
2. `-seed midProgram`, light appearance: light tokens throughout (no snapshot; spot check).
3. `-seed restDay` (no snapshot): WK 3 selected, "Foundation · 3 × 12", five `success` dots Mon–Fri, Sat 19 filled
   accent with no dot, rest card "Rest day. Light walk, stretch, eat.".
4. `-seed freshProgram`: "1-month program · Upper / Lower", exactly four chips (Foundation, Foundation, Peak,
   Deload bars), WK 1 selected, Mon 31 selected, "Upper A" · "Today", rows 40 / 100 / 30 / 90 / 25 lb.
5. `-seed missed -programWeek 2 -programDay 2` (no taps): WK 2 accent-bordered (WK 1–5 visible, no scrolling),
   "Foundation · 3 × 12", day row 7 ✓ · 8 ✓ · **9** · 10 ✓ · 11 ✓ · 12 · 13 (9 accent-filled, white dot), card "Legs" ·
   "Missed" in `warning`, rows Goblet Squat · Dumbbell · 3×12 · 50 lb; Dumbbell Romanian Deadlift · Dumbbells · 50 lb;
   Leg Extension · Marcy · leg developer · 70 lb; Leg Curl · Marcy · leg developer · 50 lb; Bulgarian Split Squat ·
   Dumbbells + bench · 30 lb. Same screen from `-seed missed` via WK 2 ("Push" · "Completed") then W 9.
6. `-seed midProgram -units kg`: rows 49.9 / 45.4 / 21.5 / 23.8 / 12.5 kg; nothing else differs from AC-1.
7. `-seed freshProgram`, tap WK 4: "Deload · 2 × 12 · −30% load", "Upper A" · "Sep 21", scheme "2×12", rows
   30 / 80 / 22.5 / 70 / 20 lb. Tap WK 3: "Peak · 4 × 8", "Sep 14", "4×8", rows 45 / 120 / 35 / 110 / 30 lb.
8. `-seed midProgram`, tap M 14: "Push" · "Completed" (`success`), rows 42.5 / 37.5 / 32.5 / 80 / 17.5 lb;
   tap W 16: "Legs" · "Sep 16" (`mu`), rows 52.5 / 52.5 / 80 / 60 / 32.5 lb.

Behavior (simulator):

9. Tapping a chip changes the border, phase line, day row and card together and selects that week's default day;
   tapping a day changes only the day fill and the card. Kill and relaunch shows AC-1 again (byte-identical with
   the status bar pinned).
9a. `-seed midProgram`: tap WK 5, then T 8 (Oct 1); switch to Home; return → WK 3, Tue 15, "Pull" · "Today" (decision 4).
    With `-seed missed -programWeek 2 -programDay 2` the same round trip (even after tapping WK 3) returns to WK 2 · W 9 · "Legs" · "Missed".
10. Scrolling the chip row to WK 24 and tapping it shows "Deload · 2 × 12 · −30% load", the week Feb 8–14 with
    Mon 8 selected (default day: earliest session in the window) and "Push" · "Feb 8"; tapping F 12 shows "Lower" ·
    "Feb 12". Switching to Home and back re-selects WK 3 and, because the row was left scrolled to the end, scrolls
    the minimum: WK 3 lands flush with the **leading** edge, not centered (decision 3); with the row already showing
    WK 1–5 no scrolling happens (relaunch shows AC-1).
10a. `-seed midProgram -programWeek 24`: WK 24 selected and wholly visible at the trailing edge on launch, "Push" ·
    "Feb 8" (week alone → its default day). `-seed midProgram -programWeek 99 -programDay 7`: identical to AC-1.
11. With WK 24 selected (AC-10a launch): "i" on row 1 opens Dumbbell Bench Press ("Chest · Dumbbells + bench", three
    cues, no images); Done (or a scrim tap) closes it and **WK 24 · Mon 8 stays selected**. On `-seed midProgram` row 1
    opens Lat Pulldown ("Back · Marcy · high pulley").
12. The Program tab (not "Coming in milestone 2") shows when the pill's Program tab is selected; the store is unchanged after every tap above.

Unit tests (Engine, `TestCalendar`, plain values from `HomeFixtures` and a new Example E fixture generated from
`TestCalendar.exampleAInputs(generatedOn: day(2026, 9, 9))`):

13. `weekAnchor` / `weekCount`: (08-31, 24) for `midProgram`, (08-31, 4) for `freshProgram`, (09-07, 5) for
    Example E, (nil, 0) for empty.
14. `weekChips`: the three rows of 5.2 exactly (count, order, phases); a window with no session → nil phase.
15. `initialWeek`: the six rows of 5.3; nil for empty.
16. `defaultDay`: 1, 5, 0, 0 per 5.4, and 0 for a week beyond `weekCount`.
17. `dayCells`: the five rows of 5.5 (dates, day numbers, session indexes); always seven; week 0 and week 99 give
    seven dated cells with nil sessions; two sessions dated the same day → the lower index.
18. `HomeStats.sessionState`: `.completed`, `.skipped` (any date), `.today`, `.missed`, `.scheduled` for `midProgram`
    sessions 10, 10-as-skipped, 11, 7, 12 on Tue 09-15; the existing `weekStrip` tests still pass unchanged.
18a. `CalendarRules.days(from:to:)`: 08-31 → 09-15 = 15; 08-31 → 2027-02-12 = 165; same day = 0; 09-15 → 09-14 = −1;
    **2027-03-13 → 03-15 = 2 and 03-14 → 03-15 = 1** (spring forward in America/New_York; `/ 86 400` would give 1 and 0).
19. Text: subtitle for (6, 5) and (1, 4); phase lines for all four phases; status text and color token per 5.6;
    kg texts of 5.8.
20. `HomeSnapshotBuilder.sessionSummaries(from:)` on the `midProgram` container's rows yields 120 summaries and
    `weekChips` count 24 with no validator in between (persistence test; no log is faulted).
21. `ClockUsageTests` still passes with `Features/Program`, the new Engine file and `Shared/ProgramTabText.swift`.
22. `DebugProgramSelection` parser (Seed suite, Debug only): `["-seed", "missed", "-programWeek", "2", "-programDay", "2"]`
    → (2, 2); `["-programWeek", "24"]` → (24, nil); `["-programDay", "5"]` → (nil, 5); `["-programWeek", "x"]` and a
    trailing `["-programWeek"]` → week nil; `["-programDay", "7"]` → (nil, 7) and `"-1"` → (nil, −1) **raw** (no range
    check, no throw); nothing → (nil, nil). Resolution (plain values): (2, 2) → `.day(2, 2)`; (24, nil) → `.week(24)`;
    (nil, 5) with `initialWeek` 3 → `.day(3, 5)`; with `weekCount` 24, `.week(99)`, `.day(2, 7)`, `.day(0, 1)` → (`initialWeek`, `defaultDay`).
23. Release safety: the Release build (`/ship-check` command) compiles, and a static scan finds the strings
    `-programWeek` / `-programDay` only in files under `App/DebugSeed/` (every file there begins with `#if DEBUG`).

---

## 9. Decisions (user, 2026-09-11)

1. **Week chips are calendar windows** from the Monday of the earliest session (5.1–5.2): a re-slotted program shows
   one more chip than `Program.weeks`; chip phase = the highest-index session in the window. → 5.1, 5.2, 6.
2. **Skipped** sessions read "Skipped" in `mu` with a `mu` dot. → 5.6, 6.
3. **Chip scroll is minimal** (revised by the user at the review): scroll only as far as needed to make the selected
   chip wholly visible, never when it already is; a chip beyond the edge lands flush with that edge. → 2.2, AC-10, AC-10a.
4. **Selection resets on every appear** of the tab (each return from another tab, relaunch, program change), not
   only on relaunch: week and day snap back to `initialWeek` / `defaultDay` for the current `now`; taps persist only
   while the tab stays visible. → 3, 6, 7, AC-9a, AC-10.
5. **DEBUG launch arguments** `-programWeek <n>` / `-programDay <d>` (0 = Monday … 6 = Sunday), parsed next to
   `-seed` under `#if DEBUG`, replace the computed initial selection on every appear; invalid values are ignored;
   Release never sees them. → 4.1, 6, AC-5, AC-9a, AC-10a, AC-22, AC-23.

From the architecture review (2026-09-11):

6. **One validity rule, no clamping** (B1): an out-of-range week or day — tapped, stale or DEBUG — behaves as
   `.followToday`; DEBUG values are written raw. → 3, 4.1, 6, AC-22.
7. **No `HomeStatsInput` on the Program tab** (B2): summaries feed `ProgramTabStats` directly; no Release fallback. → 4.1, 5, AC-20.
8. **Preselection delivery** (B3): `ProgramTabPreselection` in `Features/Program/`, an environment value defaulting to
   nil, set at the root only inside `#if DEBUG` from `DebugProgramSelection`; the view has no `#if`. → 3, 4.1, AC-23.
9. **Minimal scroll** (B4) replaces "center when off-screen" — decision 3 above.
10. **`ExerciseInfoSheet` moves to `Shared/`** with its presentation modifiers as a Shared view extension (NB1). → 2.7.
11. **`HomeStats.sessionState`** replaces a separate card-status enum (NB2). → 4.3, 5.6, AC-18.
12. **`CalendarRules.days(from:to:)`** for every day count, tested across 2027-03-14 (NB3). → 4.3, 5, AC-18a.
13. **Selection is one enum** `ProgramSelection { followToday, week, day(week:day:) }` (NB4). → 3.
14. **DEBUG `-tab <home|program|progress|settings>` launch argument** (added at planning, 2026-09-11): scripted taps are
    refused on this machine, so seeded screenshots need a way to open the Program tab. Same delivery shape as the
    preselection: `@Entry var initialTab: AppTab?` defaulting to nil, set only inside the root's `#if DEBUG` block from a
    DEBUG-only `DebugInitialTab` parser; `ShellView` applies it once on appear. Release never sees it. → 4.1, AC-23 (the
    string scan covers `-tab` too).

No open questions remain.

# M2 slice 1 — Onboarding, root routing, units, seeded states

**Status: implemented 2026-09-10 on branch `m2-onboarding`.** 162 Swift Testing tests pass on iPhone 15 / iOS 17.5
and iPhone 17 / iOS 26.5; the Release configuration builds. `ob0`–`ob5` (AC-1–6) compared against the prototype
rendered with headless Chrome: all match with the recorded deviations ("H" tile and HomeGymLog copy, "up to 52.5 lb",
17 starting-weight rows in 5.1 order, and the A6 split-name tile wrapping to two lines at phone width). Pending the
user on the device: the manual tap-through behaviors AC-8–13 and the device install. Post-review changes
(`docs/reviews/m2-onboarding-swift-review.md`): `WorkoutLogStore.start` returns the session's existing log on a
second call instead of replacing it; "Start program" shows an alert when the save fails in Release (assertion in
Debug); `isStarting` stays set after a successful start until the route flips; `DebugSeed` maps `obN` to a step
count with an explicit switch; `App.init` keeps every `DebugSeed` reference inside `#if DEBUG` (the Release build had
been broken); a Release build step was added to `/ship-check` and CLAUDE.md.
(Earlier: revised 2026-09-10 after the architecture review and researcher report; all open questions decided.)
Source: `design/BenchmarkApp.prototype.html` (markup `<!-- ONBOARDING -->`; logic `obNext`, `obDots`,
`obNextLabel`, `lengthOpts`, `freqOpts`, `dayOpts`, `expOpts`, `lenOpts`, `calibRows`, `unitOpts`, `phaseBar`,
`phaseList`, `firstSessionLabel`, `D`, `Dk`; Tweaks `startState`, `theme`, `missedDayPrompt`), `CLAUDE.md`,
`insights/INSIGHTS.md` (2026-09-10 entries), `docs/reviews/m2-onboarding-{architecture,researcher}.md`, M1 spec.
Flow labels: A1 Welcome & units (`ob0`), A2 Program length (`ob1`), A3 Frequency & days (`ob2`), A4 About you
(`ob3`), A5 Starting weights (`ob4`), A6 Generated program (`ob5`). Section 10 collects the milestone-wide
decisions later M2 slices reference.

---

## 1. Purpose

Build the six-step onboarding (A1–A6, snapshots `ob0`–`ob5`) that turns five answers into a generated,
persisted program; route the app root between onboarding and the tab shell; fix the lb/kg display rules;
and add DEBUG-only `-seed` launch states so `/design-compare` can reach every prototype snapshot without
tapping. After "Start program" the shell still shows M1's placeholders; real Home content is the next slice.

---

## 2. User-facing behavior

### 2.1 Onboarding chrome (all steps)

One screen whose content switches on the current step (decision: not a navigation stack, not a swipeable
pager); step changes animate the content while the chrome stays put.

| Element | Behavior |
|---|---|
| Back button | 36 pt `sf` circle with "‹", top-left. Shown on steps 1–5; step 0 shows an empty 36 pt spacer. Tap → previous step; draft answers are kept. |
| Dots | Five 6 pt dots, centered, 6 pt apart. Dot *i* (1…5) is accent when `step ≥ i`, else `sf2`. Step 0: none lit; step 5: all lit. |
| CTA | Full-width 52 pt accent button, radius 14, white 16 pt bold label, pinned at the bottom (18 pt above, 40 pt below) over a `bg` gradient fade that content scrolls under. Label by step: 0 "Set up my program", 1 "Continue", 2 "Continue", 3 "Continue", 4 "Generate program", 5 "Start program". Disabled (40 % opacity, no action) only on step 2 while the picked-day count ≠ frequency. |
| Content | Scrollable; 22 pt side padding; step title 28 pt bold, subtitle 14 pt `mu`. Steppers are − / + buttons around a value; no keyboard anywhere in onboarding. |

### 2.2 A1 · Welcome & units (`ob0`)

Bottom-aligned content. 44 pt accent tile with a bold white **"H"** (decided: replaces the prototype's "B"
until the M5 icon), headline "Your gym.\nYour program." (38 pt), body "HomeGymLog builds a phased strength
program around exactly what you own — then tracks every set." (decision: never "Benchmark"). Three `sf`
rows with an accent dot:

| Title | Detail (lb) | Detail (kg) |
|---|---|---|
| Dumbbells | up to 52.5 lb | up to 23.8 kg |
| Adjustable bench | flat · incline | flat · incline |
| Marcy home gym | 150 lb stack | 68 kg stack |

(Deviation from `ob0`: "up to 55 lb" becomes 52.5, the real equipment per INSIGHTS.) Below: "Units" label
and a two-segment lb / kg toggle (selected segment accent with white text, other `mu` on `sf`). Tapping a
segment changes the draft unit immediately; every weight shown on later steps re-renders (5.3). Initial
value: the stored `units` preference if one exists (restart path, M4), else lb.

### 2.3 A2 · Program length (`ob1`)

Title "How long?", subtitle "Longer programs get longer Build and Peak phases." Four option cards, one per
`months ∈ {1, 2, 3, 6}`: label "1 month" / "2 months" / "3 months" / "6 months", right-aligned "`4m` weeks",
and a 5 pt phase bar of segments (Foundation `#5b8def`, Build accent, Peak `#f59e0b`, Deload `mu`) with
flex weights = weeks per phase (M1 5.2): 1 month 2/0/1/1 (the empty Build segment is omitted, see 6),
2 months 3/2/2/1, 3 months 4/4/3/1, 6 months 9/8/6/1. Selected card: 1.5 pt accent border; others
transparent. Legend row under the cards: Foundation · Build · Peak · Deload swatches. Tap selects only.

### 2.4 A3 · Frequency & days (`ob2`)

Title "How often?", subtitle "The split is chosen for you from frequency." Segmented control "3 days" /
"4 days" / "5 days" (selected accent). Picking a frequency **replaces the day selection with
`SplitPlans.defaultWeekdays`** (3 → Mo We Fr; 4 → Mo Tu Th Fr; 5 → Mo–Fr). Card: "Split" caption, then the
split name and description verbatim from `SplitPlans.info` (M1 4.9: "Full body A / B / C", "Upper / Lower",
"Push / Pull / Legs + Upper / Lower" with their one-line descriptions).

"Training days · pick N" (N = frequency, `mu`) then seven 44 pt buttons "Mo Tu We Th Fr Sa Su" (0 = Monday).
Tapping a selected day deselects it; tapping an unselected day selects it, and when N days are already
selected the new day replaces the earliest selected day of the week (Monday first), so the count stays N
(decision 2026-09-10, replaces the prototype's no-op). Selected: accent with white text; unselected: `sf` with `tx`.
Continue is enabled iff exactly N days are selected.

### 2.5 A4 · About you (`ob3`)

Title "About you", subtitle "Used to size sessions and starting loads." (decided: verbatim until the M5
copy audit, although only session length is used by a formula). Three cards:

| Card | Controls |
|---|---|
| Body weight (lb / kg pill under the title) | Its own unit toggle, initially the welcome-step unit, changeable independently (decision 2026-09-10); the choice is saved as the `bodyWeightUnits` preference at Start program. − / + 34 pt round buttons around a 22 pt bold value. Step ±5 lb regardless of unit, bounded 50…500 lb (5.4). Default 180 lb (shows "180" / "82" kg). |
| Experience | Beginner / Intermediate / Advanced segments; default Intermediate. Stored, unused by any formula (decision). |
| Session length (caption = "N exercises per session") | 20m / 30m / 45m / 60m segments; default 45m. Caption 3 / 4 / 5 / 6 exercises. |

### 2.6 A5 · Starting weights (`ob4`) — decision: one row per program exercise

Title "Starting weights", subtitle "What you can lift for a clean 10 reps. Everything else is inferred."
One row per exercise the program will use, in the order given by
`SplitPlans.exerciseKeys(frequency:sessionLengthMinutes:)` (5.1) — **not** the prototype's five anchors
(decision, INSIGHTS "Starting weight is user-settable for every exercise"). Row: exercise name (14 pt
semibold), equipment string (11.5 pt `mu`), − / + 32 pt buttons around the weight (18 pt bold) with a small
unit suffix. Prefilled with the library default. − / + move by the equipment step in pounds (dumbbell 2.5,
Marcy 10), stopping at the equipment minimum (5 / 10) and maximum (52.5 / 150); at a bound the button does
nothing. Values persist in the draft while the user goes back and changes frequency or length; rows for
exercises no longer used are hidden, not reset.

### 2.7 A6 · Generated program (`ob5`)

Kicker "YOUR PROGRAM" (accent, uppercase), title "`M`-month program" ("1-month program" too). Card: 8 pt
phase bar (flex = weeks per phase, colors as A2), then one line per non-empty phase: swatch, name, "Week N"
or "Weeks A–B", scheme "sets × reps" (3 × 12, 4 × 10, 4 × 8, 2 × 12). Three tiles: "`total` sessions",
"`f`/wk" over the split name, "`len` min" over "per session". Footer "First session · **Name · EEE, MMM d**"
(en-US: "Push · Mon, Aug 31"). The values are a `ProgramSummary` (5.2) computed **once when step 5 is
entered** (a preview run of `ProgramGenerator.generate` with the draft inputs and `generatedOn` = the
clock's today) and held with the draft; re-entering step 5 recomputes it. Nothing is written on this step.

### 2.8 Start program

Tapping "Start program" calls the model-layer `ProgramStore.start(inputs, bodyWeightLb:, experience:,
now:, calendar:, in:) throws -> Program?` with `now`/`calendar` from the app clock (2.9). `start` returns
nil **without writing** when `ProgramStore.current(in:)` already finds a program with `archivedAt == nil`;
otherwise it generates (`generatedOn = now`'s day), applies (one `Program` with `archivedAt == nil`,
`createdAt = now`, N pending sessions, `bodyWeightLb`, `experience`) and saves. The screen then writes the
`units` preference. The screen never calls the generator on the write path, and ignores re-taps while
`start` runs. Routing (2.9) moves to the shell by itself once the program is saved. If `start` throws
(a `ProgramInputError` is a programming error; the UI cannot produce invalid inputs), debug builds stop
with the error; release builds stay on step 5 and do nothing.

### 2.9 Root routing and clock (decision, section 10)

The root is a live query on "programs with `archivedAt == nil`" (verified on iOS 17.5 and 26.5): it shows
onboarding while the result is empty and the shell otherwise, flipping on its own when `start` saves or
when M4's restart archives. There is no navigation state. One **app clock** (`now` and `calendar`) is set
at the root — the real clock, or the seed's frozen day — and everything below reads it; nothing below the
root reads the device clock or calendar directly. `generatedOn`, `createdAt` and every "today" come from it.

| Store state at launch | Root shows |
|---|---|
| No `Program` with `archivedAt == nil` | Onboarding at step 0 with default draft |
| A current program exists | Tab shell (Home). M3 adds "an in-progress log reopens the workout" to the same root. |
| Store failed to open | M1 behavior (debug crash / release error screen) |

---

## 3. States and transitions

All answers live in **one draft object owned by the flow root** (switching step content resets anything
held inside a step). The draft clamps every mutation (bounds, grids, day count). In memory only.

| Field | Values | Default | Changed on |
|---|---|---|---|
| `step` | 0…5 | 0 | CTA (+1), back (−1) |
| `units` | lb, kg | stored preference, else lb | A1 toggle |
| `months` | 1, 2, 3, 6 | 1 | A2 |
| `frequency` | 3, 4, 5 | 4 | A3 (also resets `days`) |
| `days` | set of 0…6, size ≤ frequency | `defaultWeekdays(4)` = {0,1,3,4} | A3 day buttons |
| `bodyWeightLb` | 50…500, multiple of 5 | 180 | A4 ±5 |
| `experience` | Beginner / Intermediate / Advanced | Intermediate | A4 |
| `sessionLengthMinutes` | 20, 30, 45, 60 | 45 | A4 |
| `startingWeightsLb` | key → loadable lb (user-touched keys only) | empty | A5 steppers |
| `preview` | `ProgramSummary` or none | none | set on entering step 5, cleared on leaving it |

Transitions: `4 → 5` computes `preview`; `5 → shell` runs 2.8. Back from 5 to 4 keeps everything. No
sheets, alerts or overlays. First run = empty store = onboarding. Kill during onboarding → relaunch at
step 0 with defaults (decision: no draft persistence, the flow takes under a minute). Kill after Start
program → shell. Background/foreground does not reset the draft.

---

## 4. Data

### 4.1 Read / written

| When | Read | Written |
|---|---|---|
| Launch | current-program query; `units` preference | — |
| A6 preview | static library, split plans, phase table; clock `now` and `calendar` | — |
| Start program | same, plus `ProgramStore.current` | `Program` (+ `PlannedSession` × N, pending) via `ProgramStore.start`; `units` preference |

`Program` fields written (M1 4.2): `startDate` (Monday of the generation week), `months`, `frequency`,
`trainingWeekdays` (sorted), `sessionLengthMinutes`, `bodyWeightLb` (lb, ±5 grid), `experience`,
`startingWeightsLb` (every used key, user value or default, lb), `createdAt = now`. Nothing kg is stored.

Preferences (UserDefaults via app storage, decision): key `units`, raw value of `WeightUnit` ("lb" / "kg"),
default "lb", written at Start program (and by Settings in M4). Appearance, reminder, haptics are M4.

### 4.2 Derived (never stored)

Phase ranges, total sessions, first session label (`ProgramSummary`), starting-weight row list (5.1),
kg display text (5.3), "N exercises per session".

### 4.3 Seed catalogue (DEBUG only; decision, section 10)

A Debug build parses the launch argument `-seed <name>` at app start (Release ignores it; the gate is in
code, since only the Debug configuration defines DEBUG). A seeded run uses an **in-memory store**, a
**cleared throwaway preferences suite** (writes such as `units` are discarded) and a **frozen app clock**:
`now` = 12:00 local on the reference day, device time zone. Everything below the root is identical to an
unseeded run, so tests can build a seed too. Names are exactly the prototype snapshots (the researcher's
`onboarding<N>` form is not adopted).

| Seed | Reference day | Store | Screen and draft |
|---|---|---|---|
| `onboarding` | Mon 2026-08-31 | empty | Onboarding step 0, defaults from section 3 (1 month, 4 days Mo Tu Th Fr, lb, 180, Intermediate, 45) |
| `ob1` … `ob5` | Mon 2026-08-31 | empty | Onboarding at that step with **months 6, frequency 5, days Mo–Fr**, all other defaults (prototype `snapshot(ob*)`) |
| `midProgram` | Tue 2026-09-15 | 4.4 | Tab shell, Home |
| `missed` | Tue 2026-09-15 | 4.4 | Same as `midProgram` plus the "show the missed-day prompt" flag M4 honors; until M4, indistinguishable from `midProgram` |
| unknown name | — | — | Debug build stops with a message naming the argument |

### 4.4 `midProgram` data (prototype `initial('midProgram')`, WEEK0 = Mon 2026-08-31, dayOffset 15)

Program: generated Mon 2026-08-31 (`createdAt` 2026-08-31 **06:00** local, before the first workout),
6 months, frequency 5, Mo–Fr, 45 min, body weight 180, Intermediate, lb, all starting weights = library
defaults. Hence `startDate` Mon 2026-08-31, 24 weeks (Foundation 1–9, Build 10–17, Peak 18–23, Deload 24),
120 sessions, last session 119 = Lower, Fri 2027-02-12. Session *i*: week `i/5 + 1`, day `i mod 5`,
date = 08-31 + 7(week−1) + day.

Exercises per session (45 min → 5): Push dbBench, inclineDb, shoulderPress, pecDeck, latRaise · Pull latPull,
lowRow, dbRow, rdl, curl · Legs goblet, rdl, legExt, legCurl, split · Upper chestPress, dbRow, shoulderPress,
pecDeck, skull · Lower split, legExt, legCurl, lunge, goblet. Targets (Foundation ×1.0; every default is
already in the slow regime except latRaise): week 1 = default; week 2 = default except latRaise 17.5;
week 3 = default + one step (latRaise 17.5).

Completed sessions: 0–10 except 7 (prototype), produced **only through the store functions** (the seeder
never touches `statusRaw` or `finishedAt`): `WorkoutLogStore.start(session:at:in:)` at 07:00 local on the
session's date (log, one exercise per planned exercise, `sets` pending sets at target and reps); every set
then marked `done` with `weightLb` = the **top weight** below, `reps` 12, `rpe` 7, `loggedAt` = 07:00 +
90 s × set number; then `WorkoutLogStore.finish(_:at:in:)` at 07:00 + 41 min + (10 + 3 i) s (prototype
"41:(10+3i)"), which writes `finishedAt` and `status = completed` in one save. Top weight = target − one
equipment step for i ≤ 4, + one step for i = 9, target otherwise (the prototype's ±5 lb on the real grid).
Session 7 (Legs, Wed 2026-09-09) stays `pending` → missed. Session 11 (Pull, Tue 2026-09-15) is today.

| i | Name | Date | Top weights (lb, in exercise order) |
|---|---|---|---|
| 0 | Push | Mon 08-31 | 37.5, 32.5, 27.5, 60, 12.5 |
| 1 | Pull | Tue 09-01 | 90, 80, 42.5, 47.5, 22.5 |
| 2 | Legs | Wed 09-02 | 47.5, 47.5, 60, 40, 27.5 |
| 3 | Upper | Thu 09-03 | 80, 42.5, 27.5, 60, 22.5 |
| 4 | Lower | Fri 09-04 | 27.5, 60, 40, 27.5, 47.5 |
| 5 | Push | Mon 09-07 | 40, 35, 30, 70, 17.5 |
| 6 | Pull | Tue 09-08 | 100, 90, 45, 50, 25 |
| 8 | Upper | Thu 09-10 | 90, 45, 30, 70, 25 |
| 9 | Lower | Fri 09-11 | 32.5, 80, 60, 32.5, 52.5 |
| 10 | Push | Mon 09-14 | 42.5, 37.5, 32.5, 80, 17.5 |

Derived facts later slices will assert (verified by the architecture review): done 10 / 120; streak 3
(10, 9, 8; session 7 breaks it); current week 3, Foundation; week-3 volume = session 10 only =
36 × (42.5+37.5+32.5+80+17.5) = **7 560 lb** ("7.6k"; the prototype's fake 9.6k is a known deviation);
session 0 volume 6 120 lb; PRs set by session 10: dbBench 42.5, inclineDb 37.5, shoulderPress 32.5,
pecDeck 80 (latRaise 17.5 ties session 5, not a PR).

---

## 5. Rules and formulas

### 5.1 Starting-weight rows — `SplitPlans.exerciseKeys(frequency:sessionLengthMinutes:)`

Walk `SplitPlans.days(frequency)` in order; take the first `exerciseCount(sessionLengthMinutes)` keys of
each; keep each key at its first appearance. The **generator uses the same function** for the keys it
resolves in `startingWeightsLb`, so rows and stored keys can never differ. Each row = library name,
equipment string, draft value or default, equipment kind (step/min/max).

| Frequency, length | Rows |
|---|---|
| 3, 20 (3) | dbBench, latPull, goblet, chestPress, dbRow, rdl, inclineDb, lowRow, split — 9 |
| 4, 45 (5) | dbBench, latPull, shoulderPress, lowRow, curl, goblet, rdl, legExt, legCurl, lunge, inclineDb, dbRow, pecDeck, latRaise, skull, split — 16 |
| 5, 20 (3) | dbBench, inclineDb, shoulderPress, latPull, lowRow, dbRow, goblet, rdl, legExt, chestPress, split, legCurl — 12 |
| 5, 45 (5) (`ob4` seed) | dbBench, inclineDb, shoulderPress, pecDeck, latRaise, latPull, lowRow, dbRow, rdl, curl, goblet, legExt, legCurl, split, chestPress, skull, lunge — 17 (no pushdown) |
| 5, 60 (6) | dbBench, inclineDb, shoulderPress, pecDeck, latRaise, pushdown, latPull, lowRow, dbRow, rdl, curl, goblet, legExt, legCurl, split, lunge, chestPress, skull — 18 |

### 5.2 `ProgramSummary` (Engine value; text formatting lives in Shared)

Plain value from the draft inputs, the clock's today and calendar: title months, phase ranges with scheme,
total sessions, frequency, split name, session length, first session name and date. From M1 5.2–5.4.

| Draft | Title | Phase list | Sessions | Tiles | First session (generated Mon 2026-08-31) |
|---|---|---|---|---|---|
| `ob5` seed: 6 mo, 5 d, 45 | 6-month program | Foundation Weeks 1–9 · 3 × 12; Build Weeks 10–17 · 4 × 10; Peak Weeks 18–23 · 4 × 8; Deload Week 24 · 2 × 12 | 120 | 5/wk Push / Pull / Legs + Upper / Lower · 45 min | Push · Mon, Aug 31 |
| defaults: 1 mo, 4 d, 45 | 1-month program | Foundation Weeks 1–2 · 3 × 12; Peak Week 3 · 4 × 8; Deload Week 4 · 2 × 12 | 16 | 4/wk Upper / Lower · 45 min | Upper A · Mon, Aug 31 |
| 2 mo, 3 d Mo We Fr, generated Wed 2026-09-09 | 2-month program | Foundation 1–3; Build 4–5; Peak 6–7; Deload 8 | 24 | 3/wk … | Full Body A · Wed, Sep 9 (mid-week start, M1 5.7) |

Phase-bar flex = weeks in the phase. Date label pattern "EEE, MMM d" in the device locale (en-US shown).

### 5.3 Weight display (decided; `WeightUnit` and `WeightDisplay` in Engine)

Storage and all arithmetic are pounds. The prototype's `D` rounds kg to the nearest 2.5 kg, which
collapses adjacent dumbbell steps (42.5 lb → 20 kg, 45 lb → 20 kg: a stepper tap would show no change).
Rule: `kg = lb × 0.45359237`, **shown to one decimal**; lb shown as is. Both drop a trailing ".0".
Steppers always move by the lb equipment step; the kg text changes by ≈1.1 (dumbbell) or ≈4.5 (Marcy).
The engine produces the number text for a unit; screens only append the unit suffix.

| lb | kg shown | lb | kg shown |
|---|---|---|---|
| 5 | 2.3 | 100 | 45.4 |
| 15 | 6.8 | 110 | 49.9 |
| 40 | 18.1 | 150 | 68 |
| 42.5 | 19.3 | 52.5 | 23.8 |
| 45 | 20.4 | 10 | 4.5 |

Volumes and body weight (prototype `Dk`): integer kg, `round(lb × 0.45359237)`: 180 → 82, 175 → 79,
185 → 84, 7 560 → 3 429.

### 5.4 Body weight (decided)

Stepper ±5 lb in both units (prototype `bwDown`/`bwUp`), bounded 50…500 lb (the prototype has no bounds;
at a bound the button does nothing). Display: lb integer; kg per `Dk`. Stored on `Program.bodyWeightLb`;
unused by any formula (decision).

### 5.5 Generation inputs

`ProgramInputs(months, frequency, trainingWeekdays = sorted days, sessionLengthMinutes, startingWeightsLb =
draft map, generatedOn = clock today)` with the clock's calendar. Validation failures throw
`ProgramInputError` (M1 5.1); the UI cannot produce one because A3 gates Continue and the draft clamps
every stepper to its grid.

---

## 6. Edge cases

- **Mid-week start.** Generated on a non-Monday: preview and program follow M1 5.7 (first session on the
  first training weekday ≥ today; the label shows it). On a weekend with Mo–Fr the first session is next
  Monday; `startDate` is still the past Monday. Month/year boundary: `midProgram` ends Fri 2027-02-12.
- **Midnight between A6 and Start.** `start` generates with its own `now`; the stored first session may
  differ from the preview seen a moment earlier. Accepted.
- **1-month phase bar.** Build has zero weeks; the segment is omitted (the prototype renders a zero-width
  flex item that still consumes a 3 px gap — deviation the comparison skips).
- **Day picker.** With frequency 5 and 5 days picked, tapping a sixth day does nothing. Reducing frequency
  from 5 to 3 resets to Mo We Fr (never keeps a 5-day set). Days are stored sorted.
- **Starting weights at bounds.** dbBench 52.5 → "+" does nothing; legCurl 10 → "−" does nothing. A value
  set for an exercise later dropped by a shorter session length is kept in the draft and simply not shown;
  the generator resolves only used keys (5.1).
- **Unit switching.** Toggling on A1 re-renders A3/A4/A5/A6 text only; the draft never changes.
  Switching back to lb shows the exact lb values (no round-trip loss).
- **Rounding.** kg one decimal, halves away from zero; 12.5 lb → 5.7; 17.5 → 7.9; 47.5 → 21.5; 22.5 → 10.2.
- **Backgrounded / killed / double tap.** Background keeps the draft; kill restarts onboarding at step 0; a
  program written by `start` is durable (saved before returning); re-taps are ignored and `start` refuses
  a second program, so there is never more than one.
- **Seeded launch.** `-seed` never reads or writes the on-disk store or the user's preferences; the clock
  is frozen, so `midProgram` looks identical on any real date (M3 decides how elapsed-time timers behave
  under it). Skipped sets and swaps are unreachable from onboarding; `midProgram` deliberately contains
  a missed session (7) for the Home and M4 slices.

---

## 7. Out of scope

Real Home / Program tab content (next M2 slices; they consume section 10 and 4.4). Settings' restart path
(M4). Appearance, reminder, haptics (M4). Workout flow and resume, including the workout screen's use of
`WorkoutLogStore.start`/`finish` (M3). Missed-day prompt UI (M4). Exercise images. Draft persistence.

---

## 8. Acceptance criteria

Numbering 1–22 is unchanged from the draft; 19, 20 and 22 now exercise `ProgramStore.start`; 23–27 are new.

Screens (iPhone 15 / iOS 17.5 simulator, dark appearance; check = matches by `/design-compare`):

1. `ob0` via `-seed onboarding`: matches. Deviations: tile letter "H", body copy says HomeGymLog,
   "up to 52.5 lb".
2. `ob1` via `-seed ob1`: matches; "6 months" card has the accent border; bars 2/0/1/1, 3/2/2/1,
   4/4/3/1, 9/8/6/1. Deviation: no zero-width Build segment on "1 month".
3. `ob2` via `-seed ob2`: matches; "5 days" selected, split copy for 5, Mo–Fr selected, Continue enabled.
4. `ob3` via `-seed ob3`: matches; 180 / lb, Intermediate, 45m, "5 exercises per session".
5. `ob4` via `-seed ob4`: matches for the first row (Dumbbell Bench Press · Dumbbells + bench · 40 lb)
   and row styling. Deviation: 17 rows in 5.1 order instead of the prototype's five anchors.
6. `ob5` via `-seed ob5`: matches; values exactly as the first row of 5.2.
7. Light appearance on any step uses the light tokens (no separate snapshot; spot check `ob0`).

Behavior (simulator):

8. From `-seed onboarding`, tapping through with defaults reaches A6 showing the second row of 5.2, and
   "Start program" lands on the shell's Home placeholder with no explicit navigation (the route flips).
9. On A3, deselecting one default day disables Continue (40 % opacity, no navigation); reselecting any day
   re-enables it; a fifth tap with 4 selected swaps out the earliest selected day and keeps Continue enabled.
10. Switching to kg on A1 shows "82" with caption "kg" on A4 and "18.1 kg" for Dumbbell Bench Press on
    A5; switching back shows 180 / 40 lb.
11. Killing the app on A4 and relaunching (no seed, empty store) shows A1 with defaults.
12. Without a seed and with a current program on disk, launch shows the shell; deleting the app data and
    relaunching shows A1.
13. `-seed midProgram` launches the shell (Home placeholder for now) without touching the on-disk store or
    the user's preferences: a later unseeded launch shows whatever was there before, and a `units` change
    made during a seeded run (once Settings exists) is not visible afterwards.

Unit tests (Engine/derivation, plain values):

14. `SplitPlans.exerciseKeys` for (3,20), (4,45), (5,20), (5,45), (5,60) equals the lists in 5.1, in order.
15. For all 3 × 4 frequency/length pairs, `exerciseKeys` as a set equals `GeneratedProgram.startingWeightsLb.keys`.
16. `WeightDisplay`: every row of the 5.3 table and the 6 rounding examples; lb 40 → "40", 42.5 → "42.5",
    150 lb → "68" kg; integer kg 180 → 82, 7 560 → 3 429.
17. `ProgramSummary` for the three rows of 5.2 (title, phase ranges with schemes, session count, first
    session name and date) computed with a fixed calendar.
18. Seed fixture: `midProgram` built with the fixed calendar has 120 sessions, session 119 on
    2027-02-12, 10 completed logs with the top weights of 4.4, session 7 pending on 2026-09-09, session 11
    on 2026-09-15; every logged weight is loadable; every done set has a non-nil `loggedAt`; every
    completed session satisfies `status == completed` iff `workoutLog?.finishedAt != nil`.

Persistence tests (in-memory store):

19. `ProgramStore.start` with the `ob5` draft, `now` = 2026-08-31 12:00 and the fixed calendar, writes
    exactly one `Program` (`archivedAt == nil`, `createdAt == now`, months 6, frequency 5,
    `trainingWeekdays` [0,1,2,3,4], `bodyWeightLb` 180, `experience` "Intermediate", 17 `startingWeightsLb`
    entries) and 120 pending sessions, session 0 dated 2026-08-31, and returns it.
20. `start` with a user-set A5 value (dbBench 30) stores it in `startingWeightsLb` and session 0's dbBench
    target is 30.
21. Routing predicate: empty store → onboarding; one current program → shell; only archived programs →
    onboarding.
22. `start` invoked when `ProgramStore.current(in:)` finds a program returns nil and writes nothing
    (program count unchanged, no new sessions).
23. `WorkoutLogStore.start(session:at:in:)` on a pending session creates one `WorkoutLog` (`startedAt ==
    at`, `finishedAt == nil`) linked to the session, one `LoggedExercise` per planned exercise in order
    with the planned key and target, and `sets` pending `LoggedSet`s per exercise at the target weight and
    session reps; the session stays `pending`.
24. `WorkoutLogStore.finish(_:at:in:)` sets `finishedAt == at` and `session.status == completed` in one
    save; read back through a fresh context both hold; the invariant `status == completed iff
    finishedAt != nil` holds before and after; nothing else on the session changes.
25. The seed parser maps each of `onboarding`, `ob1`…`ob5`, `midProgram`, `missed` from `-seed <name>`
    arguments to its seed with the reference day of 4.3; an absent argument yields no seed; the parsed
    `ob3` seed's initial draft is months 6, frequency 5, days [0,1,2,3,4], step 3.
26. The seeded `midProgram` container is in-memory and contains exactly one current program.
27. Static check: no source under `Features/`, `Models/` or `Engine/` reads the device clock or current
    calendar directly (a grep for the two calls finds only the root's clock setup).

---

## 9. Open questions

None. The draft's Q1–Q6 were decided 2026-09-10 (kg one decimal → 5.3; body weight ±5 lb bounded 50…500 →
5.4; tile "H" → 2.2; A4 subtitle verbatim → 2.5; restart archives → section 10; frozen seed dates → 4.3)
and recorded in INSIGHTS "M2 milestone-wide decisions".

---

## 10. Milestone-wide decisions fixed by this slice

- **Routing rule** (2.9): onboarding iff no `Program` has `archivedAt == nil`, as a live query; nothing
  navigates explicitly. M3 adds the in-progress-log route to the same root. **Restart archives, never
  deletes**: M4 sets `archivedAt = now`; logs and PRs stay for Progress, which shows the current program only.
- **One app clock** (2.9): `now` and `calendar` set once at the root, real or frozen by a seed; every
  `generatedOn`, `createdAt`, `startedAt`, `finishedAt` and "today" below comes from it.
- **Single writers.** `ProgramStore.start` owns "at most one current program" on the create side (`apply`
  stays unguarded for tests). `WorkoutLogStore.finish` is the only writer of `finishedAt` + `status ==
  completed`; `WorkoutLogStore.start` the only creator of a log with exercises and pending sets. Seeder
  and M3 use these and nothing else.
- **Draft**: one object owned by the flow root, clamped mutations, A6 preview held on it, never persisted.
- **Unit display rule** (5.3): pounds stored and stepped; preference `units` = `WeightUnit` raw value,
  default lb; kg one decimal for weights, integer for body weight and volumes; trailing ".0" dropped;
  `WeightDisplay` produces the number text, screens append the suffix. **Body weight** ±5 lb, 50…500 lb.
- **Seed catalogue** (4.3): `onboarding`, `ob1`…`ob5` (today Mon 2026-08-31), `midProgram`, `missed`
  (today Tue 2026-09-15; data and reference numbers in 4.4: 10/120 done, streak 3, week 3 Foundation,
  week volume 7 560 lb, PRs from session 10). Snapshots `home`, `home-light`, `program`, `progress`,
  `settings` are reached from `midProgram` by tab.
- **Row-order rule** (5.1): `SplitPlans.exerciseKeys(frequency:sessionLengthMinutes:)` shared by A5 and
  the generator.

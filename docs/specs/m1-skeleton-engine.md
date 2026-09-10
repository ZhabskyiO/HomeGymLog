# M1 — Skeleton and engine

**Status: implemented 2026-09-10.** 80 Swift Testing tests pass on iPhone 15 / iOS 17.5 and iPhone 17 /
iOS 26.5; shell verified by screenshot on both (dark and light, no system tab bar on iOS 26). Physical
device install pending the user's iPhone. Recorded deviations from this spec:
(a) `.cascade` delete rules are not honored on the iOS 17.5 runtime, so deletes go through
`ProgramStore.delete(_:in:)` and `WorkoutLogStore.delete(_:in:)`, which delete children explicitly;
AC-10 and AC-11 are satisfied via those helpers, and the rules stay declared for iOS 18+ and CloudKit.
(b) `ProgramStore.skip` is a `guard` no-op on a non-pending session, not a precondition.
(c) `CascadeDeleteTests` count rows on a fresh `ModelContext` so results reflect what is persisted.
(d) iOS 17.0–17.4 runtimes were not available; verified on 17.5 and 26.5 only.

Previous status: draft, revised 2026-09-09 (equipment, weight formula, open-question decisions, and the
architecture review folded in). Source: `design/BenchmarkApp.prototype.html` (option **1a**, the
clickable prototype; markup for the tab bar at `<!-- tab bar -->`, logic in the `text/x-dc` script),
`CLAUDE.md`, `insights/INSIGHTS.md`, `insights/gotchas.md`. Where this spec and the prototype disagree,
a recorded decision is cited. In particular the prototype's equipment (≤55 lb dumbbells, 5 lb steps)
and its `weightFor` function are **not** the rule; the decisions in INSIGHTS are (gotchas, "Design
export").

Note on flow labels: the design export has only option ids `1a`, `1b`, `1c` and snapshot names
(`ob0`–`ob5`, `home`, `home-light`, `program`, `progress`, `settings`, `missed`, `wo-*`, `summary`).
This spec uses those. `1b` and `1c` are the alternate homes that are not built.

---

## 1. Purpose

Stand up the app so later milestones have a place to land: the four-tab shell with the prototype's
floating pill tab bar and theme tokens, the SwiftData container and the full v1 model set, the static
exercise library with the real equipment limits, and a program generator (plus a re-slot primitive used
by both mid-week start and missed-day shift) as pure, unit-tested functions over plain values. It covers
the app frame that wraps snapshots `home`, `home-light`, `program`, `progress`, `settings` (tab bar,
background, theme), and the program-derivation logic behind `ob1`–`ob5` and the `missed` snapshot. No
real screen content ships in this milestone: each tab is a placeholder.

---

## 2. User-facing behavior

### 2.1 App launch

- The app launches directly into the tab shell on the Home tab. There is no onboarding yet (M2), so
  there is no program and nothing to display beyond placeholders.
- The window background is the theme `bg` color edge to edge, including under the status bar and
  behind the tab bar.
- The display name is **HomeGymLog** (decision: the prototype's "Benchmark" never appears in UI).

### 2.2 Tab shell

Four tabs, in this order, with these exact labels: **Home**, **Program**, **Progress**, **Settings**.

Each tab shows placeholder content only:

| Tab | Title shown | Body text |
|---|---|---|
| Home | Home | Coming in milestone 2 |
| Program | Program | Coming in milestone 2 |
| Progress | Progress | Coming in milestone 4 |
| Settings | Settings | Coming in milestone 4 |

Title uses the prototype's page-title style (large, bold, `tx` color). Body text uses `mu` color.
Placeholder content is scrollable and keeps a 110 pt bottom inset so the last line clears the floating
bar (the prototype's app scroll area has `padding: 62px 18px 110px`; the top value is the prototype's
fake status bar and is replaced by the real safe area).

Platform note (INSIGHTS, verified on iOS 17.5 and 26.5): the shell is the system tab container with its
own bar hidden on every tab, and the pill is supplied as a bottom safe-area inset so content scrolls
under it. Each tab keeps its own navigation state alive while another tab is selected. The system
"Liquid Glass" bar must never appear.

### 2.3 Floating tab bar (from `<!-- tab bar -->`)

Geometry and style, from the prototype's inline CSS, in points:

- Floats over content. 14 pt from the left and right edges, 26 pt from the bottom edge of the screen
  (measured from the screen bottom, not the home-indicator safe area; the prototype frame has no
  separate inset), 64 pt tall, corner radius 32 (full pill).
- Background `sf`, 1 pt border `bd`, shadow: black at 25 % opacity, y-offset 10, blur 30. Blurred
  backdrop (the prototype uses a 20 px backdrop blur; a system material of equivalent look is
  acceptable).
- Inner horizontal padding 8 pt. Four equal-width buttons, each 52 pt tall, laid out vertically:
  a 22×22 pt icon, 4 pt gap, then the label at 10.5 pt semibold.
- Color: the selected tab's icon and label are the accent `#e11d48`; the other three are `mu`.
- Icons (line art in the prototype's 22×22 viewbox, drawn in `currentColor`):
  - Home: a ring (radius 8, stroke 2) with a filled dot (radius 3.5) at its center.
  - Program: a 2×2 grid of rounded squares (7×7, radius 2), the bottom-right one outlined (stroke 2)
    instead of filled.
  - Progress: three rising bars (widths 4; heights 7, 12, 16; radius 1.5), left to right.
  - Settings: two horizontal slider tracks (16×2.5, radius 1.25) each with a circular knob (radius 3),
    knob right on the top track, knob left on the bottom track.
- Tapping a button selects that tab; the content area swaps to that tab's placeholder. Re-tapping the
  selected tab does nothing. There is no animation specified; a plain swap is acceptable.
- The bar is visible on all four tabs. (In later milestones the workout and summary screens replace
  the shell and hide the bar; not applicable here.)

### 2.4 Theme

Two token sets, from the `THEMES` object, plus constants:

| Token | Dark | Light | Used for |
|---|---|---|---|
| `bg` | `#0f0e10` | `#f4f2f3` | window/screen background |
| `sf` | `#1a191c` | `#ffffff` | cards, tab bar, chips |
| `sf2` | `#242226` | `#ebe8ea` | secondary surfaces, inactive pills |
| `tx` | `#f5f3f4` | `#17161a` | primary text |
| `mu` | `#8f8b91` | `#6e6a70` | muted text, unselected icons |
| `bd` | white at 8 % | black at 8 % | hairline borders |

Constants, identical in both themes:

| Name | Value |
|---|---|
| accent | `#e11d48` |
| success | `#22c55e` |
| warning | `#f59e0b` |
| phase Foundation | `#5b8def` |
| phase Build | `#e11d48` |
| phase Peak | `#f59e0b` |
| phase Deload | `#8f8b91` |

Appearance follows the system setting by default (decision: options are System / Dark / Light, default
System). In this milestone there is no way to change it in-app; toggling the simulator's appearance must
switch the whole shell between the two token sets, including the tab bar and placeholder text.

---

## 3. States and transitions

### 3.1 Shell

- `tabs.selected ∈ {home, program, progress, settings}`, initial `home`. Changed only by tapping a
  tab-bar button. Not persisted: a relaunch returns to Home.
- No sheets, overlays, or alerts exist in this milestone.

### 3.2 First run, relaunch, and store failure

- First run: empty store. The shell shows placeholders. Nothing is written.
- Relaunch after background or kill: identical to first run. There is no in-progress workout to resume
  yet; the resume rule ("on launch, an in-progress log reopens the workout screen") is M3.
- Store open (decided, INSIGHTS "ModelContainer is built explicitly in App.init"): the persistent
  container is created once at app start and the outcome is held as a success-or-failure result; the
  root switches on it. Success shows the shell. Failure: in debug builds the app stops immediately
  (crash) so the problem is seen; in release it shows a plain error screen. The app never silently
  recreates an empty store that would hide data loss. The release error screen's copy and any recovery
  action are M4.

### 3.3 Engine and model states

The engine has no UI state. A `Program` is either absent (M1 always) or present (M2+); at most one
program is *current* (`archivedAt == nil`, decision "Program.archivedAt reserved").

`PlannedSession.status` is stored with three values: `pending`, `completed`, `skipped`. Transitions:

- `pending → completed`: a workout for that session finishes (M3).
- `pending → skipped`: the skip mutation (M4 wires the button).
- Dates change only through the re-slot primitive applied to rows (section 5.6/5.7); status never
  changes because of a date change.

Invariants (decided, INSIGHTS "Status invariants have one writer"):

- A `WorkoutLog` is in progress **iff** `finishedAt == nil`. There is no separate status field.
- `PlannedSession.status == completed` **iff** `workoutLog?.finishedAt != nil`. Exactly one function
  (the finish step, M3) writes both `finishedAt` and `status` in a single save; nothing else may set
  either.
- `skipped` is stored because it is not derivable from anything else.
- One `WorkoutLog` per `PlannedSession`. Exiting a workout without finishing deletes its log so the
  session returns to `pending` and can be started again (M3 implements; the one-to-one relies on it).

Persistence tests in M1 assert these invariants hold after each write they perform.

---

## 4. Data

Everything below is defined in this milestone. In M1 only unit tests write to these models; the app
itself creates no rows. Weights are `Double` pounds everywhere; kg is never stored (decision). Durations
are `Int` seconds. Dates are calendar days unless noted.

### 4.1 Container, layering, and schema conventions

- One SwiftData container at app level, persisted on disk, containing all six models below, built
  explicitly at app start (3.2).
- An in-memory variant with the same schema for previews and tests. Tests must never touch the on-disk
  store. Platform note (INSIGHTS): tests use Swift Testing; each test builds its own in-memory container
  and its own context; no main-actor isolation is required for that.
- Project note (INSIGHTS): the Xcode project is wizard-created once with synchronized folders; any
  source file placed under `HomeGymLog/` or `HomeGymLogTests/` joins the matching target with no project
  edits (gotchas, "Xcode / build": a file outside those folders is silently in no target).
- **Engine/Model boundary (decided).** The engine takes plain values plus an explicit calendar and
  reference date and returns plain values; it never touches the store or the UI. Applying an engine
  result to stored rows is a thin model-layer step covered by persistence tests. `Phase`,
  `SessionStatus`, `SetStatus` and `PlannedExercise` are engine value types that the models reuse; the
  engine never depends on the models. The engine is organized as namespaces of static functions (no
  protocols or abstractions are introduced for it).
- **Schema conventions (decided, fixed now because changing them later is a versioned migration):**
  - Every to-one relationship is optional (`program`, `session`, `workout`, `exercise`,
    `workoutLog`).
  - No uniqueness constraints in the schema. "One `ExerciseNote` per exercise" is enforced by
    fetch-then-insert in the model layer.
  - Enumerations (`phase`, `status` fields) are stored as raw strings and exposed through a computed
    enum accessor, so predicates can filter on them on iOS 17.
  - To-many relationships are unordered; every read sorts by the stored `index` or `order`.
  - Cascade rules as in 4.8.

### 4.2 `Program`

At most one program is current (`archivedAt == nil`); older ones, if kept, are archived. Whether
"Restart program" deletes or archives, and what Progress shows across programs, is an M2 decision; the
field exists now so either choice needs no migration.

Stored:

| Field | Type / unit | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date (timestamp) | when generated |
| `archivedAt` | Date? (timestamp) | nil while current; at most one program has nil |
| `startDate` | Date (calendar day) | the **Monday** of the week containing the day the program was generated; used for week numbering (see 5.4) |
| `months` | Int | 1, 2, 3 or 6 |
| `frequency` | Int | 3, 4 or 5 sessions per week |
| `trainingWeekdays` | [Int] | 0 = Monday … 6 = Sunday (app-wide convention), sorted ascending, exactly `frequency` distinct values |
| `sessionLengthMinutes` | Int | 20, 30, 45 or 60 |
| `bodyWeightLb` | Double | collected in onboarding, unused by any formula (decision) |
| `experience` | String | "Beginner", "Intermediate" or "Advanced"; unused by any formula (decision) |
| `startingWeightsLb` | [String: Double] | exercise key → starting weight in pounds, for **every exercise that appears in the program** (decision: settable for every exercise, not only the prototype's five anchors); always fully populated at generation, the library default filling any the user did not touch |
| `sessions` | [PlannedSession] | unordered in the store; read sorted by `index`; **cascade** delete |

Derived (not stored): `weeks = months × 4`; `totalSessions = weeks × frequency`; phase ranges (5.2);
`endDate = max(sessions.scheduledDate)`.

Not on this model (decided): unit preference (lb/kg), appearance, reminder and haptics toggles are app
preferences held in user defaults via app storage, not SwiftData. They are specified in M2/M4; M1 reads
none of them.

### 4.3 `PlannedSession`

Stored:

| Field | Type / unit | Notes |
|---|---|---|
| `id` | UUID | |
| `index` | Int | 0-based position in the program; never changes |
| `week` | Int | 1-based, `index / frequency + 1`; never changes, even after a date shift |
| `phase` | String (raw) | "Foundation", "Build", "Peak", "Deload"; computed `Phase` accessor |
| `name` | String | split day name, e.g. "Full Body A", "Upper B", "Push" |
| `scheduledDate` | Date (calendar day) | **mutable** (decision: re-slot changes it) |
| `sets` | Int | from the phase table |
| `reps` | Int | from the phase table |
| `restSeconds` | Int | from the phase table |
| `exercises` | [PlannedExercise] (embedded, ordered array) | see below |
| `status` | String (raw) | "pending", "completed", "skipped"; computed `SessionStatus` accessor |
| `program` | Program? | inverse of `Program.sessions` |
| `workoutLog` | WorkoutLog? | the log that completed (or is completing) it; **cascade** delete |

`PlannedExercise` is an embedded encodable value stored inside the session, not a separate table
(decided):

| Field | Type / unit |
|---|---|
| `order` | Int, 0-based |
| `exerciseKey` | String, a library key |
| `targetWeightLb` | Double, pounds, always loadable on the exercise's equipment (multiple of its step, within min…max) |

Caveats that follow from embedding: the array's stored order is the exercise order (this is the one
place order is stored, since the array itself is a single value); embedded values get no lightweight
migration, so **every field added to `PlannedExercise` later must be optional**; a swap (M3) replaces
one element (new key plus a recomputed target from 5.5) and records the old key as `swappedFromKey` on
the `LoggedExercise`, never on the planned value.

`targetWeightLb` is computed once by the generator and stored. Everything a screen needs to render a
session (name, scheme, exercise names, weights) comes from this row plus the static library; nothing
needs to re-run the generator.

Derived: `isMissed = status == pending && scheduledDate < today` (calendar-day comparison).

### 4.4 `WorkoutLog`

| Field | Type / unit | Notes |
|---|---|---|
| `id` | UUID | |
| `startedAt` | Date (timestamp) | |
| `finishedAt` | Date? (timestamp) | nil while in progress; the only in-progress indicator |
| `session` | PlannedSession? | inverse of `PlannedSession.workoutLog` |
| `exercises` | [LoggedExercise] | unordered in the store; read sorted by `order`; **cascade** delete |

There is no `status` field (decided): in progress iff `finishedAt == nil`. One log per session;
exiting a workout without finishing deletes the log (M3), so a session never accumulates partial logs.

Derived: `durationSeconds = finishedAt − startedAt` (or now − startedAt while in progress);
`volumeLb = Σ weightLb × reps` over sets with status `done`; top weight per exercise; PRs (M3/M4).
Position for resume (which exercise, which set) is derived: the first set in order that is still
`pending`. M3 may add optional fields for the rest timer; adding optional fields is a lightweight
migration.

### 4.5 `LoggedExercise`

| Field | Type / unit | Notes |
|---|---|---|
| `id` | UUID | |
| `order` | Int | 0-based position in the workout |
| `exerciseKey` | String | library key actually performed |
| `swappedFromKey` | String? | the planned key if the user swapped; nil otherwise |
| `targetWeightLb` | Double | the planned/recomputed target at workout start |
| `workout` | WorkoutLog? | inverse |
| `sets` | [LoggedSet] | unordered in the store; read sorted by `order`; **cascade** delete |

### 4.6 `LoggedSet`

Created up front when a workout starts (the prototype builds every set at start), one per planned set.

| Field | Type / unit | Notes |
|---|---|---|
| `id` | UUID | |
| `order` | Int | 0-based |
| `weightLb` | Double | starts at the exercise target; changed by "adjust" in steps of the equipment step (decision), never below the equipment minimum |
| `reps` | Int | starts at the session's reps; changed by "adjust" |
| `status` | String (raw) | "pending", "done", "skipped"; computed `SetStatus` accessor |
| `rpe` | Int? | 6–10, nil until chosen or if skipped |
| `loggedAt` | Date? | timestamp when marked done or skipped |
| `exercise` | LoggedExercise? | inverse |

### 4.7 `ExerciseNote`

One free-text note per exercise, keyed by library key (prototype `notes[k]`). No relationships. The
"one per key" rule is not a schema constraint: the model-layer save fetches by `exerciseKey` and
updates the existing row or inserts a new one.

| Field | Type / unit |
|---|---|
| `id` | UUID |
| `exerciseKey` | String (not unique in the schema; uniqueness by fetch-then-insert) |
| `text` | String |
| `updatedAt` | Date |

### 4.8 Delete rules summary

`Program → sessions` cascade; `PlannedSession → workoutLog` cascade; `WorkoutLog → exercises` cascade;
`LoggedExercise → sets` cascade. `ExerciseNote` is independent. Deleting a program therefore deletes its
history; whether "Restart program" (M2 decision) deletes or archives is out of scope here.

### 4.9 Static library (Swift code, not database rows — decision)

Each entry: stable key, display name, muscle group, equipment description, default weight (lb),
equipment kind, three cues. Equipment kind is `marcy` when the prototype's `eq` string starts with
"Marcy", else `dumbbell`. The kind determines the load grid (decision, INSIGHTS "Equipment"):

| Kind | Real equipment | Step (lb) | Minimum (lb) | Maximum (lb) | 30 % threshold (lb, see 5.5) |
|---|---|---|---|---|---|
| `dumbbell` | adjustable dumbbells 5–52.5 lb | 2.5 | 5 | 52.5 | 15.75 |
| `marcy` | Marcy MWM-8147 stack, 15 × 10 lb plates including the top carriage plate | 10 | 10 | 150 | 45 |

A weight is *loadable* for a kind when it is a multiple of the step and within min…max. Every target
weight, starting weight and adjusted weight in the app must be loadable. The prototype's "≤55 lb, 5 lb
steps" is superseded.

| Key | Name | Muscle | Equipment | Default lb | Kind |
|---|---|---|---|---|---|
| dbBench | Dumbbell Bench Press | Chest | Dumbbells + bench | 40 | dumbbell |
| inclineDb | Incline Dumbbell Press | Chest | Dumbbells + bench (incline) | 35 | dumbbell |
| chestPress | Seated Chest Press | Chest | Marcy · press arms | 90 | marcy |
| pecDeck | Pec Deck Fly | Chest | Marcy · butterfly arms | 70 | marcy |
| latPull | Lat Pulldown | Back | Marcy · high pulley | 100 | marcy |
| lowRow | Seated Low Row | Back | Marcy · low pulley | 90 | marcy |
| dbRow | One-arm Dumbbell Row | Back | Dumbbell + bench | 45 | dumbbell |
| shoulderPress | Seated Shoulder Press | Shoulders | Dumbbells + bench (upright) | 30 | dumbbell |
| latRaise | Dumbbell Lateral Raise | Shoulders | Dumbbells | 15 | dumbbell |
| curl | Dumbbell Curl | Arms | Dumbbells | 25 | dumbbell |
| pushdown | Triceps Pushdown | Arms | Marcy · high pulley | 60 | marcy |
| skull | Dumbbell Skullcrusher | Arms | Dumbbells + bench | 25 | dumbbell |
| goblet | Goblet Squat | Legs | Dumbbell | 50 | dumbbell |
| rdl | Dumbbell Romanian Deadlift | Legs | Dumbbells | 50 | dumbbell |
| legExt | Leg Extension | Legs | Marcy · leg developer | 70 | marcy |
| legCurl | Leg Curl | Legs | Marcy · leg developer | 50 | marcy |
| split | Bulgarian Split Squat | Legs | Dumbbells + bench | 30 | dumbbell |
| lunge | Dumbbell Walking Lunge | Legs | Dumbbells | 30 | dumbbell |

Default-weight check against the new grid: all eleven dumbbell defaults (40, 35, 45, 30, 15, 25, 25, 50,
50, 30, 30) are multiples of 2.5 and within 5…52.5; all seven Marcy defaults (90, 70, 100, 90, 60, 70,
50) are multiples of 10 and within 10…150. **No default needed rounding.** Note that every Marcy default
is already above the 45 lb threshold and every dumbbell default except latRaise (15) is above 15.75, so
with defaults only latRaise ever runs in the fast regime (5.5).

Cues, verbatim from `LIB`:

- dbBench: "Feet planted, shoulder blades pinned to the bench." / "Lower to chest level, elbows ~45°." / "Press up and slightly in; don't clank the bells."
- inclineDb: "Bench at 30°, ribs down." / "Lower to upper chest." / "Drive through and finish over the shoulders."
- chestPress: "Handles at mid-chest height." / "Press straight forward, elbows soft at lockout." / "Control the return, stack never slams."
- pecDeck: "Elbows level with shoulders." / "Squeeze pads together, pause 1s." / "Open only to a light stretch."
- latPull: "Lean back 10–15°, chest up." / "Pull the bar to upper chest, elbows down." / "Let the lats stretch fully at the top."
- lowRow: "Sit tall, knees slightly bent." / "Pull to the belly, elbows tight." / "Shoulders back — no shrugging."
- dbRow: "Hand on bench, back flat." / "Row to the hip, not the chest." / "Full stretch at the bottom."
- shoulderPress: "Bells at ear height to start." / "Press up and in; don't flare the ribs." / "Lower slowly to ear height."
- latRaise: "Slight forward lean." / "Lead with elbows to shoulder height." / "Pause, then lower for 2 counts."
- curl: "Elbows pinned at your sides." / "Curl and rotate pinky up." / "Lower under control — no swinging."
- pushdown: "Elbows glued to ribs." / "Push to full lockout." / "Return only to 90°."
- skull: "Arms vertical, bells over forehead." / "Bend only at the elbows." / "Extend to lockout, squeeze."
- goblet: "Bell at chest, elbows down." / "Sit between the heels." / "Stand tall — knees track over toes."
- rdl: "Soft knees, hips back." / "Bells slide down the thighs." / "Stop at hamstring stretch, drive hips forward."
- legExt: "Pad above the ankles." / "Extend to full lockout, pause." / "Lower for 2 counts."
- legCurl: "Hips stay down." / "Curl heels to glutes." / "Slow, controlled return."
- split: "Rear foot on bench." / "Drop straight down, front knee over ankle." / "Push through the whole front foot."
- lunge: "Long stride, torso upright." / "Back knee kisses the floor." / "Drive through front heel."

Muscle-group counts (for tests): Chest 4, Back 3, Shoulders 2, Arms 3, Legs 6 = 18. Kind counts:
marcy 7 (chestPress, pecDeck, latPull, lowRow, pushdown, legExt, legCurl), dumbbell 11.

Also static, verbatim from the script:

**Split plans (`PLANS`)** — day name and its full ordered exercise list (six each):

- 3 days: Full Body A [dbBench, latPull, goblet, shoulderPress, curl, pushdown]; Full Body B [chestPress, dbRow, rdl, latRaise, legExt, skull]; Full Body C [inclineDb, lowRow, split, pecDeck, legCurl, curl].
- 4 days: Upper A [dbBench, latPull, shoulderPress, lowRow, curl, pushdown]; Lower A [goblet, rdl, legExt, legCurl, lunge, split]; Upper B [inclineDb, dbRow, pecDeck, latRaise, skull, curl]; Lower B [split, rdl, legExt, legCurl, goblet, lunge].
- 5 days: Push [dbBench, inclineDb, shoulderPress, pecDeck, latRaise, pushdown]; Pull [latPull, lowRow, dbRow, rdl, curl, latRaise]; Legs [goblet, rdl, legExt, legCurl, split, lunge]; Upper [chestPress, dbRow, shoulderPress, pecDeck, skull, curl]; Lower [split, legExt, legCurl, lunge, goblet, rdl].

**Split names and descriptions (`SPLIT`)**:

- 3: "Full body A / B / C" — "Every session hits chest, back, legs, shoulders and arms."
- 4: "Upper / Lower" — "Two upper and two lower days; each muscle twice a week."
- 5: "Push / Pull / Legs + Upper / Lower" — "Five days, every muscle hit twice with a different emphasis."

**Default training days (`DEF_DAYS`)**, 0 = Monday: 3 → [0, 2, 4] (Mon Wed Fri); 4 → [0, 1, 3, 4]
(Mon Tue Thu Fri); 5 → [0, 1, 2, 3, 4] (Mon–Fri).

**Phase table (`PHASE`)**:

| Phase | Sets × reps | Rest (s) | Multiplier | Color |
|---|---|---|---|---|
| Foundation | 3 × 12 | 75 | 1.00 | `#5b8def` |
| Build | 4 × 10 | 90 | 1.00 | `#e11d48` |
| Peak | 4 × 8 | 120 | 1.05 | `#f59e0b` |
| Deload | 2 × 12 | 60 | 0.70 | `#8f8b91` |

**Starting-weight anchors.** The prototype's `CALIB` list (dbBench, latPull, goblet, shoulderPress,
rdl, "clean 10 reps") is superseded: starting weight is settable for every exercise in the program
(decision). The five-key list is not carried into the app as a rule; M2's onboarding lists every
exercise the generated program uses, defaults prefilled.

---

## 5. Rules and formulas

All rules are pure functions of plain values: same inputs, same output, no clock, store, or UI access
(decision, "Engine/Model boundary"). Every function that touches a date takes an explicit `calendar`
and an explicit reference date (`generatedOn` or `today`) as inputs; nothing reads the device clock or
the current calendar implicitly. Tests use a fixed Gregorian calendar and time zone.

Date conventions (decided): weekday **0 = Monday … 6 = Sunday** everywhere in app code; the one
conversion from the system calendar's numbering (1 = Sunday) lives in a single engine helper. Day
arithmetic always goes through the calendar's "add N days to the start of this day" operation, never by
adding multiples of 86 400 seconds, so daylight-saving transitions cannot shift a date.

### 5.1 Generator: inputs, validation, output

`generate(inputs, calendar) throws → GeneratedProgram`.

Inputs: `months ∈ {1,2,3,6}`, `frequency ∈ {3,4,5}`, `trainingWeekdays` (distinct values in 0…6,
count == frequency), `sessionLengthMinutes ∈ {20,30,45,60}`, `startingWeightsLb` (partial map, any
library key; missing keys use the library default), `generatedOn` (a calendar day; the app passes
today), plus `calendar`.

Each starting weight must be loadable on its exercise's equipment: a multiple of the equipment step
(2.5 dumbbell / 10 Marcy), ≥ the equipment minimum (5 / 10) and ≤ the equipment maximum (52.5 / 150).
Onboarding steppers (M2) move by the equipment step and stop at min and max, so they cannot produce an
invalid value; the generator still rejects one.

Validation failures are reported by **throwing a typed error** (`ProgramInputError`, one case per rule:
unsupported months, unsupported frequency, unsupported session length, weekday count ≠ frequency,
duplicate or out-of-range weekday, unknown exercise key, unloadable starting weight). The generator
never traps on bad input, so tests can assert each case. Onboarding (M2) cannot produce any of them
(the prototype disables "Continue" until exactly `frequency` days are picked), so a thrown error is a
programming error, not a user-facing message.

Output `GeneratedProgram` is a plain value mirroring 4.2 and 4.3 without relationships or identity:
`startDate` (Monday, 5.4), `months`, `frequency`, `trainingWeekdays`, `sessionLengthMinutes`,
`startingWeightsLb` (fully resolved for every key the program uses), and `sessions`: an ordered list of
`GeneratedSession` values, each with `index`, `week`, `phase`, `name`, `scheduledDate`, `sets`, `reps`,
`restSeconds`, `exercises: [PlannedExercise]`. Body weight and experience are onboarding data the model
layer copies onto `Program` alongside the generated values. Writing a `GeneratedProgram` into a
`Program` row and its `PlannedSession` rows (all `status = pending`) is the model-layer apply step.

### 5.2 Phase split (INSIGHTS, quoted)

> Weeks = months × 4. Last week is Deload. Of the remaining R weeks: Foundation = ceil(R × 0.35),
> Peak = ceil(R × 0.25), Build = the rest.

Week `w` (1-based) of `W` weeks: Deload if `w == W`; else with `R = W − 1`, `F = ceil(0.35 R)`,
`P = ceil(0.25 R)`: Foundation if `w ≤ F`; Peak if `w > R − P`; otherwise Build.

Worked for every allowed duration:

| Months | W | R | F | P | B = R−F−P | Foundation | Build | Peak | Deload |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 4 | 3 | ceil(1.05) = 2 | ceil(0.75) = 1 | 0 | weeks 1–2 | none | week 3 | week 4 |
| 2 | 8 | 7 | ceil(2.45) = 3 | ceil(1.75) = 2 | 2 | 1–3 | 4–5 | 6–7 | 8 |
| 3 | 12 | 11 | ceil(3.85) = 4 | ceil(2.75) = 3 | 4 | 1–4 | 5–8 | 9–11 | 12 |
| 6 | 24 | 23 | ceil(8.05) = 9 | ceil(5.75) = 6 | 8 | 1–9 | 10–17 | 18–23 | 24 |

The 1-month program has **no Build phase**; the phase list for it is Foundation, Peak, Deload (the
prototype's `phaseRanges` simply omits empty phases and its length picker shows `b = 0`).

Compute `F` and `P` with integer arithmetic (`ceil(R × 35 / 100)` as integers) so no floating-point
representation of 0.35 or 0.25 can flip a ceiling. For the four allowed R values the float and integer
results agree; the integer form is required so a future duration cannot silently differ.

### 5.3 Session list

Sessions are numbered `i = 0 … W × frequency − 1`. For each:

- `week = i / frequency + 1` (integer division).
- `phase` from 5.2.
- Split day = `PLANS[frequency][i mod frequency]` (the split cycles in order, restarting every week
  because the plan count equals the frequency).
- `sets`, `reps`, `restSeconds` from the phase table for `phase`.
- Exercises: the first `n` keys of the day's list, `n` = 3 / 4 / 5 / 6 for 20 / 30 / 45 / 60 minutes,
  in list order, each with `targetWeightLb` from 5.5 for `(key, week, phase)`.
- `scheduledDate` from 5.4 and 5.7.
- `status = pending` (set by the model-layer apply step).

Session count: 1 month × 3 days = 12; 6 months × 5 days = 120.

### 5.4 Dates

`programStart` = the Monday of the week containing `generatedOn` (the week always starts on Monday
regardless of the device locale's first weekday; weekday 0 = Monday).

Base schedule: with `days` = `trainingWeekdays` sorted ascending,
`scheduledDate(i) = programStart + 7 × (week − 1) + days[i mod frequency]` days, each date being the
start of that calendar day in `calendar`.

If `generatedOn` is itself a Monday, that is the whole rule and session 0 is on `generatedOn` if Monday
is a training day. If `generatedOn` is later in the week, one or more base dates fall before
`generatedOn`; 5.7 re-slots them.

Worked example A — generated Monday 2026-09-07, 1 month, 3 days Mon/Wed/Fri, 45 min:

| i | week | phase | name | date |
|---|---|---|---|---|
| 0 | 1 | Foundation | Full Body A | Mon 2026-09-07 |
| 1 | 1 | Foundation | Full Body B | Wed 2026-09-09 |
| 2 | 1 | Foundation | Full Body C | Fri 2026-09-11 |
| 3 | 2 | Foundation | Full Body A | Mon 2026-09-14 |
| 4 | 2 | Foundation | Full Body B | Wed 2026-09-16 |
| 5 | 2 | Foundation | Full Body C | Fri 2026-09-18 |
| 6 | 3 | Peak | Full Body A | Mon 2026-09-21 |
| 7 | 3 | Peak | Full Body B | Wed 2026-09-23 |
| 8 | 3 | Peak | Full Body C | Fri 2026-09-25 |
| 9 | 4 | Deload | Full Body A | Mon 2026-09-28 |
| 10 | 4 | Deload | Full Body B | Wed 2026-09-30 |
| 11 | 4 | Deload | Full Body C | Fri 2026-10-02 |

The last session crosses a month boundary; nothing special happens, it is plain day arithmetic.

### 5.5 Weight formula (INSIGHTS, "Weight progression is step-based, slows above 30% of equipment max, cap applied last")

This **replaces** the prototype's `weightFor` (+5 lb per week, cap before multiplier). Do not copy the
script here (gotchas, "Design export").

For an exercise with equipment `step` (2.5 dumbbell / 10 Marcy), `min` (5 / 10), `max` (52.5 / 150) and
`threshold = 0.3 × max` (**15.75 / 45**), and week `k` (1-based):

1. `start` = the program's starting weight for the key if present, else the library default.
2. **Base progression.** `base(1) = start`.
   - *Fast regime:* while `base(k−1) < threshold`, `base(k) = base(k−1) + step` — one step every week.
   - *Slow regime:* from the first week `s` at which `base(s) ≥ threshold`,
     `base(k) = base(s) + step × floor((k − s) / 2)` — one step every second week, the first slow
     increment landing at week `s + 2`. (If `start ≥ threshold`, `s = 1`.)
   - The base is not capped; it may exceed `max`.
3. **Phase multiplier.** `scaled = base(k) × multiplier` (Foundation 1.0, Build 1.0, Peak 1.05,
   Deload 0.7).
4. **Round to the equipment step**, halves up: `rounded = round(scaled / step) × step`.
5. **Clamp last:** `target = clamp(rounded, min, max)`. Because the clamp is the final operation every
   target is loadable.

Arithmetic (decided, "Date and weekday conventions"): steps 3–4 are carried out on **integers** —
weights in tenths of a pound (40 lb = 400, 2.5 lb = 25) and multipliers in percent (100, 105, 70) — so
the quotient is an exact rational and "halves up" is deterministic. Binary floating point is never used
for the rounding decision; the result is converted back to pounds only at the end. Exact-half cases
that this guarantees: dumbbell 12.5 × 0.7 = 8.75 → 3.5 steps → **10**; 37.5 × 0.7 = 26.25 → 10.5 →
**27.5**; 62.5 × 0.7 = 43.75 → 17.5 → **45**; Marcy 50 × 0.7 = 35 → 3.5 → **40**.

Interpretation to confirm (recorded in INSIGHTS with the same caveat): the "30 %" in the user's
instruction is read as a **weight threshold relative to the equipment maximum** (15.75 lb for dumbbells,
45 lb for the Marcy stack), not as a fraction of the program length. The threshold comparison uses
`base(k−1) < threshold`: a Marcy base of exactly 45 is already in the slow regime; 15.75 is not on the
dumbbell grid so a dumbbell base is always strictly below or strictly above it.

**Base sequences** (`base(1…)`), the raw progression before any multiplier:

| Exercise, start | Regime | base(1) … |
|---|---|---|
| dbBench 40 (default) | slow from week 1 | 40, 40, 42.5, 42.5, 45, 45, 47.5, 47.5, 50, 50, 52.5, 52.5, 55, … , base(24) = 67.5 |
| latPull 100 (default) | slow from week 1 | 100, 100, 110, 110, 120, 120, 130, … , base(20) = 190 |
| latRaise 15 (default) | fast for one week, then slow from week 2 | 15, 17.5, 17.5, 20, 20, 22.5, 22.5, 25, … |
| goblet 50 (default) | slow from week 1 | 50, 50, 52.5, 52.5, 55, 55, … , base(10) = 60, base(18) = 70, base(24) = 77.5 |
| shoulderPress 30 (default) | slow from week 1 | 30, 30, 32.5, 32.5, 35, … |
| curl 25 (default) | slow from week 1 | 25, 25, 27.5, 27.5, 30, … |
| curl 5 (user-set minimum) | fast weeks 1–6, slow from week 6 | 5, 7.5, 10, 12.5, 15, 17.5, 17.5, 20, 20, 22.5, … |
| legCurl 10 (user-set minimum) | fast weeks 1–5, slow from week 5 | 10, 20, 30, 40, 50, 50, 60, 60, 70, … |
| chestPress 40 (user-set) | fast for one week, slow from week 2 | 40, 50, 50, 60, 60, 70, … |
| chestPress 30 (user-set) | fast weeks 1–3, slow from week 3 | 30, 40, 50, 50, 60, 60, … |

**Worked targets:**

| Exercise, start | Week, phase | base | scaled | rounded | target |
|---|---|---|---|---|---|
| dbBench 40 | 1 Foundation | 40 | 40 | 40 | **40** |
| dbBench 40 | 3 Peak (1-mo) | 42.5 | 44.625 | 45 (17.85 → 18 steps) | **45** |
| dbBench 40 | 4 Deload (1-mo) | 42.5 | 29.75 | 30 (11.9 → 12) | **30** |
| dbBench 40 | 7 Build (3-mo) | 47.5 | 47.5 | 47.5 | **47.5** |
| dbBench 40 | 24 Deload (6-mo) | 67.5 | 47.25 | 47.5 (18.9 → 19) | **47.5** |
| latPull 100 | 1 Foundation | 100 | 100 | 100 | **100** |
| latPull 100 | 3 Peak (1-mo) | 110 | 115.5 | 120 (11.55 → 12) | **120** |
| latPull 100 | 4 Deload (1-mo) | 110 | 77 | 80 (7.7 → 8) | **80** |
| latPull 100 | 20 Peak (6-mo) | 190 | 199.5 | 200 | **150** (clamped to the stack) |
| latRaise 15 | 2 Foundation | 17.5 | 17.5 | 17.5 | **17.5** (fast-regime step) |
| latRaise 15 | 4 Deload (1-mo) | 20 | 14 | 15 (5.6 → 6) | **15** |
| latRaise 15 | 6 Build (3-mo) | 22.5 | 22.5 | 22.5 | **22.5** |
| goblet 50 | 3 Peak (1-mo) | 52.5 | 55.125 | 55 (22.05 → 22) | **52.5** (clamped) |
| goblet 50 | 10 Build (6-mo) | 60 | 60 | 60 | **52.5** (clamped) |
| goblet 50 | 18 Peak (6-mo) | 70 | 73.5 | 72.5 (29.4 → 29) | **52.5** (clamped) |
| goblet 50 | 24 Deload (6-mo) | 77.5 | 54.25 | 55 (21.7 → 22) | **52.5** (clamped even in Deload) |
| shoulderPress 30 | 3 Peak | 32.5 | 34.125 | 35 (13.65 → 14) | **35** |
| shoulderPress 30 | 4 Deload | 32.5 | 22.75 | 22.5 (9.1 → 9) | **22.5** |
| curl 25 | 3 Peak | 27.5 | 28.875 | 30 (11.55 → 12) | **30** |
| curl 25 | 4 Deload | 27.5 | 19.25 | 20 (7.7 → 8) | **20** |
| curl 5 | 4 Deload (1-mo) | 12.5 | 8.75 | 10 (3.5 → half up → 4) | **10** |
| chestPress 30 | 4 Deload (1-mo) | 50 | 35 | 40 (3.5 → half up → 4) | **40** |
| legCurl 10 | 4 Deload (1-mo) | 40 | 28 | 30 (2.8 → 3) | **30** |
| legCurl 10 | 5 Foundation (2-mo) | 50 | 50 | 50 | **50** |

**On the minimum clamp.** For allowed inputs the lower clamp never engages: Deload is never before
week 4, and by week 4 a 10 lb Marcy start has climbed to 40 (→ 28 → 30) and a 5 lb dumbbell start to
12.5 (→ 8.75 → 10). Rounding alone keeps every result at or above the minimum (a Marcy `scaled` of 7
would round to 10; a dumbbell `scaled` of 3.5 would round to 2.5 and then clamp to 5, but no reachable
base produces it). The rule still applies and is tested on the round-and-clamp step in isolation:
Marcy base 10 × 0.7 = 7 → 10; dumbbell base 5 × 0.7 = 3.5 → 2.5 → clamp → 5.

**Full-session examples** — Example A (1 month, Mon/Wed/Fri, 45 min, all defaults), Full Body A
exercises dbBench, latPull, goblet, shoulderPress, curl:

| Session | Week, phase | Scheme, rest | dbBench | latPull | goblet | shoulderPress | curl |
|---|---|---|---|---|---|---|---|
| 0 | 1 Foundation | 3 × 12, 75 s | 40 | 100 | 50 | 30 | 25 |
| 3 | 2 Foundation | 3 × 12, 75 s | 40 | 100 | 50 | 30 | 25 |
| 6 | 3 Peak | 4 × 8, 120 s | 45 | 120 | 52.5 | 35 | 30 |
| 9 | 4 Deload | 2 × 12, 60 s | 30 | 80 | 37.5 | 22.5 | 20 |

(Session 9 goblet: base 52.5 × 0.7 = 36.75 → 14.7 → 15 steps → 37.5.)

### 5.6 Re-slot primitive and missed-day "shift" — recorded decisions

The prototype's "shift" button only dismisses the prompt (`missedShift = set({missedDone:true})`). The
recorded decisions (INSIGHTS "Missed-day shift", "Shift never doubles up a day", "Engine/Model
boundary") apply.

**One engine primitive serves both mid-week start (5.7) and shift:**

`reslot(slots: [SessionSlot], fromIndex, startingAt cursor: Date, inclusive: Bool, trainingWeekdays,
calendar) → [Int: Date]`

- `SessionSlot` is a plain value `{index, scheduledDate, status}` — the only three facts about a
  session the primitive needs. The caller passes every session of the program, sorted by `index`.
- The session at `fromIndex` must be `pending`. Its new date is `cursor` itself when `inclusive` is
  true (the caller has chosen that exact day, which may be a rest day), otherwise the first training
  weekday strictly after `cursor`.
- Every session with a higher `index` whose status is `pending`, in index order, takes the first
  training weekday strictly after the previously assigned date.
- Sessions that are `completed` or `skipped` are never moved and do not consume a slot; sessions with a
  lower `index` are never touched.
- The result maps `index → new scheduledDate` **only for sessions whose date actually changed**. An
  empty map means nothing moved.
- The primitive reads no store and mutates nothing. Writing the map onto `PlannedSession.scheduledDate`
  rows is the model-layer apply step, covered by persistence tests.

**Shift** (`missedSession.status == pending`, `missedSession.scheduledDate < today`):

1. If no `completed` session is dated `today`: call `reslot` with `fromIndex = missed.index`,
   `cursor = today`, `inclusive = true` — the missed session takes today, even if today is a rest day.
2. Otherwise (decided, "never doubles up"): `cursor = today`, `inclusive = false` — the missed session
   takes the first training weekday strictly after today (equivalently, cursor = that weekday with
   `inclusive = true`).
3. Apply the returned map to rows. `week`, `phase`, `name`, sets/reps/rest, exercises and `status` do
   not change. Week numbers are therefore no longer aligned with calendar weeks after a shift; that is
   accepted (INSIGHTS: "the schedule cannot be derived from index alone after a shift").

No two sessions ever share a date after a shift.

Worked example B — Example A, session 0 (Mon 09-07) missed, today Wed 09-09 (a training day, session 1
pending): map = {0: Wed 09-09, 1: Fri 09-11, 2: Mon 09-14, …, 11: Mon 10-05}. Every later session moved
one slot; the program ends one training day later (10-05 instead of 10-02).

Worked example C — Example A, session 1 (Wed 09-09) missed, today Thu 09-10 (not a training day):
map = {1: Thu 09-10}. Session 2's first training weekday after Thu 09-10 is Fri 09-11, its existing
date, so it is not in the map; nothing after moves. "Extends by one session" is the common case (today
is a training day already holding a pending session); on a rest day the moved session fills it.

Worked example D — two missed: sessions 0 (Mon) and 1 (Wed) both pending, today Fri 09-11. The prompt
(M4) offers the earliest missed session, session 0. map = {0: Fri 09-11, 1: Mon 09-14, 2: Wed 09-16, …,
11: Wed 10-07}. Both missed sessions are repaired by one call.

Worked example H (decided, "never doubles up") — Example A, session 0 (Mon 09-07) missed, session 1
completed on Wed 09-09, today still Wed 09-09. `inclusive = false`: map = {0: Fri 09-11, 2: Mon 09-14,
…, 11: Mon 10-05}. Session 1 is absent from the map and stays on 09-09.

### 5.7 Generation on a non-Monday (first training day already past) — decided

The prototype always starts on its Monday anchor `WEEK0` and never exercises this case. Decision
(INSIGHTS "Mid-week program start"): start immediately and re-slot the past.

Inside `generate`, after computing the base schedule (5.4): if any session's base date is before
`generatedOn`, call `reslot` on the base sessions (all `pending`) with `fromIndex = 0`,
`cursor = the first training weekday on or after generatedOn`, `inclusive = true`, and fold the map
into the returned `GeneratedProgram`. (Unlike a shift, the first session does not take a non-training
"today": the user is setting up, not choosing to train today.) The stored `week` values are unaffected.

Worked example E — generated Wed 2026-09-09, 1 month, Mon/Wed/Fri: base dates put session 0 on Mon
09-07 (past). Result: session 0 Wed 09-09, 1 Fri 09-11, 2 Mon 09-14, 3 Wed 09-16, …, 11 Mon 10-05.
`programStart` is still Mon 09-07 and session 2 is still `week 1` for phase and weight purposes even
though it lands in the second calendar week.

Worked example F — generated Wed 09-09, 4 days Mon/Tue/Thu/Fri: base puts sessions 0 and 1 in the
past. First training weekday ≥ Wed is Thu 09-10. Result: Upper A Thu 09-10, Lower A Fri 09-11, Upper B
Mon 09-14, Lower B Tue 09-15, Upper A (week 2) Thu 09-17, … . No session lands on Wednesday.

Worked example G — generated Sat 09-12 or Sun 09-13 with Mon/Wed/Fri: all three week-1 base dates are
past; first training weekday ≥ Saturday is Mon 09-14, so the program effectively starts the next
Monday, but `programStart` is Mon 09-07 and the first session is `week 1`. Downstream screens must use
the session's stored `week`, never `(today − programStart) / 7` (5.9).

### 5.8 Skip — recorded decision

Skip is a single model mutation, not engine logic (decided): `session.status = skipped`. No other
session changes; no date changes. Precondition: status was `pending`. A skipped session still occupies
its date (it will appear as skipped in the week strip and calendar in M2/M4; the prototype has no
skipped state to copy, so the visual is an M4 decision). Verified by a persistence test, not an engine
test.

### 5.9 Program week and end date (derived) — decided

- `endDate = max(scheduledDate)` over all sessions, recomputed after any shift.
- `currentWeek` (for M2's "Week N · Phase" header; not shown in M1) = the `week` of today's session if
  one exists, else of the next pending session, else the last week `W`. The prototype's calendar
  formula `floor((today − programStart) / 7) + 1` is **not** used: it diverges from stored `week`
  after a shift or a mid-week start.

---

## 6. Edge cases

- **Week boundary.** A 5-day program has sessions Mon–Fri; the Sat/Sun gap is a plain two-day gap.
  The week strip and calendar (M2/M4) map a date to a session by same-calendar-day match; a session
  can only ever be on one date.
- **Month and year boundaries.** Dates are day arithmetic; Example A's session 11 is 2026-10-02.
  A 6-month program generated 2026-09-07 ends in February 2027 (session 119 = programStart +
  23 × 7 + 4 = Fri 2027-02-19 for Mon–Fri). Tests must include a program that crosses a year end.
- **Daylight-saving transitions.** Because day arithmetic goes through the calendar, a session on the
  far side of a DST change is still local midnight of its day. Test: in a US time zone, a program
  generated Mon 2026-10-26 (Mon/Wed/Fri) has session 3 on Mon 2026-11-02 — the Monday after DST ends
  on 2026-11-01 — and its `scheduledDate` equals the calendar's start of that day, not 7 × 86 400 s
  after session 0 (which would be 23:00 on 11-01).
- **Weekday numbering.** 0 = Monday app-wide; the single helper that converts from the calendar's
  1 = Sunday numbering is tested for all seven days (Sunday → 6, Monday → 0, Saturday → 5).
- **Day comparisons (decided; accepted v1 limitation).** "Before today", "today", "after today" are
  calendar-day comparisons in the device's current calendar, never raw timestamp comparisons.
  `scheduledDate` is stored as local midnight on the day it was set. A time-zone change that moves a
  stored midnight into the neighboring day is an accepted limitation for v1 (single user, home gym);
  if it bites, store year/month/day components.
- **Caps.** Dumbbell targets never exceed 52.5 lb and Marcy targets never exceed 150 lb, in any phase,
  because the clamp is the last operation. With default starts, goblet and rdl (50) reach the dumbbell
  cap by week 5 (base 55 → 52.5) and stay there; latPull (100) reaches the Marcy cap around week 11
  (base 150). Peak's ×1.05 can only push a value *toward* the cap, never past it (goblet week 3:
  55.125 → 55 → 52.5).
- **Minimums.** Never below 5 lb dumbbell / 10 lb Marcy. For allowed inputs the lower clamp is never
  reached (5.5); it is still enforced.
- **Rounding.** Always to the equipment step, halves up, computed on integer tenths and percents:
  dumbbells 44.625 → 45, 29.75 → 30, 8.75 → 10, 26.25 → 27.5, 43.75 → 45, 36.75 → 37.5; Marcy
  115.5 → 120, 77 → 80, 35 → 40, 28 → 30.
- **Threshold on the grid.** A Marcy start of exactly 45 is in the slow regime from week 1; a start of
  40 takes one fast step to 50 and is slow from week 2. No dumbbell base can equal 15.75; 15 is fast,
  17.5 is slow.
- **Unbounded base.** `base(k)` is not capped and keeps growing (dbBench default reaches 67.5 by week
  24); only the target is clamped. This matters for swaps and for any future "de-cap" of equipment.
- **1-month program** has no Build weeks; phase ranges for it are exactly three entries.
- **Session length vs list length.** Every plan day lists six exercises, so `n ≤ 6` never truncates
  more than the list has. Lower B in the 4-day split and Lower in the 5-day split reuse keys from
  other days (goblet, rdl, legExt, legCurl); within one session keys are always distinct.
- **Skipped sets / adjusted sets / RPE.** Modeled (`LoggedSet.status`, `weightLb`, `reps`, `rpe`) but
  not produced in M1. The adjust stepper (M3) moves `weightLb` by the equipment step (2.5 / 10) and
  stops at the equipment minimum and maximum (decision), not by the prototype's fixed 5.
- **Swapped exercises.** Swap candidates are "same muscle group, not already in the session, weight
  from the same formula" (INSIGHTS). The formula must therefore be callable for any
  `(key, week, phase)`, not only for keys in the plan; the swapped-in exercise uses its own starting
  weight (user-set if present in `startingWeightsLb`, else its library default) and its own equipment
  grid. The swap writes the new `PlannedExercise` element on the session and `swappedFromKey` on the
  `LoggedExercise`. Not wired until M3.
- **Missed sessions.** A session is missed when `pending` and dated before today. Shift and skip
  behave as in 5.6 and 5.8, including the completed-today case (example H). Re-slotting never moves a
  `completed` or `skipped` session and never returns an unchanged date.
- **Unit switching.** Storage is pounds; nothing in M1 displays a weight. kg conversion is display-only
  and specified in M2 (the prototype's `D` rounds to 2.5 kg; a 2.5 lb dumbbell step is ~1.1 kg, so
  M2 must decide the kg display rounding for dumbbells — noted there, not here).
- **Backgrounded or killed.** The shell has no state worth preserving; relaunch returns to Home. The
  store must reopen with whatever tests or later milestones wrote.
- **Generator called twice with the same inputs** returns identical output (including dates); tests
  rely on this.
- **Invalid inputs** (e.g. 5 training days with frequency 4, a 7-week duration, a starting weight of
  41 lb for a dumbbell exercise or 55 lb for a Marcy exercise, a starting weight above 52.5 / 150 or
  below 5 / 10, an unknown exercise key) make `generate` throw the matching `ProgramInputError` case,
  never silently coerce and never trap.
- **Second current program.** The model layer must not leave two programs with `archivedAt == nil`;
  how a restart archives or deletes the old one is M2.

---

## 7. Out of scope

- Onboarding screens `ob0`–`ob5` (the starting-weight steppers for every program exercise, day picker,
  program preview). M2.
- Real Home and Program content (greeting, stat tiles, week strip, today card, week chips). M2.
- Restart semantics (archive vs delete) and cross-program Progress. M2.
- Starting, logging, adjusting, swapping, rest timer, summary, resume-after-kill, the finish step that
  writes `finishedAt` and `status` together, deleting an unfinished log on exit. M3.
- Progress charts, calendar, PR list, streak, the missed-day prompt UI and when it appears, Settings
  behavior (units, appearance picker, reminder, haptics), the release-build store-error screen copy. M4.
- Local notifications, Live Activities, haptics, export, icon. M4/M5.
- CloudKit sync, kg-native progression, user-created exercises, exercise images.
- The alternate home layouts `1b` and `1c`.

---

## 8. Acceptance criteria

Shell (simulator, and on the user's iPhone):

1. The app builds, launches on an iPhone simulator, and installs and launches on the user's iPhone with
   display name "HomeGymLog" and bundle id `com.zhabskyi.homegymlog`.
2. On launch the Home tab is selected; a floating pill tab bar is visible with labels Home, Program,
   Progress, Settings in that order; the selected item is `#e11d48`, the others `mu`. No system tab
   bar is visible on any tab (on iOS 26 the Liquid Glass bar does not appear).
3. Tapping each tab shows that tab's title and its "Coming in milestone N" text (2, 2, 4, 4).
4. The bar's frame is 14 pt from each side, 26 pt from the bottom, 64 pt tall, radius 32, `sf`
   background with a 1 pt `bd` border and a drop shadow; item icons are 22 pt with a 10.5 pt semibold
   label 4 pt below.
5. Switching the simulator between light and dark appearance changes background to `#0f0e10` /
   `#f4f2f3`, tab bar to `#1a191c` / `#ffffff`, text to `#f5f3f4` / `#17161a`, muted to `#8f8b91` /
   `#6e6a70`, without relaunch. No in-app control for appearance exists yet.
6. The string "Benchmark" does not appear anywhere in the app bundle's UI strings.
7. Killing and relaunching the app returns to the Home placeholder with no error.
8. The container is created once at app start and its outcome is held as a result the root switches
   on; the success path shows the shell. (The failure path is exercised by inspection or a debug-only
   switch, not by corrupting a store.)

Persistence (Swift Testing, each test on its own in-memory container and context):

9. All six models can be inserted, fetched, and round-tripped with the fields in section 4; every
   to-one relationship is optional; `phase` and every `status` field round-trip as raw strings and
   through their computed enum accessors; fetching `sessions`, `exercises` and `sets` and sorting by
   `index`/`order` returns the inserted order.
10. Deleting a `Program` deletes its `PlannedSession`s, their `WorkoutLog`s, `LoggedExercise`s and
    `LoggedSet`s; an `ExerciseNote` survives.
11. Deleting a `WorkoutLog` deletes its exercises and sets but not the `PlannedSession`.
12. Saving a note for the same `exerciseKey` twice through the model-layer save leaves exactly one
    `ExerciseNote` row for that key, with the second text.
13. Applying a `GeneratedProgram` creates one `Program` (`archivedAt == nil`) and one `PlannedSession`
    per generated session with `status = pending`; reading them back sorted by `index` reproduces the
    generated values field for field, including the embedded `PlannedExercise` arrays in order.
14. Applying a re-slot map updates `scheduledDate` on exactly the listed indices and nothing else.
15. Skip: setting a pending session to `skipped` changes no other field on that session and nothing on
    any other session.
16. Status invariants: a `WorkoutLog` with `finishedAt == nil` is reported in progress; writing
    `finishedAt` and `status = completed` together yields `status == completed` iff
    `workoutLog?.finishedAt != nil`; deleting an unfinished log leaves the session `pending`.

Library (unit tests):

17. The library has exactly 18 entries with the keys, names, muscle groups, equipment strings, default
    weights, and kinds in 4.9; every entry has exactly three cues; muscle-group counts are
    Chest 4, Back 3, Shoulders 2, Arms 3, Legs 6.
18. Equipment grid: `dumbbell` step 2.5, min 5, max 52.5, threshold 15.75; `marcy` step 10, min 10,
    max 150, threshold 45; the seven Marcy keys are chestPress, pecDeck, latPull, lowRow, pushdown,
    legExt, legCurl.
19. Every library default weight is loadable on its own equipment (multiple of the step, within
    min…max).
20. Every key referenced by `PLANS` exists in the library; every plan day lists six distinct keys;
    `DEF_DAYS[f]` has `f` entries.

Phase split (unit tests):

21. `phaseOf(week:, weeks:)` matches the table in 5.2 for all 4, 8, 12 and 24 weeks (every week
    checked, not just boundaries).
22. Phase ranges for 1 month are [Foundation 1–2, Peak 3, Deload 4]; for 6 months [Foundation 1–9,
    Build 10–17, Peak 18–23, Deload 24].

Weights (unit tests):

23. Base sequences: every row of the "Base sequences" table in 5.5 for its listed weeks (dbBench 40
    weeks 1–7 and 24; latPull 100 weeks 1–5 and 20; latRaise 15 weeks 1–8; curl 5 weeks 1–10;
    legCurl 10 weeks 1–9; chestPress 40 weeks 1–6; chestPress 30 weeks 1–6).
24. Targets: every row of the "Worked targets" table in 5.5 produces the stated result, including the
    clamped goblet rows (52.5) and latPull week 20 (150).
25. Exact halves round up on the integer path: dumbbell 12.5 × 0.7 → 10, 37.5 × 0.7 → 27.5,
    62.5 × 0.7 → 45; Marcy 50 × 0.7 → 40. The round-and-clamp step in isolation yields 10 for Marcy
    base 10 × 0.7 and 5 for dumbbell base 5 × 0.7.
26. A user-set starting weight overrides the default for any key (dbBench 30 at week 1 → 30; pushdown
    40 at week 2 → 50 via the fast regime), and a missing key falls back to the library default.
27. Every generated target is loadable: a multiple of its equipment step within min…max, for all
    sessions of all 4 × 3 × 4 duration/frequency/length combinations with default starts.

Generator (unit tests, fixed Gregorian calendar and time zone):

28. Session count is `months × 4 × frequency` (12 for 1 mo × 3, 120 for 6 mo × 5); indices are
    0…n−1 in order; `week = index / frequency + 1`.
29. Names cycle through the split in order; sets/reps/rest match the session's phase.
30. Exercise count is 3/4/5/6 for 20/30/45/60 minutes and equals the first n keys of the plan day;
    each target weight equals the formula for `(key, week, phase)`.
31. Example A (generated Mon 2026-09-07) produces exactly the twelve dates in 5.4 and the four
    full-session rows in 5.5.
32. `startDate` is the Monday of the generation week for each weekday Mon…Sun; a Sunday generation
    yields the preceding Monday; the weekday helper maps the calendar's Sunday…Saturday to 6, 0…5.
33. Examples E, F and G (mid-week generation) produce the stated dates, with no session before the
    generation day and no session on a non-training weekday; `week` values are unchanged from the
    Monday case.
34. A 6-month, 5-day program generated 2026-09-07 ends Fri 2027-02-19 (crosses a year boundary).
35. DST: in a US time zone, a program generated Mon 2026-10-26 (Mon/Wed/Fri) has session 3 dated the
    calendar start of Mon 2026-11-02.
36. Same inputs produce identical output on repeated calls.
37. Each invalid input in 5.1 (weekday count ≠ frequency, duplicate or out-of-range weekday,
    unsupported months/frequency/length, unknown exercise key, unloadable starting weight) makes
    `generate` throw the matching `ProgramInputError` case.
38. `startingWeightsLb` on the generated program contains an entry for every exercise key used by any
    session, and no others.

Re-slot primitive (unit tests on plain `SessionSlot` values):

39. Example B: `fromIndex 0`, cursor Wed 09-09, inclusive, returns {0: 09-09, 1: 09-11, …, 11: 10-05};
    applying it leaves no two sessions on one date.
40. Example C: `fromIndex 1`, cursor Thu 09-10, inclusive, returns exactly {1: 09-10}.
41. Example D: `fromIndex 0`, cursor Fri 09-11, inclusive, returns twelve entries ending {11: 10-07}.
42. Example H: with slot 1 `completed`, `fromIndex 0`, cursor Wed 09-09, not inclusive, returns
    {0: 09-11, 2: 09-14, …, 11: 10-05} and omits index 1.
43. `completed` and `skipped` slots after `fromIndex` are never in the map and never consume a slot;
    slots before `fromIndex` are never in the map; an unchanged date is never in the map; the input
    array is not mutated.

---

## 9. Open questions

**Q1. The "30 %" threshold interpretation.** INSIGHTS records it as a weight threshold relative to the
equipment maximum (15.75 lb dumbbell, 45 lb Marcy) and asks to confirm with the user if a result looks
off. With library defaults only latRaise (15) is ever in the fast regime; every other exercise slows
from week 1. If the user expected a faster early ramp for the defaults, the alternative reading is a
fraction of the program length (fast for the first 30 % of weeks). *Default:* the recorded weight
threshold; tests encode it.

No other open questions. Q2–Q6 from the first draft are decided and folded into 3.2, 5.6, 5.7, 5.9 and
section 6; the architecture review's decisions are folded into 3.2, 3.3, 4.1–4.8, 5.1, 5.5–5.8 and
section 8.

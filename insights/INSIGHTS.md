# Insights

Durable learnings about this project: architecture decisions, why they were made, and patterns that
worked. Read at the start of every session. Add an entry when a decision is made or changed.
Keep entries short. Date them. Newest at the top within each section.

## Architecture decisions

### 2026-09-10 — Open for M4: does an occupied day block re-slotting?
`Reslot` steps over completed and skipped sessions without reserving their day, exactly as the M1 spec says,
so a pending session can be re-dated onto a day a completed or skipped session already holds (only when that
session is dated after the cursor: a future session skipped, or finished early). The same spec also says no
two sessions share a date. M4's missed-day work must decide; a Reslot test documents the current behavior.
Model-layer note: `apply(reslotMap:)`, `skip`, and both `delete` helpers do not save; callers must
`try context.save()` explicitly (never rely on autosave, per "every set is written immediately").

### 2026-09-10 — Deletes go through explicit model-layer helpers, not cascade rules
The iOS 17.5 runtime ignores `.cascade` (see gotchas). `ProgramStore.delete(_:in:)` removes sessions, logs,
exercises and sets before the program; `WorkoutLogStore.delete(_:in:)` removes exercises and sets before the
log. M2's restart path and M3's exit-without-finish must call these, never `context.delete` on a parent
directly. The `.cascade` declarations remain because they are correct on iOS 18+ and required for CloudKit.

### 2026-09-09 — Engine/Model boundary (from the M1 architecture review)
`Engine/` takes plain values plus an explicit `Calendar` and `today`/`generatedOn` dates, and returns plain values
(a generated program, or an index → date map for re-slotting). It never imports SwiftData or SwiftUI. Applying a
result to `@Model` rows is a thin step in `Models/`, tested by persistence tests. `Phase`, `SessionStatus`,
`SetStatus`, and `PlannedExercise` are Engine types; models depend on Engine, never the reverse. Skip is a single
model mutation, not Engine logic. Generator input validation `throws` a typed error (testable), never traps.
Analogy: Engine is a reducer over plain objects returning a patch; the model layer is the thunk that writes it.

### 2026-09-09 — Schema shape chosen for CloudKit readiness and iOS 17 delete safety
All to-one relationships are optional (`Program?`, `PlannedSession?`, `WorkoutLog?`, `LoggedExercise?`); no
`#Attribute(.unique)` (uniqueness such as one `ExerciseNote` per exercise is enforced by fetch-then-insert); enums
are stored as raw `String` with a computed enum accessor so `#Predicate` works on iOS 17. To-many relationships
are unordered; every read sorts by the stored `index`/`order`. Changing any of these after users have data would
be a versioned migration, so they are fixed now. Cascade rules stay as specified.

### 2026-09-09 — PlannedExercise is an embedded Codable value on PlannedSession
Not a separate `@Model`. Swap replaces one element (key + recomputed target) and records the old key on the
`LoggedExercise`. Embedded values get no lightweight migration, so every field added later must be optional.

### 2026-09-09 — Status invariants have one writer
`WorkoutLog` is in progress iff `finishedAt == nil` (no separate status field). `PlannedSession.status ==
.completed` iff `workoutLog?.finishedAt != nil`; the single finish function (M3) writes both in one save.
`.skipped` is stored because it is not derivable. One `WorkoutLog` per `PlannedSession`; exiting a workout
without finishing deletes its log so the session can be started again (M3 implements; the 1:1 depends on it).

### 2026-09-09 — Preferences live in UserDefaults via @AppStorage, not SwiftData
Units, appearance, reminder, haptics. Analogy: `useState` backed by `localStorage`.

### 2026-09-09 — ModelContainer is built explicitly in App.init
`ModelContainer(for: Schema, configurations:)` wrapped in a `Result`, root view switches on it, so an open failure
can show an error screen in release. `.modelContainer(for:)` on the App body is not used because it traps.

### 2026-09-09 — Date and weekday conventions
Weekday 0 = Monday everywhere in app code; the `Calendar.weekday` (1 = Sunday) conversion lives in one Engine
helper. Day arithmetic goes through `calendar.date(byAdding: .day, ...)` from `startOfDay`, never `+ 86400 × n`.
Weight rounding is done in integer tenths of a pound with percent multipliers, never in floating point, so exact
halves round predictably. Tests use a fixed Gregorian calendar and time zone.

### 2026-09-09 — Program.archivedAt reserved; restart semantics decided in M2
`Program` carries `archivedAt: Date?` from day one so "Build a new program" can either archive (keep history) or
delete without a migration. At most one program with `archivedAt == nil`. Whether restart deletes or archives,
and what Progress shows across programs, is an M2 decision.

### 2026-09-09 — Equipment: dumbbells 5–52.5 lb in 2.5 lb steps; Marcy MWM-8147 stack 10–150 lb in 10 lb plates
Replaces the prototype's "≤55 lb / 5 lb steps" assumption. The Marcy stack is 15 plates × 10 lb (14 numbered
plus the top carriage plate), so the minimum load is 10 lb and every load is a multiple of 10. Equipment step:
dumbbell 2.5, Marcy 10. Equipment minimum: 5 / 10. Equipment maximum: 52.5 / 150. All steppers (onboarding
starting weights, the adjust sheet) move by the equipment step, not the prototype's fixed 5.

### 2026-09-09 — Weight progression is step-based, slows above 30% of equipment max, cap applied last
Replaces the prototype's "+5 lb per week, cap before multiplier" formula. For an exercise with equipment step
`step` (2.5 / 10), maximum `max` (52.5 / 150) and `threshold = 0.3 × max` (15.75 / 45):

- `base(1) = start` (user's starting weight, else library default).
- Fast regime: while `base(k−1) < threshold`, `base(k) = base(k−1) + step` every week.
- Slow regime: from the first week `s` where `base(s) ≥ threshold`, `base(k) = base(s) + step × floor((k − s) / 2)`,
  i.e. one step every second week, the first slow increment landing at week s+2.
- `target(k) = clamp(roundToStep(base(k) × phaseMultiplier), min, max)` with Peak ×1.05, Deload ×0.7,
  Foundation and Build ×1.0. Rounding is to the equipment step, halves up. The clamp is the last operation, so a
  target is always loadable.

Worked: dbBench start 40 (already ≥ 15.75, so slow from week 1): base = 40, 40, 42.5, 42.5, 45, 45, … ;
week 3 Peak → 42.5 × 1.05 = 44.625 → 45; week 4 Deload → 42.5 × 0.7 = 29.75 → 30. latPull start 100: base
100, 100, 110, 110, 120, … ; week 3 Peak → 110 × 1.05 = 115.5 → 120. latRaise start 15 (< 15.75): week 2 = 17.5
(fast), now ≥ threshold so slow from week 2: 17.5, 17.5, 20, 20, 22.5, … .
This encodes the user's instruction "for the first 30% of the weight of the machine +2.5 dumbbells / +10 Marcy,
after that increase every second week"; the 30% is read as a weight threshold relative to the equipment
maximum, not as a fraction of the program length. Confirm with the user if a result looks off.

### 2026-09-09 — Starting weight is user-settable for every exercise
Not only the five prototype anchors. The engine accepts a starting weight for any exercise key; the library
default is the fallback. Onboarding (M2) lists every exercise in the generated program with defaults prefilled.

### 2026-09-09 — Mid-week program start: start immediately, re-slot the past
Base schedule is Monday-anchored (`programStart` = Monday of the generation week). Any session whose base date is
before the generation day is re-slotted, in order, onto training weekdays on or after the generation day; every
later session takes the next training weekday. `week` stays index-based (session i is in week i / frequency + 1)
for phase and weight purposes even when it lands in a later calendar week. Screens must use a session's stored
`week`, never `(today − programStart) / 7`. Current week for the header (M2) = week of today's session, else of
the next pending session, else the last week.

### 2026-09-09 — Shift never doubles up a day
If today already holds a completed session, "shift" dates the missed session on the first training weekday
strictly after today, and later pending sessions follow. Otherwise the missed session takes today. Completed and
skipped sessions never move; sessions earlier than the missed one never move.

### 2026-09-09 — Accepted v1 limitations (from the M1 spec's open questions)
Only the iOS 17.5, 18.0 and 26.5 simulator runtimes are installed; the schema's Codable collections
(`[PlannedExercise]`, `[Int]`, `[String: Double]`) were verified on 17.5 and 26.5, not on 17.0–17.4. The user's
phone is the effective floor. If a 17.0 runtime is ever installed, run the persistence suites on it once.
Scheduled dates are stored as local midnight and compared by calendar day; a time-zone change may shift a day.
If the on-disk store fails to open: crash in debug, plain error screen in release, never silently recreate an
empty store (formalized in M4).

### 2026-09-09 — Xcode project is wizard-created once; synchronized folders do the rest
`HomeGymLog/` and `HomeGymLogTests/` are `PBXFileSystemSynchronizedRootGroup`s. Any `.swift` written under them
(nested subfolders included) is compiled by the matching target with no pbxproj edit; verified with xcodebuild
on the iOS 17.5 simulator. No xcodegen or tuist. Keep the Xcode 26 defaults: `SWIFT_VERSION = 5.0`,
`SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (app target). Do not move to
Swift 6 language mode; it only adds friction with SwiftData's non-Sendable `ModelContext`.
Observed 2026-09-10 after Step 0 of M1: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set on the **app target only**
(both Debug and Release); the `HomeGymLogTests` target has no default isolation. Both targets: iOS 17.0,
`SUPPORTED_PLATFORMS = iphoneos iphonesimulator`, `TARGETED_DEVICE_FAMILY = 1`. Shared scheme lives at
`HomeGymLog.xcodeproj/xcshareddata/xcschemes/HomeGymLog.xcscheme`.

### 2026-09-09 — Tab bar is TabView + hidden system bar + safeAreaInset pill
`TabView(selection:)` keeps per-tab state and each tab's `NavigationStack` alive (like keeping every panel
mounted). Each tab's `NavigationStack` gets `.toolbar(.hidden, for: .tabBar)`; the pill is supplied through
`.safeAreaInset(edge: .bottom)` so content scrolls under it. Verified to render identically on iOS 17.5 and
iOS 26.5; the iOS 26 Liquid Glass tab bar never appears. All APIs iOS 16 or earlier.

### 2026-09-09 — Tests: Swift Testing, in-memory ModelContainer per test; @MainActor only where app-target code is called
`ModelContext` itself is not `@MainActor` (only `ModelContainer.mainContext` is), so raw SwiftData calls need no
isolation in tests. But the app target has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so every app-target type
(`AppSchema`, the stores, `@Model` classes) is main-actor-isolated; persistence suites and the shared
`makeTestStore()` helper are declared `@MainActor`. Engine types are `nonisolated` so Engine suites need nothing.
Each test builds `ModelConfiguration(isStoredInMemoryOnly: true)` and its own `ModelContext`. Verified on iOS 17.5.
Step 0 of M1 records which targets actually carry the isolation setting.

### 2026-09-09 — Missed-day "shift" re-slots to the next training weekdays
The prototype's button does nothing. Chosen behavior: the missed session is dated today; all later sessions
keep their order and take the next scheduled training weekdays in sequence, so the program end typically
extends by one session (not when today is a rest day: the moved session fills it and nothing else moves).
This keeps sessions on training days only and never doubles up a day (see the entry above for the case
where today's session is already completed). "Skip" only marks the
session skipped. Implication: `PlannedSession.scheduledDate` is mutable and the schedule cannot be derived
from index alone after a shift.

### 2026-09-09 — Product name is HomeGymLog, not Benchmark
Display name HomeGymLog, bundle id com.zhabskyi.homegymlog. The design's "Benchmark" branding is a
prototype artifact. Do not put the word Benchmark in UI strings.

### 2026-09-09 — SwiftUI + SwiftData over Expo/React Native
The original plan was Expo with expo-sqlite and Drizzle. Dropped because the app is iPhone-only, so the
cross-platform benefit is gone, and the features a gym app wants (Live Activity rest timer, HealthKit,
widgets, CloudKit sync) are native-only surfaces. The user knows React/TS, not Swift, and accepted the
learning curve. Not a hybrid: no native modules bolted onto Expo.

### 2026-09-09 — Pounds are canonical
All equipment increments (2.5 lb dumbbells, 10 lb Marcy plates) and the program's weight formula are pound-native. The prototype's kg mode is
display-only rounding to 2.5 kg. Storing kg would force reconversion rounding everywhere. Store `Double`
pounds; convert for display. A kg-native progression is a v2 concern.

### 2026-09-09 — Exercise library is static Swift, not SwiftData rows
18 exercises, fixed at ship time, no user-created exercises in the design. Static structs keyed by a stable
string id avoid seeding, migration, and orphaned-history problems. Logs store the key.

### 2026-09-09 — Planned sessions are persisted, not derived
The prototype derives the whole schedule on every render. We persist `PlannedSession` rows because swaps
change one session's exercises and missed-day shifts change dates. A 6-month, 5-day program is 120 rows.
Weights are still computed from the program rules unless a set was adjusted.

### 2026-09-09 — Every set is written immediately
A killed app mid-workout must resume. `WorkoutLog` is created with an in-progress status at start;
each swipe writes a `LoggedSet`. On launch, an in-progress log reopens the workout screen.

## Program generation rules (from the prototype script, as amended by decisions above)

- Weeks = months × 4. Last week is Deload. Of the remaining R weeks: Foundation = ceil(R × 0.35),
  Peak = ceil(R × 0.25), Build = the rest.
- Phase table: Foundation 3×12 rest 75s ×1.0; Build 4×10 rest 90s ×1.0; Peak 4×8 rest 120s ×1.05;
  Deload 2×12 rest 60s ×0.7.
- Split by frequency: 3 → Full Body A/B/C; 4 → Upper A, Lower A, Upper B, Lower B;
  5 → Push, Pull, Legs, Upper, Lower. Sessions cycle through the split in order.
- Exercise count by session length: 20→3, 30→4, 45→5, 60→6, taken from the front of each day's list.
- Weight: see the step-based progression decision above (supersedes the prototype's +5/week, cap-first formula).
- Starting weights: user-settable per exercise (the prototype's five anchors dbBench, latPull, goblet,
  shoulderPress, rdl are only the prototype's subset); library default otherwise.
- Swap candidates: same muscle group, not already in the session, weight from the same formula.
- PR = top logged weight for an exercise exceeds the previous best across all completed sessions.
- Streak counts consecutive completed scheduled sessions backward from today; today's unfinished session
  does not break it.

## Patterns

### 2026-09-10 — Test fixtures: fixed calendar, fresh in-memory store per test, one sample-graph helper
`HomeGymLogTests/Support/` holds three pieces every suite reuses. `TestCalendar.calendar` is Gregorian,
`America/New_York`, `en_US_POSIX`, with Sunday as first weekday on purpose (the app's Monday-based helpers
must not depend on that setting); `TestCalendar.day(y, m, d)` gives local midnight, and `exampleASlots` /
`exampleAInputs` are the spec's Example A (1 month, Mon/Wed/Fri from Mon 2026-09-07). `makeTestStore()`
returns a `TestStore` holding both the in-memory `ModelContainer` and a `ModelContext` (the struct keeps
the container alive for the context's lifetime); call it inside each test, never share across tests.
`insertSampleGraph(in:)` inserts one program, N sessions, one log with two exercises × three sets, and
one note, deliberately appending children in shuffled order so `sorted*` accessors are exercised. Suites
that touch app-target types are `@MainActor` (the app target defaults to main-actor isolation); Engine
suites are plain. Analogy: `TestCalendar` is a frozen clock/TZ fixture, `makeTestStore` is a per-test
fresh in-memory DB, `insertSampleGraph` is a seed script.

### 2026-09-10 — Diagnose a SwiftData behavior with a throwaway test-only experiment
When SwiftData does something surprising (the `.cascade` no-op on iOS 17.5), do not reason from docs:
write a temporary test that builds the smallest graph reproducing it, run it on each installed runtime,
and read values back through a fresh `ModelContext` (`ModelContext(container).fetchCount(...)`) so the
result reflects the store, not the in-memory object graph. Because `print` is invisible under
xcodebuild, surface values via a failing `#expect(Bool(false), Comment(rawValue:))` and read the result
bundle. Delete the experiment once the finding is recorded in gotchas; keep only the regression test.

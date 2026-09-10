# M1 — Skeleton and engine: implementation plan

Status: draft 2026-09-10, revised the same day for plan-verifier findings F1–F11, for `docs/specs/m1-skeleton-engine.md` (revised 2026-09-09). Sections 4, 5 and 8
of the spec are the contract; acceptance criteria are referenced as `AC-N`.

---

## 1. Goal and scope

Create the Xcode project once through the wizard, then land (in this order) the pure Engine with its unit
tests, the six SwiftData models with persistence tests, the theme tokens, and the four-tab shell with the
prototype's floating pill bar, so that M2 can drop real screens into an app that already builds, tests,
persists, and runs on the user's iPhone. Every step leaves the project building with all tests green.

Out of scope (spec section 7): onboarding screens, real Home/Program/Progress/Settings content, restart
semantics, the workout flow (start/log/adjust/swap/rest timer/summary/resume/finish/delete-on-exit),
charts, calendar, PRs, streak, the missed-day prompt UI, settings behavior, release error-screen copy,
notifications, Live Activities, haptics, export, app icon, CloudKit, kg-native progression, exercise
images, home variants `1b`/`1c`. Also out of scope for this plan: `VersionedSchema`/migration plans (the
schema conventions are fixed now so the first versioned schema can be declared retroactively in the
milestone that first needs a migration), and any in-app appearance control. No AC is excluded.

---

## 2. Decisions this plan relies on

From `insights/INSIGHTS.md` (all dated 2026-09-09):

- **Engine/Model boundary**: Engine takes plain values + explicit `Calendar` + reference date, returns
  plain values, never imports SwiftData/SwiftUI. `Phase`, `SessionStatus`, `SetStatus`, `PlannedExercise`
  are Engine types; models depend on Engine. Generator validation `throws` a typed error. Skip is a model
  mutation. → Steps 2–7.
- **Schema shape**: optional to-one relationships, no `.unique`, enums as raw `String` + computed
  accessor, unordered to-many sorted on read by `index`/`order`, cascade rules per spec 4.8. → Step 6.
- **PlannedExercise is embedded Codable** on `PlannedSession`. → Steps 2, 6.
- **Status invariants have one writer** (`WorkoutLog` in progress iff `finishedAt == nil`;
  `completed` iff `workoutLog?.finishedAt != nil`; skipped stored). → Step 6 tests.
- **ModelContainer built explicitly in App.init**, held as a `Result`, root switches on it. → Step 10.
- **Date and weekday conventions** (0 = Monday, one conversion helper, day arithmetic through the
  calendar, integer tenths + percent for weight rounding, fixed Gregorian calendar and zone in tests).
  → Steps 3, 4.
- **Program.archivedAt reserved**. → Step 6.
- **Equipment** (dumbbell 2.5/5/52.5, Marcy 10/10/150) and **step-based weight progression with the
  30 %-of-max threshold, clamp last**. → Steps 2, 3.
- **Starting weight user-settable for every exercise**. → Steps 3, 5.
- **Mid-week start re-slots the past**; **shift never doubles up a day**; **missed-day shift** semantics
  (one `reslot` primitive). → Steps 4, 5, 7.
- **Xcode project wizard-created once; synchronized folders**; keep Xcode 26 defaults (Swift 5 mode,
  approachable concurrency, default actor isolation MainActor on the app target). → Steps 0, 1.
- **Tab bar = TabView + `.toolbar(.hidden, for: .tabBar)` per NavigationStack + `.safeAreaInset` pill**.
  → Step 9.
- **Tests: Swift Testing, in-memory container per test, own `ModelContext`; `@MainActor` on persistence suites and `makeTestStore()` because app-target code is main-actor-isolated**. → Steps 2–7.
- **Product name HomeGymLog, bundle id `com.zhabskyi.homegymlog`**; no "Benchmark" in UI. → Steps 0, 9.
- **Pounds canonical; static exercise library; sessions persisted**. → Steps 2, 5, 6.

From the spec: section 2.3 geometry and the `<!-- tab bar -->` markup (icon paths quoted in Step 9);
2.4 token values; 4.9 library table, plans, split names, default days, phase table; 5.1–5.9 rules and
worked examples; 8 acceptance criteria.

Plan-level choices (not in INSIGHTS; stated here so the verifier can challenge them):

- **Engine types are declared `nonisolated`** (`nonisolated enum ProgramGenerator { … }`,
  `nonisolated struct PlannedExercise …`, SE-0449, supported by the Xcode 26 toolchain in Swift 5 mode).
  The build setting stays MainActor-by-default; only the Engine opts out, because pure value code has no
  reason to be main-actor bound, and its `Codable` conformances must not become isolated conformances (SwiftData
  encodes/decodes them). Models, stores and views keep the default and are therefore main-actor-isolated.
  Consequence for tests (F1 of the plan review): a `@Suite` that is not itself `@MainActor` calling
  `AppSchema.makeContainer`, `ProgramStore`, `ExerciseNoteStore` or any `@Model` initializer synchronously
  is a **compile error** in Swift 5 mode, not a warning. So every persistence suite (Steps 6, 7) is declared
  `@MainActor @Suite struct …Tests`; each test still builds its own in-memory container and `ModelContext`
  (the INSIGHTS rule "no `@MainActor` needed" applies to `ModelContext` itself, not to calling into
  main-actor-isolated app code). Engine suites stay nonisolated because the Engine types are `nonisolated`.
  Fallback if the compiler rejects `nonisolated` on an Engine type: drop the keyword and mark the Engine
  suites `@MainActor` too; nothing about this depends on the test target's own isolation setting. React
  analogy: `@MainActor` ≈ "UI-thread only"; a nonisolated test calling it is like calling a DOM API from a
  Web Worker.
- **Tab icons are drawn as SwiftUI shapes** (`TabIcon.swift`, ~70 lines), not SF Symbols and not asset
  images. Why: the prototype icons are four compositions of circles and rounded rects with exact
  coordinates (quoted in Step 9), so shapes reproduce them exactly and tint through `foregroundStyle`
  (the SVG's `currentColor`); asset-catalog SVGs do not honor `currentColor` strokes and would need
  template-rendering workarounds; SF Symbols have no matching glyphs and would be a visible regression to
  fix later. Fallback if the shapes take more than an hour: `house`, `square.grid.2x2`, `chart.bar`,
  `slider.horizontal.3` SF Symbols, replaced in M5 polish. Taking the fallback is a recorded deviation from
  spec 2.3's icon geometry and must be noted in the status lines of both this plan and the spec.
- **Theme tokens are asset-catalog color sets** read by name (`Color("bg")`) through the `Theme`
  namespace. The six themed tokens get an "Any Appearance" (light) and a "Dark" variant so the system
  appearance switches them with no code (AC-5). The constants are universal sets. The wizard's
  `AccentColor` set is filled with `#e11d48` and doubles as `Theme.accent`; phase Build reuses
  `Theme.accent` and phase Peak reuses `Theme.warning` (identical values in spec 2.4), so only
  `phaseFoundation` and `phaseDeload` need their own sets.
- **Placeholder title style**: the prototype has no page-title element; its largest screen heading
  (`todayName`, 24 px / weight 700 / letter-spacing −0.6) is used: `.system(size: 24, weight: .bold)`,
  `tracking(-0.6)`, `Theme.tx`. M2 may revise.
- **Bottom inset arithmetic**: the `safeAreaInset` pill (64 + 26 = 90 pt) plus 20 pt bottom padding on
  the placeholder content gives the spec's 110 pt clearance.

Open questions: none. Spec Q1 (30 % threshold as a weight threshold) is taken as decided; tests encode it.

---

## 3. Steps

Simulators (from `xcrun simctl list`): `iPhone 15` (iOS 17.5) and `iPhone 17` (iOS 26.5). Do not use
`iPhone SE (3rd generation)`: the name exists on two runtimes and `-destination name=` is ambiguous.

Command shorthands used below (from `.claude/skills/build-and-run` and `run-tests`; `build/` is gitignored):

```
BUILD='xcodebuild -scheme HomeGymLog -destination "platform=iOS Simulator,name=iPhone 15" -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log'
TEST='xcodebuild test -scheme HomeGymLog -destination "platform=iOS Simulator,name=iPhone 15" -derivedDataPath build/DerivedData'
# filter one Swift Testing suite:  $TEST -only-testing:HomeGymLogTests/ExerciseLibraryTests
# grep the output:                  2>&1 | grep -E "✔|✘|Executed|error:|BUILD|TEST (SUCCEEDED|FAILED)"
```

Every test file wraps its tests in a `@Suite struct <Name>Tests` so `-only-testing:HomeGymLogTests/<Name>Tests`
works. Tests `@testable import HomeGymLog`.

### Step 0 — User creates the Xcode project (no agent edits)

In Xcode: File → New → Project → iOS → App. Product Name `HomeGymLog`, Team **None for now**, Organization
Identifier `com.zhabskyi`, Interface SwiftUI, Language Swift, Testing System **Swift Testing**, Storage
**SwiftData**, Host in CloudKit off, "Create Git repository" off. Xcode's wizard appends a
`<ProductName>/` folder to the chosen location, so choose `/Users/zhabskyi/AppleApps` as the location and
accept Xcode merging into the existing `HomeGymLog/` repo folder; the result must be
`HomeGymLog.xcodeproj` beside `CLAUDE.md`. If Xcode refuses because the folder exists, create the project in
a scratch folder (e.g. `/Users/zhabskyi/AppleApps/scratch/`) and move `HomeGymLog.xcodeproj`, `HomeGymLog/`
and `HomeGymLogTests/` into the repo root with Finder or `mv`; synchronized groups are path-relative to the
project file, so this needs no pbxproj edit.

If the template also generated a `HomeGymLogUITests` target, the user deletes it in Xcode (project editor →
Targets list → select `HomeGymLogUITests` → Delete) and removes its folder; its sample launch/performance
tests make every `xcodebuild test` a minute slower. This is a user action in Xcode's target list, never a
pbxproj edit.

Then, in the `HomeGymLog` target, in this order:

1. Signing & Capabilities → Bundle Identifier → `com.zhabskyi.homegymlog` (the wizard derives
   `com.zhabskyi.HomeGymLog`; fix the case **before** picking a team, see gotcha "changing the bundle id
   burns an App ID").
2. Signing & Capabilities → Team → the personal team.
3. General → Minimum Deployments → iOS 17.0.
4. Product → Scheme → Manage Schemes → tick **Shared** for `HomeGymLog`.
5. Leave every build setting at its default (`SWIFT_VERSION = 5.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`,
   `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).

Generated files: `HomeGymLog.xcodeproj/`, `HomeGymLog/HomeGymLogApp.swift` (with
`.modelContainer(for: Item.self)`), `HomeGymLog/ContentView.swift` (a `@Query` list of `Item`),
`HomeGymLog/Item.swift` (sample `@Model`), `HomeGymLog/Assets.xcassets/` (`AccentColor`, `AppIcon`),
`HomeGymLog/Preview Content/Preview Assets.xcassets/`, `HomeGymLogTests/HomeGymLogTests.swift` (one
`@Test func example()`). Step 1 deals with them.

Verify (read-only look at the pbxproj is fine; never edit it):

```
ls HomeGymLog.xcodeproj/xcshareddata/xcschemes/HomeGymLog.xcscheme
grep -nE "IPHONEOS_DEPLOYMENT_TARGET|PRODUCT_BUNDLE_IDENTIFIER|SWIFT_VERSION|SWIFT_APPROACHABLE_CONCURRENCY|fileSystemSynchronizedGroups" HomeGymLog.xcodeproj/project.pbxproj | sort -u
# isolation: print each occurrence with its surrounding build-configuration block so the target is visible
grep -nB25 "SWIFT_DEFAULT_ACTOR_ISOLATION" HomeGymLog.xcodeproj/project.pbxproj | grep -E "SWIFT_DEFAULT_ACTOR_ISOLATION|PRODUCT_NAME|PRODUCT_BUNDLE_IDENTIFIER|name = (Debug|Release)|TEST_HOST|BUNDLE_LOADER"
$BUILD && $TEST
```

Expect deployment target 17.0, bundle id lowercase, `PBXFileSystemSynchronizedRootGroup` entries, BUILD
and TEST SUCCEEDED (one sample test). Record in `insights/INSIGHTS.md` (entry "Xcode project is
wizard-created once") exactly which targets and configurations carry `SWIFT_DEFAULT_ACTOR_ISOLATION` and
its observed value — the app target alone, or the app and the test target — because Steps 6 and 7 rely on
the app target being MainActor-by-default and the persistence suites are written `@MainActor` either way.
AC: groundwork for AC-1.

### Step 1 — Clear the wizard sample, lay out the folder skeleton

Files:

- Delete `HomeGymLog/Item.swift`.
- Move `HomeGymLog/HomeGymLogApp.swift` → `HomeGymLog/App/HomeGymLogApp.swift`; body becomes
  `WindowGroup { ContentView() }` with the `.modelContainer(for: Item.self)` line removed (the app owns no
  container until Step 10).
- Replace `HomeGymLog/ContentView.swift` body with `Text("HomeGymLog")` (temporary; deleted in Step 9).
- Delete `HomeGymLogTests/HomeGymLogTests.swift`. The test target is empty until Step 2; `xcodebuild test`
  succeeds with "Executed 0 tests". (If it refuses to run an empty bundle, keep a single
  `@Test func projectCompiles() { #expect(true) }` in `HomeGymLogTests/SmokeTests.swift` and delete it in
  Step 2.)
- Subfolders `App/`, `Models/`, `Engine/`, `Shared/` under `HomeGymLog/` and `Support/`, `Engine/`,
  `Persistence/` under `HomeGymLogTests/` are created as files land; empty directories are not needed by
  synchronized folders and are not tracked by git.

Tests: none. Verify: `$BUILD && $TEST`; `grep -rn "Item" HomeGymLog/ HomeGymLogTests/` returns nothing.
AC: none (housekeeping).

### Step 2 — Engine value types, equipment grid, exercise library, split plans

Files (all `HomeGymLog/Engine/`, all types `nonisolated`, no imports beyond Foundation):

`EngineTypes.swift`
```swift
enum Phase: String, CaseIterable, Codable, Sendable   // "Foundation", "Build", "Peak", "Deload"
    var sets: Int; var reps: Int; var restSeconds: Int; var multiplierPercent: Int   // phase table 4.9
enum SessionStatus: String, CaseIterable, Codable, Sendable   // "pending", "completed", "skipped"
enum SetStatus: String, CaseIterable, Codable, Sendable       // "pending", "done", "skipped"
enum MuscleGroup: String, CaseIterable, Codable, Sendable     // "Chest", "Back", "Shoulders", "Arms", "Legs"
struct PlannedExercise: Codable, Hashable, Sendable { var order: Int; var exerciseKey: String; var targetWeightLb: Double }
```

`Equipment.swift`
```swift
enum EquipmentKind: String, CaseIterable, Codable, Sendable { case dumbbell, marcy
    var stepTenths: Int   // 25 / 100
    var minTenths: Int    // 50 / 100
    var maxTenths: Int    // 525 / 1500
    var stepLb: Double; var minLb: Double; var maxLb: Double; var thresholdLb: Double   // 15.75 / 45 (display/tests)
    func isBelowThreshold(baseTenths: Int) -> Bool   // baseTenths * 10 < maxTenths * 3  (no float)
    func isLoadable(lb: Double) -> Bool              // tenths on the grid and within min…max
    static func tenths(fromLb lb: Double) -> Int?    // nil unless lb is an exact tenth
    static func lb(fromTenths tenths: Int) -> Double
}
```

`ExerciseLibrary.swift`
```swift
struct Exercise: Identifiable, Hashable, Sendable { let key: String; var id: String { key }; let name: String;
    let muscle: MuscleGroup; let equipment: String; let defaultWeightLb: Double; let kind: EquipmentKind; let cues: [String] }
enum ExerciseLibrary { static let all: [Exercise]  /* 18 rows, table order of 4.9 */
    static let byKey: [String: Exercise]; static func exercise(for key: String) -> Exercise? }
```

`SplitPlans.swift`
```swift
struct SplitDay: Hashable, Sendable { let name: String; let exerciseKeys: [String] }
struct SplitInfo: Hashable, Sendable { let name: String; let description: String }
enum SplitPlans {
    static func days(frequency: Int) -> [SplitDay]?          // PLANS, nil unless 3/4/5
    static func info(frequency: Int) -> SplitInfo?           // SPLIT
    static func defaultWeekdays(frequency: Int) -> [Int]?    // DEF_DAYS
    static func exerciseCount(sessionLengthMinutes: Int) -> Int?   // 20→3, 30→4, 45→5, 60→6
}
```

Tests (`HomeGymLogTests/Engine/`):

- `ExerciseLibraryTests.swift`: 18 entries with the exact keys/names/muscles/equipment/defaults/kinds of
  4.9; three cues each and verbatim cue text spot-checked; muscle counts 4/3/2/3/6; the seven Marcy keys
  (AC-17, AC-18 second half); every default loadable on its kind (AC-19); every `PLANS` key exists, each
  day lists six distinct keys, `DEF_DAYS[f].count == f`, `info` present for 3/4/5, `exerciseCount` table
  (AC-20).
- `EquipmentTests.swift`: step/min/max/threshold per kind (AC-18); `isLoadable` for 41, 55, 2.5, 52.5,
  55 (dumbbell) and 45, 150, 160 (Marcy); `tenths(fromLb:)` round trip; `isBelowThreshold` at 15, 17.5,
  40, 45.

Verify: `$TEST -only-testing:HomeGymLogTests/ExerciseLibraryTests -only-testing:HomeGymLogTests/EquipmentTests`.
AC-17, AC-18, AC-19, AC-20.

### Step 3 — Phase split and weight formula

Files (`HomeGymLog/Engine/`):

`PhaseSplit.swift`
```swift
struct PhaseRange: Equatable, Sendable { let phase: Phase; let firstWeek: Int; let lastWeek: Int }
enum PhaseSplit {
    static func weeks(months: Int) -> Int                       // months × 4
    static func phaseOf(week: Int, weeks: Int) -> Phase          // 5.2, integer ceil: (R*35 + 99) / 100, (R*25 + 99) / 100
    static func phaseRanges(weeks: Int) -> [PhaseRange]          // empty phases omitted (1 month → 3 entries)
}
```

`WeightFormula.swift`
```swift
enum WeightFormula {
    static func baseTenths(startTenths: Int, kind: EquipmentKind, week: Int) -> Int
    // loop k = 2…week: if no slowStart and kind.isBelowThreshold(base) { base += step; if !isBelowThreshold(base) { slowStart = k } }
    //                  else if (k - slowStart) % 2 == 0 { base += step }; start ≥ threshold ⇒ slowStart = 1
    static func roundAndClampTenths(baseTenths: Int, multiplierPercent: Int, kind: EquipmentKind) -> Int
    // steps = (2 * baseTenths * percent + stepTenths * 100) / (2 * stepTenths * 100)   (half up, all Int) → clamp to min…max
    static func baseWeightLb(start: Double, kind: EquipmentKind, week: Int) -> Double
    static func targetWeightLb(start: Double, kind: EquipmentKind, week: Int, phase: Phase) -> Double
    static func targetWeightLb(key: String, week: Int, phase: Phase, startingWeightsLb: [String: Double]) -> Double?
    // nil for an unknown key; start = startingWeightsLb[key] ?? library default
}
```

Tests (`HomeGymLogTests/Engine/`):

- `PhaseSplitTests.swift`: every week of 4/8/12/24 weeks against the 5.2 table (AC-21); ranges for 1 and 6
  months (AC-22); `phaseRanges(weeks: 4)` has exactly three entries.
- `WeightFormulaTests.swift`: every "Base sequences" row for its listed weeks (AC-23); every "Worked
  targets" row including clamped goblet and latPull week 20 = 150 (AC-24); exact halves round up on the
  integer path: dumbbell 12.5 × 0.7 → **10**, 37.5 × 0.7 → **27.5**, 62.5 × 0.7 → **45**, Marcy 50 × 0.7
  → **40**; plus `roundAndClampTenths` in isolation for Marcy 10 × 0.7 → **10** and dumbbell 5 × 0.7 → **5**
  (AC-25); override dbBench 30 week 1 → 30, pushdown 40 week 2 → 50, missing key → default,
  unknown key → nil (AC-26). All expected values are multiples of 2.5 and exactly representable, so `==`
  on `Double` is safe.

Verify: `$TEST -only-testing:HomeGymLogTests/PhaseSplitTests -only-testing:HomeGymLogTests/WeightFormulaTests`.
AC-21, AC-22, AC-23, AC-24, AC-25, AC-26.

### Step 4 — Calendar rules and the re-slot primitive

Files (`HomeGymLog/Engine/`):

`CalendarRules.swift`
```swift
enum CalendarRules {
    static func appWeekday(of date: Date, calendar: Calendar) -> Int          // (calendar.component(.weekday) + 5) % 7 → 0 = Monday
    static func startOfDay(_ date: Date, calendar: Calendar) -> Date
    static func day(_ date: Date, adding days: Int, calendar: Calendar) -> Date   // calendar.date(byAdding: .day, to: startOfDay)
    static func monday(ofWeekContaining date: Date, calendar: Calendar) -> Date   // startOfDay − appWeekday days
    static func firstTrainingDay(onOrAfter date: Date, trainingWeekdays: [Int], calendar: Calendar) -> Date
    static func nextTrainingDay(strictlyAfter date: Date, trainingWeekdays: [Int], calendar: Calendar) -> Date
    static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar) -> Bool
}
```
Both training-day helpers walk forward at most 7 days with `day(_:adding:)`; `trainingWeekdays` must be
non-empty (the generator guarantees it; the helpers `precondition` it since it is a programming error).

`Reslot.swift`
```swift
struct SessionSlot: Equatable, Sendable { var index: Int; var scheduledDate: Date; var status: SessionStatus }
enum Reslot {
    static func reslot(slots: [SessionSlot], fromIndex: Int, startingAt cursor: Date, inclusive: Bool,
                       trainingWeekdays: [Int], calendar: Calendar) -> [Int: Date]
}
```
Algorithm: find the slot at `fromIndex`; if absent or not `pending` return `[:]` (documented caller
contract, no trap). `next = inclusive ? startOfDay(cursor) : nextTrainingDay(strictlyAfter: cursor)`;
assign it; then for each later slot in index order whose status is `pending`,
`next = nextTrainingDay(strictlyAfter: next)`; assign. `assign` records `index → next` only when
`!isSameDay(slot.scheduledDate, next)`. Completed/skipped slots are neither moved nor stepped over as a
consumed day. Input array untouched (value type).

Test support (`HomeGymLogTests/Support/TestCalendar.swift`):
```swift
enum TestCalendar {
    static let calendar: Calendar    // .gregorian, TimeZone "America/New_York", Locale en_US_POSIX, firstWeekday = 1 (Sunday, on purpose)
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date     // start of that day
    static func exampleASlots(status: (Int) -> SessionStatus = { _ in .pending }) -> [SessionSlot]   // the 12 dates of 5.4
}
```

Tests (`HomeGymLogTests/Engine/`):

- `CalendarRulesTests.swift`: `appWeekday` for 2026-09-06 (Sun) … 09-12 (Sat) → 6, 0, 1, 2, 3, 4, 5;
  `monday(ofWeekContaining:)` for each of the seven days → Mon 09-07 (AC-32, helper half); DST:
  `day(Mon 2026-10-26, adding: 7)` equals `calendar.startOfDay(Mon 2026-11-02)` and not
  `+ 7 × 86 400` (feeds AC-35); `nextTrainingDay(strictlyAfter: Fri 09-11, [0,2,4])` = Mon 09-14;
  `firstTrainingDay(onOrAfter: Sat 09-12, [0,2,4])` = Mon 09-14; on-or-after a training day returns it.
- `ReslotTests.swift`: Example B (AC-39, plus "no two dates equal after applying"), Example C (AC-40),
  Example D (AC-41), Example H with slot 1 `completed` (AC-42), and the rules: completed/skipped after
  `fromIndex` absent from the map and not consuming a day, indices below `fromIndex` absent, unchanged
  dates absent, input array equal to a copy taken before the call, `fromIndex` not pending → `[:]` (AC-43).
  One more test, **documents behavior, spec gap for M4**: Example A with session 0 (Mon 09-07) pending and
  session 1 (Wed 09-09) `skipped`, `fromIndex 0`, cursor Tue 09-08, inclusive → {0: Tue 09-08, 2: Wed 09-09,
  3: Fri 09-11, …}; the algorithm as specified lets pending session 2 land on Wed 09-09, the date the skipped
  session 1 still occupies, because skipped slots neither move nor consume a day. The test asserts exactly
  this output so that when M4 decides whether skipped sessions block a date it changes it deliberately.

Verify: `$TEST -only-testing:HomeGymLogTests/CalendarRulesTests -only-testing:HomeGymLogTests/ReslotTests`.
AC-32 (helper), AC-39, AC-40, AC-41, AC-42, AC-43.

### Step 5 — Program generator

File `HomeGymLog/Engine/ProgramGenerator.swift`:
```swift
struct ProgramInputs: Equatable, Sendable { var months: Int; var frequency: Int; var trainingWeekdays: [Int];
    var sessionLengthMinutes: Int; var startingWeightsLb: [String: Double]; var generatedOn: Date }
enum ProgramInputError: Error, Equatable {
    case unsupportedMonths(Int), unsupportedFrequency(Int), unsupportedSessionLength(Int)
    case weekdayCountMismatch(expected: Int, actual: Int), invalidWeekday(Int)   // duplicate or out of 0…6
    case unknownExerciseKey(String), unloadableStartingWeight(key: String, weightLb: Double) }
struct GeneratedSession: Equatable, Sendable { var index: Int; var week: Int; var phase: Phase; var name: String;
    var scheduledDate: Date; var sets: Int; var reps: Int; var restSeconds: Int; var exercises: [PlannedExercise] }
struct GeneratedProgram: Equatable, Sendable { var startDate: Date; var months: Int; var frequency: Int;
    var trainingWeekdays: [Int]; var sessionLengthMinutes: Int; var startingWeightsLb: [String: Double]; var sessions: [GeneratedSession] }
enum ProgramGenerator {
    static let allowedMonths: Set<Int> = [1, 2, 3, 6]; static let allowedFrequencies: Set<Int> = [3, 4, 5]
    static let allowedSessionLengths: Set<Int> = [20, 30, 45, 60]
    static func generate(_ inputs: ProgramInputs, calendar: Calendar) throws -> GeneratedProgram
}
```
Order inside `generate`: validate (months, frequency, length, weekday count, each weekday in 0…6 and
distinct, each starting-weight key known, each starting weight loadable on its kind); `days =
trainingWeekdays.sorted()`; `startDate = monday(ofWeekContaining: generatedOn)`; build sessions per 5.3/5.4
(`week = i / frequency + 1`, phase via `PhaseSplit.phaseOf`, day = `SplitPlans.days(frequency)[i % frequency]`,
first `n` keys, targets via `WeightFormula.targetWeightLb(key:week:phase:startingWeightsLb:)`, base date =
`day(startDate, adding: 7 × (week − 1) + days[i % frequency])`); then `Reslot.reslot(slots: all pending,
fromIndex: 0, startingAt: firstTrainingDay(onOrAfter: generatedOn), inclusive: true, …)` and fold the map
in (the map is empty when no base date precedes `generatedOn`, so the call is safe unconditionally and
identical to the spec's guarded form); resolve `startingWeightsLb` to exactly the keys used by any
session (user value else library default).

Test support, second file, written in this step because it needs `ProgramInputs`
(`HomeGymLogTests/Support/TestInputs.swift`):
```swift
extension TestCalendar {
    static func exampleAInputs(generatedOn: Date = day(2026, 9, 7)) -> ProgramInputs
    // months 1, frequency 3, trainingWeekdays [0, 2, 4], sessionLengthMinutes 45, startingWeightsLb [:]
}
```

Tests `HomeGymLogTests/Engine/ProgramGeneratorTests.swift` (with `TestCalendar.exampleAInputs()`):
session counts 12 and 120, indices and weeks (AC-28); names cycle, scheme per phase (AC-29); exercise
count per length and equality with the formula (AC-30); Example A's twelve dates and its four full-session
rows (AC-31); `startDate` for generation on each of Mon…Sun of 2026-09-07's week (AC-32); Examples E, F, G
with "no session before generatedOn", "every session on a training weekday", weeks equal to the Monday case
(AC-33); 6 mo × 5 days from 2026-09-07 ends Fri 2027-02-19 (AC-34); DST session 3 == start of
2026-11-02 (AC-35); two calls equal (AC-36); one test per `ProgramInputError` case, including weekday
count 5 with frequency 4, duplicate weekday, weekday 7, months 7, frequency 2, length 25, key "bench",
dumbbell 41, Marcy 55, 55 for a dumbbell key, 4 for a dumbbell key, 160 for a Marcy key (AC-37); resolved
`startingWeightsLb` keys == union of session keys, no extras (AC-38); every target loadable across all
4 × 3 × 4 combinations with defaults (AC-27).

Verify: `$TEST -only-testing:HomeGymLogTests/ProgramGeneratorTests`, then the whole Engine folder:
`$TEST` (all suites so far).
AC-27, AC-28, AC-29, AC-30, AC-31, AC-32, AC-33, AC-34, AC-35, AC-36, AC-37, AC-38.

### Step 6 — SwiftData models, schema factory, round-trip and cascade tests

Files (`HomeGymLog/Models/`, one model per file, `import SwiftData`; each has an explicit `init` with
every non-optional attribute defaulted where the spec gives a natural default):

- `Program.swift` — `@Model final class Program` (fields in section 4). `@Relationship(deleteRule: .cascade,
  inverse: \PlannedSession.program) var sessions: [PlannedSession] = []`. Computed: `var weeks: Int`,
  `var totalSessions: Int`, `var sortedSessions: [PlannedSession]`, `var endDate: Date?`, `var isCurrent: Bool`.
- `PlannedSession.swift` — stored `phaseRaw: String`, `statusRaw: String`; computed `var phase: Phase
  { get set }`, `var status: SessionStatus { get set }`; `var exercises: [PlannedExercise]`;
  `var program: Program?`; `@Relationship(deleteRule: .cascade, inverse: \WorkoutLog.session) var workoutLog:
  WorkoutLog?`; `func isMissed(today: Date, calendar: Calendar) -> Bool`.
- `WorkoutLog.swift` — `var session: PlannedSession?`; `@Relationship(deleteRule: .cascade, inverse:
  \LoggedExercise.workout) var exercises: [LoggedExercise] = []`; computed `var isInProgress: Bool
  { finishedAt == nil }`, `var sortedExercises`.
- `LoggedExercise.swift` — `var workout: WorkoutLog?`; `@Relationship(deleteRule: .cascade, inverse:
  \LoggedSet.exercise) var sets: [LoggedSet] = []`; `var sortedSets`.
- `LoggedSet.swift` — `statusRaw` + computed `status: SetStatus`; `var exercise: LoggedExercise?`.
- `ExerciseNote.swift` — no relationships.
- `AppSchema.swift`:
  ```swift
  enum AppSchema {
      static let schema = Schema([Program.self, PlannedSession.self, WorkoutLog.self, LoggedExercise.self, LoggedSet.self, ExerciseNote.self])
      static func makeContainer(inMemory: Bool) throws -> ModelContainer   // ModelConfiguration(schema:, isStoredInMemoryOnly: inMemory)
  }
  ```
  Inverses are declared on exactly one side (the to-many/owner side as above); the other side is a plain
  optional property.

Test support `HomeGymLogTests/Support/TestContainer.swift`:
```swift
struct TestStore { let container: ModelContainer; let context: ModelContext }   // keeps the container alive
@MainActor func makeTestStore() throws -> TestStore   // AppSchema.makeContainer(inMemory: true), ModelContext(container); @MainActor because AppSchema is main-actor-isolated on the app target
```

Tests (`HomeGymLogTests/Persistence/`, every suite declared `@MainActor @Suite struct …Tests` because
the models and `AppSchema` are main-actor-isolated under the app target's default; each test still calls
`makeTestStore()` for its own in-memory container and context):

- `ModelRoundTripTests.swift`: insert a full graph (program → 3 sessions inserted in shuffled index order →
  one log → 2 exercises inserted in reverse order → 3 sets inserted in reverse order, plus a note), save,
  fetch each model with `FetchDescriptor`, compare every field of section 4; `phaseRaw`/`statusRaw` strings
  and enum accessors both ways; every one of the five to-one relationships (`PlannedSession.program`,
  `PlannedSession.workoutLog`, `WorkoutLog.session`, `LoggedExercise.workout`, `LoggedSet.exercise`) is
  exercised with `nil` at least once (insert the row unlinked, save, fetch, assert nil); the sorted
  accessors `sortedSessions`/`sortedExercises`/`sortedSets` return `index`/`order` order regardless of
  insertion order; embedded `[PlannedExercise]` and `[String: Double]` round-trip (AC-9); `isMissed` for
  yesterday/today/tomorrow.
- `CascadeDeleteTests.swift`: delete the program → save → counts of the five dependent models are 0 and
  the note count is 1 (AC-10); delete a log → exercises and sets 0, session still present with
  `workoutLog == nil` (AC-11).
- `StatusInvariantTests.swift`: new log `isInProgress`; set `finishedAt` and `status = .completed` in one
  save → `session.status == .completed && session.workoutLog?.finishedAt != nil`; delete an unfinished log →
  session `pending`, `workoutLog == nil` (AC-16).

Verify: `$TEST -only-testing:HomeGymLogTests/ModelRoundTripTests -only-testing:HomeGymLogTests/CascadeDeleteTests -only-testing:HomeGymLogTests/StatusInvariantTests`
on iPhone 15 (iOS 17.5; this is where SwiftData differences show).
AC-9, AC-10, AC-11, AC-16.

### Step 7 — Model-layer actions: apply, re-slot, skip, note save

Files (`HomeGymLog/Models/`):

`ProgramStore.swift`
```swift
enum ProgramStore {
    @discardableResult
    static func apply(_ generated: GeneratedProgram, bodyWeightLb: Double, experience: String, createdAt: Date,
                      in context: ModelContext) throws -> Program        // inserts Program first, then sessions (status pending); saves
    static func apply(reslotMap: [Int: Date], to program: Program)        // sets scheduledDate on listed indices only; caller saves
    static func skip(_ session: PlannedSession)                          // precondition pending; status = .skipped only
    static func slots(of program: Program) -> [SessionSlot]              // sorted by index, for the M4 caller of Reslot
}
```
`apply(_:bodyWeightLb:experience:createdAt:in:)` does **not** enforce "at most one program with
`archivedAt == nil`"; it inserts unconditionally. M2's restart path (archive or delete the old program before
applying the new one) owns that invariant, so M2's planner inherits it explicitly.
`ExerciseNoteStore.swift`
```swift
enum ExerciseNoteStore {
    static func note(forExerciseKey key: String, in context: ModelContext) throws -> ExerciseNote?   // #Predicate on exerciseKey
    @discardableResult
    static func save(text: String, forExerciseKey key: String, updatedAt: Date, in context: ModelContext) throws -> ExerciseNote  // fetch-then-insert; saves
}
```

Tests (`HomeGymLogTests/Persistence/`, both suites `@MainActor @Suite` as in Step 6):

- `ProgramStoreTests.swift`: apply Example A → one `Program` with `archivedAt == nil`, 12 sessions
  `pending`, read back sorted by index equal field-for-field to the generated values including the
  `[PlannedExercise]` arrays (AC-13); apply Example B's map (from `Reslot` on `slots(of:)`) → exactly those
  indices changed, others untouched (AC-14); `skip` on session 1 → only `statusRaw` changed on it, nothing
  on any other session (AC-15).
- `ExerciseNoteStoreTests.swift`: save "a" then "b" for `dbBench` → one row, text "b", `updatedAt` from the
  second call; a second key gets its own row (AC-12).

Verify: `$TEST -only-testing:HomeGymLogTests/ProgramStoreTests -only-testing:HomeGymLogTests/ExerciseNoteStoreTests`.
AC-12, AC-13, AC-14, AC-15.

### Step 8 — Theme: color sets and the `Theme` namespace

Files:

- `HomeGymLog/Assets.xcassets/<name>.colorset/Contents.json` for `bg`, `sf`, `sf2`, `tx`, `mu`, `bd`
  (light value as "Any Appearance", dark value as the `luminosity: dark` appearance) and universal sets
  `success` (`#22c55e`), `warning` (`#f59e0b`), `phaseFoundation` (`#5b8def`), `phaseDeload` (`#8f8b91`);
  fill the wizard's `AccentColor` with `#e11d48`. Values from spec 2.4; `bd` is white/black at alpha 0.08.
  Illustrative `bg`:
  ```json
  { "colors": [
      { "idiom": "universal", "color": { "color-space": "srgb", "components": { "red": "0xF4", "green": "0xF2", "blue": "0xF3", "alpha": "1.000" } } },
      { "idiom": "universal", "appearances": [ { "appearance": "luminosity", "value": "dark" } ],
        "color": { "color-space": "srgb", "components": { "red": "0x0F", "green": "0x0E", "blue": "0x10", "alpha": "1.000" } } } ],
    "info": { "author": "xcode", "version": 1 } }
  ```
- `HomeGymLog/Shared/Theme.swift`
  ```swift
  enum Theme {
      static let bg = Color("bg"), sf = Color("sf"), sf2 = Color("sf2"), tx = Color("tx"), mu = Color("mu"), bd = Color("bd")
      static let accent = Color("AccentColor"), success = Color("success"), warning = Color("warning")
      static func phaseColor(_ phase: Phase) -> Color   // foundation → "phaseFoundation", build → accent, peak → warning, deload → "phaseDeload"
  }
  ```

Tests: none (asset lookups are verified visually in Step 9). Verify: `$BUILD` with no `actool` warnings
about the new sets (`grep -i "colorset\|warning" build/last-build.log`). AC-5 groundwork.

### Step 9 — Tab shell: placeholders, floating bar, icons

Files:

- `HomeGymLog/App/AppTab.swift`
  ```swift
  enum AppTab: String, CaseIterable, Identifiable { case home, program, progress, settings
      var id: String { rawValue }; var label: String   // "Home", "Program", "Progress", "Settings"
      var placeholderMilestone: Int }                  // 2, 2, 4, 4
  ```
- `HomeGymLog/Shared/PlaceholderScreen.swift` — `struct PlaceholderScreen: View { let tab: AppTab }`:
  `ScrollView` → `VStack(alignment: .leading, spacing: 8)` with the title (24 pt bold, tracking −0.6,
  `Theme.tx`) and "Coming in milestone N" (`Theme.mu`), `.padding(.horizontal, 18)`, `.padding(.bottom, 20)`,
  `.frame(maxWidth: .infinity, alignment: .leading)`; `.background(Theme.bg.ignoresSafeArea())`;
  `.toolbar(.hidden, for: .navigationBar)` (the placeholder draws its own title).
- `HomeGymLog/Shared/TabIcon.swift` — `struct TabIcon: View { let tab: AppTab }`, 22×22 frame, drawn from
  the prototype's `viewBox="0 0 22 22"` (stroke width 2 where noted, everything else filled, tinted by the
  caller's `foregroundStyle`):
  - home: `circle cx 11 cy 11 r 8` stroked; `circle r 3.5` filled.
  - program: `rect 3,3 7×7 rx 2`; `rect 12,3`; `rect 3,12` filled; `rect 12,12 7×7 rx 2` stroked.
  - progress: `rect 3,12 4×7 rx 1.5`; `rect 9,7 4×12`; `rect 15,3 4×16`.
  - settings: `rect 3,6 16×2.5 rx 1.25` + `circle 14,7.25 r 3`; `rect 3,14 16×2.5` + `circle 8,15.25 r 3`.
  Implement with `Path` in a `Canvas`-free way (`Path { $0.addEllipse(in:) / addRoundedRect(in:cornerSize:) }`
  per icon, `.fill` and `.stroke(lineWidth: 2)` layered in a `ZStack`).
- `HomeGymLog/Shared/FloatingTabBar.swift` — `struct FloatingTabBar: View { @Binding var selected: AppTab }`:
  `HStack(spacing: 0)` of four `Button`s (`flex: 1`, height 52, `VStack(spacing: 4)` of `TabIcon` and
  `Text(label).font(.system(size: 10.5, weight: .semibold))`, `foregroundStyle(isSelected ? Theme.accent :
  Theme.mu)`, `.buttonStyle(.plain)`); `.padding(.horizontal, 8)`; `.frame(height: 64)`;
  `.background(Theme.sf)` as a plain opaque fill (AC-5 is checked by exact hex values, so no material or
  partial-opacity fill; the prototype's backdrop blur is invisible behind an opaque `sf` anyway); `Capsule()` clip and
  `.overlay(Capsule().strokeBorder(Theme.bd, lineWidth: 1))`; `.shadow(color: .black.opacity(0.25), radius: 15,
  y: 10)` (CSS blur 30 ≈ SwiftUI radius 15); `.padding(.horizontal, 14)`; `.padding(.bottom, 26)`. Re-tapping
  the selected tab sets the same value (no-op). Accessibility: `.accessibilityLabel(label)` and
  `.accessibilityAddTraits(.isSelected)` on the selected button.
- `HomeGymLog/App/RootView.swift` — `struct RootView: View { @State private var selected: AppTab = .home }`:
  `TabView(selection: $selected) { ForEach(AppTab.allCases) { tab in NavigationStack { PlaceholderScreen(tab:
  tab) }.toolbar(.hidden, for: .tabBar).tag(tab) } }` then `.safeAreaInset(edge: .bottom) {
  FloatingTabBar(selected: $selected).ignoresSafeArea(edges: .bottom) }` and `.background(Theme.bg.ignoresSafeArea())`.
  `@State` ≈ `useState`; `TabView(selection:)` keeps all four stacks mounted.
- `HomeGymLog/App/HomeGymLogApp.swift` — body `WindowGroup { RootView() }`. Delete `ContentView.swift`.

Tests: none (views). Verify:

```
$BUILD && APP=$(find build/DerivedData/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "*.app" | head -1)
xcrun simctl boot "iPhone 15"; open -a Simulator; xcrun simctl install booted "$APP"; xcrun simctl launch booted com.zhabskyi.homegymlog
xcrun simctl ui booted appearance dark; xcrun simctl ui booted appearance light
grep -rniI "benchmark" HomeGymLog/ ; echo "exit $? (1 = no match, good)"
```
Then repeat the boot/install/launch on `iPhone 17` (iOS 26.5) and confirm no system tab bar appears.
Measure the bar in Xcode's view debugger (Debug → View Debugging → Capture View Hierarchy): frame 14 pt
from each side, 26 pt from the screen bottom, 64 pt tall; if the measured bottom gap is 26 + the home
indicator inset, replace `.ignoresSafeArea` on the inset content with an `.overlay(alignment: .bottom)` on
the `TabView` that ignores the bottom safe area and give `PlaceholderScreen` a 110 pt bottom padding.
AC-2, AC-3, AC-4, AC-5, AC-6, AC-7 (relaunch), and AC-1 on the simulator.

### Step 10 — Container at launch and the store-failure branch

Files:

- `HomeGymLog/App/HomeGymLogApp.swift`
  ```swift
  @main struct HomeGymLogApp: App {
      private let containerResult: Result<ModelContainer, Error>
      init() {
          containerResult = Result { try AppSchema.makeContainer(inMemory: false) }
          #if DEBUG
          if case .failure(let error) = containerResult { fatalError("SwiftData store failed to open: \(error)") }
          #endif
      }
      var body: some Scene { WindowGroup { switch containerResult {
          case .success(let container): RootView().modelContainer(container)
          case .failure(let error): StoreErrorView(error: error) } } }
  }
  ```
- `HomeGymLog/App/StoreErrorView.swift` — `struct StoreErrorView: View { let error: Error }`: `Theme.bg`
  background, title "Couldn't open your data", `error.localizedDescription` in `Theme.mu`. Copy and recovery
  are M4; this is the placeholder branch.

Tests: none new (`AppSchema` is covered by every persistence test). Verify: `$BUILD`, launch on iPhone 15,
then `ls "$(xcrun simctl get_app_container booted com.zhabskyi.homegymlog data)/Library/Application Support/"`
shows `default.store`; kill (`xcrun simctl terminate booted com.zhabskyi.homegymlog`) and relaunch → Home
placeholder, no error. Failure path by inspection: the `Result` is built once in `init`, the switch has both
arms, DEBUG crashes, release shows `StoreErrorView`; a release build is not required in M1.
AC-7, AC-8.

### Step 11 — Full test pass on iOS 17.5, build on iOS 26.5, device install

No files. Verify:

```
rm -rf build/tests.xcresult
$TEST -resultBundlePath build/tests.xcresult 2>&1 | tee build/last-test.log | grep -E "✔|✘|Executed|error:|TEST (SUCCEEDED|FAILED)"
xcodebuild -scheme HomeGymLog -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath build/DerivedData build
```
Then `/device-install` (phone plugged in and unlocked; personal team selected in Step 0; first install needs
Settings → General → VPN & Device Management → Trust). Confirm the home-screen label reads "HomeGymLog" and
the app launches to the Home placeholder with the pill bar. AC-1.

After Step 11 the doc-writer records the M1 status line in the spec and this plan and appends anything
that bit to `insights/gotchas.md` (not done by the implementer mid-step).

---

## 4. Data model changes

All six models are new; there is no existing store, so there is no migration. The conventions below are
the ones INSIGHTS fixes for CloudKit readiness and iOS 17 predicate/delete safety; changing any of them
after users have data is a versioned migration. `VersionedSchema` is not introduced in M1; when a
migration is first needed, `SchemaV1` is declared to match exactly what ships here.

| Model | Fields (type, unit) | Relationships |
|---|---|---|
| `Program` | `id: UUID`, `createdAt: Date`, `archivedAt: Date?`, `startDate: Date` (Monday, local midnight), `months: Int`, `frequency: Int`, `trainingWeekdays: [Int]` (0 = Mon, sorted), `sessionLengthMinutes: Int`, `bodyWeightLb: Double`, `experience: String`, `startingWeightsLb: [String: Double]` (lb) | `sessions: [PlannedSession]` cascade, inverse `PlannedSession.program` |
| `PlannedSession` | `id: UUID`, `index: Int`, `week: Int` (1-based), `phaseRaw: String` (+ `phase: Phase`), `name: String`, `scheduledDate: Date` (local midnight, mutable), `sets: Int`, `reps: Int`, `restSeconds: Int`, `exercises: [PlannedExercise]` (embedded Codable, ordered), `statusRaw: String` (+ `status: SessionStatus`) | `program: Program?`; `workoutLog: WorkoutLog?` cascade, inverse `WorkoutLog.session` |
| `WorkoutLog` | `id: UUID`, `startedAt: Date`, `finishedAt: Date?` | `session: PlannedSession?`; `exercises: [LoggedExercise]` cascade, inverse `LoggedExercise.workout` |
| `LoggedExercise` | `id: UUID`, `order: Int`, `exerciseKey: String`, `swappedFromKey: String?`, `targetWeightLb: Double` | `workout: WorkoutLog?`; `sets: [LoggedSet]` cascade, inverse `LoggedSet.exercise` |
| `LoggedSet` | `id: UUID`, `order: Int`, `weightLb: Double`, `reps: Int`, `statusRaw: String` (+ `status: SetStatus`), `rpe: Int?`, `loggedAt: Date?` | `exercise: LoggedExercise?` |
| `ExerciseNote` | `id: UUID`, `exerciseKey: String` (not unique in schema), `text: String`, `updatedAt: Date` | none |

Embedded value `PlannedExercise { order: Int, exerciseKey: String, targetWeightLb: Double }`: any field
added later must be optional (no lightweight migration for embedded values). Weights `Double` pounds;
durations `Int` seconds; `week`/`index`/`order` `Int`. No `@Attribute(.unique)`. Inverse declared once
per pair. `Program.archivedAt` exists now so M2's restart choice needs no migration.

---

## 5. Risks and gotchas

From `insights/gotchas.md`:

- **Bundle id burns an App ID (free tier)** — Step 0 sets `com.zhabskyi.homegymlog` before selecting the
  team; the wizard's `com.zhabskyi.HomeGymLog` must never be provisioned.
- **7-day provisioning expiry** — Step 11 device install; "unable to verify" later means re-run from Xcode,
  not a code problem.
- **Design export: do not copy `weightFor`** — Step 3 implements INSIGHTS' step-based formula; tests encode
  the spec's tables, not the prototype's. The prototype's shift button is a no-op; Step 4 implements the
  decided algorithm. Equipment limits are the real ones.
- **`.toolbar(.hidden, for: .tabBar)` goes on each `NavigationStack`** (Step 9), not on views inside it;
  use `toolbar(_:for:)`, never `toolbarVisibility` (iOS 18).
- **`tabBarMinimizeBehavior` / `tabViewBottomAccessory` are iOS 26-only** — not used.
- **Files outside `HomeGymLog/`/`HomeGymLogTests/` are in no target** — every new file's path is listed per
  step; "cannot find X in scope" means a misplaced file. Never edit `project.pbxproj` (Step 0 greps it read-only).
- **Shared scheme required for `xcodebuild`** — Step 0 item 4.

New risks:

- **Default MainActor isolation vs tests.** Models, `AppSchema`, `ProgramStore` and `ExerciseNoteStore`
  are main-actor-isolated; a nonisolated Swift Testing suite calling them synchronously is a compile error
  ("call to main actor-isolated … in a synchronous nonisolated context"). Mitigation: every persistence
  suite is `@MainActor @Suite` (Steps 6, 7). Engine types are `nonisolated` so Engine suites need nothing;
  if the compiler rejects `nonisolated` on a type, drop it and mark the Engine suites `@MainActor` as well.
  Neither path depends on the test target's own isolation setting, which Step 0 records in INSIGHTS.
  React analogy: `@MainActor` ≈ UI-thread-only code; a nonisolated test is a Web Worker trying to call it.
- **Codable collections on `@Model` on iOS 17** (`[PlannedExercise]`, `[String: Double]`, `[Int]`).
  Supported as encoded attributes, but Step 6 runs on the iOS 17.5 simulator first. Fallback: store as
  JSON `Data` with a computed accessor (a stored-field rename before any user data exists is free).
- **iOS 17 relationship insert order.** Linking a child to a parent that is not yet inserted can raise
  "illegal attempt to establish a relationship between objects in different contexts" or silently drop the
  link. Mitigation: `ProgramStore.apply` and every test insert the parent, then append children
  (`program.sessions.append(session)`), then save.
- **Cascade deletes are visible only after `save()`** on iOS 17 in some cases. Mitigation: cascade tests
  `try context.save()` after the delete before counting; if counts still lag, fetch on a fresh
  `ModelContext(container)`.
- **Inverse declared on both sides crashes at container build.** Mitigation: one `@Relationship(inverse:)`
  per pair, on the owner side (section 4 table); the round-trip test builds the container first, so a
  mistake fails every persistence test immediately.
- **`@Model` stored `let`** is not supported by the macro; use `var id: UUID = UUID()`.
- **Pill geometry inside `safeAreaInset`.** The inset view is placed above the home-indicator safe area,
  so 26 pt of padding may become 26 + 34. Mitigation in Step 9 (ignore the bottom safe area on the inset
  content; overlay fallback with 110 pt content padding). Verify with the view debugger, not by eye.
- **Missing color-set name renders clear with only a console warning.** Mitigation: every `Theme` name
  appears in the Step 8 file list; Step 9's light/dark toggle exercises all six themed tokens visually.
  Alternative if a typo slips through: the compile-checked generated symbols (`Color.bg`) that Xcode emits
  for the catalog.
- **Floating-point in tests.** All expected weights are multiples of 2.5 lb (exactly representable), so
  `==` is safe; the formula itself never rounds in floating point. `EquipmentKind.tenths(fromLb:)` uses
  `(lb * 10).rounded()` and rejects values further than 1e-6 from an integer, so 15.75 is "not a tenth".
- **Ambiguous simulator name** `iPhone SE (3rd generation)` (17.5 and 18.0). Use `iPhone 15` / `iPhone 17`.
- **`-only-testing` filter naming with Swift Testing** needs the `@Suite` type name
  (`HomeGymLogTests/ProgramGeneratorTests`); a stale `build/tests.xcresult` makes xcodebuild refuse to run.
- **`generate` and `Reslot` on empty `trainingWeekdays`** would loop; the generator validates count ==
  frequency ≥ 3 first, and the helpers `precondition` non-empty (programming error, not user input).
- **Placeholder title size is a plan choice** (24 pt bold); if the user prefers the iOS large-title look,
  it is a one-line change in `PlaceholderScreen` and M2 replaces the screens anyway.

---

## 6. Definition of done

Shell (simulator iPhone 15 / iOS 17.5 and iPhone 17 / iOS 26.5, then the user's iPhone):

- [ ] AC-1 — Builds; launches on both simulators; installs and launches on the phone as "HomeGymLog",
      bundle id `com.zhabskyi.homegymlog` (Steps 0, 9, 11).
- [ ] AC-2 — Launches on Home; pill bar shows Home, Program, Progress, Settings in order; selected item
      `#e11d48`, others `mu`; no system tab bar on either OS (Step 9).
- [ ] AC-3 — Each tab shows its title and "Coming in milestone 2 / 2 / 4 / 4" (Step 9).
- [ ] AC-4 — View debugger: bar 14 pt from each side, 26 pt from the screen bottom, 64 pt tall, capsule,
      `sf` fill, 1 pt `bd` border, shadow; icons 22 pt; label 10.5 pt semibold 4 pt below (Step 9).
- [ ] AC-5 — `xcrun simctl ui booted appearance dark|light` swaps bg `#0f0e10`/`#f4f2f3`, bar
      `#1a191c`/`#ffffff`, text `#f5f3f4`/`#17161a`, muted `#8f8b91`/`#6e6a70` without relaunch; no in-app
      appearance control (Steps 8, 9).
- [ ] AC-6 — `grep -rniI benchmark HomeGymLog/` finds nothing (Step 9).
- [ ] AC-7 — Terminate and relaunch → Home placeholder, no error (Steps 9, 10).
- [ ] AC-8 — `HomeGymLogApp.init` builds the container once into a `Result`; body switches on it; success
      shows `RootView`; DEBUG crashes on failure; release shows `StoreErrorView` (inspection) (Step 10).

Persistence (`$TEST` on iPhone 15, all green):

- [ ] AC-9 round trip, AC-10 program cascade, AC-11 log cascade, AC-16 status invariants (Step 6).
- [ ] AC-12 note fetch-then-insert, AC-13 apply generated program, AC-14 apply re-slot map, AC-15 skip (Step 7).

Library, phases, weights, generator, re-slot (unit tests, all green):

- [ ] AC-17, AC-18, AC-19, AC-20 (Step 2).
- [ ] AC-21, AC-22, AC-23, AC-24, AC-25, AC-26 (Step 3).
- [ ] AC-32 weekday helper and Monday-of-week, AC-39, AC-40, AC-41, AC-42, AC-43 (Step 4).
- [ ] AC-27, AC-28, AC-29, AC-30, AC-31, AC-32 `startDate`, AC-33, AC-34, AC-35, AC-36, AC-37, AC-38 (Step 5).

Process:

- [ ] After every step `$BUILD` and `$TEST` succeed on iPhone 15 (iOS 17.5); Step 11 also builds on
      iPhone 17 (iOS 26.5).
- [ ] No dependency, entitlement, or capability added; `project.pbxproj` never hand-edited.
- [ ] Folder tree matches the appendix.

---

## Appendix — folder tree at the end of M1

```
HomeGymLog.xcodeproj/
  project.pbxproj                              (wizard; never hand-edited)
  xcshareddata/xcschemes/HomeGymLog.xcscheme   (shared scheme)
HomeGymLog/
  App/
    HomeGymLogApp.swift          @main, container Result, root switch
    RootView.swift               TabView + hidden system bar + safeAreaInset pill
    AppTab.swift                 tab enum: label, placeholder milestone
    StoreErrorView.swift         release-only store failure screen (placeholder copy)
  Models/
    AppSchema.swift              Schema + makeContainer(inMemory:)
    Program.swift
    PlannedSession.swift
    WorkoutLog.swift
    LoggedExercise.swift
    LoggedSet.swift
    ExerciseNote.swift
    ProgramStore.swift           apply(generated), apply(reslotMap), skip, slots(of:)
    ExerciseNoteStore.swift      note(forExerciseKey:), save(text:forExerciseKey:)
  Engine/
    EngineTypes.swift            Phase, SessionStatus, SetStatus, MuscleGroup, PlannedExercise
    Equipment.swift              EquipmentKind: step/min/max/threshold, loadability, tenths
    ExerciseLibrary.swift        Exercise, ExerciseLibrary (18 entries)
    SplitPlans.swift             SplitDay, SplitInfo, SplitPlans (PLANS, SPLIT, DEF_DAYS, exercise count)
    PhaseSplit.swift             weeks, phaseOf(week:weeks:), phaseRanges
    WeightFormula.swift          baseTenths, roundAndClampTenths, targetWeightLb
    CalendarRules.swift          appWeekday, monday(ofWeekContaining:), day(adding:), training-day helpers
    Reslot.swift                 SessionSlot, Reslot.reslot
    ProgramGenerator.swift       ProgramInputs, ProgramInputError, GeneratedSession, GeneratedProgram, generate
  Shared/
    Theme.swift                  Theme namespace over the color sets
    PlaceholderScreen.swift      title + "Coming in milestone N"
    FloatingTabBar.swift         the pill
    TabIcon.swift                four shape-drawn icons
  Assets.xcassets/
    AccentColor.colorset         #e11d48 (wizard set, filled)
    AppIcon.appiconset           (wizard, empty until M5)
    bg.colorset  sf.colorset  sf2.colorset  tx.colorset  mu.colorset  bd.colorset   (light + dark)
    success.colorset  warning.colorset  phaseFoundation.colorset  phaseDeload.colorset  (universal)
  Preview Content/Preview Assets.xcassets/      (wizard)
HomeGymLogTests/
  Support/
    TestCalendar.swift           fixed Gregorian / America/New_York calendar, day(), Example A slot fixtures
    TestInputs.swift             TestCalendar.exampleAInputs() (needs ProgramInputs; written in Step 5)
    TestContainer.swift          TestStore, @MainActor makeTestStore() (in-memory)
  Engine/
    EquipmentTests.swift
    ExerciseLibraryTests.swift
    PhaseSplitTests.swift
    WeightFormulaTests.swift
    CalendarRulesTests.swift
    ReslotTests.swift
    ProgramGeneratorTests.swift
  Persistence/
    ModelRoundTripTests.swift
    CascadeDeleteTests.swift
    StatusInvariantTests.swift
    ProgramStoreTests.swift
    ExerciseNoteStoreTests.swift
```
`Features/` is not created in M1 (no real screen exists yet); M2 adds `Features/Home/` and
`Features/Program/`. `ContentView.swift`, `Item.swift` and the wizard's `HomeGymLogTests.swift` are gone.

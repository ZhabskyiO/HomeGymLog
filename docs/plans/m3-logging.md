# M3 slice 1 — Workout logging (start, swipe, RPE, adjust, next, exit, summary, resume): implementation plan

**Status: drafted 2026-09-13 on branch `m3-logging`; verifier round 1 PASS WITH FIXES (applied in the main session), round 2 PASS; awaiting the user's approval to implement.** For `docs/specs/m3-logging.md` (architecture review applied). Spec §2–6 and §8 are the contract (ACs
`AC-1`…`AC-41`); format follows `docs/plans/m2-program-tab.md`.

## 1. Goal and scope
Land the workout-logging slice in the order of §3: Engine rules and suites, the `rpeSkipped` field and guarded store writers, predicates and mapping, Shared text, DEBUG seeds, the lifted
tab, the in-progress route with the full-screen workout (logging, swipe, RPE, adjust, summary, Done), then the Home and Program start buttons and the sweep. Every step builds with all tests
green on iPhone 15 / iOS 17.5.

Out of scope (spec §7): rest overlay and notification (m3-rest-timer); detail sheet, notes, swap, progression pill (m3-exercise-tools; Swap, Add note and ⓘ stay inert); missed-day prompt,
shift/skip UI, Settings, the restart tab reset (M4); schema versioning, haptics (M5); stray-log cleanup. **No AC is excluded.** User-run because scripted taps are refused here (gotchas
2026-09-10): AC-13–AC-23 (AC-20 is the Exit-flash recording) on the simulator, AC-24–AC-27 on the device.

## 2. Decisions this plan relies on
- INSIGHTS "2026-09-13 — M3 decisions" (root route, startable sessions, Done → Home, streak, Exit confirm, Next exercise, stored RPE skip, carry, summary rules, stray logs, inert controls,
  guarded writers, row ids, `clock.now()` at the action, invariants, root-owned tab, one `WorkoutSheet`, unversioned field) → Steps 1–13.
- M2 Home and Program architecture (screen-owned `@Query` built in `init`, mapping only in the query owner, `.id(model.id)`, selection reset on appear, `-tab`, `-programWeek`,
  `-programDay`), DEBUG seeding with nil-by-default `@Entry` values, Engine/Model boundary, one writer per invariant, explicit deletes, test conventions (Swift Testing, `@MainActor` only for
  app-target types) → all steps.
- Researcher facts 4.5 (1–10) and 4.6 (1–5); architecture review B1–B3 and items 1–12 as applied; gotchas SwiftData, SwiftUI, Swift language and Xcode entries.

Plan-level choices (challengeable):
- **Reordered build.** Seeds (Step 7) and the tab lift (Step 8) come before the views, and the root route lands with the first workout screen (Step 9): every screen step verifies with a
  seeded `/design-compare`, which needs the seeds and the route, and `RootView` cannot name `WorkoutView` before it exists. Start wiring stays last.
- **Writers return `Bool`** (`@discardableResult`; true = wrote and saved), so a guard no-op is assertable. One private `commit(_:)` saves, or rolls back and rethrows; the existing
  `start(session:at:in:)` and `finish` adopt it.
- **Inert Swap, Add note and ⓘ are `Text`, not `Button`** (AC-23). **`Shared/StartWorkoutButton`** serves Home and Program, so both share Home's style by construction. **`StepperButton`
  gains `var fill: Color = Theme.sf2`.** **Thousands grouping is a manual ","** like `kfmt`, so snapshots are locale-independent.
- **The `summary` seed logs E1S1 last**, so Save & log set at 120 lb finds no pending sibling to carry to (seed table: store functions only; E1S2–S3 stay 110).

Open questions: none. The `isDiscarding` flag is conditional on AC-20 (§5).

## 3. Steps
Shorthands (`build/` is gitignored; `ffmpeg` is not installed, so Step 9 writes its own frame sampler):
```
DEST='platform=iOS Simulator,name=iPhone 15,OS=17.5'
BUILD='xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"'
TEST='rm -rf build/tests.xcresult; xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult test 2>&1 | tee build/last-test.log | grep -E "✘|error:|TEST (SUCCEEDED|FAILED)"'
UDID=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-5"][] | select(.name=="iPhone 15") | .udid')
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app
BOOT() { xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b; xcrun simctl status_bar "$UDID" override --time 9:41; }
LAUNCH() { xcrun simctl terminate "$UDID" com.zhabskyi.homegymlog.ios 2>/dev/null; xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" com.zhabskyi.homegymlog.ios "$@"; }
SHOT() { sleep 3; xcrun simctl io "$UDID" screenshot "build/shot-$1.png"; }
DARK() { xcrun simctl ui "$UDID" appearance dark; }; LIGHT() { xcrun simctl ui "$UDID" appearance light; }
ONLY() { rm -rf build/tests.xcresult; xcodebuild test -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult -parallel-testing-enabled NO -only-testing:"HomeGymLogTests/$1" 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)"; }   # names need ()
PROTO() { (cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &); sleep 1
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=3000,5600 \
    --virtual-time-budget=20000 --screenshot=build/proto-all.png "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
  c() { sips -c "$2" "$3" --cropOffset "$4" "$5" build/proto-all.png --out "build/proto-$1.png" >/dev/null; }
  c home 900 700 930 40; c program 720 1620 2530 30                                   # recorded in the design-compare skill
  c wo-start 600 300 930 740; c wo-swipe 600 300 930 1045; c wo-rpe 700 310 930 1345; c summary 640 330 930 1975; c wo-adjust 570 300 1890 40; }   # B2 B3 B4 B6, C1
```
The five workout crops were found on a `sips -Z 1500` thumbnail and each crop was read at planning time; read every `build/proto-*.png` once after `PROTO`. `/design-compare <snapshot>
"<args>"` follows the skill (dark unless stated, status bar pinned by `BOOT`) and writes `build/compare-<snapshot>.png`. "Fails if" names the assertion that catches a wrong rule.
React analogies for concepts new in this slice (repeat them in doc comments): `.alert(isPresented:)` ≈ a controlled `<Dialog open>`; `.sheet(item:)` ≈ a modal rendered while a state
value is non-null; `DragGesture` ≈ pointer events with `touch-action: pan-y`; `accessibilityAction(named:)` ≈ ARIA custom actions; `.safeAreaInset(edge: .bottom)` ≈ a sticky footer.
### Step 1 — Engine: `WorkoutFlow` (values, state, rows, hint, progress, reps floor, startable)
File `Engine/WorkoutFlow.swift` (new; every type `nonisolated`, `Equatable, Sendable`; no SwiftData, SwiftUI or text):
```swift
struct WorkoutSetValue { let id: UUID; let order: Int; let weightLb: Double; let reps: Int; let status: SetStatus; let rpe: Int?; let rpeSkipped: Bool; let loggedAt: Date? }
struct WorkoutExerciseValue { let id: UUID; let order: Int; let exerciseKey: String; let targetWeightLb: Double; let sets: [WorkoutSetValue] }
struct WorkoutSessionInfo { let name: String; let week: Int; let phase: Phase };  enum ProgressTone { case passed, current, upcoming }   // success / accent / sf2
enum WorkoutState { case logging(exercise: Int, set: Int), rpePending(exercise: Int, set: Int), summary }
enum SetRowKind { case done(rpe: Int?), skipped, active, waiting };  struct SetRowState { let kind: SetRowKind; let dimmed: Bool }
enum WorkoutFlow {   // positions index `sorted` output: (order, id.uuidString) for exercises and their sets; nothing traps
    static func sorted(_ exercises: [WorkoutExerciseValue]) -> [WorkoutExerciseValue];  static func state(exercises: [WorkoutExerciseValue]) -> WorkoutState   // 5.1
    static func focusSet(exercises: [WorkoutExerciseValue], state: WorkoutState) -> WorkoutSetValue?;  static func isRatingPending(_ state: WorkoutState) -> Bool
    static func rowStates(exercises: [WorkoutExerciseValue], state: WorkoutState, sheetOpen: Bool) -> [SetRowState];  static func displayedExercise(_ state: WorkoutState) -> Int?
    static func showsHint(_ state: WorkoutState, sheetOpen: Bool) -> Bool;  static func nextExerciseEnabled(_ state: WorkoutState) -> Bool   // logging(0, 0) + no sheet; .logging
    static func progress(exerciseCount: Int, displayed: Int) -> [ProgressTone];  static func hasLoggedSet(_ exercises: [WorkoutExerciseValue]) -> Bool   // Exit confirmation
    static func decrementedReps(_ reps: Int) -> Int;  static func isStartable(_ state: WeekStripState) -> Bool   // max(1, reps − 1); .today or .missed
}
```
Fixture `HomeGymLogTests/Support/WorkoutFixtures.swift` (new, plain): `uuid(_ n: Int) -> UUID` (fixed-width digits, so `uuidString` order is `n` order); `session11` = latPull 110, lowRow
100, dbRow 47.5, rdl 52.5, curl 27.5 and `session7` = goblet 50, rdl 50, legExt 70, legCurl 50, split 30 (typed from spec 5.3, 5.7); `exercises(_ targets: [(String, Double)], sets: Int = 3,
reps: Int = 12) -> [WorkoutExerciseValue]` (all pending, exercise ids `uuid(100·(i+1))`, set ids `uuid(100·(i+1)+j+1)`); `editing(_:exercise:set:status:rpe:rpeSkipped:weightLb:loggedAt:)`
returning new values; `shuffled(_:)` reversing exercises and sets. Tests `Engine/WorkoutFlowTests.swift` (new, plain):
- **walks:** the twelve rows of 5.1 as literal states, each repeated on `shuffled` (fails if `state` reads array position). **Ties:** two sets with `order` 1 and ids `uuid(9)`/`uuid(3)` in
  both input orders → `uuid(3)` first (fails without the tie-break). Broken prefix (E1S1 pending, E1S2 done) → `.logging(0, 0)`, no trap; a done set with RPE 7 and `rpeSkipped` →
  `.logging(0, 1)`, never `.rpePending`.
- **rows, hint, next, focus:** the four rows of 5.2 as literal `[SetRowState]`; `.logging(0, 1)` with a sheet → row 2 `.waiting`, not dimmed; `.rpePending(0, 2)` → three `.done`, none
  dimmed; `showsHint` true only for `.logging(0, 0)` without a sheet; `nextExerciseEnabled` false for `.rpePending(0, 0)` and `.summary`; `focusSet` = E1S1 on the `wo-rpe` rows, E1S2 on
  `wo-adjust`, nil in summary; `hasLoggedSet` false when all pending, true with one skipped set.
- **progress (bucketed):** `(5, 2)` → `[passed, passed, current, upcoming, upcoming]`; `(5, 0)`; before the first bucket `(5, −1)` → five `upcoming`.
- **startable:** on `HomeFixtures.midProgramInput(completedIndexes: [0, 1, 2, 3, 4, 5, 6, 8, 9, 10])` at `midProgramDay`, `isStartable(HomeStats.sessionState(…))` is true for 11 and 7, false
  for 10, 12, 7 or 11 passed in `skippedIndexes`, and `.rest`.

`Engine/AdjustStepperTests.swift` (new, plain): the 5.3 stepper table as literals through `EquipmentKind.stepped(lb:by:)` (marcy 110 → 100/120, 150 +1 → nil, 10 −1 → nil; dumbbell 47.5 →
45/50, 50 +1 → 52.5, 52.5 +1 → nil, 5 −1 → nil, 5 +1 → 7.5, 27.5 stepped −1 nine times → 5); `decrementedReps` 12 → 11, 1 → 1, 0 → 1; kg text 45.4/49.9/54.4, 150 → "68", 20.4/21.5/22.7, 52.5
→ "23.8", 5 → "2.3". Verify: `$BUILD && $TEST`. AC-28, AC-29, AC-31, AC-34 (Engine half).
### Step 2 — Engine: `WorkoutSummary`
File `Engine/WorkoutSummary.swift` (new, `nonisolated`, `Equatable, Sendable`):
```swift
struct SummaryRecord { let exerciseKey: String; let previousBestLb: Double?; let weightLb: Double }
struct WorkoutSummaryValue { let volumeLb: Double; let endedAt: Date; let durationSeconds: Int; let muscles: [MuscleGroup]; let records: [SummaryRecord] }
enum WorkoutSummary {
    static func make(exercises: [WorkoutExerciseValue], startedAt: Date, bestsBefore: [String: Double]) -> WorkoutSummaryValue   // spec 5.4, 5.6
    static func endInstant(exercises: [WorkoutExerciseValue], startedAt: Date) -> Date   // latest loggedAt of a non-pending set, else startedAt
    static func elapsedSeconds(from start: Date, to end: Date) -> Int;  static func bests(from records: [PersonalRecord]) -> [String: Double]   // max(0, ⌊Δ⌋); uniquingKeysWith max
}
```
Tests `Engine/WorkoutSummaryTests.swift` (new, plain; `start = midProgramDay − 2 520 s`):
- **5.4:** `session11` all done at RPE 7, E1S1 at 120, set *k* at `start + 168·k`, bests latPull 100, lowRow 90, dbRow 45, rdl 50, curl 25 → volume 12 270, `[.back, .legs, .arms]`, the five
  literal records, 2 520 s, `endedAt == start + 2520`. **5.7:** `session7` at target, bests goblet 52.5, rdl 50, legExt 80, legCurl 60, split 32.5 → 9 000, `[.legs]`, no records (fails on
  the rdl tie if the rule uses `>=`).
- **edges:** empty bests → five records with nil previous; one done 110 × 12 + one skipped + one pending → 1 320; a skipped rating equals RPE 7 in every value; all skipped → 0, `[]`, `[]`;
  all pending → `endedAt == start`, 0 s; a `loggedAt` before `start` → 0 s (before the first bucket; fails without the clamp); key `"mystery"` → volume counted, no muscle, record under the
  key; latPull at positions 0 (top 110) and 3 (top 130) → one record at position 0 with 130; `bests(from:)` with latPull records 100 and 120 → 120, no trap; `elapsedSeconds` 754.9 s → 754,
  −0.5 s → 0. Verify: `$BUILD && $TEST`. AC-30.
### Step 3 — Models: `rpeSkipped`, save-or-rollback, shared start, `discard`
`Models/LoggedSet.swift`: add exactly `var rpeSkipped: Bool = false` with the researcher's doc comment (the default is mandatory); the `rpe` comment becomes "6–10; nil until chosen, when the
rating was skipped (`rpeSkipped`), or when the set was skipped"; the init is unchanged. `Models/WorkoutLogStore.swift`:
```swift
private static func commit(_ context: ModelContext) throws { do { try context.save() } catch { context.rollback(); throw error } }   // ≈ a transaction
@discardableResult static func start(sessionIndex: Int, rows: [PlannedSession], at: Date, in context: ModelContext) throws -> WorkoutLog?   // first row with that index; nil unless pending
static func discard(_ log: WorkoutLog, in context: ModelContext) throws   // Exit: delete(_:in:), then commit
```
`start(session:at:in:)` and `finish` end in `commit`. Fixture `HomeGymLogTests/Support/WorkoutStoreFixtures.swift` (new, `@MainActor`): `sixMonthRows(in:) throws -> [PlannedSession]`
(`ProgramStore.start` 6 months, days 0…4, 45 min, `now:` 08-31 12:00; fetch with `sessionPredicate` sorted by index) and `sets(of: WorkoutLog) -> [[LoggedSet]]`
(`sortedExercises.map(\.sortedSets)`). Tests: `Persistence/RpeSkippedTests.swift` — `LoggedSet(order: 0, weightLb: 40, reps: 12)` saved reads `false` from `ModelContext(container)`; set
`true`, save → a fresh context reads `true`. `Static/SchemaSourceTests.swift` — the comment-stripped lines of `HomeGymLog/Models/LoggedSet.swift` (the `#filePath` root `ClockUsageTests`
uses) contain one that trims to `var rpeSkipped: Bool = false` (fails when the default is dropped). `Persistence/WorkoutStartTests.swift` (`#if DEBUG`, `DebugSeed.midProgram` container) —
indexes 11 and 7 → a log whose `startedAt` is the passed date, 15 sets; 10 (completed), 12 after `ProgramStore.skip` + save, and 999 → nil with `fetchCount(WorkoutLog)` unchanged; 11 twice →
the same log (`===`), one new log; `discard` of 11's log → fresh counts drop by exactly 1 log, 5 exercises, 15 sets, and session 11 is pending with no log. Verify: `$BUILD && $TEST`. AC-33
(discard), AC-34, AC-41.
### Step 4 — Models: the six guarded set writers
`Models/WorkoutLogStore.swift` (add; each returns false before mutating anything when its guard fails, otherwise mutates and `commit`s):
```swift
enum WorkoutLogStoreError: Error, Equatable { case invalidRPE(Int) }   // every writer below is @discardableResult
static func logSet(_ set: LoggedSet, at: Date, in context: ModelContext) throws -> Bool                       // pending → done, loggedAt
static func saveAndLogSet(_ set: LoggedSet, weightLb: Double, reps: Int, at: Date, in context: ModelContext) throws -> Bool
    // pending only: this set weight, reps, done, loggedAt; `set.exercise?.sets` with order > set.order and pending get weight, reps
static func skipSet(_ set: LoggedSet, weightLb: Double, reps: Int, at: Date, in context: ModelContext) throws -> Bool   // pending only; this set only
static func setRPE(_ rpe: Int, on set: LoggedSet, in context: ModelContext) throws -> Bool;  static func skipRPE(on set: LoggedSet, in context: ModelContext) throws -> Bool
    // setRPE throws outside 6…10 first; both require done, rpe == nil, !rpeSkipped (B1)
static func nextExercise(_ exercise: LoggedExercise, at: Date, in context: ModelContext) throws -> Bool   // no-op while a set awaits RPE or none pends
```
Tests `Persistence/WorkoutSetWriterTests.swift` (new, `@MainActor`; `sixMonthRows` + `start(session:)` on session 11 (3 × 12) or 45 (Build, 4 × 10); values read through a fresh
`ModelContext`; every no-op also asserts `false` and `context.hasChanges == false`): logSet → done with `loggedAt`, weight, reps and RPE unchanged; on a done set → false. Save & log set on
session 45 with set 1 done and draft 120 × 11 on set 2 → set 2 done at 120 × 11, sets 3–4 pending at 120 × 11, set 1 and exercise 2 untouched; set 1 done, set 2 skipped, draft on set 3 →
only sets 3–4 change; on set 4 → only set 4; set 3's `order` rewritten to 1 → set 3 not carried to (fails if carry uses `>=`). Skip set → skipped at the draft, set 2 still at target. setRPE
7 → `rpe` only; 5 and 11 throw `.invalidRPE`, nothing written; `setRPE(8)` after `setRPE(7)` → false, still 7; `setRPE(7)` after `skipRPE` → false, nil. skipRPE on a done nil set →
`rpeSkipped`; a second skip, a pending, a skipped and an RPE-7 set → false. nextExercise with set 1 done at 7 → sets 2–3 skipped, exercise 2 untouched; with set 1 done and nil RPE → false,
sets pending. Verify: `$BUILD && $TEST`. AC-33.
### Step 5 — Models: `WorkoutSnapshotBuilder` (predicates, mapping, id map, PR baseline)
File `Models/WorkoutSnapshotBuilder.swift` (new):
```swift
@MainActor enum WorkoutSnapshotBuilder {   // rows in, Engine values out; maps, never validates
    static let inProgressPredicate = #Predicate<WorkoutLog> { log in   // nested flatMap: a second `?.` hop crashes at fetch (gotchas 2026-09-13)
        log.finishedAt == nil && log.session.flatMap { session in session.program.flatMap { $0.archivedAt == nil } } == true }
    static func exercisePredicate(logID: UUID) -> Predicate<LoggedExercise>   // #Predicate { $0.workout?.id == logID }
    static func setPredicate(exerciseIDs: [UUID]) -> Predicate<LoggedSet>     // #Predicate { set in set.exercise.flatMap { exerciseIDs.contains($0.id) } == true }
    static func values(exercises: [LoggedExercise], sets: [LoggedSet]) -> [WorkoutExerciseValue]   // Dictionary(grouping:) on set.exercise?.id
    static func sessionInfo(of log: WorkoutLog) -> WorkoutSessionInfo;  static func byID<Row>(_ rows: [Row], id: (Row) -> UUID) -> [UUID: Row]   // ("", 1, .foundation) fallback; uniquingKeysWith first
    static func bestsBefore(programID: UUID?, in context: ModelContext) throws -> [String: Double]   // sessionPredicate → summaries + finishedLogs → personalRecords → bests; nil → [:]
}
```
Tests (iPhone 15 / iOS 17.5 here, iPhone 17 / iOS 26.5 in Step 14):
- `Persistence/WorkoutRoutingPredicateTests.swift` — `insertSampleGraph` (its log on session 0 is in progress) → 1; after `finish` → 0; a fresh store after `discard` → 0; an orphan
  `WorkoutLog` added → still 1; the program archived → 0; a second in-progress log on session 1 with an earlier `startedAt` → 2, sorted by `startedAt` as [second, first]; no fetch crashes.
  AC-36.
- `Persistence/WorkoutQueriesTests.swift` (`#if DEBUG`) — `midProgram` (10 finished logs) + `start(session 11)`: exercise predicate → 5 rows, orders 0…4; set predicate on their ids → 15
  rows, orders five 0s, five 1s, five 2s; `UUID()` → 0 for both; `WorkoutFlow.sorted(values(…))` keys latPull, lowRow, dbRow, rdl, curl at 110/100/47.5/52.5/27.5, all pending, `rpeSkipped`
  false, state `.logging(0, 0)`. AC-37.
- `Persistence/WorkoutSnapshotBuilderTests.swift` (`#if DEBUG`) — `sessionInfo`: 11's log → ("Pull", 3, .foundation), orphan → ("", 1, .foundation); `byID([a, b, a])` → 2 keys, no trap; rows
  reversed, `byID` of E1S2's value id → `logSet` → a fresh context shows latPull order 1 done and 14 pending; `bestsBefore(program.id)` on `midProgram` holds latPull 100, lowRow 90, dbRow
  45, rdl 50, curl 25 (spec 5.4 literals); nil → `[:]`. AC-32 (fallbacks), AC-33 (id map).
- `Persistence/MissedWorkoutEndToEndTests.swift` (`#if DEBUG`) — `missed` container, now 09-15 12:00: `start(sessionIndex: 7)`, each of 15 sets `logSet(at: now + 60·k)` + `setRPE(7)`;
  `make(…)` → 9 000, `[.legs]`, no records; `finish(at: endInstant)` → session 7 completed, `scheduledDate` 2026-09-09, `week` 2; `HomeStats` on refetched rows: streak 11, completed 11, week
  volume 7 560, today session 11, recent keys dbBench, inclineDb, shoulderPress, pecDeck; 7 no longer startable. AC-35. Verify: `$BUILD && $TEST`.
### Step 6 — Shared: `WorkoutText`, `FlowLayout`, `StepperButton` fill
`Shared/WorkoutText.swift` (new): constants `swipeHint`, `rpeTitle`, `kicker` ("SESSION COMPLETE"), `noRecords` ("No new records today."), `discardTitle`, `discardMessage`, and these
`String` functions: `clock(seconds:)` ("%02d:%02d", minutes uncapped, negative → "00:00"), `grouped(_:)` (manual ","), `volume(lb:unit:)` (grouped `WeightDisplay.whole`),
`volumeCaption(unit:)` ("lb total volume"), `weightCaption(unit:)` ("Weight · lb"), `exerciseName(key:)` (library name, else the key), `exerciseLine(number:count:key:)` ("Exercise 1 of 5 ·
Back"; no suffix for an unknown key), `equipment(key:)` ("" when unknown), `meta(startedAt:info:calendar:)` (`HomeText.dayLabel` + " · Week 3 · Foundation"), `rowLabel(_: SetRowKind)` ("RPE
7", "logged", "skipped", "← →", ""), `rpeLabel(_:)` (easy … max, "" outside 6…10), `recordPrevious(_:unit:)` ("100 lb", "—" when nil), `recordNew(_:unit:)` ("120 lb") and
`setAccessibilityLabel(number:weightLb:reps:unit:)` ("Set 1, 110 lb × 12 reps"). `Shared/FlowLayout.swift` (new): `struct FlowLayout: Layout { var spacing: CGFloat = 6 }`, wrapping rows at
the proposed width (`Layout` ≈ a CSS `flex-wrap` container; checked by the `summary` screenshot; if the compiler diagnoses the conformance under MainActor default isolation, declare
`nonisolated struct FlowLayout`, verifier 1 finding 6). `Shared/StepperButton.swift`: `var fill: Color = Theme.sf2` fills the circle, **declared before `action`** so
`StepperButton(symbol:size:fill:) { … }` compiles (the memberwise init follows declaration order; verifier 1 finding 3). Tests
`Shared/WorkoutTextTests.swift` (new, `@MainActor`, `TestCalendar.calendar` with locale `en_US`): clock 0/59/754/2 520/3 600/4 503 → "00:00"/"00:59"/"12:34"/"42:00"/"60:00"/"75:03" and −1 →
"00:00" (before the first bucket; without the clamp it reads "00:-1"); `grouped` 0, 999, 1 000, 9 000, 12 270, 1 234 567; `volume` 12 270 lb → "12,270", in kg "5,566", 9 000 lb in kg
"4,082"; captions in lb and kg; latPull → "Lat Pulldown", "Exercise 1 of 5 · Back", "Marcy · high pulley"; "mystery" → "mystery", "Exercise 2 of 5", ""; meta ("Pull", 3, .foundation) at
09-15 12:00 → "Tue, Sep 15 · Week 3 · Foundation", ("", 1, .foundation) → "Tue, Sep 15 · Week 1 · Foundation"; `rowLabel` for all five kinds; `rpeLabel` 6…10, 5 and 11 → ""; records 100 →
120 in lb and kg ("45.4 kg" / "54.4 kg"), nil previous "—"; the accessibility label in lb and kg ("Set 1, 49.9 kg × 12 reps"). Verify: `$BUILD && $TEST`. AC-32.
### Step 7 — DEBUG workout seeds and the two preview environment values
`App/DebugSeed/DebugSeed.swift`: cases `woStart = "wo-start"`, `woSwipe = "wo-swipe"`, `woRPE = "wo-rpe"`, `woAdjust = "wo-adjust"`, `summary = "summary"` (explicit raw values so the scan
sees every name); `referenceDate` 09-15 12:00 for all five; `initialDraft` nil; `makeContainer` → `MidProgramSeed.populate`, then `WorkoutSeed.populate(stage, now: referenceDate(calendar:),
in:)`; `var workoutDragPreview: CGFloat?` (72 for `.woSwipe`) and `var workoutAdjustPreview: Bool?` (true for `.woAdjust`), nil otherwise. `App/DebugSeed/WorkoutSeed.swift` (new, whole file
`#if DEBUG`):
```swift
enum WorkoutSeed {   // store functions only, on session 11 of the current program
    enum Stage { case started, awaitingRating, rated, finishedSets }   // wo-start and wo-swipe, wo-rpe, wo-adjust, summary
    @discardableResult static func populate(_ stage: Stage, now: Date, in context: ModelContext) throws -> WorkoutLog
}
```
Recipe: `start(sessionIndex: 11, rows: sortedSessions, at: now − 754 s)` (`finishedSets`: − 2 520 s); `awaitingRating` adds `logSet(E1S1, at: start + 168)`; `rated` adds `setRPE(7)`;
`finishedSets` logs every set but E1S1 at `start + 168·k` with `setRPE(7)`, then `saveAndLogSet(E1S1, weightLb: 120, reps: 12, at: start + 168)` + `setRPE(7)` last, so no pending sibling is
carried to. `App/AppClock.swift` (existing extension): `@Entry var workoutDragPreview: CGFloat? = nil` and `@Entry var workoutAdjustPreview: Bool? = nil`, documented like
`programTabPreselection`. `App/HomeGymLogApp.swift`: stored `dragPreview` and `adjustPreview` from nil locals assigned inside the existing `if let seed` branch; the body adds both
`.environment(…)` modifiers. Tests: `Seed/DebugSeedTests.swift` — `parses` maps the five to 09-15, `drafts` expects nil for them, and `DebugSeed.allCases.filter { $0.workoutDragPreview !=
nil } == [.woSwipe]` (value 72), likewise `[.woAdjust]` for the adjust preview. `Seed/WorkoutSeedTests.swift` (new, `#if DEBUG`, `@MainActor`, parameterised over the five): an
`inProgressPredicate` fetch → one log on session 11; `startedAt` = 09-15 12:00 − 754 s (summary − 2 520 s); 5 exercises, 15 sets, all `rpeSkipped` false; statuses, RPE and `loggedAt` per the
seed table (`wo-rpe` E1S1 done nil at +168; `wo-adjust` E1S1 RPE 7; `summary` weights 120, 110, 110, 100 ×3, 47.5 ×3, 52.5 ×3, 27.5 ×3 at +168·k, RPE 7); `WorkoutFlow.state` → `.logging(0,
0)`, `.logging(0, 0)`, `.rpePending(0, 0)`, `.logging(0, 1)`, `.summary`. `Seed/SeedHomeStatsTests.swift` — argument rows for `.woStart` and `.summary` carrying `midProgram`'s numbers (3,
10, 120, 7 560, the same recent keys, week 3): in-progress logs are not mapped. `Seed/SummaryDoneHomeStatsTests.swift` (new, `#if DEBUG`, `@MainActor`; verifier 1 finding 1):
`DebugSeed.summary` container, the in-progress log fetched with `inProgressPredicate`, `WorkoutLogStore.finish(log, at: WorkoutSummary.endInstant(exercises: values, startedAt: log.startedAt))`,
then `HomeStats` on refetched rows at 09-15 12:00: streak 4, completed 11 of 120, `weekVolumeLb` 19 830, recent-record keys `[latPull, lowRow, dbRow, rdl]` all dated 09-15, the next session
index 12 ("Legs", Wed 09-16) (fails if `finish` is not written or the in-progress mapping leaks). AC-21 (numbers; the user checks only the screen). `Static/SeedNameScanTests.swift` (new): every app source whose code contains a quoted `"wo-start"`,
`"wo-swipe"`, `"wo-rpe"`, `"wo-adjust"` or `"summary"` is under `App/DebugSeed/`, and each name is found there at least once (an empty scan cannot pass). Verify: `$BUILD && $TEST`; `BOOT;
DARK; LAUNCH -seed wo-start; SHOT seed-shell` → still the shell on Home with the Pull Today card (the route lands in Step 9). AC-38, AC-39 (scan).
### Step 8 — Lift the tab selection into `RootView`
`App/RootView.swift`: `@State private var selectedTab: AppTab = .home`, `@State private var appliedInitialTab = false`, `@Environment(\.initialTab) private var initialTab`, and
```swift
Group {
    if let program = currentPrograms.first { ShellView(program: program, selected: $selectedTab) }
    else { OnboardingView(initialDraft: seedDraft ?? OnboardingDraft(units: WeightUnit(rawValue: unitsRaw) ?? .lb)) }
}
.onAppear {   // a Group re-runs this on every route switch; the flag makes it once (≈ a useRef "has run" flag)
    if !appliedInitialTab { appliedInitialTab = true; if let initialTab { selectedTab = initialTab } }
}
```
`App/ShellView.swift`: `@Binding var selected: AppTab` (≈ lifting state above a component that unmounts); its `initialTab` read and `.onAppear` go; the preview passes `.constant(.home)`. No
new tests (the flag is covered by AC-21's `-tab program` case). Verify: `$BUILD && $TEST`; `LAUNCH -seed midProgram -tab program; SHOT tab-program` → Program, WK 3 · Tue 15, "Pull" ·
"Today", pill on Program; `LAUNCH -seed midProgram; SHOT tab-home` → Home.
### Step 9 — Root route and the logging screen (header, rows, bottom bar, Next exercise, Exit)
`App/RootView.swift`: `@Query(filter: WorkoutSnapshotBuilder.inProgressPredicate, sort: \WorkoutLog.startedAt) private var activeLogs: [WorkoutLog]` and a first branch `if let log =
activeLogs.first { WorkoutView(log: log).id(log.id) }` (replaces the shell, never a cover: fact 3; `.id` ≈ `key={log.id}`). `Features/Workout/WorkoutView.swift` (new; owns rows, state and
handlers):
```swift
struct WorkoutView: View {
    let log: WorkoutLog;  private let info: WorkoutSessionInfo   // log: startedAt, and the row passed to discard (and finish, Step 12)
    @Query private var exerciseRows: [LoggedExercise];  @Query private var setRows: [LoggedSet]   // ≈ useQuery: re-fetched after every save (fact 1)
    @State private var isConfirmingExit = false            // plus appClock, modelContext and @AppStorage("units") → unit
    init(log: WorkoutLog) {
        self.log = log; info = WorkoutSnapshotBuilder.sessionInfo(of: log)
        _exerciseRows = Query(filter: WorkoutSnapshotBuilder.exercisePredicate(logID: log.id), sort: \LoggedExercise.order)
        _setRows = Query(filter: WorkoutSnapshotBuilder.setPredicate(exerciseIDs: log.exercises.map(\.id)), sort: \LoggedSet.order)
    }
    var body: some View {
        let exercises = WorkoutFlow.sorted(WorkoutSnapshotBuilder.values(exercises: exerciseRows, sets: setRows))
        let state = WorkoutFlow.state(exercises: exercises)
        Group {
            if state == .summary {
                Theme.bg.ignoresSafeArea()                   // Step 12 puts WorkoutSummaryView here
            } else {
                WorkoutLoggingContent(info: info, startedAt: log.startedAt, exercises: exercises, state: state, sheetOpen: false, unit: unit,
                                      onExit: { exitTapped(exercises) }, onNext: nextExercise)   // onNext: (UUID) -> Void
            }
        }
        .alert(WorkoutText.discardTitle, isPresented: $isConfirmingExit) {
            Button("Discard", role: .destructive) { discard() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(WorkoutText.discardMessage) }
    }
    // Handlers nextExercise(_ exerciseID: UUID), exitTapped(_:) (hasLoggedSet ? confirm : discard()) and discard(): row via byID, clock.now() read
    // in the handler, store call in do/catch + assertionFailure (the store rolled back, so the screen stays derived from rows; never blank in Release).
}
```
`Features/Workout/WorkoutLoggingContent.swift` (new): `VStack(spacing: 0) { WorkoutHeader; ScrollView { exercise block, set rows (gap 8), hint }.padding(.horizontal, 18) }` plus
`.safeAreaInset(edge: .bottom) { WorkoutBottomBar }`; the exercise block is a private subview using `WorkoutText.exerciseLine`, `exerciseName` + a `Text` " ⓘ", `equipment`; rows, hint and
progress come from `WorkoutFlow`. `Features/Workout/WorkoutHeader.swift` (new): Exit pill `Button`, Swap pill `Text`, centre name and `WorkoutElapsedClock` (researcher Q4 sketch:
`TimelineView(.periodic(from: startedAt, by: 1))` ≈ a framework-owned `setInterval`, text `WorkoutText.clock(seconds: WorkoutSummary.elapsedSeconds(from: startedAt, to: clock.now()))`), and
`ProgressSegments(tones:)` (an `HStack(spacing: 4)` of 3 pt capsules, each `.frame(maxWidth: .infinity)`, never `containerRelativeFrame`). `Features/Workout/SetRow.swift` (new):
`SetRow(number: Int, set: WorkoutSetValue, row: SetRowState, unit: WeightUnit)` per spec 2.3 (accent border only for `.active`; `.opacity(row.dimmed ? 0.45 : 1)`).
`WorkoutLoggingContent` declares `onNext: (UUID) -> Void` and passes `WorkoutBottomBar(nextEnabled: …, onNext: { onNext(displayedExercise.id) })` (verifier 1 finding 4).
`Features/Workout/WorkoutBottomBar.swift` (new): `WorkoutBottomBar(nextEnabled: Bool, onNext: () -> Void)`, "Add note" as `Text`, "Next exercise ›" as a `Button` with
`.disabled(!nextEnabled)` and `.opacity(nextEnabled ? 1 : 0.4)`. No new unit tests (every value is Step 1 or 6 output). Verify: `$BUILD && $TEST`; `BOOT; DARK; PROTO; /design-compare
wo-start "-seed wo-start"` against `build/proto-wo-start.png` → matches except the deviations (no "↑ +5 lb" pill; ⓘ inert): "Exit" · "Pull" / "12:34" · "Swap", five segments (first accent),
"Exercise 1 of 5 · Back", three "110 lb × 12 reps" rows (row 1 accent border, "1", "← →"; rows 2–3 dimmed), the hint, "Add note" · "Next exercise ›". **AC-9 (no shell frame):** write
`build/frames.swift` (AVFoundation `AVAssetImageGenerator`, zero time tolerance, one PNG per 1/30 s of the **whole clip** into the folder given, verifier 1 finding 2), then
```
xcrun simctl terminate "$UDID" com.zhabskyi.homegymlog.ios; xcrun simctl install "$UDID" "$APP"; xcrun simctl io "$UDID" recordVideo --codec=h264 --force build/ac9.mov & REC=$!; sleep 2
xcrun simctl launch "$UDID" com.zhabskyi.homegymlog.ios -seed wo-start; sleep 4; kill -INT $REC; wait $REC
mkdir -p build/ac9 && swift build/frames.swift build/ac9.mov build/ac9
```
and read the frames from launch to the first workout frame. The check is valid only if the sampled set contains at least one workout frame ("Exit" pill, "12:34"); if none does, lengthen
the post-launch sleep and repeat. Pass: no frame before the first workout frame shows the Home greeting, a stat tile or the tab pill. The AC-20 reuse (Step 14) applies the same rule with
"a frame after Discard shows the shell" as its validity condition. Also on `-seed wo-start`: the exercise name `Text` has no `lineLimit` (wraps at 24 pt) and the reps/weight `Text`s in
`SetRow` use `.fixedSize(horizontal: true, vertical: false)` so "100 reps" never truncates (spec §6 long name / 3-digit reps; verifier 1 finding 5). A 3-digit reps row needs taps
(adjust reps to 100), so its glance is added to the user's AC-16 hand-off in Step 14; the name wrap is checked on the `wo-start` screenshot (Lat Pulldown fits on one line, so also read
`SetRow`/exercise-block code for the absent `lineLimit`). AC-1, AC-9.
### Step 10 — Swipe row, accessibility actions, RPE card
`Features/Workout/SetSwipeRow.swift` (new): the researcher's Q3 sketch as written — `SetSwipeRow<Content: View>(label:onLog:onAdjust:content:)` (a generic `@ViewBuilder` content ≈
`children`), `@State dragX: CGFloat?`, `@Environment(\.workoutDragPreview)`, offset `dragX ?? preview ?? 0`, the `success` "✓ Logged" /`warning` "Adjust / skip" track at `min(1, ±x / 90)`,
`.gesture(DragGesture(minimumDistance: 20))` clamped to ±140 with commits past ±90 and `withAnimation(.spring(duration: 0.25)) { dragX = 0 }`, `.accessibilityElement(children: .combine)`,
`.accessibilityLabel(label)`, and the "Log set" / "Adjust set" `accessibilityAction(named:)`s. `Features/Workout/RPECard.swift` (new): `RPECard(onPick: (Int) -> Void, onSkip: () -> Void)`
per spec 2.5 ("Skip" text button with `.accessibilityLabel("Skip rating")`, five equal buttons 6–10 with `WorkoutText.rpeLabel`). `WorkoutLoggingContent` gains `onLog: (UUID) -> Void`,
`onAdjust: (UUID) -> Void`, `onRate: (UUID, Int) -> Void`, `onSkipRating: (UUID) -> Void`; inside `ForEach(Array(exercise.sets.enumerated()), id: \.element.id)` each row is
```swift
if row.kind == .active {
    SetSwipeRow(label: WorkoutText.setAccessibilityLabel(number: index + 1, weightLb: set.weightLb, reps: set.reps, unit: unit),
                onLog: { onLog(set.id) }, onAdjust: { onAdjust(set.id) }) { SetRow(number: index + 1, set: set, row: row, unit: unit) }
} else {
    SetRow(number: index + 1, set: set, row: row, unit: unit)
}
```
and after the hint `if WorkoutFlow.isRatingPending(state), let rated = WorkoutFlow.focusSet(exercises: exercises, state: state) { RPECard(onPick: { onRate(rated.id, $0) }, onSkip: {
onSkipRating(rated.id) }) }`. `WorkoutView` adds handlers for `logSet`, `setRPE` and `skipRPE`; `onAdjust` is `{ _ in }` until Step 11. Verify: `$BUILD && $TEST`; `/design-compare wo-swipe
"-seed wo-swipe"` → row 1 shifted 72 pt over the `success` track with "✓ Logged" at 80 % (screenshot only, fact 8), otherwise as wo-start; `/design-compare wo-rpe "-seed wo-rpe"` → row 1 ✓
"logged" without border, rows 2–3 dimmed, no hint, the card 6 easy … 10 max; deviations: the pill, the card's "Skip", "Next exercise ›" at 40 %. AC-2, AC-3.
### Step 11 — Adjust sheet
`Features/Workout/WorkoutSheet.swift` (new): `struct AdjustDraft: Equatable { let setID: UUID; let setNumber: Int; let kind: EquipmentKind?; var weightLb: Double; var reps: Int }` and `enum
WorkoutSheet: Identifiable, Equatable { case adjust(AdjustDraft); var id: UUID }` (one modal union ≈ instead of several `isOpen` flags; `.detail`/`.swap` join in m3-exercise-tools).
`Features/Workout/AdjustSheet.swift` (new): `AdjustSheet(initial: AdjustDraft, unit: WeightUnit, onSave: (AdjustDraft) -> Void, onSkip: (AdjustDraft) -> Void)` with `@State private var
draft` seeded in `init` (≈ `useState(initialProp)`), spec 2.6 layout, `StepperButton(symbol:size: 36, fill: Theme.sf)`; weight ∓ = `draft.kind?.stepped(lb:by: ∓1)` (nil → unchanged), reps −
= `WorkoutFlow.decrementedReps`, + unbounded. `WorkoutView`: `@State private var sheet: WorkoutSheet?`, `@Environment(\.workoutAdjustPreview) private var adjustPreview`, `sheetOpen: sheet !=
nil`, `onAdjust: { openAdjust($0, in: exercises) }` (`openAdjust(_ setID: UUID, in exercises: [WorkoutExerciseValue])` builds the draft from the set value, its 1-based position and the library `kind`), and on the `Group`
```swift
.sheet(item: $sheet) { item in
    switch item {
    case .adjust(let draft):
        AdjustSheet(initial: draft, unit: unit, onSave: saveAndLog, onSkip: skipSet)
            .presentationDetents([.height(300)]).presentationCornerRadius(28).presentationDragIndicator(.hidden).presentationBackground(Theme.sf)
    }
}
.onAppear { if adjustPreview == true, !WorkoutFlow.isRatingPending(state), let set = WorkoutFlow.focusSet(exercises: exercises, state: state) { openAdjust(set.id, in: exercises) } }
```
`saveAndLog` and `skipSet` set `sheet = nil`, then call the store with `clock.now()`. Verify: `$BUILD && $TEST`; `/design-compare wo-adjust "-seed wo-adjust"` → under the dim row 1 "RPE 7",
row 2 "2" without border at full opacity, row 3 dimmed; "Adjust set 2", "Weight · lb" 110, "Reps" 12, "Skip set" · "Save & log set"; deviation: the pill. `LAUNCH -seed wo-adjust -units kg;
SHOT ac6-adjust` → "49.9 kg × 12 reps", "Weight · kg" 49.9. AC-4, AC-6.
### Step 12 — Summary screen, lazy PR baseline, Done from the root
`Features/Workout/WorkoutSummaryView.swift` (new): `WorkoutSummaryView(info:startedAt:summary: WorkoutSummaryValue, recordsReady: Bool, unit:calendar:onDone: () -> Void)` per spec 2.9, Done
pinned by `.safeAreaInset(edge: .bottom)`, and `if recordsReady { if summary.records.isEmpty { NoRecordsCard() } else { RecordsCard(records:unit:) } }`; `SummaryTiles`, `MusclesCard`
(`FlowLayout` chips), `RecordsCard`, `NoRecordsCard` live in `Features/Workout/SummaryCards.swift` (new) so each body stays under 80 lines. `WorkoutView`: `init(log:onDone: @escaping (Date)
-> Void)`, `private let programID: UUID?` (`log.session?.program?.id`, read once), `@State private var bestsBefore: [String: Double]?`; the summary branch is `let summary =
WorkoutSummary.make(exercises: exercises, startedAt: log.startedAt, bestsBefore: bestsBefore ?? [:])` then `WorkoutSummaryView(…, recordsReady: bestsBefore != nil, onDone: {
onDone(summary.endedAt) })`; the `Group` gains `.task(id: state == .summary) { guard state == .summary, bestsBefore == nil else { return }; do { bestsBefore = try
WorkoutSnapshotBuilder.bestsBefore(programID: programID, in: modelContext) } catch { assertionFailure("\(error)") } }` (≈ an effect keyed on "is summary"; a failure leaves nil, so only the
records cards stay hidden). `App/RootView.swift`: `@Environment(\.modelContext)`, `WorkoutView(log: log, onDone: { finish(log, at: $0) }).id(log.id)` and `private func finish(_ log:
WorkoutLog, at end: Date)` that sets `selectedTab = .home` first, then `try WorkoutLogStore.finish(log, at: end, in: modelContext)` in do/catch + `assertionFailure`. Verify: `$BUILD &&
$TEST`; `/design-compare summary "-seed summary"` → "SESSION COMPLETE", "Pull", "Tue, Sep 15 · Week 3 · Foundation", "12,270" / "lb total volume", "42:00" / "duration", Back · Legs · Arms,
the five record rows of 5.4, "Done"; deviations: the prototype's "12,840", four rows, "Invalid Date" meta. `LAUNCH -seed summary -units kg; SHOT ac6-summary` → "5,566", "kg total volume",
the kg rows of 5.4. `LIGHT; LAUNCH -seed wo-start; SHOT ac7-start; LAUNCH -seed summary; SHOT ac7-summary; DARK` → light tokens throughout. AC-5, AC-6, AC-7.
### Step 13 — Start from Home's Today card and the Program card
`Shared/StartWorkoutButton.swift` (new): `StartWorkoutButton(action: () -> Void)`, Home's current button moved verbatim. `Features/Home/TodayCard.swift`: `let onStart: () -> Void` drives it
(the "inert until M3" comment goes); `HomeContent` gains `onStart: (Int) -> Void` and passes `{ onStart(todaySession.index) }`. `SessionCard` gains `let showsStart: Bool; let onStart: () ->
Void` and `if showsStart { StartWorkoutButton(action: onStart).padding(.top, 14) }` after the rows; `ProgramContent` gains `onStart: (Int) -> Void`, computes `let state =
HomeStats.sessionState(…)` once and passes `showsStart: WorkoutFlow.isStartable(state)`. `HomeView` and `ProgramView` add `@Environment(\.modelContext)` and
```swift
private func start(sessionIndex: Int) {   // the shared start (B3): nothing is written unless the row is still pending
    do { try WorkoutLogStore.start(sessionIndex: sessionIndex, rows: sessions, at: clock.now(), in: modelContext) }
    catch { assertionFailure("Start workout failed: \(error)") }   // rolled back; the shell stays
}
```
The doc comments of `ProgramView` and `ProgramContent` now say the tab writes only through the shared start. Verify: `$BUILD && $TEST`; `/design-compare home "-seed midProgram"` → m2-home
AC-1 unchanged; `/design-compare program "-seed midProgram -tab program"` → m2-program-tab AC-1 deviations plus the button under row 5; `LAUNCH -seed freshProgram -tab program; SHOT
ac10-fresh` → button under "Upper A" · "Today"; `LAUNCH -seed missed -tab program -programWeek 2 -programDay 2; SHOT ac11` → "Legs" · "Missed", 50/50/70/50/30 lb, button; `-seed midProgram
-tab program -programWeek 3` with `-programDay 0`, `2`, `5` → `SHOT ac12-d0`, `ac12-d2`, `ac12-d5`, no button; `grep -rnE 'inert until M3|never writes|writes nothing'
HomeGymLog/Features/Home HomeGymLog/Features/Program` → no output. AC-8, AC-10, AC-11, AC-12.
### Step 14 — Acceptance sweep
```
P='Date\(\)|Date\.now|Calendar\.(current|autoupdatingCurrent)'; grep -rnE "$P" HomeGymLog/Features HomeGymLog/Models HomeGymLog/Engine HomeGymLog/Shared | grep -v '///'
grep -rn 'DragGesture(' HomeGymLog | grep -v 'minimumDistance: 20'; grep -rln '#if DEBUG' HomeGymLog/Features HomeGymLog/Shared; grep -rniI benchmark HomeGymLog/; grep -rn 'uniqueKeysWithValues' HomeGymLog/Engine/Workout*.swift HomeGymLog/Models/WorkoutSnapshotBuilder.swift; head -1 HomeGymLog/App/DebugSeed/*.swift
xcodebuild -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
eval "$TEST"; xcrun xcresulttool get test-results summary --path build/tests.xcresult
xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData test 2>&1 | grep -E "✘|TEST (SUCCEEDED|FAILED)"
```
Expected: the greps print nothing and every `DebugSeed` file starts `#if DEBUG`; both builds and both test runs succeed; then `BOOT` (the 26.5 run shuts 17.5 down). Then add the five workout
crops to `.claude/skills/design-compare/SKILL.md` and set the status lines of this plan and the spec. **Handed to the user**, as the spec's AC text: AC-13–AC-19, AC-21, AC-22 on the iPhone
15 / iOS 17.5 simulator (AC-14's vertical drag also on iPhone 17 / iOS 26.5; AC-16 also raises a set's reps to 100 and checks "100 reps" is not truncated, spec §6); **AC-20** with Step 9's `recordVideo` and `build/frames.swift` commands on `-seed wo-start` (log one set, Exit →
Discard; a "SESSION COMPLETE" frame requires the §5 fallback and a repeat); AC-23 in the Accessibility Inspector; AC-24–AC-27 on the iPhone 14 Pro Max via `/device-install` (AC-27 over the
installed M2 build).

## 4. Data model changes
One field, `LoggedSet.rpeSkipped: Bool = false` (no unit): the default is mandatory; the unversioned store migrates automatically on 17.5 and 26.5 (researcher 4.6), `AppSchema.makeContainer`
is unchanged and existing rows read `false`. Migration impact: none for users (device check AC-27); M5's `AppSchemaV1` must copy the field. No relationship or delete-rule change; the new
predicates and the `discard` delete path are tested in Steps 3 and 5 on 17.5, the predicates again in Step 14 on 26.5.

## 5. Risks and gotchas
- **Exit summary flash** (spec 2.8): the emptied queries map to `.summary`. Check AC-20 (meaningful from Step 12). Fallback: `@State isDiscarding` set before the store call and reset in
  `catch`; the body's first branch `if isDiscarding { Theme.bg.ignoresSafeArea() }`.
- **Swipe jump of about 20 pt at `minimumDistance` 20** (`translation` counts from touch-down; unverified). Check AC-14, AC-24. Fallback: draw `translation.width − 20·sign` once recognized,
  keep the ±90 commit on the raw clamped value; never go below 15 (blocks row-started scrolling on 26.5).
- **17.5 save hitch** (fact 10): tap-driven saves took 1–2 ms, but saves with the live queries mounted cost ~10 ms and 1–2 frames in a task loop. Check AC-24. Fallback: start the spring
  first and run the store call in `Task { @MainActor in … }` one turn later; record it in gotchas.
- **`ClockUsageTests` with the new files:** the elapsed clock and every handler read `clock.now()`, never `TimelineView`'s `context.date` (a frozen seed must render "12:34"); seeds derive
  from `referenceDate`. The suite runs in every `$TEST`; Step 14 also greps `Date.now`.
- **Release catching DEBUG-only names:** `WorkoutSeed` and the `DebugSeed` preview properties appear only inside `App.init`'s `#if DEBUG`; the `@Entry` values, `WorkoutSheet` and all views
  are production. Step 7's scan and Step 14's Release build catch a leak; build Release early if `App.init` changes shape.
- **17.5 retention and predicates:** only the query owner `WorkoutView` maps rows, children get values, no view traverses `log` in `body`, no two-hop `?.`.
- **Sheet from `onAppear`** may run before layout on 17.5 (like `scrollTo`): fallback `Task { @MainActor in openAdjust(…) }`; a system dim unlike 50 % black is a recorded deviation.
  **Baseline cost** (~0.4 s at program end) only delays the records card (`recordsReady`).
- **Tooling:** `OS=17.5`, `BOOT` after 26.5 runs, stale result bundles removed, `()` in `-only-testing` names, no `ffmpeg`, no `project.pbxproj` edit, no new dependency, entitlement or
  capability.

## 6. Definition of done
- [ ] `$BUILD` and `$TEST` green after every step on iPhone 15 / iOS 17.5; Step 14 green on iPhone 17 / iOS 26.5; Release builds; static greps clean. `/design-compare` matches for wo-start, wo-swipe, wo-rpe, wo-adjust, summary, home, program; kg, light, missed and no-button shots read; no shell frame (AC-9).
- [ ] The user's AC-13–AC-23 simulator and AC-24–AC-27 device checks pass (or a §5 fallback is applied and re-checked); `project.pbxproj` untouched; one schema field; status lines set; crops
      recorded in the design-compare skill.

## 7. Traceability, files, test estimate
| AC | Step | Proof |
|---|---|---|
| 1 · 2 · 3 · 4 · 5 | 9 · 10 · 10 · 11 · 12 | `/design-compare` wo-start · wo-swipe · wo-rpe · wo-adjust · summary |
| 6 · 7 · 8 · 9 | 11, 12 · 12 · 13 · 9 | `ac6-adjust`, `ac6-summary` (kg) · `ac7-start`, `ac7-summary` (light) · `/design-compare home` · `recordVideo` frames |
| 10 · 11 · 12 | 13 | `/design-compare program` + `ac10-fresh` · `ac11` · `ac12-d0/d2/d5` |
| 13–23 · 24–27 | 14 (user) · 14 (user, device) | the spec's AC steps; AC-20 `recordVideo` frames + §5 fallback; AC-23 Accessibility Inspector · swipe, hitch, kills, install over M2 |
| 21 (numbers) | 7 | `SummaryDoneHomeStatsTests` (streak 4, 11/120, 19 830, records, next session 12); the user checks only the screen |
| 28 · 29 · 30 · 31 | 1 · 1 · 2 · 1 | `WorkoutFlowTests` walks/ties · rows/hint/progress · `WorkoutSummaryTests` · `AdjustStepperTests` |
| 32 · 33 · 34 | 5, 6 · 3, 4, 5 · 1, 3 | `WorkoutTextTests` + `sessionInfo` fallbacks · `WorkoutStartTests` (discard), `WorkoutSetWriterTests`, id-map test · startable cases, `WorkoutStartTests` |
| 35 · 36 · 37 · 38 · 39 · 40 · 41 | 5 · 5, 14 · 5 · 7 · 7, 14 · all, 14 · 3 | `MissedWorkoutEndToEndTests` · `WorkoutRoutingPredicateTests` · `WorkoutQueriesTests` · `WorkoutSeedTests`, `DebugSeedTests`, `SeedHomeStatsTests` · `SeedNameScanTests` + Release · `ClockUsageTests` + grep · `RpeSkippedTests`, `SchemaSourceTests` |

**Files.** New app files: `Engine/WorkoutFlow`, `Engine/WorkoutSummary`, `Models/WorkoutSnapshotBuilder`, `Shared/{WorkoutText, FlowLayout, StartWorkoutButton}`, `App/DebugSeed/WorkoutSeed`,
`Features/Workout/{WorkoutView, WorkoutLoggingContent, WorkoutHeader, SetRow, SetSwipeRow, RPECard, WorkoutSheet, AdjustSheet, WorkoutBottomBar, WorkoutSummaryView, SummaryCards}`. Changed:
`Models/{LoggedSet, WorkoutLogStore}`, `Shared/StepperButton`, `App/{AppClock, HomeGymLogApp, RootView, ShellView}`, `App/DebugSeed/DebugSeed`, `Features/Home/{HomeView, HomeContent,
TodayCard}`, `Features/Program/{ProgramView, ProgramContent, SessionCard}`, the design-compare skill. New tests: `Support/{WorkoutFixtures, WorkoutStoreFixtures}`, `Engine/{WorkoutFlowTests,
AdjustStepperTests, WorkoutSummaryTests}`, `Persistence/{RpeSkippedTests, WorkoutStartTests, WorkoutSetWriterTests, WorkoutRoutingPredicateTests, WorkoutQueriesTests,
WorkoutSnapshotBuilderTests, MissedWorkoutEndToEndTests}`, `Shared/WorkoutTextTests`, `Seed/WorkoutSeedTests`, `Static/{SchemaSourceTests, SeedNameScanTests}`; changed `Seed/{DebugSeedTests,
SeedHomeStatsTests}`. **Test estimate:** about +70 test functions (292 → ~360), roughly +120 runs with parameterised cases.

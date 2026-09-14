# M3 slice 2 — Rest timer (card, ring, +30s / Skip, background and kill survival, local notification): implementation plan

**Status: implemented 2026-09-14 (branch `m3-rest-timer`). Steps 0–11 done by implementer (473 tests), test-writer added 42: 515 tests green on iOS 17.5 and 26.5, Release build green, `project.pbxproj` untouched; `wo-rest` matches the prototype with the listed deviations and the other workout seeds are byte-identical to their baselines. No §5 fallback taken (`WorkoutView.body` 73 lines, so no `RestEffects.swift`; `.onChange(…, initial: true)` logged no "Modifying state"). Deviations: the 0.001/75 fraction row uses tolerance 1e-9; `observeRestEnd` returns early while `isDiscarding`. Step 10 scratch-copy UI tests passed AC-5–AC-10 and parts of AC-11. Ship-check: swift-reviewer "ship" (applied: a discard guard in the scene-phase handler, title and countdown as one accessibility element, test clean-ups). Pending the user's MVP pass: slide animations, countdown behind the sheet, fuller ring, VoiceOver ("Rest" as a second stop, "Rest over" once), device checks AC-12–AC-17. Later: light-mode shadow (M5); rest-start animation direction unverified. Planning: verifier round 1 PASS WITH FIXES, round 2 PASS.** For `docs/specs/m3-rest-timer.md` (architecture review and researcher addendum applied). Spec §2–6 and §8 are the contract (`AC-1`…`AC-30`);
format and shorthands follow `docs/plans/m3-logging.md`. Executed by `implementer` (opus), one step per build; test-writer, swift-reviewer and doc-writer follow.

## 1. Goal and scope
Land the rest timer in dependency order: Engine rules (`RestTimer`, `RestNotificationPlan`), Shared text (`RestText`), the two `WorkoutLog` instants and the rest-aware store writers
(with `setRPE`/`skipRPE` gaining `at:`), the `RestNotifier` seam, the `wo-rest` seed, the rest card swapped into the bottom inset, then the effects (end rule, notification
reconciliation, scene phase, cancel on leave). Every step ends with a green build and green named suites on iPhone 15 / iOS 17.5.

Out of scope (spec §7): Live Activity and haptics (M5); a notification delegate or foreground banners; M4's reminder, Settings status and denied hint; schema versioning (M5); provisional
notifications; pausing a rest; rest before the first set; a blocked row during rest; detail sheet, notes, swap, progression pill (m3-exercise-tools). **No AC is excluded.** Taps are refused in the
repo's simulator session (gotchas 2026-09-10), so AC-5–AC-11 are the user's (MVP test pass) unless optional Step 10 verifies part of them in a scratch copy; AC-12–AC-17 are device-only.

**No new dependency, entitlement, capability or Info.plist key.** Local notifications (`UserNotifications`, a system framework) need none on any tier (researcher fact 14); App Privacy stays "Data Not Collected".

## 2. Decisions this plan relies on
- INSIGHTS "2026-09-14 — M3 rest-timer decisions": two stored instants, swipeable row during rest, bar replaced by the card in the inset (0.3 s ease-in-out), end rule in `.onChange` inside the
  timeline closure, `Task.isCancelled` guard before `add`, `onDisappear` cancel, struct-of-closures notifier with `@Entry` default `.live()` overridden to `.silent()` in the DEBUG seed branch,
  `decide` owns schedule-vs-cancel, finished logs carry nil, M4 delegate rule, permission at first rest, generic text, +30s unlimited.
- INSIGHTS "2026-09-13 — M3 decisions": guarded one-save writers, `clock.now()` at the action, failed-save policy (field writers snapshot, restore, `rollback()`, rethrow), row ids, `isDiscarding`.
- Patterns: failed save via `allowsSave: false`; snapshot-restore writers; nil-by-default `@Entry`; real-touch probes; SpringBoard notification probes. Researcher facts 1–16 and addendum 1–10; spec §4.4.
- Gotchas: SwiftData (container lifetime on 26.5, `rollback()` keeps values), SwiftUI (`.explicit` timeline never fires, `Text(timerInterval:)`, `.onChange` inside the closure, inset height jump),
  User notifications (add before authorization dropped, no delegate = no foreground banner, superseded task, 0 s trigger, asynchronous removal), Xcode (OS in destination, stale result
  bundle, `-only-testing` parentheses, clone stuck, `BOOT` after 26.5, curl poll, sips).

Plan-level choices (challengeable):
- **The guard lives in production code, testably.** `RestNotifier.using(_ center: RestNotificationCenter)` builds `schedule`/`cancel`/`removeDelivered` from four injected system calls;
  `.live()` = `.using(.system())`. The test double `.recording(into:)` injects a recorder with a controllable authorization await, so AC-24 fails if the guard is removed.
- **`RestNotifier.reconcile(restEndsAt:clock:)`** applies `decide`; the view's `.task(id:)` calls only it (AC-23's "applied through the double").
- **Mount and return run the end rule too.** `.onChange(of: rest != nil, initial: true)` gives 5.5's "mount" row; scene phase `.active` re-runs the rule with the current `resting`, which
  realizes 5.5's "return 12:00:55 → *L'* = 12:01:02" row (a resting value that did not change fires no `onChange`). Leaving `.active` sets *L* := nil.
- **Seed override without naming `.live()`:** the root holds `restNotifier: RestNotifier?` (nil unless the seed branch set `.silent()`) and applies `.transformEnvironment(\.restNotifier)`
  only when non-nil (≈ a provider that overrides a context value only when a prop is set).
- **Forced reorder:** the `at:` signature change (Step 4) must compile `WorkoutSeed`'s three calls, so the final `wo-adjust`/`summary` timestamps land there; Step 7 adds `wo-rest` and pins every seed's instants.
- **Step 0 baselines** (HEAD screenshots, test count) make "unchanged" checks read files this plan wrote. `RestText` also holds the card and notification strings.
- **`wo-rest` crop: 600×300 @ (930, 1665)** (row B, between `wo-rpe` x 1345 and `summary` x 1975; located on a row-B thumbnail and read at planning time: "B5 · Rest timer" label to the frame's bottom).

Open questions: none.

## 3. Steps
**Step 0 — shorthands and baselines.** Write `build/rest-env.sh` (gitignored; shell state does not persist between tool calls, so every command below starts `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/rest-env.sh`):
```
DEST='platform=iOS Simulator,name=iPhone 15,OS=17.5'; DEST26='platform=iOS Simulator,name=iPhone 17,OS=26.5'; BID=com.zhabskyi.homegymlog.ios
UDID=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-5"][] | select(.name=="iPhone 15") | .udid')
UDID26=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-26-5"][] | select(.name=="iPhone 17") | .udid')
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app
BUILD() { xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; }
TEST() { rm -rf build/tests.xcresult; xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult "$@" test 2>&1 | tee build/last-test.log | grep -E "✘|error:|TEST (SUCCEEDED|FAILED)"; }
ONLY() { local a=(); for s in "$@"; do a+=("-only-testing:HomeGymLogTests/$s"); done; TEST -parallel-testing-enabled NO "${a[@]}"; }   # a function needs "()"
COUNT() { xcrun xcresulttool get test-results summary --path build/tests.xcresult; }
BOOT() { xcrun simctl boot "$1" 2>/dev/null; xcrun simctl bootstatus "$1" -b >/dev/null; xcrun simctl status_bar "$1" override --time 9:41; }
LAUNCH() { local u=$1; shift; xcrun simctl terminate "$u" $BID 2>/dev/null; xcrun simctl install "$u" "$APP" && xcrun simctl launch "$u" $BID "$@"; }
SHOT() { sleep 3; xcrun simctl io "$1" screenshot "build/shot-$2.png"; }
APPEAR() { xcrun simctl ui "$1" appearance "$2"; }
PROTO() { (cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &); until curl -sf -o /dev/null http://127.0.0.1:8765/; do sleep 0.2; done
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=3000,5600 --virtual-time-budget=20000 \
    --screenshot=build/proto-all.png "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
  c() { sips -c "$2" "$3" --cropOffset "$4" "$5" build/proto-all.png --out "build/proto-$1.png" >/dev/null; }
  c wo-rest 600 300 930 1665; c wo-adjust 570 300 1890 40; c summary 640 330 930 1975; }
```
A run that fails before any test with "Failed to clone device … stuck in creation state" is retried as `TEST -parallel-testing-enabled NO`. Only one `xcodebuild` at a time. Undo = restore by hand
(new files have no commit; never `git checkout`/`stash`/`clean`). Then, on HEAD before any change: `BUILD && TEST; COUNT` (expect 425 passed); `BOOT $UDID; APPEAR $UDID dark; for s in wo-start wo-swipe
wo-rpe wo-adjust summary; do LAUNCH $UDID -seed $s; SHOT $UDID base-$s; done`; `PROTO` and read `build/proto-wo-rest.png` once.
`/design-compare <snapshot> "<args>"` below follows the skill (dark, status bar pinned by `BOOT`, crop from `PROTO`) and writes `build/compare-<snapshot>.png`. "Fails if" names the catching assertion.

### Step 1 — Engine: `RestTimer`, `RestNotificationPlan`
File `Engine/RestTimer.swift` (new; no SwiftUI, SwiftData or text):
```swift
nonisolated enum RestNext: Equatable, Sendable { case firstSet(exerciseKey: String); case set(number: Int, of: Int) }
nonisolated struct RestDisplay: Equatable, Sendable { let startedAt: Date; let endsAt: Date; let next: RestNext }
nonisolated struct RestEndObservation: Equatable, Sendable { let announce: Bool; let lastSeenEndsAt: Date? }
nonisolated enum RestTimer {
    static func remainingSeconds(endsAt: Date, now: Date) -> Int                      // ceil(endsAt − now); 0 when not positive
    static func remainingFraction(startedAt: Date, endsAt: Date, now: Date) -> Double  // (endsAt − now)/(endsAt − startedAt) clamped 0…1; 0 when total ≤ 0
    static func display(restStartedAt: Date?, restEndsAt: Date?, now: Date, exercises: [WorkoutExerciseValue], state: WorkoutState) -> RestDisplay?
        // spec 4.3/5.3 over WorkoutFlow.sorted(exercises): nil unless both instants, now < restEndsAt, .logging(e, s), e in range
    static func observeEnd(lastSeenEndsAt: Date?, restEndsAt: Date?, resting: Bool, now: Date) -> RestEndObservation   // spec 5.5
}
nonisolated enum RestNotificationPlan: Equatable, Sendable {
    case schedule(Date), cancel
    static func decide(restEndsAt: Date?, now: Date) -> RestNotificationPlan   // .schedule(e) iff e > now
}
```
Tests (plain, `t` = `TestCalendar.day(2026, 9, 15)` + 12 h; expected values typed from the spec, fractions as literal divisions with tolerance 1e-12):
- `Engine/RestTimerTests.swift` — **remainingSeconds** parameterised over 5.2: 62, 61.993, 92, 75, 60, 120, 632 (→ themselves, 61.993 → 62), 5, 1, 0.5 → 1, 0.001 → 1 (past-the-last-bucket
  side), 0 → 0, −5 → 0 (before the first; fails without the `> 0` guard or with `rounded(.down)`), 80 → 80 (the "clock moved back" row). **remainingFraction:** 62/75, 92/105, 0.001/75, 75/75 → 1,
  total 0 and total −10 → 0, now before `startedAt` (80 left of 75) → 1 (fails without the upper clamp), past end → 0. **display** on `WorkoutFixtures.exercises(session11)` + `editing`: the eight
  rows of 5.3 as literal states and literal expected `RestDisplay`/nil (`.set(number: 2, of: 3)`, `.set(number: 3, of: 3)`, `.firstSet(exerciseKey: "lowRow")`, nil, nil, Skip-set replacement
  `.set(number: 3, of: 3)` with instants t, t+75, summary nil, `now == restEndsAt` nil); nil when either instant is nil (both orders), for `.rpePending(0, 1)`, `.logging(exercise: 5, set: 0)` (past the
  last) and `.logging(exercise: -1, set: 0)` (before the first); `startedAt`/`endsAt` equal the passed instants; the `.firstSet` row repeated on `WorkoutFixtures.shuffled` gives `lowRow` (fails
  if `display` indexes the unsorted input). **Rows while resting (AC-20):** on the `wo-rest` rows (E1S1 done RPE 7) `rowStates(… state: .logging(0, 1), sheetOpen: false)` equals the literal
  `[done(7) not dimmed, active not dimmed, waiting dimmed]`; `showsHint(.logging(0, 1), sheetOpen: false)` false and `(.logging(0, 0), false)` true; **signature check:** `let _: ([WorkoutExerciseValue],
  WorkoutState, Bool) -> [SetRowState] = WorkoutFlow.rowStates(exercises:state:sheetOpen:)` and `let _: (WorkoutState, Bool) -> Bool = WorkoutFlow.showsHint(_:sheetOpen:)` (a rest parameter breaks the build).
- `Engine/RestEndRuleTests.swift` — **observeEnd**: every row of the 5.5 table as literals with E = t + 62 (mount, end tick → `announce` true, later evaluation, +30s to t + 92 then its tick → true,
  Skip, swipe clear, Skip-set replacement, relaunch, background both ways, prompt); fails if `announce` ignores `now ≥ L` or `E == L`. `announce` is false whenever *L* is nil (four combinations of
  `resting` and `now` around E). **decide:** `restEndsAt` t + 0.001 → `.schedule` (just past the threshold), nil, t (equal) and t − 5 → `.cancel`.
Verify: `source build/rest-env.sh; BUILD && ONLY RestTimerTests RestEndRuleTests WorkoutFlowTests`. AC-18, AC-19, AC-20, AC-21, AC-23 (rule).

### Step 2 — Shared: `RestText`
File `Shared/RestText.swift` (new): `static let title = "Rest"`, `addLabel = "+30s"`, `skipLabel = "Skip"`, `addAccessibility = "Add 30 seconds"`, `skipAccessibility = "Skip rest"`,
`restOver = "Rest over"`, `notificationBody = "Time for your next set."`; `static func clock(seconds: Int) -> String` (`"%d:%02d"`, clamp ≥ 0, minutes uncapped); `static func spoken(seconds: Int) -> String`
(5.2 rule); `static func next(_ next: RestNext) -> String` ("set 2 of 3"; "`WorkoutText.exerciseName(key:)` · set 1"). Tests `Shared/RestTextTests.swift` (`@MainActor`): clock 62/75/60/632/5/1/0/−3
→ "1:02"/"1:15"/"1:00"/"10:32"/"0:05"/"0:01"/"0:00"/"0:00" and 3600 → "60:00" (past the last hour; fails if minutes wrap); spoken 62, 92, 60, 120, 632, 5, 1, 0, −3, 3600 → "1 minute 2 seconds",
"1 minute 32 seconds", "1 minute", "2 minutes", "10 minutes 32 seconds", "5 seconds", "1 second", "0 seconds", "0 seconds", "60 minutes" (fails on "1 minutes" or a missing seconds part); `next(.set(number: 2,
of: 3))` "set 2 of 3", `.firstSet(exerciseKey: "lowRow")` "Seated Low Row · set 1", `"mystery"` "mystery · set 1"; the seven constants as literals. Verify: `BUILD && ONLY RestTextTests ClockUsageTests`. AC-22.

### Step 3 — Models: the two instants
`Models/WorkoutLog.swift`: after `finishedAt`, exactly `var restStartedAt: Date?` and `var restEndsAt: Date?` with the spec 4.2 doc comments; init unchanged. Tests (iPhone 15 / iOS 17.5):
`Persistence/RestFieldsTests.swift` (`@MainActor`, holds `TestStore`): `WorkoutLog(startedAt: t)` inserted and saved reads nil for both from `ModelContext(store.container)`; both set to t, t + 75 and
saved read back exactly from a fresh context (fails if either field is not persisted). `Static/SchemaSourceTests.swift` gains one test: `HomeGymLog/Models/WorkoutLog.swift` code lines contain one
that trims to `var restStartedAt: Date?` and one to `var restEndsAt: Date?` (fails if a field becomes non-optional or is dropped). Verify: `BUILD && ONLY RestFieldsTests SchemaSourceTests
ModelRoundTripTests`. AC-29.

### Step 4 — Models: rest-aware writers, `at:` on the RPE writers, call sites
`Models/WorkoutLogStore.swift`:
```swift
private struct RestSnapshot { let log: WorkoutLog?; let startedAt: Date?; let endsAt: Date?; init(_ log: WorkoutLog?); func restore() }
private static func startRestIfSetFollows(_ log: WorkoutLog?, at: Date)   // any pending set in log.exercises && (log.session?.restSeconds ?? 0) > 0 → at, at + restSeconds; else both nil
private static func clearRest(_ log: WorkoutLog?)
@discardableResult static func setRPE(_ rpe: Int, on set: LoggedSet, at: Date, in context: ModelContext) throws -> Bool
@discardableResult static func skipRPE(on set: LoggedSet, at: Date, in context: ModelContext) throws -> Bool
```
`setRPE`/`skipRPE`/`skipSet` call `startRestIfSetFollows(set.exercise?.workout, at:)` after their field write; `logSet`/`saveAndLogSet` call `clearRest(set.exercise?.workout)`; `nextExercise` calls
`clearRest(exercise.workout)`; each takes `RestSnapshot` before writing and commits with `{ snapshot(s).restore(); rest.restore() }`. Guards run before any snapshot (unchanged). `finish`,
`discard`, `start` untouched. Call sites (grep-verified at planning time): `WorkoutView.rate`/`skipRating` pass `at: clock.now()`; `WorkoutSeed` `.rated` passes `at: firstLoggedAt`, `.finishedSets`
passes each set's own `startedAt + 168·k` and `firstLoggedAt` for E1S1 (spec seed table); tests pass the instant of the preceding `logSet` (or `t0`) — `WorkoutSetWriterTests` 14,
`WorkoutSetWriterEdgeTests` 6, `WorkoutCommitRollbackTests` 2 (`at`), `MissedWorkoutEndToEndTests` 1 (`now + 60·k`); no existing assertion changes. Then
`grep -rnE 'setRPE\([^)]*on: [^,]+, in:|skipRPE\(on: [^,]+, in:' HomeGymLog HomeGymLogTests` prints nothing. `WorkoutCommitRollbackTests.LogValues` gains `restStartedAt`/`restEndsAt` (values
and `changes` lines), so its seven-action tests now fail if a writer does not restore the rest fields (the `setRPE`/`skipRPE` cases start a rest before the refused save).
Tests `Persistence/WorkoutRestWriterTests.swift` (`@MainActor`, holds `TestStore`; `sixMonthRows` + `start(session:)`; read back through a fresh context; t = `t0` + 168):
- `setRPE(7, at: t)` after `logSet(E1S1)` on session 11 → `restStartedAt == t`, `restEndsAt == t + 75`; `skipRPE(at: t)` the same; E1S3 rated with exercise 2 pending → t, t + 75 (between exercises).
- E5S3 rated with the other 14 done and rated → both nil; then `finish` → a fresh context reads nil in both (4.2 invariant).
- `skipSet(E1S2, at: t2)` during a live rest from t → t2, t2 + 75 (fails if the old start survives); `skipSet` on E5S3 with the rest done → nil.
- Session 45 (Build) → `restEndsAt == t + 90` (fails on a hard-coded 75).
- Parameterised over `logSet`, `saveAndLogSet` on E1S2 during a live rest → set done and both instants nil from a fresh context; `nextExercise(E1)` after E1S1 rated → E1S2–S3 skipped and both nil.
- `setRPE(8, at: t + 10)` on the already rated E1S1 → false, `restStartedAt` still t, `hasChanges` false.
- Parameterised: session 11's `restSeconds` set to 0, and a log with `session == nil` (inserted by hand with one exercise of two sets), each with instants pre-set to t − 5, t + 70 → after the
  rating both nil (fails if the writer skips clearing).
Verify: `BUILD && ONLY WorkoutRestWriterTests WorkoutSetWriterTests WorkoutSetWriterEdgeTests WorkoutCommitRollbackTests MissedWorkoutEndToEndTests WorkoutSeedTests SummaryDoneHomeStatsTests && TEST`. AC-25, AC-27 (rating half).

### Step 5 — Models: `addRestTime`, `skipRest`
`WorkoutLogStoreError` gains `case invalidRestExtension(Int)`. `WorkoutLogStore`:
```swift
@discardableResult static func addRestTime(_ seconds: Int, to log: WorkoutLog, at: Date, in context: ModelContext) throws -> Bool
    // throws invalidRestExtension for seconds ≤ 0 first; false unless restEndsAt != nil && at < restEndsAt; else restEndsAt += seconds, commit { rest.restore() }
@discardableResult static func skipRest(_ log: WorkoutLog, in context: ModelContext) throws -> Bool   // false unless restEndsAt != nil; else both nil, commit
```
Tests `Persistence/RestExtendSkipTests.swift` (`@MainActor`, holds `TestStore`; rest t → t + 75 via `setRPE`): +30 at t + 13 → true, `restEndsAt == t + 105`, `restStartedAt == t` (fails if the start
moves); at t + 75 (equal) and t + 80 → false, unchanged, `hasChanges` false; nil rest → false; 0 and −30 throw `.invalidRestExtension(0)`/`(-30)` on a live rest without writing; `skipRest` live →
true and both nil; stale (at any time after t + 75) → true and both nil; nil → false, `hasChanges` false.
`Persistence/RestCommitRollbackTests.swift` (`@MainActor`; the `allowsSave: false` pattern: on-disk writer container, session 11 started, E1S1 logged and rated at `t0` + 60 → rest t0 + 60 … t0 + 135,
reopened read-only; both containers bound with `withExtendedLifetime((writer, readOnly)) {}`; temp dir removed after release), parameterised over `addRestTime(30, at: t0 + 90)`, `skipRest`,
`logSet(E1S2, at: t0 + 90)`, `skipSet(E1S2, at: t0 + 90)`: threw; `hasChanges` false; the writing context's log still reads t0 + 60, t0 + 135 and E1S2 pending; a fresh writer context reads the same.
Verify: `BUILD && ONLY RestExtendSkipTests RestCommitRollbackTests`. AC-26, AC-27.

### Step 6 — App: `RestNotifier`
File `App/RestNotifier.swift` (new; `import Foundation`, `import UserNotifications`; reads time only through `AppClock`):
```swift
/// The system calls the notifier makes (≈ an injected API client), so the scheduling guard is testable.
struct RestNotificationCenter {
    var authorize: () async -> Void                                        // requestAuthorization([.alert, .sound]); prompts once per install
    var add: (_ identifier: String, _ endsAt: Date, _ interval: TimeInterval) async -> Void
    var removePending: (_ identifier: String) -> Void
    var removeDelivered: (_ identifier: String) -> Void
    static func system() -> RestNotificationCenter   // reads UNUserNotificationCenter.current() lazily inside each closure, never at construction (a seeded run builds the .live() default but never touches the center; verifier 1 finding 5); content RestText.restOver / notificationBody, .default sound, UNTimeIntervalNotificationTrigger
}
/// Rest-end notification seam (≈ a service in context; `UNUserNotificationCenter` ≈ the browser Notification API with a scheduled, server-less delivery).
struct RestNotifier {
    var schedule: (Date, AppClock) async -> Void
    var cancel: () -> Void
    var removeDelivered: () -> Void
    static let identifier = "rest-timer"
    static func live() -> RestNotifier     // .using(.system())
    static func silent() -> RestNotifier   // no-ops: seeds and previews
    static func using(_ center: RestNotificationCenter) -> RestNotifier
    func reconcile(restEndsAt: Date?, clock: AppClock) async   // switch RestNotificationPlan.decide(restEndsAt:, now: clock.now()): schedule or cancel
}
```
`using`'s `schedule`: `await center.authorize()`; `guard !Task.isCancelled else { return }` (≈ ignoring a stale fetch response: a newer `.task(id:)` run owns the request; after every await and before
`add`); `let interval = endsAt.timeIntervalSince(clock.now())` (after the await: the prompt can hold it for seconds); `guard interval > 0` else remove pending and delivered and return (a 0 s trigger
terminates the app); `await center.add(identifier, endsAt, interval)`. `cancel` removes pending and delivered; never remove-then-add. `App/AppClock.swift` extension: `@Entry var restNotifier: RestNotifier = .live()`
(doc: live by default so production never sets it; only the root's DEBUG seed branch overrides it). `App/HomeGymLogApp.swift`: stored `private let restNotifier: RestNotifier?` from a nil local set to
`.silent()` inside the existing `if let seed` branch; the body adds `.transformEnvironment(\.restNotifier) { value in if let override = restNotifier { value = override } }`.
Test support `HomeGymLogTests/Support/RestNotifierRecorder.swift` (new, `@MainActor final class RestNotifierRecorder`): `now: Date`, `holdsAuthorization: Bool`, `private(set) added: [(endsAt: Date, interval:
TimeInterval)]`, `pending: Date?` (same id replaces), `cancels: Int`, `deliveredRemovals: Int`, `waitingCount: Int`, `release(_ index: Int)` (resumes one held `CheckedContinuation`), plus
`extension RestNotifier { @MainActor static func recording(into: RestNotifierRecorder) -> RestNotifier }` = `.using(…)` over the recorder, and `clock` = `AppClock(now: { recorder.now }, calendar: TestCalendar.calendar)`.
Tests `App/RestNotifierTests.swift` (`@MainActor`; now 12:00:00): `reconcile` with 12:01:02 → exactly one add at 12:01:02, 0 cancels; nil, 12:00:00 and 11:59:00 → one cancel, no add (AC-23).
**Superseded run (AC-24):** hold authorization; `first = Task { await n.schedule(12:01:32, clock) }`; wait for `waitingCount == 1`; `first.cancel()`; `second = Task { await n.schedule(12:02:02,
clock) }`; wait for 2; release the second, await it; release the first, await it → `added.map(\.endsAt) == [12:02:02]`, `pending == 12:02:02` (fails without the guard: `[12:02:02, 12:01:32]`).
A single run cancelled during its await → `added` empty; then `cancel()` → `pending == nil`, `added` empty, `cancels == 1`. **Interval after the await:** schedule 12:01:15, advance `now` to 12:00:02.5
before release → interval 72.5 (fails if measured before the await: 75). **Past after the await:** schedule 12:00:05, advance to 12:00:06 → no add, one cancel.
`Static/RestNotifierSourceTests.swift` (plain, `#filePath` scan like `ClockUsageTests`, comments stripped): in `App/HomeGymLogApp.swift` exactly one code line contains `.silent()`, located after the
line containing `if let seed = try DebugSeed.parse` and before the next `#endif`; across all app sources, code lines containing `.live()` but not `AppClock.live()` number exactly one, in
`App/AppClock.swift`, containing `@Entry var restNotifier` (fails if the root sets the live notifier or the seed override leaves the DEBUG branch).
Verify: `BUILD && ONLY RestNotifierTests RestNotifierSourceTests ClockUsageTests && TEST`; `xcodebuild -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData
CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"` (App.init changed shape). AC-23 (applied), AC-24, AC-30 (static half).

### Step 7 — Seed `wo-rest`
`App/DebugSeed/WorkoutSeed.swift`: `Stage` gains `resting` (doc: wo-rest); recipe `logSet(E1S1, at: firstLoggedAt)` then `setRPE(7, on: firstSet, at: now − 13)`. `App/DebugSeed/DebugSeed.swift`:
`case woRest = "wo-rest"` (doc: set 1 rated 13 s ago, rest "1:02" of 75); added to `referenceDate`'s 09-15 group, `initialDraft`'s nil group, `makeContainer`'s workout group and `workoutStage` → `.resting`.
Tests: `Seed/DebugSeedTests.swift` — `.woRest` joins the 09-15 case of `parses`, `workoutNames` gains `("wo-rest", .woRest)`, the `drafts` loop gains it (`previews` already pins nil for it).
`Seed/WorkoutSeedTests.swift` — `seed` gains `(DebugSeed.woRest, 754.0, .logging(exercise: 0, set: 1))` with the `woAdjust` rows; new `restInstants` parameterised: wo-start, wo-swipe, wo-rpe, summary →
(nil, nil); wo-adjust → (noon − 586, noon − 511) and `display(…)` nil at noon; wo-rest → (noon − 13, noon + 62), `remainingSeconds` 62, fraction 62/75, `display(…)?.next == .set(number: 2, of: 3)`
(container bound with `defer { withExtendedLifetime(container) {} }`). `Seed/SeedHomeStatsTests.swift` — a `.woRest` row with `midProgram`'s numbers. `Static/SeedNameScanTests.swift` — `"wo-rest"` joins
`names`. Verify: `BUILD && ONLY DebugSeedTests WorkoutSeedTests SeedHomeStatsTests SeedNameScanTests`. AC-28, AC-30 (scan).

### Step 8 — Views: `RestOverlay`, inset swap, timeline wrapper, +30s / Skip
File `Features/Workout/RestOverlay.swift` (new): `RestOverlay(rest: RestDisplay, onAdd: () -> Void, onSkip: () -> Void)` with `@Environment(\.appClock)`; body `TimelineView(.periodic(from: rest.startedAt,
by: 1)) { _ in … }` reading `clock.now()` once: `HStack(spacing: 18) { RestRing; text column; button column }`, padding 20 top and sides and 10 bottom, background
`UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28).fill(Theme.sf).shadow(color: .black.opacity(0.4), radius: 25, y: -20).ignoresSafeArea(edges: .bottom)`. Text column: `RestText.title`
12 `mu` (`.accessibilityHidden(true)`); countdown `RestText.clock` 34 bold, `.tracking(-1)`, `.monospacedDigit()`, `.accessibilityLabel(RestText.title)`, `.accessibilityValue(RestText.spoken(…))`,
`.accessibilityAddTraits(.updatesFrequently)`; `"Next: " + RestText.next(rest.next)` 12.5 `mu`, 6 below. Buttons (gap 6, 38 high, padding 0/14, radius 10): `+30s` `sf2` 13 semibold `tx` with
`accessibilityLabel(RestText.addAccessibility)`, `Skip` accent 13 bold white with `skipAccessibility`. `private struct RestRing(remainingFraction: Double)`: researcher's compiled sketch (track `sf2`, arc
accent round caps, `trim(from: 0, to:)`, `rotationEffect(-90°)`, `.animation(.linear(duration: 1), value:)`, 72 pt circle in an 84 pt box).
`Features/Workout/WorkoutLoggingContent.swift`: `let rest: RestDisplay?` after `unit`; `let onAddRest: () -> Void`, `let onSkipRest: () -> Void` after `onSkipRating`; the inset becomes (≈ a sticky footer whose child switches):
```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
    if let rest {
        RestOverlay(rest: rest, onAdd: onAddRest, onSkip: onSkipRest)
    } else {
        WorkoutBottomBar(nextEnabled: WorkoutFlow.nextExerciseEnabled(state), onNext: { if let exercise { onNext(exercise.id) } })
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8).background(Theme.bg)
    }
}
.animation(.easeInOut(duration: 0.3), value: rest != nil)
```
`Features/Workout/WorkoutView.swift`: the logging branch becomes
```swift
} else {
    // ≈ a setInterval the framework owns, anchored on the rest start so ticks land on whole rest seconds (spec 4.4)
    TimelineView(.periodic(from: log.restStartedAt ?? startedAt, by: 1)) { _ in
        let rest = RestTimer.display(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, now: clock.now(), exercises: exercises, state: state)
        WorkoutLoggingContent(info: info, startedAt: startedAt, exercises: exercises, state: state, sheetOpen: sheet != nil, unit: unit, rest: rest,
                              onExit: { exitTapped(exercises) }, onNext: nextExercise, onLog: logSet, onAdjust: { openAdjust($0, in: exercises) },
                              onRate: rate, onSkipRating: skipRating, onAddRest: addRest, onSkipRest: skipRest)
    }
}
```
plus handlers `addRest()` (`WorkoutLogStore.addRestTime(30, to: log, at: clock.now(), in: modelContext)`) and `skipRest()` in do/catch + `assertionFailure`. No unit tests (values are Steps 1–2).
Geometry helper `build/cardtop.swift` (new, ImageIO): `swift build/cardtop.swift <png> <screenHeightPt>` samples the card colour at (30 pt, height − 22 pt), scans the centre column down from 600 pt and
prints `top=<pt>` of the first pixel within ±6 per channel (scale = pixel height / points).
Verify: `BUILD && TEST`; `BOOT $UDID; APPEAR $UDID dark`; `/design-compare wo-rest "-seed wo-rest"` against `build/proto-wo-rest.png` → the AC-1 list; deviations to skip: row 2 Active, no pill, Swap/ⓘ inert,
card bottom follows the safe area, row 3 dimmed above the card (inset), "Next: set 2 of 3" on one line. `LAUNCH $UDID -seed wo-rest; SHOT $UDID wo-rest-a; SHOT $UDID wo-rest-b; cmp build/shot-wo-rest-a.png
build/shot-wo-rest-b.png` (frozen "1:02", identical 3 s later); `swift build/cardtop.swift build/shot-wo-rest-a.png 852` → `top=704` ± 1. `LAUNCH $UDID -seed wo-rest -units kg; SHOT $UDID ac2-kg` → rows
"49.9 kg × 12 reps", card as in `wo-rest-a`. `APPEAR $UDID light; LAUNCH $UDID -seed wo-rest; SHOT $UDID ac3-light; APPEAR $UDID dark` → `sf` card, `sf2` track and +30s, accent arc and Skip in light tokens.
Regression: `/design-compare wo-adjust "-seed wo-adjust"` and `/design-compare summary "-seed summary"` (m3-logging AC-4/AC-5, no card); for `wo-start wo-swipe wo-rpe wo-adjust summary`: `LAUNCH $UDID -seed $s;
SHOT $UDID now-$s; cmp build/base-$s.png build/shot-now-$s.png` (a byte difference is read side by side; only a visible difference fails). AC-1, AC-2, AC-3, AC-4.

### Step 9 — Effects: end rule, reconciliation, scene phase, cancel on leave
`WorkoutView`: `@State private var lastSeenRestEnd: Date?` (≈ a `useRef`, written only in effects), `@Environment(\.restNotifier) private var notifier`, `@Environment(\.scenePhase) private var scenePhase`.
Inside the timeline closure, on `WorkoutLoggingContent`, **once each and nowhere else** (outside the closure a time-based end never fires; twice, a save runs the effect twice):
```swift
.onChange(of: rest != nil, initial: true) { _, resting in observeRestEnd(resting: resting) }   // ≈ useEffect(…, [resting]), also on mount
.onChange(of: log.restEndsAt) { observeRestEnd(resting: rest != nil) }
```
On the outer `Group`:
```swift
.task(id: isDiscarding ? nil : log.restEndsAt) {   // ≈ an effect whose AbortController fires when the id changes
    await notifier.reconcile(restEndsAt: isDiscarding ? nil : log.restEndsAt, clock: clock)   // not read after Discard (verifier 1 finding 6; researcher P4 also read it safely)
}
.onChange(of: scenePhase) { _, phase in                                                        // ≈ visibilitychange
    if phase == .active {
        notifier.removeDelivered()
        observeRestEnd(resting: RestTimer.display(restStartedAt: log.restStartedAt, restEndsAt: log.restEndsAt, now: clock.now(), exercises: exercises, state: state) != nil)
    } else {
        lastSeenRestEnd = nil
    }
}
.onDisappear { notifier.cancel() }
```
`private func observeRestEnd(resting: Bool)`: `let result = RestTimer.observeEnd(lastSeenEndsAt: lastSeenRestEnd, restEndsAt: log.restEndsAt, resting: resting, now: clock.now())`; `lastSeenRestEnd =
result.lastSeenEndsAt`; `if result.announce { AccessibilityNotification.Announcement(RestText.restOver).post() }` (≈ an `aria-live` message; no-op without VoiceOver). The `#Preview` adds
`.environment(\.restNotifier, .silent())`. Body length: `sed -n '/var body: some View {/,/^    }$/p' HomeGymLog/Features/Workout/WorkoutView.swift | wc -l`; estimate 75. If above 80, move the
three outer modifiers into `Features/Workout/RestEffects.swift`: `struct RestEffects: ViewModifier { let restEndsAt: Date?; let onActive: () -> Void; let onInactive: () -> Void }` (reads notifier, clock,
scene phase from the environment); the two `.onChange` handlers stay inside the closure either way.
Verify: `BUILD && TEST`; `grep -c 'onChange(of: rest != nil' HomeGymLog/Features/Workout/*.swift | grep -v ':0'` and the same for `onChange(of: log.restEndsAt` → one file, count 1 each;
`grep -rln '#if DEBUG' HomeGymLog/Features` → only files whose `#if DEBUG` wraps `#Preview`; `LAUNCH $UDID -seed wo-rest; SHOT $UDID wo-rest-c; cmp build/shot-wo-rest-a.png build/shot-wo-rest-c.png`
(identical: the effects draw nothing, and a seeded run that reached the live center would show the permission alert). AC-11 (mechanism), AC-21 (wiring).

### Step 10 (optional) — Live-clock checks in a scratch copy (repo untouched)
Only if `R=/private/tmp/claude-501/-Users-zhabskyi-AppleApps-HomeGymLog/94f5923f-c5ac-45d7-b4d4-1f10300309aa/scratchpad/rest` (the researcher's probe copy, same pbxproj as HEAD) still exists; otherwise skip and hand everything to the user. `SP` = the implementer's scratchpad.
```
source build/rest-env.sh; test -f "$R/HomeGymLog.xcodeproj/project.pbxproj" || { echo "no probe copy: skip Step 10"; exit 0; }
rm -rf "$SP/live" && rsync -a --exclude build --exclude .git ./ "$SP/live/" && mkdir -p "$SP/live/HomeGymLogUITests" "$SP/live-out"
diff -u HomeGymLog.xcodeproj/project.pbxproj "$R/HomeGymLog.xcodeproj/project.pbxproj" > "$SP/uitest-target.patch"   # UI-test target + bundle id com.zhabskyi.homegymlog.probe
patch "$SP/live/HomeGymLog.xcodeproj/project.pbxproj" < "$SP/uitest-target.patch"
```
In the copy only: `HomeGymLog/App/DebugSeed/LiveRestProbe.swift` (`#if DEBUG`; `static func prepareIfAsked(arguments: [String], in: ModelContext, now: Date)`): with `-liveRest <s>` (and
`-liveFresh` discarding any in-progress log) it runs `ProgramStore.start` (6 months, Mon–Fri, 45 min, `now`) or, when that returns nil because an earlier test already created the program,
`ProgramStore.current(in:)`; sets session `-liveSession <i>` (default 0) `restSeconds = s`, saves, `WorkoutLogStore.start(session:at: now)`. Each test uses its own session (test1 0, test2 1, test3 2,
test4 3, test5 4, test6 45), so a session an earlier test finished never blocks `start` (verifier 1 finding 1). With `-probeLog <path>` the copy's `WorkoutView` `.active` branch also appends a flushed
line `delivered=<count of delivered requests>` (INSIGHTS Patterns; verifier 1 finding 2);
called from the copy's `HomeGymLogApp.init` after `containerResult` with `live.now()` (on-disk store, live clock, live notifier, no `-seed`). `HomeGymLogUITests/RestLiveUITests.swift` (XCTest, SpringBoard
queries per INSIGHTS Patterns; drags with `press(forDuration:thenDragTo:)` on the element labelled `BEGINSWITH "Set n,"`; the countdown is the element labelled "Rest", read by its value), in order:
`test1_startCountEnd` (`-liveRest 8 -liveFresh`: drag row 1 right 160, tap the "7" button, Allow the alert; value decreases across 2 s; "Add 30 seconds" and "Skip rest" exist, "Next exercise ›" absent;
card gone ≤ 10 s, bar back; rating set 3 of exercise 1 shows a text `BEGINSWITH "Next: " AND ENDSWITH " · set 1"`) → AC-5, AC-11 (tree); `test2_swipeDuringRest` (drag row 2 right → "How hard was
that set?" and no "Skip rest" within 1 s, home, 12 s, no banner `label CONTAINS 'Rest over'`; new workout: left drag row 2 → sheet, swipe down → card still, left drag → "Skip set" → "Next: set 3 of 3", value
back to 8 s) → AC-6; `test3_addAndSkip` (`-liveRest 20`: +30s → value ≥ old + 29; two more quick +30s, home, poll banners every 0.5 s: exactly one, not before the extended end − 1 s; new rest: Exit →
Cancel keeps the card; a 60 pt drag on row 2 → no RPE card; Skip rest → card gone at once) → AC-7; `test4_skipSetAndLast` (Skip set rests with "Next: set 2 of 3"; Next exercise ×4, log and rate the last three
sets skipping rests → "SESSION COMPLETE", no card) → AC-8; `test5_killRelaunch` (`-liveRest 30`: rate, 5 s, `terminate`, `launch` → value 20–25 s; `terminate`, 31 s, `launch` → no card, "Next exercise ›"
present, and with `-probeLog` a `delivered=0` line within 1.5 s of that relaunch, removal being asynchronous) → AC-9; `test6_clearance` (`-liveSession 45 -liveRest 60`: sets 1–3 logged and rated, swipe up twice → row 4 `maxY` ≤ "Add 30 seconds" `minY` − 21 − 12) → AC-11 (clearance).
`RestDeniedUITests.testDenied` (fresh install, "Don’t Allow": rest counts and ends; home during a second rest past its end: no banner; no alert on the second rest) → AC-10.
```
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe 2>/dev/null; rm -rf "$SP/live.xcresult"
xcodebuild test -project "$SP/live/HomeGymLog.xcodeproj" -scheme HomeGymLog -destination "$DEST" -derivedDataPath "$SP/live-dd" -parallel-testing-enabled NO \
  -resultBundlePath "$SP/live.xcresult" -only-testing:HomeGymLogUITests/RestLiveUITests 2>&1 | grep -E "✘|error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)"
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe; rm -rf "$SP/live-denied.xcresult"
xcodebuild test -project "$SP/live/HomeGymLog.xcodeproj" -scheme HomeGymLog -destination "$DEST" -derivedDataPath "$SP/live-dd" -parallel-testing-enabled NO \
  -resultBundlePath "$SP/live-denied.xcresult" -only-testing:HomeGymLogUITests/RestDeniedUITests 2>&1 | grep -E "✘|error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)"
xcrun simctl uninstall "$UDID" com.zhabskyi.homegymlog.probe; xcrun simctl uninstall "$UDID" com.zhabskyi.probe.uitests.xctrunner; git diff --quiet -- HomeGymLog.xcodeproj && echo pbxproj-untouched
```
Handle the alert explicitly before touching the app (XCUITest's interruption handler may auto-allow). A failing check is reported with its log line, not fixed in the copy. Passed checks leave only
the visual and VoiceOver parts of AC-5–AC-11 with the user (§6).

### Step 11 — Acceptance sweep
```
source build/rest-env.sh
P='Date\(\)|Date\.now|Calendar\.(current|autoupdatingCurrent)'; grep -rnE "$P" HomeGymLog/Features HomeGymLog/Models HomeGymLog/Engine HomeGymLog/Shared HomeGymLog/App/RestNotifier.swift | grep -v '///'
grep -rn 'TimelineView(.explicit\|timerInterval' HomeGymLog; grep -rn 'UNUserNotificationCenter' HomeGymLog | grep -v 'App/RestNotifier.swift'; grep -rniI benchmark HomeGymLog/; head -1 HomeGymLog/App/DebugSeed/*.swift
xcodebuild -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
TEST; COUNT
xcodebuild -scheme HomeGymLog -destination "$DEST26" -derivedDataPath build/DerivedData test 2>&1 | grep -E "✘|TEST (SUCCEEDED|FAILED)"
BOOT $UDID26; LAUNCH $UDID26 -seed wo-rest; SHOT $UDID26 wo-rest-26; swift build/cardtop.swift build/shot-wo-rest-26.png 874; BOOT $UDID
```
Expected: greps print nothing and every `DebugSeed` file starts `#if DEBUG`; Release and both test runs succeed; `top=726` ± 1 on 26.5 (read the shot: same card). Then set the status lines of this plan and the
spec (with Step 10's per-check results). **Skill:** `wo-rest 600×300 @ (930, 1665)` joins row B in `.claude/skills/design-compare/SKILL.md` — the implementer lists it in its report and the main session
edits the skill (implementer.md rule 7 forbids skill edits). Hand-off in §6.

## 4. Data model changes
`WorkoutLog.restStartedAt: Date?` (when the current rest began) and `WorkoutLog.restEndsAt: Date?` (when it ends; the card shows while `now < restEndsAt`); absolute instants, no unit; no default needed
(optionals migrate an unversioned on-disk store automatically on 17.5 and 26.5, existing logs read nil; researcher Q1, A→B1/B2). `AppSchema.makeContainer` unchanged. No relationship, delete rule or
`#Predicate` change; persistence tests for the fields (Step 3) and every writer (Steps 4–5) run on iPhone 15 / iOS 17.5, and all again on 26.5 in Step 11. Invariant: both nil on every finished log.
Migration impact: none for users (AC-9 over the m3-logging build, the §6 "Install over m3-logging build" row); M5's `AppSchemaV1` must copy both fields.

## 5. Risks and gotchas
- **VoiceOver pre-empts "Rest over"** (unverified; the removal re-layout may speak first). Check AC-11 on device. Fallback in `observeRestEnd`: `Task { await Task.yield(); AccessibilityNotification.Announcement(RestText.restOver).post() }`.
- **1 Hz re-evaluation hitch** of the whole logging content. Check AC-17. Fallback (spec 4.4): the outer timeline computes only `resting: Bool` and passes it to a child whose handlers are `WorkoutView`
  methods (stable, not per-render closures); `RestOverlay`'s own timeline keeps drawing the label and ring; the two `.onChange` stay inside the outer closure.
- **Rest-start animation direction** (bar → card, with the RPE card leaving in the same transaction) is unverified. Check AC-5. Fallback: `.animation(rest == nil ? .easeInOut(duration: 0.3) : nil, value: rest != nil)` (animate only the end).
- **`ClockUsageTests` with the notifier:** `RestNotifier.swift` reads `clock.now()` only and names no `Date()`; the recorder lives in the test target. The suite runs in every `TEST`; Step 11 greps.
- **Release safety of `.silent()` only in DEBUG:** the `@Entry` default is `.live()`, so a Release build needs no override; `RestNotifierSourceTests` pins both halves, Steps 6 and 11 build Release, Step 9's
  `cmp` catches a seeded run reaching the live center. Hosted unit tests launch the production app on a clone store with no in-progress log, so `reconcile` only cancels.
- **Call-site churn (23 test + 5 app):** mechanical `at:` insertion, the Step 4 grep proves none remain, no assertion changes; the extended `LogValues` makes the churn load-bearing.
- **Unprobed shapes:** `.onChange(…, initial: true)` inside the timeline closure (P2 probed the plain form) → fallback `.onAppear { observeRestEnd(resting: rest != nil) }` inside the closure;
  closure-typed notifier fields warn under MainActor default isolation → fallback private static methods called from the closures (researcher's compiled protocol bodies).
- **Tooling:** `OS=` on every destination, `BOOT` after 26.5, stale bundles removed, one `xcodebuild` at a time, clone-stuck retry, curl poll, sips non-zero offsets act as top-left (crops read before use),
  `withExtendedLifetime` on every container, no `project.pbxproj` edit (Step 10 patches only the copy).

## 6. Definition of done
- [ ] Steps 1–9 and 11 green on iPhone 15 / iOS 17.5; full suite green on iPhone 17 / iOS 26.5; Release builds; Step 11 greps clean; `project.pbxproj` untouched; no new dependency or entitlement.
- [ ] `wo-rest` matches the prototype with the listed deviations; identical 3 s later; card top 704 (17.5) and 726 (26.5); kg and light shots read; wo-adjust and summary compares match; wo-start, wo-swipe, wo-rpe unchanged.
- [ ] Step 10 results recorded per check (or "skipped"); the skill carries the `wo-rest` crop (the main session edits it); plan and spec status lines set.
- [ ] **User, MVP test pass (simulator or phone, production launch):** AC-5 slide in both directions and the scrolled 4-set slide; AC-6 countdown visible behind the sheet; AC-7 fuller ring; AC-11 `updatesFrequently` value read on focus, rotor without "Next exercise ›", "Log set" action mid-rest, wrapped-name clearance; plus every AC-5–AC-11 check Step 10 skipped or failed.
- [ ] **User, iPhone 14 Pro Max:** AC-12 lock-screen banner and sound, AC-13 timing, AC-14 kill, AC-15 denied, AC-16 Exit mid-rest, AC-17 hitch, AC-11 VoiceOver "Rest over" exactly once.

## 7. Traceability, files, test estimate
| AC | Step | Proof |
|---|---|---|
| 1 · 2 · 3 · 4 | 8 (+11 for 726) | `/design-compare wo-rest` + `cmp` a/b + `cardtop` · `ac2-kg` · `ac3-light` · `/design-compare wo-adjust`, `summary` + `cmp` base vs now |
| 5 · 6 · 7 · 8 · 9 · 10 | 10 (optional), 11 (user) | `RestLiveUITests` test1 · test2 · test3 · test4 · test5 · `RestDeniedUITests`; visual parts in §6 |
| 11 | 8, 9, 10, 11 | a11y modifiers; `onChange` wiring grep; test1 tree + test6 clearance; VoiceOver on device |
| 12–17 | 11 (user, device) | the spec's device checks |
| 18 · 19 · 20 · 21 | 1 · 1 · 1 · 1, 9 | `RestTimerTests` remaining/fraction · display · rows + signature · `RestEndRuleTests` observeEnd + Step 9 grep |
| 22 · 23 · 24 | 2 · 1, 6 · 6 | `RestTextTests` · `decide` + `RestNotifierTests` reconcile · superseded, cancelled, interval-after-await |
| 25 · 26 · 27 | 4 · 5 · 4, 5 | `WorkoutRestWriterTests` · `RestExtendSkipTests` · extended `WorkoutCommitRollbackTests` + `RestCommitRollbackTests` |
| 28 · 29 · 30 | 7 · 3 · 6, 7, 11 | `WorkoutSeedTests.restInstants`, `DebugSeedTests`, `SeedHomeStatsTests` · `RestFieldsTests`, `SchemaSourceTests` · `RestNotifierSourceTests`, `SeedNameScanTests`, `ClockUsageTests`, Release |

**Files.** New app: `Engine/RestTimer`, `Shared/RestText`, `App/RestNotifier`, `Features/Workout/RestOverlay` (and `RestEffects` only if Step 9's count exceeds 80). Changed app: `Models/{WorkoutLog,
WorkoutLogStore}`, `App/{AppClock, HomeGymLogApp}`, `App/DebugSeed/{DebugSeed, WorkoutSeed}`, `Features/Workout/{WorkoutView, WorkoutLoggingContent}`. New tests: `Support/RestNotifierRecorder`,
`Engine/{RestTimerTests, RestEndRuleTests}`, `Shared/RestTextTests`, `Persistence/{RestFieldsTests, WorkoutRestWriterTests, RestExtendSkipTests, RestCommitRollbackTests}`, `App/RestNotifierTests`,
`Static/RestNotifierSourceTests`. Changed tests: `Persistence/{WorkoutSetWriterTests, WorkoutSetWriterEdgeTests, WorkoutCommitRollbackTests, MissedWorkoutEndToEndTests}`, `Seed/{DebugSeedTests,
WorkoutSeedTests, SeedHomeStatsTests}`, `Static/{SchemaSourceTests, SeedNameScanTests}`. Other: `docs/plans/m3-rest-timer.md` and spec status lines, the design-compare skill (main session);
`build/rest-env.sh`, `build/cardtop.swift` (gitignored). **Test estimate:** about +47 test functions (425 → ~472) before test-writer, plus new arguments on `DebugSeedTests.parses`,
`WorkoutSeedTests.seed`, `SeedHomeStatsTests.stats` and the seven-action rollback tests; a result bundle that counts parameterised cases per argument will show more.

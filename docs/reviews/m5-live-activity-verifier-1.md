VERDICT: PASS WITH FIXES

## Plan Verifier result — docs/plans/m5-live-activity.md against docs/specs/m5-live-activity.md

Round 1, 2026-10-02. Read in order: `CLAUDE.md`, `insights/INSIGHTS.md` (2026-10-02 live-activity entry, 2026-09-24 slicing),
`insights/gotchas.md` (2026-10-02 SwiftData / Swift / SwiftUI / Xcode entries), the spec (523 lines, 34 ACs), the plan (399 lines),
`docs/reviews/m5-live-activity-architecture.md` (B1–B3, NB1–NB13), `docs/reviews/m5-live-activity-researcher.md` (Q1–Q11, P1–P7), then
the code the plan touches or cites (listed in the claims table). No file other than this report was written.

**Spec alignment (S1–S9) check.** Grep of the spec confirms every resolution landed: S1 AC-18 "`@MainActor` is allowed only on `static var`
lines — `handler` and `inFlight` — never on a type" (spec:411); S2 `RestActivityHandler.makeHook(container:clock:defaults:notifier:center:)`,
the `let run = Task {…}; … await run.value` chain and "its own task, not `inFlight?.value`" (spec:186); S3 `ContentState.interval =
restStartedAt...max(restStartedAt, restEndsAt)` in §4.3 (spec:153) and the §5.1 last row (spec:265); S4 `RestActivityCenter` "imports
SwiftUI and ActivityKit, **not** `import UIKit`" (spec:185); S5 `ReminderActionRow` "becomes internal (was `private`)" (spec:441); S6
"`-liveActivity off` behaves exactly as absent" (spec:204); S7 AC-16 literal pins "(an equality with `RestText` would be trivially true once
aliased)" (spec:402-403); S8 AC-10 "one shared event log both recorders append to" (spec:376); S9 `nonisolated struct RestActivityDecision:
Equatable, Sendable` in §4.4 (spec:182) and §9 item 9 (spec:497). INSIGHTS carries none of the old wording (grep for "handler property",
"(endIDs, step)", "0-length", "inFlight?.value", "bool(forKey" returns nothing in `insights/INSIGHTS.md`). Two leftovers: spec §2.2 still
writes `timerInterval: start…end` (F3), and S8 is only half-applied — the spec's AC-10 sequence still contains a "write" event the plan's
recorder never records (F1).

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | Step 12 | `settings` shot: sixth row "Lock Screen timer", toggle on, under Sound | grep `AC-1`, `midProgram -tab settings` | plan:318-319 names the launch, `/design-compare settings` vs `build/proto-settings.png`, the deviations | covered |
| AC-2 | Step 12 | `activity-denied` shows denied subtitle + "Open iOS Settings"; `-appearance light` too | grep `activity-denied`, `-appearance light` | plan:319-320 | covered |
| AC-3 | Steps 10, 12, 14 | every existing seed shot unchanged; `wo-rest` pixel-identical | grep `SHOTALL`, `CMPALL`, `wo-rest` | plan:272 "`wo-rest` byte-identical outside the home-indicator band", plan:320-321 `CMPALL s12 skip`, plan:345 | covered |
| AC-4 | Step 13 | compact island shot after `simctl terminate`, flaky, retry ≤ 6, both runtimes | grep `ISLAND`, `terminate` | plan:52-53 `ISLAND()` (terminate, 5 shots at 2 s), plan:336-338 retry rule, 26.5, "not a baseline" | covered |
| AC-5 | Step 6 | `decide` over every §5.1 row as literals + five extras | grep `RestActivityPlanTests`, `11:59:47` | plan:145-146 "every §5.1 row as a typed argument table, plus AC-5's five extras", literals via `TestCalendar.day(2026, 9, 15)` | covered |
| AC-6 | Step 6 | `stranded` four rows + (true, true, []) | grep `AC-6` | plan:146 "the five AC-6 rows" | covered |
| AC-7 | Step 6 | `rowState` three rows + (true, nil), (false, false) | grep `AC-7` | plan:146 "the five AC-7 rows" | covered |
| AC-8 | Step 6 | `RestActivityKey` / `RestStrandedKey` equality field by field | grep `RestActivityKeyTests` | plan:147-148 each of seven fields alone, `RestStrandedKey` three | covered |
| AC-9 | Step 8 | recorder: ends before step, §2.1 sequences, B2 cancel + `end([a, missing])`, `.silent` flag | grep `holdsEnd`, `missing` | plan:197-202 incl. positive control for the cancel test, `.silent(activitiesEnabled: false)` → flag false | covered |
| AC-10 | Step 9 | handler rows on `wo-rest`; B1 ordered sequence; NB3 earliest log | grep `12:01:32`, `12:02:02`, `stray` | plan:234-242 every row; B1 expects `update, schedule, update, schedule` — spec:376/380 wants "write, update, schedule, …" via a write hook (F1); hook global shared with Step 5's suite (F2) | partial |
| AC-11 | Step 9 | failed save: same-context fetch by id reads 12:01:02, `hasChanges == true`, rollback before delete | grep `allowsSave`, `hasChanges` | plan:243-246 matches B3 exactly; shape cited `RestCommitRollbackTests.swift:83-118` verified | covered |
| AC-12 | Step 5 | hook tests `.serialized`, save/restore `handler`+`inFlight`, nil → no-op, each intent once, flags false | grep `LiveActivityIntentHookTests` | plan:113-116 `@MainActor @Suite(.serialized)`, `defer` restore, positive first | covered |
| AC-13 | Step 11 | five colorsets byte-equal to the app's; exactly those + wizard sets; `elevenColorsets` unchanged | grep `byte` | plan:275-276 `cp` loop, plan:289-290 `Data ==`, set membership, `ColorsetContrastTests` run | covered |
| AC-14 | Step 7 (+8,9) | ninth key round trip, missing → true, wrong type → nil → true, nine sorted keys, eight-key file decodes | grep `BackupLiveActivityKeyTests` | plan:164-167; "no test touches ActivityKit" via recorder-only rule plan:197, 383 | covered |
| AC-15 | Steps 12, 13 | `activity-denied` parses (09-15, flags), `DebugLiveActivity.parse` cases, `makeContainer(calendar:now:)` instants | grep `2027-03-03`, `now − 13` | plan:311-313 seed test; plan:331-334 parse cases + `−13 / +62 / −754` at an arbitrary `now` and equality at `referenceDate` | covered |
| AC-16 | Steps 5, 12 | seven shared literals, `nextLine` two cases, three Settings strings | grep `"Rest over"`, `Seated Low Row` | plan:110-112; plan:311 `SettingsTextTests` three literals | covered |
| AC-17 | Step 5 | shared folder: no UIKit/UIApplication/app type; imports ⊆ three | grep `AC-17` | plan:117-118 scan list | covered |
| AC-18 | Step 5 | every shared type `nonisolated`; `@MainActor` only on `static var` lines | grep `AC-18` | plan:118-119 | covered |
| AC-19 | Steps 1–4 | pbxproj pins: 17.0 ×6, family 1 ×6, key ×2, isolation 2, appex 1, exception, bundle id | grep `LiveActivityProjectTests` | plan:91-95 reads `project.pbxproj` via `#filePath`; GUI greps plan:71-77 | covered |
| AC-20 | Step 11 | `Button(intent:` placement scan; no alert/widgetURL/`Text("`; colors ⊆ five | grep `WidgetSourceTests` | plan:289-293 | covered |
| AC-21 | Steps 5–10, 14 | app-target scans (ActivityKit file, key once, four `@AppStorage` files, `UIApplication.` three files, hook line, `"Next: "` gone, Clock scan) | grep `LiveActivitySourceTests` | plan:120 ("Next: "), 152 (key once), 202-206 (seam, `uiApplicationStaysInApp`), 231-233 (hook line), 266-270 (four files), 342 sweep | covered |
| AC-22 | Steps 12, 13 | `SeedNameScanTests` gains `"activity-denied"`, `"-liveActivity"` | grep `SeedNameScanTests` | plan:310, 334 | covered |
| AC-23 | Steps 1–3, 14 | Debug build + full suite green on 17.5 and 26.5 with the extension | grep `TEST26` | plan:342 | covered |
| AC-24 | Steps 2, 11, 14 | Release green; `.appex` present; widgetkit point; `NSSupportsLiveActivities = true` | grep `plutil` | plan:294 first `RELEASE && ls`, plan:343-344 both `plutil -p` checks | covered |
| AC-25 | Step 14 | `Metadata.appintents` in both bundles | grep `Metadata.appintents` | plan:344-345 `ls -d` both paths | covered |
| AC-26 | — | Lock Screen view on device | plan §1, §6 | plan:29 "Excluded ACs (device, MVP pass, non-gating): AC-26–AC-32"; plan:398 | out-of-scope |
| AC-27 | — | buttons, app in background | plan §1, §6 | plan:29; plan:398 "AC-28 then AC-27 first (U1; failure → Step R)" | out-of-scope |
| AC-28 | — | buttons, app terminated | plan §1, §6 | plan:29, 398 | out-of-scope |
| AC-29 | — | end while locked shows "Rest over" | plan §1, §6 | plan:29, 399 | out-of-scope |
| AC-30 | — (Step 15 c partial) | Settings switch and denied pair on device | plan §1, §6 | plan:29, 368 "30 also Step 15 c", 399 | out-of-scope |
| AC-31 | — | locked buttons inert | plan §1, §6 | plan:29, 399 | out-of-scope |
| AC-32 | — | second App ID signs automatically | plan §1, §6 | plan:29, 399 | out-of-scope |
| AC-33 | Step 6 | `RestTimer.next` rows + `display == next` under the gate | grep `RestTimerNextTests` | plan:148-151 `.logging(0,1)`, `.logging(1,0)`, `.rpePending`, `.summary`, 5 and −1, shuffled; `display` equality incl. `now == end` nil | covered |
| AC-34 | Step 5 | `ClockUsageTests` second root, ≥ 4 files, no `Date()` / `Calendar.current` | grep `ClockUsageTests` | plan:120-121 | covered |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| `SettingsScreenSourceTests.filesScanned` lists 8 files (→ 9) | read | `HomeGymLogTests/Static/SettingsScreenSourceTests.swift:50-51` — eight names, `ReminderRows.swift` … `SettingsView.swift`; `ls Features/Settings` = 8 files | true |
| `.dividerCount` is 9 (→ 10) | read + count | `:115` `#expect(dividers == 9, …)`; `grep -c "SettingsDivider()" SettingsContent.swift` = 9 | true |
| `.preferencesRowOrder` token list ends `"SettingsText.sound,"` | read | `:57` tokens `[… "SettingsText.haptics", "SettingsText.sound,"]` — appending `"LiveActivityRows("` keeps it sorted | true |
| `.feedbackToggleRows` counts `SettingsToggleRow(` = 2 in `SettingsContent` | grep -c | 2 (`:67`, `:69`) | true |
| `RestNotifierSourceTests.liveOnlyAsEntryDefault` scans the whole target for `.live()` + `restNotifier` | read | `:39-54` — `found.count == 1`, path `App/AppClock.swift` | true (the Step 9 continuation line breaks it; fix planned) |
| `RestNotifierSourceTests.silentOnlyInSeedBranch` matches `.silent()` only | read | `:27` `contains(".silent()")` | true |
| `SettingsSourceTests.appearanceMechanism` pins `import UIKit` to `RootView.swift` | read | `:58` `hits("import UIKit", in: all).map(\.path) == ["App/RootView.swift"]` | true |
| `SettingsSourceTests.uiApplicationStaysInApp` two files | read | `:86` `["App/ReminderPermission.swift", "App/RootView.swift"]` | true |
| `FeedbackSourceTests.seedWritesKeys` wants each key once in `HomeGymLogApp.swift`, inside the seed branch, on a `suite.set(` line | read | `:219-230` | true |
| `BackupPreferencesTests.defaults` uses the `ResolvedPreferences` memberwise init | read | `:13-15` | true |
| `BackupPreferencesTests.swift:47-49` eight-key JSON | read | `:47-49` midProgram JSON with eight keys | true |
| `DebugSeedTests.parses(seed:)` `default:` expects 2026-08-31 | read | `:26` `default: expectedDay = TestCalendar.day(2026, 8, 31)` | true |
| `ClockUsageTests` scans `HomeGymLog/` only | read | `appSourceRoot` = `<repo>/HomeGymLog`; `onlyAppClockReadsTheClock` expects `["App/AppClock.swift"]` | true |
| `ReminderRows.swift:50` `private struct ReminderActionRow` | read | `:50` `private struct ReminderActionRow: View` | true |
| `ReminderPermission.swift:1,16` imports SwiftUI, uses `UIApplication.openNotificationSettingsURLString` | read | `:1` `import SwiftUI`; `:16` `static let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString)!` | true |
| `RestOverlay.swift:33` `Text("Next: " + RestText.next(rest.next))` | read | `:33` exact | true |
| `"Next: "` nowhere else in the app target | grep | only `RestOverlay.swift:33` and a `///` comment at `RestText.swift:32` (comments are stripped by the scans) | true |
| `ExerciseLibrary.swift:33` "Seated Low Row" | read | `:33` `Exercise(key: "lowRow", name: "Seated Low Row", …)` | true |
| `RestTextTests.swift:33-38` pins the six `RestText` constants | read | `:32-40` `@Test("the seven constants")` with `title` … `restOver`, `notificationBody` | true (lines 34-40) |
| `RestTimer.display(restStartedAt:restEndsAt:now:exercises:state:) -> RestDisplay?`; `RestNext.set(number:of:)`, `.firstSet(exerciseKey:)` | read `Engine/RestTimer.swift` | `:8-11`, `:41-52` | true |
| `RestTimerTests.swift:64-66` `session11` + `.logging(exercise: 1, set: 0)` → `lowRow` | read | `:64-66` | true |
| `RestSeedFlowTests.swift:27-32` reads rows with the screen's predicates | read | `:28-33` `screen(_:)` using `inProgressPredicate`, `exercisePredicate`, `setPredicate` | true |
| `RestCommitRollbackTests.swift:83-118` on-disk store, `allowsSave: false`, both containers bound | find + read | `HomeGymLogTests/Persistence/RestCommitRollbackTests.swift:83-114` `run(_:storeAt:)` — `allowsSave: false`, `rollback()` before `removeItem`, `withExtendedLifetime((writer, readOnly))` | true |
| `AutomaticPolicyPassEdgeTests.swift:173`, `ExerciseNoteSaveTests.swift:88` pin `hasChanges == true` | read | `Persistence/AutomaticPolicyPassEdgeTests.swift:173`, `Persistence/ExerciseNoteSaveTests.swift:88` | true |
| `FloatingTabBar.swift:7` `static let height: CGFloat = 64` | read | `:7` | true |
| `RootView` mounts `ReminderHost(…).id(…)` in `.background {}`; `activeLogs` sorted by `startedAt`; eight restore writes | read `App/RootView.swift` | `.background { ReminderHost(programID:…, workoutInProgress: activeLogs.first != nil).id(…) }`; `@Query(filter: inProgressPredicate, sort: \WorkoutLog.startedAt)`; `performRestore` writes eight bindings | true |
| `ReminderSourceTests.rootMount` survives a `ZStack` wrapper | read `:123-135` | requires `.background {`, the `ReminderHost(` line to contain `.id(`, no `activeLogs.first?.session`, background index < `.environment(permission)` — all hold for plan:262-263 | true |
| `HomeGymLogApp.init`: `containerResult = Result(catching: makeContainer)`; locals `clock`, `defaults`, `restNotifier`; seed branch between `DebugSeed.parse(` and `#endif` | read | `App/HomeGymLogApp.swift:97` and the `#if DEBUG` block `:58-96` | true |
| `AppClock.swift` `@Entry var restNotifier: RestNotifier = .live()` | read | `App/AppClock.swift:22-26` | true |
| `RestNotifier.reconcile(restEndsAt:clock:withSound:)`; `using` guards `Task.isCancelled` | grep | `App/RestNotifier.swift:100`, `:80` | true |
| `WorkoutLogStore.addRestTime(_:to:at:in:) throws -> Bool`, `skipRest(_:in:) throws -> Bool` via `StoreCommit.commit` | read | `Models/WorkoutLogStore.swift:172-188` | true |
| `WorkoutSnapshotBuilder.inProgressPredicate`, `values(exercises:sets:)`; `WorkoutFlow.sorted`, `.state` | grep | `Models/WorkoutSnapshotBuilder.swift:20, 37`; `Engine/WorkoutFlow.swift:72`; `WorkoutView.swift:75-76` | true |
| `WorkoutLog.exercises`, `LoggedExercise.sets` relationships (handler's hops) | read | `Models/WorkoutLog.swift:18-19`, `Models/LoggedExercise.swift:18-19` | true |
| `WorkoutView`: `restKey` in `body`, `.task(id: restKey)`, `observeRestEnd` guarded by `isDiscarding`, scene-phase handler guarded | grep | `:79`, `:131`, `:157-158`, `:136-140` | true |
| `FeedbackCues.soundKey = "soundEnabled"`, `defaultEnabled = true` | grep | `Engine/FeedbackCues.swift:26-27` | true |
| `BackupPreferences` lenient `(try? decodeIfPresent) ?? nil`, `ResolvedPreferences` with eight fields | read | `Engine/Backup/BackupDocument.swift:140-201` | true |
| `BackupStoreFixtures.midProgramPreferences` eight args | read | `Support/BackupStoreFixtures.swift:58-59` | true |
| `BackupSourceTests.noPreferenceKeyLiterals` key list (six keys) | read | `:91` | true |
| `DebugSeed.makeContainer(calendar:)` workout branch passes `referenceDate`; `WorkoutSeed.populate(_:now:in:)`; −13 / +62 / −754 | read | `DebugSeed.swift:128-150`; `WorkoutSeed.swift:26, 31, 50` (`setRPE … at: now − 13`, 75 s rest) | true |
| "the 63 `makeContainer(calendar:)` call sites" (spec:446, plan:327) | grep -v `func` | 70 call sites: 7 in the app target (`HomeGymLogApp.swift:75` + six `#Preview`s) and 63 in tests | inexact (F5) |
| `DebugFeedbackPreferences.value(of:in:)` is `private static` | read | `App/DebugSeed/DebugFeedbackPreferences.swift:27` | true |
| `MidProgramSeed.populate(in:calendar:)`, `AppSchema.makeContainer(inMemory:)` | grep | `MidProgramSeed.swift:19`; `DebugSeed.swift:129` | true |
| `WorkoutFixtures.session11`, `TestCalendar.day(_:_:_:)`, `RestNotifierRecorder` hold shape | grep | `Support/WorkoutFixtures.swift:12`; `Support/TestCalendar.swift:16`; `Support/RestNotifierRecorder.swift:19-42` (`held`, `release(_:)`, `waitingCount`) | true |
| `SeedNameScanTests.names` list; names must appear only under `App/DebugSeed/` | read | `Static/SeedNameScanTests.swift:8-15, 37-50` | true |
| `ColorsetContrastTests.elevenColorsets` scans `HomeGymLog/Assets.xcassets` only | read | `:45`, `:116`; the app catalog holds `AccentColor sf sf2 tx mu` among its eleven | true |
| `ReminderText.openSettings == "Open iOS Settings"` | grep | `Shared/ReminderText.swift:11` | true |
| `build/haptics-env.sh` supplies every Step 0 name | grep across `build/*.sh` | chain `haptics → reminder → settings` (+ `reminder-shots`); every name resolves (`DEST26`/`BID` on `settings-env.sh:1`); `LAUNCH` = terminate, install, launch (so the activity is requested after the install, Q8) | true |
| `build/settings-env.sh` `sips -c 800 290 --cropOffset 2555 4148` | grep | `:18` | true |
| `build/light-cmpx.py`, `.claude/hooks/guard-pbxproj.sh` exist | ls | both present | true |
| `project.pbxproj` baseline: appex 0, 17.0 ×4, family-1 ×4, key 0, isolation 2, `HomeGymLogShared` 0 | grep -c | 0 / 4 / 4 / 0 / 2 / 0; `HomeGymLogShared/`, `HomeGymLogWidgets/` absent on disk; tree clean except the four new docs | true |

### Findings

1. **should-fix** — AC-10's planned sequence does not match the spec's (S8 half-applied). Evidence: spec:376 "observed through one shared
   event log … **the write logged by a hook on the recorder's first call reading the row**" and spec:380-381 "the sequence is write, update,
   schedule, write, update, schedule"; plan:191-192 `enum Event { request, update, end, schedule, cancel }` has no write case and plan:240
   expects "events exactly `update(12:01:32), schedule(12:01:32), update(12:02:02), schedule(12:02:02)`". The plan's test still fails when the
   chain is removed (the yielding doubles interleave to `update, update, schedule, schedule`; the implementer's mutation check at plan:241 is
   right), so the AC's intent is met; the wording is not. Fix (one line in the spec, since the update's value already proves the write order):
   AC-10 → "the recorder's sequence is `update(12:01:32), schedule(12:01:32), update(12:02:02), schedule(12:02:02)` (an update reading
   12:02:02 can only follow the second write's re-sync); the doubles `await Task.yield()` inside every closure so an unserialized chain
   interleaves and the test fails"; delete "the write logged by a hook on the recorder's first call reading the row" and the two "write,"
   tokens at spec:380-381.
2. **should-fix** — Two suites assign the process-wide `LiveActivityIntentHooks.handler` and can race. Evidence: plan:113-116 puts the hook
   tests in `App/LiveActivityIntentHookTests.swift` (`@Suite(.serialized)`); plan:239 puts the B1 test "through `makeHook` … installed in the
   hook (save/restore `handler`, `inFlight`; `.serialized`)" in `Seed/RestActivityHandlerTests.swift`. `.serialized` orders tests inside one
   suite only; Swift Testing runs different suites concurrently, both are `@MainActor`, and `perform()`'s `await MainActor.run { handler }`
   (spec:153) is a suspension point at which the other suite can reassign `handler`, so an intent can land on the wrong recorder. Fix: move the
   B1 test into `LiveActivityIntentHookTests` (the one `.serialized` suite that touches the global) and add to plan:239 and the spec's AC-12
   "no other suite assigns `handler` or `inFlight`"; `LiveActivitySourceTests` may pin it (`LiveActivityIntentHooks.handler =` appears in
   exactly one test file). React analogy: two Jest files mutating one module-level singleton while Jest runs files in parallel workers.
3. **should-fix** — Pre-S3 wording left in spec §2.2. Evidence: spec:53 "`ProgressView(timerInterval: start…end, countsDown: true)`" and
   spec:55 "`Text(timerInterval: start…end, …)`", while §4.3 (spec:153) says "every `timerInterval:` reads `interval`, never the raw range".
   The plan already uses `state.interval` (plan:280-281). Fix: replace `start…end` with `state.interval` in both rows.
4. **note** — Plan S5 reads "`ReminderActionRow` is `private` (`ReminderRows.swift:50`) → drop it" (plan:15), which can be read as dropping the
   row; Step 12 (plan:298 "loses `private`") and spec:441 mean dropping the access modifier. Fix: "→ drop its `private`".
5. **note** — "the 63 `makeContainer(calendar:)` call sites" (spec:446, plan:327) is inexact: 70 exist (7 in the app target including six
   `#Preview`s, 63 in tests). Harmless because the overload keeps every one compiling; write "every existing call site (70)".
6. **note** — Step R says "Verify as Step 14" (plan:363), but Step 14 includes the AC-25 `ls -d … Metadata.appintents` check (plan:344-345),
   which must fail once both intents are deleted. Fix: "Verify as Step 14 minus the AC-25 check (metadata expected absent)".
7. **note** — The handler reads exercises through relationship hops (`log.exercises`, `log.exercises.flatMap(\.sets)`, plan:221) while the
   screen (`WorkoutView.swift:70-75`) and `RestSeedFlowTests.swift:28-33` read through `WorkoutSnapshotBuilder.exercisePredicate(logID:)` /
   `setPredicate(exerciseIDs:)`. Both relationships exist (`WorkoutLog.swift:18-19`, `LoggedExercise.swift:18-19`) and both paths give the same
   values; using the screen's two predicates would extend NB3's "exactly as the screen" rule from the log to its rows. Optional.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | plan §Steps 9 for the Lock Screen writes | both go through the existing `addRestTime` / `skipRest` (`StoreCommit.commit`, one save each) on `container.mainContext` (plan:220-221; P2 one-container rule) | addressed |
| Delete rules | plan §4 | "None: no `@Model`, relationship, delete rule, `#Predicate` or migration change" (plan:374) | addressed |
| Units | grep `kg`, `Lb` in plan | no weight in the activity; nothing stored | n/a |
| Date determinism | `Date()` / `Calendar.current` in Engine or Shared | `RestActivityPlan.decide(… now:)` takes `now` (plan:137); `ClockUsageTests` gains `HomeGymLogShared/` (plan:120-121); the seed branch's live clock is `live.now()` from the existing `AppClock.live()` local, not a new `Date()` (plan:329) | addressed |
| Concurrency | `ModelContext` off main; unowned tasks | handler is a `@MainActor enum` on `container.mainContext` (plan:211); `inFlight` is a `@MainActor static` chain; no `Activity` leaves a closure (plan:185-186) | addressed |
| Availability | APIs > iOS 17.0 | every ActivityKit call 16.1/16.2, `Button(intent:)` / `LiveActivityIntent` 17.0 (researcher Q3, Q6); `openAppWhenRun` is only read in a test (plan:116), never declared — a deprecation warning on the 26 SDK at most | addressed |
| Privacy label | network, analytics, usage strings | none; `NSSupportsLiveActivities` is a capability flag, not a usage string (researcher Q3) | addressed |
| Resume and empty states | kill mid-rest, relaunch after end, Discard, Done, restore, first run | screen key nil while `isDiscarding` (plan:253), root host ends strays from `activeLogs.first != nil` (plan:262-263), request refused in the background retried on the scene-active tick (spec §3); first run unreachable without a workout | addressed |
| Three source roots | app-target types or UIKit in `HomeGymLogShared/`; extension using app files | AC-17/18 scans (plan:117-119); extension files use only `RestActivityAttributes`, `RestActivityText`, the intents and its own catalog (plan:277-288) | addressed |
| Hand edits to `project.pbxproj` | grep `pbxproj` in plan | read-only greps only (plan:62 "agents only grep `project.pbxproj`, never edit it"); Step 4's test reads it via `#filePath` | addressed |

### Summary

- Covered: 26 of 34 acceptance criteria
- Partial: AC-10
- Missing: none
- Ambiguous: none
- Out of scope (per plan): AC-26, AC-27, AC-28, AC-29, AC-30, AC-31, AC-32 (device MVP pass, plan:29)
- False claims about existing code: 0 (one inexact count, F5)
- Traceability: plan carries AC numbers (per step and in the §Traceability line, plan:365-368)

Ordering and buildability: every step uses only types introduced earlier (Shared → Engine → backup key → seam → handler → screen/host →
extension → Settings → DEBUG); the three GUI steps have click-by-click directions, read-only greps with today's baselines (0 / 4 / 4), and a
`BUILD` (`BUILD && TEST; CNT` after Step 3); every later step ends with a focused run plus the full suite. The B1 chain (plan:224-226), the
B2 cancellation guard and call-time id resolution (plan:180-185), the B3 same-context fetch (plan:243-246), the `.background` `ZStack` host on
an `Equatable` `RestStrandedKey` with no row read in the root (plan:259-263), the NB7 `object(forKey:) as? Bool ?? fallback` read (plan:217),
the `makeContainer(calendar:now:)` overload (plan:326-327), the "not a baseline" island shot with the ≤ 6 retry rule (plan:336-339), the
Release checks for the appex and `Metadata.appintents` in both bundles (plan:343-345), Step R's exact file list (plan:359-363) and the
definition of done (plan:390-399) all match the brief's twelve checks.

### Questions only the user can answer

- None. (Step 1 click 9's "remove iPad, Mac, Vision" and Step 3's "New Folder → Target Membership" wording are researcher-unverified GUI
  paths; the plan already asks for a screenshot when unsure and verifies by grep, which is the agreed way to handle them.)

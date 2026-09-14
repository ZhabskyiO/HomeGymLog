VERDICT: PASS WITH FIXES

## Plan Verifier result — docs/plans/m3-rest-timer.md against docs/specs/m3-rest-timer.md

Round 1. Read in order: `CLAUDE.md`, `insights/INSIGHTS.md` (all 724 lines), `insights/gotchas.md`, the spec, the plan, both researcher reports, the architecture review, `.claude/agents/implementer.md`, `.claude/skills/design-compare/SKILL.md`, then every file the plan touches or claims. The plan carries AC numbers throughout (§3 step footers, §7 table).

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | 8, 11 | `wo-rest` matches prototype; identical 3 s later; card top 704 / 726 | plan §3 Step 8 Verify, Step 11 | `/design-compare wo-rest` + `cmp` a/b + `cardtop … 852 → top=704`; Step 11 `cardtop … 874 → top=726`; deviation list matches spec AC-1 | covered |
| AC-2 | 8 | `-units kg`: rows "49.9 kg × 12 reps", card unchanged | grep `ac2-kg` | Step 8 `LAUNCH … -seed wo-rest -units kg; SHOT ac2-kg`; 110 lb × 0.45359 = 49.9 ✓ (`WorkoutSeedTests.swift:12` targets 110) | covered |
| AC-3 | 8 | light tokens on the card | grep `ac3-light` | Step 8 `APPEAR light … SHOT ac3-light` → `sf`, `sf2`, accent listed | covered |
| AC-4 | 8 | wo-adjust / summary match with no card; wo-start/swipe/rpe unchanged | grep `base-` | Step 0 baselines + Step 8 `cmp build/base-$s.png build/shot-now-$s.png`, `/design-compare wo-adjust`, `summary` | covered |
| AC-5 | 10 (opt), user | rest starts on rating, counts 1:15→0:01, bar slides back, prompt over card, between-exercise "Next:" | grep `test1_startCountEnd` | Step 10 test1 (value decreases, card gone ≤ 10 s, "Next: … · set 1"); slide + prompt visual → §6 user list | covered (user-run per spec B3) |
| AC-6 | 10 (opt), user | swipe mid-rest → RPE card, no banner; sheet over card; Skip set replaces | grep `test2_swipeDuringRest` | Step 10 test2 (no "Skip rest" within 1 s; no banner over 12 s; "Next: set 3 of 3") | covered (user-run) |
| AC-7 | 10 (opt), user | +30s → 1:32, one banner at extended end, Skip, Exit→Cancel, 60 pt brush | grep `test3_addAndSkip` | Step 10 test3 (value ≥ old + 29; exactly one banner not before end − 1 s; brush → no RPE card) | covered (user-run) |
| AC-8 | 10 (opt), user | Skip set rests; last set → summary, no card | grep `test4_skipSetAndLast` | Step 10 test4 | covered (user-run) |
| AC-9 | 10 (opt), user | kill mid-rest → real time left; after end → no card; nothing left in Notification Center | grep `test5_killRelaunch` | Step 10 test5 covers the card half; Notification Center half → §6 user list (see finding 2) | covered (user-run) |
| AC-10 | 10 (opt), user | denied: timer works, no banner, no second prompt | grep `RestDeniedUITests` | Step 10 `testDenied` after `simctl uninstall` | covered (user-run) |
| AC-11 | 8, 9, 10, user | a11y labels/traits, rotor without "Next exercise ›", "Rest over" once, clearance | grep `updatesFrequently`, `test6_clearance` | Step 8 modifiers (`accessibilityValue(RestText.spoken)`, `.updatesFrequently`); test1 tree, test6 `row 4 maxY ≤ "Add 30 seconds" minY − 21 − 12`; VoiceOver → device | covered (VoiceOver user-run) |
| AC-12–17 | 11 (user, device) | lock-screen banner, timing, kill, denied, Exit mid-rest, hitch | plan §6 last bullet | listed one by one for the iPhone 14 Pro Max, as the spec's "Device" block requires | covered (device, user) |
| AC-18 | 1 | `remainingSeconds` / `remainingFraction` over every 5.2 row | grep `61.993`, `0.001`, `80 →` | Step 1: 62, 61.993→62, 92, 75, 60, 120, 632, 5, 1, 0.5→1, 0.001→1, 0→0, −5→0, 80; fractions 62/75, 92/105, 0.001/75, 1, total 0 / −10 → 0, clock-back → 1, past end → 0 | covered |
| AC-19 | 1 | `display` over the 5.3 table, nils, `next` cases, shuffled input | grep `firstSet(exerciseKey: "lowRow")`, `shuffled` | Step 1 eight literal rows, both nil orders, `now == restEndsAt`, `.rpePending`, out-of-range 5 and −1, `WorkoutFixtures.shuffled` | covered |
| AC-20 | 1 | rows unchanged while resting; signatures gained no rest input | grep `signature check` | Step 1 literal `[done(7), active, waiting dimmed]`, `showsHint` (0,1) false / (0,0) true, typed function references (a new parameter breaks the build) | covered |
| AC-21 | 1, 9 | `observeEnd` over every 5.5 row; wiring once each inside the closure | grep `RestEndRuleTests`, `grep -c 'onChange(of: rest != nil'` | Step 1 rows as literals with E = t + 62 / t + 92; Step 9 count-1 greps | covered |
| AC-22 | 2 | `RestText.clock` / `spoken` / `next` / `restOver` | grep `"10 minutes 32 seconds"` | Step 2 all nine clock and nine spoken values verbatim plus 3600; `next` both cases + `"mystery"`; seven constants | covered |
| AC-23 | 1, 6 | `decide` future/nil/equal/past; applied through the double → one record | grep `decide`, `reconcile` | Step 1 `t + 0.001`, nil, t, t − 5; Step 6 `reconcile` → one add / one cancel | covered |
| AC-24 | 6 | cancellation ordering with a controllable await | grep `Superseded run` | Step 6: hold auth, cancel first, release second then first → `added == [12:02:02]` (fails without the guard: `[12:02:02, 12:01:32]`); cancelled run records nothing; interval 72.5 after the await | covered |
| AC-25 | 4 | writers start/clear rest on the session-11 fixture; Build 90; finish → nil | grep `WorkoutRestWriterTests` | Step 4 bullets cover every clause of AC-25 including `restSeconds` 0, `session == nil`, guard on a rated set | covered |
| AC-26 | 5 | `addRestTime` / `skipRest` semantics | grep `RestExtendSkipTests` | Step 5: +30 at t+13 → t+105, start unchanged; t+75 and t+80 → false; 0 / −30 throw; stale skip → true | covered |
| AC-27 | 4, 5 | failed save restores rest fields, both containers bound | grep `allowsSave: false`, `LogValues` | Step 4 extends `LogValues` (real: `WorkoutCommitRollbackTests.swift:28-54`); Step 5 `RestCommitRollbackTests` over add/skip/logSet/skipSet with `withExtendedLifetime((writer, readOnly))` | covered |
| AC-28 | 7 | `wo-rest` instants, state, display; `wo-adjust` stale; others nil; Home unchanged | grep `restInstants` | Step 7 `(noon − 13, noon + 62)`, 62, 62/75, `.set(number: 2, of: 3)`; wo-adjust `(noon − 586, noon − 511)`; `SeedHomeStatsTests` row | covered |
| AC-29 | 3 | optional fields migrate; source check | grep `RestFieldsTests` | Step 3 fresh-context read-back; `SchemaSourceTests` trimmed-line match | covered |
| AC-30 | 6, 7, 11 | Release; scan; `ClockUsageTests`; `.silent()` in DEBUG branch only, `.live()` only as default | grep `RestNotifierSourceTests` | Step 6 static test with line-range rule; Step 7 `names` gains `"wo-rest"`; Steps 6 and 11 Release builds | covered |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| 23 test call sites: WorkoutSetWriterTests 14, Edge 6, CommitRollback 2, MissedWorkout 1; WorkoutSeed 3; WorkoutView 2 | `grep -rcE 'WorkoutLogStore\.(setRPE\|skipRPE)\('` | exactly 14 / 6 / 2 / 1 / 3 / 2 = 28; no unprefixed calls (only the two test function names) | true (the architecture review's "25" was wrong; the plan's 23 is right) |
| `WorkoutView.body` is 49 lines (47–95) | read | `WorkoutView.swift:47` `var body` … `:95` `}` | true |
| bar lives in `.safeAreaInset(edge: .bottom, spacing: 0)` lines 65–73 | read | `WorkoutLoggingContent.swift:65-73` — `WorkoutBottomBar(nextEnabled: WorkoutFlow.nextExerciseEnabled(state) …)` | true |
| `WorkoutLog` has `finishedAt`, init `(startedAt:finishedAt:)` | read | `WorkoutLog.swift:10,16` | true |
| `Phase.restSeconds` 75/90/120/60 | read | `EngineTypes.swift:37-40` | true |
| `restSeconds` written by generator and `ProgramStore.apply`; `PlannedSession.restSeconds` | grep | `ProgramGenerator.swift:94`, `ProgramStore.swift:49`, `PlannedSession.swift:19` | true |
| `phaseOf` index ranges for 24 weeks: F 0–44, B 45–84, P 85–114, D 115–119; session 11 → week 3 → 75 s; 1-month F 1–2 / P 3 / D 4 | recomputed from `PhaseSplit.swift:20-28` | remaining 23; F = (805+99)/100 = 9; P = (575+99)/100 = 6; week > 17 → Peak; 11/5+1 = 3 ≤ 9 → Foundation. 4 weeks: F = 2, P = 1, week 3 > 3−1 → Peak, Build none | true |
| 5.2 table: 62/75 = 0.8267, 92/105 = 0.8762, offsets 39.2 / 28.0, 0.001/75 ≈ 0.00001 | arithmetic | 2π·36 = 226.19; ×13/75 = 39.2; ×13/105 = 28.0 | true |
| seed instants: `startedAt` = now − 754 (11:47:26), E1S1 at +168 (11:50:14), rated now − 13 → 12:01:02 "1:02"; wo-adjust rating at now − 586 → ends now − 511; summary → nil | `WorkoutSeed.swift:27-34,55-56`, arithmetic | 754 s = 12:34 ✓; 754 − 168 = 586; 586 − 75 = 511 ✓; `.finishedSets` rates every other set while E1S1 is still pending, then rates E1S1 last with nothing pending → clear | true |
| 5.5 table under the plan's triggers (mount `initial: true`, `.active` re-run, `L := nil` off-active) | walked every row with the rule L≠nil ∧ E=L ∧ ¬resting ∧ now ≥ L | mount → L=E, no; end tick → yes, L nil; +30s → L=new E; its tick → yes; Skip/swipe → E nil → no; Skip-set → L=new E; relaunch after end (`initial` fires, L nil) → no; background-return past end (`.active` runs with resting false, then onChange true→false, both L nil) → no; return before end → `.active` sets L=E → yes at end; prompt (inactive → L nil) → no | true, no row announces when the spec says not to |
| `DebugSeed.parse`, `referenceDate` 09-15 group, `initialDraft` nil group, `makeContainer` workout group, `workoutStage` | read | `DebugSeed.swift:30-35, 41, 63, 78-82, 90-98` | true |
| `HomeGymLogApp`: seed branch `if let seed = try DebugSeed.parse` … `#endif` | read | `HomeGymLogApp.swift:32, 48` | true |
| `@Entry var appClock = AppClock.live()` precedent | read | `AppClock.swift:21` | true |
| `.live()` appears elsewhere only as `AppClock.live()` | grep | ShellView:44, HomeView:72, ProgramView:81, WorkoutView:197, HomeGymLogApp:20 — all `AppClock.live()` | true (the Step 6 static rule holds today) |
| `ClockUsageTests` scans the whole app target incl. `App/` | read | `ClockUsageTests.swift:52-56` `offenders(under: appSourceRoot) == ["App/AppClock.swift"]` | true |
| `SchemaSourceTests`, `SeedNameScanTests` shapes | read | `SchemaSourceTests.swift:14-24`; `SeedNameScanTests.swift:7` `names` array, comments stripped | true |
| `WorkoutCommitRollbackTests.LogValues` with `changes`, seven actions, `at` local | read | lines 20-22, 28-54, 72 | true |
| `MissedWorkoutEndToEndTests` uses `now + 60·k` | read | line 29 | true |
| `WorkoutSeedTests.seed` rows `(seed, 754.0, state)`, `.woAdjust` rows; `DebugSeedTests.parses/workoutNames/drafts/previews` | read | `WorkoutSeedTests.swift:39-45, 28-29`; `DebugSeedTests.swift:10-24, 26-35, 58-61, 64-70` (`previews` filters `allCases`, so a nil-preview `.woRest` passes without edits) | true |
| `WorkoutFixtures.exercises(session11)`, `editing`, `shuffled`; `WorkoutStoreFixtures.sixMonthRows` (session 45 Build) | read | `WorkoutFixtures.swift:12,17,30,56`; `WorkoutStoreFixtures.swift:9-21` | true |
| `TestStore` holds container + context | read | `TestContainer.swift:6-9` | true |
| `WorkoutText.exerciseName(key:)`, `Theme.sf/sf2/accent/tx/mu`, `WorkoutBottomBar`, `lowRow` = "Seated Low Row", session 11 exercise 2 = lowRow | grep | `WorkoutText.swift:45`; `Theme.swift:6-12`; `WorkoutBottomBar.swift:5`; `ExerciseLibrary.swift:33`; `WorkoutSeedTests.swift:58` | true |
| Baseline 425 tests | grep | `docs/plans/m3-logging.md:3`, `CLAUDE.md:180` | true |
| `$R` probe copy exists with HEAD's pbxproj + UI-test target, bundle ids `…homegymlog.probe` / `…probe.uitests` | `ls`, `diff` against `git show HEAD:…pbxproj` | 129-line diff: only `PRODUCT_BUNDLE_IDENTIFIER` swaps, `HomeGymLogUITests` target, `TEST_TARGET_NAME = HomeGymLog`; repo pbxproj unchanged since 435d7ce and clean in `git status` | true |
| `wo-rest` crop 600×300 @ (930, 1665) between wo-rpe (1345) and summary (1975) | read `build/proto-all-small.png` (803 px = 3000/3.74) | row B order home, wo-start, wo-swipe, wo-rpe, **wo-rest**, summary; wo-rest frame left ≈ 448 × 3.74 ≈ 1674, width ≈ 276, height ≈ 616 — same offset convention as the skill's wo-rpe (≈1364 vs 1345) and summary (≈1980 vs 1975) | plausible; the implementer reads the crop before use (plan §5) |
| `.onChange(of:initial:)`, `AccessibilityNotification.Announcement`, `UnevenRoundedRectangle`, `.task(id:)` are iOS 17-or-earlier | researcher Q2/P2 + SDK | onChange(of:initial:) iOS 17.0; Announcement iOS 17.0 (P2 typechecked, iOS 17 target); UnevenRoundedRectangle iOS 16; TimelineView iOS 15 | true |

False claims: 0.

### Findings

**Blocking**

None.

**Should-fix**

1. **should-fix** — Step 10's tests share one on-disk store and one session. `test4_skipSetAndLast` finishes session 0 ("SESSION COMPLETE"); `test5_killRelaunch` then launches with the default `-liveSession 0`. `WorkoutLogStore.start(session:)` returns the session's existing (finished) log (`WorkoutLogStore.swift:72` `if let existing = session.workoutLog { return existing }`), the in-progress route never opens, and test5 fails for a fixture reason. Also, on every launch after the first, `ProgramStore.start` returns nil (INSIGHTS "owns at most one current program … returns nil without writing"), and the sketch does not say what `prepareIfAsked` does then. Fix: give each test its own session (`-liveSession 1…4` for tests 2–5; test6 already uses 45) and have `prepareIfAsked` fall back to `ProgramStore.current(in:)` when `start` returns nil; `-liveFresh` keeps discarding an in-progress log only.
2. **should-fix** — AC-9's second half ("no 'Rest over' left in Notification Center" after a relaunch past the end) is handed to the user (§6) although the scratch copy can check it: the researcher's `-probeLog` pattern (INSIGHTS Patterns 2026-09-14) reported delivered counts. Fix: in the copy only, add a `-probeLog <path>` line from the `.active` branch with `deliveredNotifications().count` and have test5 assert 0 after the past-end relaunch (allow ~1.5 s; removal is asynchronous per gotchas).

**Nit**

3. **note** — Definition of done line 348 "the skill carries the `wo-rest` crop" does not say who edits it; Step 11 (line 322) and §7 (line 369) both say the main session, per `implementer.md` rule 7. Add "(main session)" to the DoD bullet so all three places agree.
4. **note** — `.onChange(of: rest != nil, initial: true)` inside the timeline closure is unprobed (P2 probed the plain form); the plan names the `.onAppear` fallback (§5). Nothing in Steps 8–9 exercises the mount row on a live clock (the seeded `cmp` is frozen), so the mount behaviour rests on AC-21's pure test plus the user's AC-5/AC-11 pass. Acceptable; keep the fallback line.
5. **note** — `.transformEnvironment(\.restNotifier)` reads the `@Entry` default before overriding it (≈ a context provider that first evaluates the default value), so `.live()` → `.using(.system())` is constructed even in a seeded run. Make `system()` capture `UNUserNotificationCenter.current()` lazily inside its closures, not at construction, so "seeds never touch the center" stays literally true (harmless either way: no prompt, no add; researcher Q3 "Center access in unit tests … did not crash and did not prompt").
6. **note** — Step 9 keys `.task(id: log.restEndsAt)` on the outer `Group`, which reads `log.restEndsAt` in the frame after `discard()` deleted and saved the row; m3-logging deliberately reads log fields "once in `init`, never in `body`" (`WorkoutView.swift:9`). Evidence it is safe: the researcher's P4 copy read `log.restEndsAt` in `body` (`$R/…/WorkoutView.swift:56`) and keyed `.task(id: log.restEndsAt)` on the outer group (`:106`) through Exit → Discard on 17.5 and 26.5 with no trap. Cite P4 in Step 9 or key the task on `isDiscarding ? nil : log.restEndsAt`.
7. **note** — Spec 5.5 says the screen calls the rule "whenever `resting` or E changes" and its relaunch row says "no call"; the plan adds a mount call and an `.active` re-run, which the spec's own "return 12:00:55 → *L'* = 12:01:02" row actually needs (a true→true `resting` fires no `onChange`). Outcomes match every row; doc-writer should align the 5.5 trigger sentence with the plan.
8. **note** — `HomeGymLogTests/App/RestNotifierTests.swift` introduces a test folder `CLAUDE.md`'s layout does not list (Engine, Onboarding, Persistence, Seed, Shared, Static, Support). Synchronized folder, so it compiles; doc-writer adds it to the layout.
9. **note** — `RestNotificationCenter` (four injected system calls) is a plan-level addition over the spec's `RestNotifier` seam. It is what makes AC-24's "controllable await" possible without touching the live center, so it is justified, not creep; record the shape in INSIGHTS with the notifier entry.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | Steps 4–5 writers end in `commit` | every rest change is one save; nothing written at zero; relaunch derives from the two instants (spec §3, researcher R8) | addressed |
| Delete rules | §4 Data model changes | two optional attributes, no relationship or predicate change; `finish`/`discard`/`start` untouched | addressed |
| Units | new properties | absolute `Date` instants, no weight or kg anywhere | addressed |
| Date determinism | `RestTimer` signatures, `RestNotifier` | Engine takes `now:`; notifier takes `AppClock`; `ClockUsageTests` scans `App/` too; Step 11 greps `Date()`/`Date.now` | addressed |
| Concurrency | notifier closures, recorder | `.task(id:)` on main; `Task.isCancelled` guard after every await and before `add`; recorder `@MainActor`; closure-field warning fallback named | addressed |
| Availability | every new API | all iOS 17.0 or earlier (see claims table); no `#available` | addressed |
| Privacy label | Info.plist, entitlements | none added; `UserNotifications` needs no key or capability (researcher fact 14) | addressed |
| Resume and empty states | spec §3, §6 rows | mid-rest relaunch, past-end relaunch, install over m3-logging (nil fields), permission denied, no-program first run (unreachable) | addressed |
| Decision conformance | INSIGHTS 2026-09-14 / 2026-09-13 | inset swap + 0.3 s animation; handlers inside the closure; no delegate; `decide` owns schedule-vs-cancel; field-writer snapshot/restore with `allowsSave: false` tests; containers bound; "Next exercise" out of the tree; row swipeable; logging clears rest in the same save; finished logs nil | addressed |
| Commands | Step 0 shorthands, Steps 6, 10, 11 | `OS=` on every destination; `rm -rf build/tests.xcresult` before `-resultBundlePath`; Release in Steps 6 and 11; 26.5 once in Step 11 then `BOOT $UDID`; `PROTO` polls with `curl`; no `git checkout`/`stash`/`clean`; no pbxproj edit (Step 10 patches only the copy and ends with `git diff --quiet -- HomeGymLog.xcodeproj`); sequential `xcodebuild` | addressed |
| Existing tests the change breaks | grep of writer tests | writer tests assert only `!hasChanges` and return values (`WorkoutSetWriterTests.swift:41-210`), so the `at:` insertion is the only change; `DebugSeedTests.parses` would fail on the new case's default day unless added (Step 7 adds it); `SeedNameScanTests`, `SchemaSourceTests`, `WorkoutSeedTests`, `SummaryDoneHomeStatsTests`, `WorkoutCommitRollbackTests` all updated in Steps 3, 4, 7 | addressed |
| Ordering / buildability | each step's types vs earlier steps | Step 2 uses `RestNext` (Step 1); Step 6 uses `RestNotificationPlan` (1) and `RestText` (2); Step 7 uses `setRPE(at:)` (4) and `RestTimer.display` (1); Step 8 uses `RestDisplay` (1), `addRestTime` (5), the fields (3); Step 9 uses `restNotifier` (6); `WorkoutLoggingContent` has one constructor call (`WorkoutView.swift:58`), updated in Step 8 | addressed |

### Summary

- Covered: 30 of 30 acceptance criteria (AC-5–AC-17 by the spec's own rule are user/device checks, with Step 10 optionally scripting AC-5–AC-10 in the scratch copy)
- Partial: none
- Missing: none
- Ambiguous: none
- Out of scope (per plan): none ("No AC is excluded", plan line 12)
- False claims about existing code: 0
- Traceability: plan carries AC numbers
- Verdict rationale: no blocking finding; two should-fix items (Step 10 session reuse, AC-9's scriptable half) and seven nits.

### Questions only the user can answer

- None.

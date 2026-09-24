VERDICT: PASS WITH FIXES

## Plan Verifier result — docs/plans/m5-haptics.md against docs/specs/m5-haptics.md

Round 1, 2026-09-24. Read in order: `CLAUDE.md`, `insights/INSIGHTS.md` (2026-09-24 M5 haptics + slicing, 2026-09-23 reminder),
`insights/gotchas.md` (whole file), the spec, the plan, `docs/reviews/m5-haptics-architecture.md`, `docs/reviews/m5-haptics-researcher.md`;
then the code the plan touches (`WorkoutView`, `RestTimer`, `RestNotifier`, `ReminderNotifier`, `ReminderHost`, `ReminderPlan`, `AppClock`,
`HomeGymLogApp`, the four Settings files, `SettingsText`, `WorkoutLogStore` signatures, `WorkoutFlow.state`, `DebugSeed`, the recorders, the
static suites `RestNotifierSourceTests`, `SettingsScreenSourceTests`, `SeedNameScanTests`, `ReminderSourceTests`, `SettingsSourceTests`,
`ClockUsageTests`, `FailedSavePolicySourceTests`, `RestEndRuleTests`, `RestSeedFlowTests`, `ReminderRowStateTests`, `ReminderNotifierTests`,
`SettingsTextTests`, `RestExtendSkipTests`, `build/*.sh`, `project.pbxproj` by grep). `git status`: only the four m5 docs and the three
insight/CLAUDE edits are uncommitted; no Swift changed since HEAD `49faa75`, so the code claims below are read against the plan's baseline.

**S1–S7 check (brief):** the spec now carries every stated resolution — S1 `reconcile(desired, key.sound)` at spec lines 127 and 143;
S2 "the first `restFinishedCount += 1` after it" at 371–373; S3 `dividerCount` 7 → 8 and `rowAccessibilityShape` re-bounded at 375–376;
S4 AC-14 smoke test at 356–357; S5 "in the static box's method, which is declared below `live()`" at 362; S6 "re-declared from the private
members at `RestEndRuleTests.swift:7-10`" at 346; S7 `unknownValue(argument: "-haptics", value: "")` at 388. Spec and plan agree on all seven.
Remaining copies of the **old** wording: plan line 116 ("spec §4.2 writes `withSound: key.sound`; issue S1"), plan §5 "Spec issues found while
planning" (lines 338–350, still phrased as open), and `docs/reviews/m5-haptics-architecture.md:134` ("§4.2 already passes `withSound: key.sound`",
a historical review record). See finding 2.

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | Step 6 | `settings` matches with two rows Haptics / Sound, both on; two-row deviation allowed | grep `AC-1`, `design-compare`, `56 pt` in plan | plan §Steps/6 — "`/design-compare settings` against `build/proto-settings.png`: **AC-1** — rows 4–5 … both on (accent), undimmed; allowed deviations: the two-row split (card ≈ 56 pt taller …)"; `PROTO` in `build/settings-env.sh` crops `sips -c 800 290 --cropOffset 2555 4148` (gotchas 2026-09-22) | covered |
| AC-2 | Step 7 | `-haptics off`, `-sound off`, both: only that toggle flips, subtitles unchanged | grep `AC-2`, `-haptics off` | plan §Steps/7 — "`-seed midProgram -tab settings -haptics off` → Haptics off, Sound on; `… -sound off` → reverse; `… -haptics off -sound off` → both off; subtitles unchanged (**AC-2**, compared with the Step 6 shot …: only the toggle differs)" | covered |
| AC-3 | Step 7 | reminder-on/denied/unasked, freshProgram, settings-restart, kg, light regressions | grep `AC-3`, `reminder-denied` | plan §Steps/7 lists every seed named by the AC; Step 0 adds `S:reminder-on`, `S:reminder-denied`, `S:reminder-unasked` to `SHOTLIST` (absent from `build/reminder-shots.sh` today, verified) | covered |
| AC-4 | Steps 5, 7 | every workout/Home/Program/Progress/missed shot pixel-identical, with and without the flags | grep `AC-4`, `CMPALL` | plan §Steps/5 "`SHOTALL s5; CMPALL s5` → all same, in particular `wo-swipe`, `wo-rest`, `summary` (**AC-4**, first half)"; §Steps/7 "`-seed wo-swipe` and `-seed wo-rest`, each with and without `-haptics off -sound off`: `cmp` equal … (**AC-4**, second half)"; `SHOTLIST` in `build/reminder-shots.sh` holds `home`, `program`, `progress`, `missed`, all ten `wo-*`/`summary` entries | covered |
| AC-5 | — (Step 9 optional) | set-logged buzz on device | plan §1 | plan line 15–17 — "**Excluded ACs (deferred, non-gating).** AC-5–AC-10 are user-run on the iPhone 14 Pro Max … They belong to the MVP pass, are not a merge gate"; spec §8 itself says "MVP pass, not a merge gate" | out-of-scope |
| AC-6 | — (Step 9 optional) | rest-finished buzz + chime over music, silent switch, VoiceOver | plan §1 | same plan line; Step 9 covers the request-level half only if the user asks | out-of-scope |
| AC-7 | — (Step 9 optional) | Skip cue, +30s, mid-rest log, sub-second window | plan §1 | same plan line | out-of-scope |
| AC-8 | — (Step 9 optional) | summary buzz once; none on relaunch | plan §1 | same plan line | out-of-scope |
| AC-9 | — | background notification with/without sound; reminder silent | plan §1 | same plan line | out-of-scope |
| AC-10 | — (Step 9 optional) | VoiceOver reads "Haptics, Set logged, …, switch button, on" | plan §1 | same plan line | out-of-scope |
| AC-11 | Steps 1, 2 | `cue` ten rows; `restEndCue` every 5.2 row via `observeEnd`; `restSkipCue` six rows; keys; pure file; `RestReconcileKey` | grep `AC-11`, `at(62.003)`, `hapticsEnabled` | plan §Steps/1 — `FeedbackCuesTests` "the ten rows of 5.1 as a typed file-scope argument table"; `FeedbackRestCueTests` "re-declares the `wo-rest` instants exactly as `RestEndRuleTests.swift:7-10` … the observation comes from `RestTimer.observeEnd` … the row's `announce` is also asserted"; 5.3 "with `now` = `at(30)`, `at(62.003)`, `at(70)`, and `restEndsAt` = `e` or nil"; `FeedbackSourceTests` "exactly one `import` line … no `: Error`, `Error {` or `throws`"; "`RestReconcileKey`: equal for equal fields; unequal on `withSound` alone" — matches spec 5.2/5.3 tables and `RestEndRuleTests.swift:8-9` (`t`, `e` are `private`) | covered |
| AC-12 | Steps 2, 3 | `content(withSound:)` four rows: title, body, `sound == .default` / `sound == nil` | grep `AC-12`, `content(withSound` | plan §Steps/2 "`content(withSound: true)` → title "Rest over", body "Time for your next set.", **`sound != nil`**; `false` → … `sound == nil`"; §Steps/3 same for "Training day" / "Your workout is planned for today."; plan §5 risk row: "`UNNotificationSound` equality (`== .default`) unverified — Tests assert `!= nil`". Spec AC-12 and 5.5 say `sound == .default` | partial |
| AC-13 | Steps 2, 3 | notifier over recorders records `withSound` per add; cancel rows; 30 reminder adds; `.silent` records nothing; key inequality | grep `AC-13`, `addedWithSound` | plan §Steps/2 "`reconcile(restEndsAt: at(62), …, withSound: true)` → one add, `addedWithSound == [true]`; `false` → `[false]`; restEndsAt nil, `at(0)`, `at(-60)` with either value → no add and one pending removal"; §Steps/3 "m4-reminder 5.2 row 1 … with `false` → 30 adds, `addedWithSound == Array(repeating: false, count: 30)`, `rest-timer` never removed; … `.silent(status: .authorized)` records nothing"; `ReminderRowStateTests` append "two keys equal in every m4 field but `sound` are unequal; nil status → nil key". Row 1 fixture exists: `ReminderNotifierTests.swift:19-21, 40-43` | covered |
| AC-14 | Step 4 | `.silent().play()` and repeated `.live()` never touch the audio session (smoke) | grep `AC-14`, `RestChimeTests` | plan §Steps/4 "`RestChimeTests` (`@MainActor`): … `.silent().play()` and three `.live()` constructions return without trapping (smoke only, issue S4)"; spec AC-14 now says "a smoke test only … The real guard is AC-16's static scan" | covered |
| AC-15 | Step 6 | `SettingsText` four literals; `fixedStrings` drops `comingSoon` | grep `AC-15`, `hapticsSubtitle` | plan §Steps/6 "`SettingsTextTests` (edit `fixedStrings`): the four literals of spec 4.3; the `comingSoon` line removed"; today `SettingsTextTests.swift:52-53` asserts `"Sound & haptics"` and `comingSoon` | covered |
| AC-16 | Steps 4, 8 | `.caf` in bundle, < 1 s mono; `AVFAudio` only in `RestChime.swift`; one static box; `setCategory(` once below `live()`; failure leaves player nil | grep `AC-16`, `setCategory(`, `CpResource` | plan §Steps/4 asset test "`Bundle.main.url(forResource: "rest-over", withExtension: "caf")` non-nil … `channelCount == 1`, duration … in 0.19…0.21 and < 1"; scan "exactly one line with `private static` and `PlayerBox(`; exactly one `setCategory(` line, containing `.ambient`, with a larger line index than the first `play:` line; between that line and the first `AVAudioPlayer(` line there is a `catch` or a `guard (try?` line, and no `try? AVAudioSession` line"; §Steps/8 `RELEASE` then `ls …/Release-iphonesimulator/HomeGymLog.app/rest-over.caf`; `TEST_HOST` is at `project.pbxproj:427` (verified) | covered |
| AC-17 | Steps 1, 4, 5, 6, 7, 8 | the static-scan list (keys once, `@AppStorage` readers, three `.sensoryFeedback(` lines in `WorkoutFeedback.swift`, B1 line order, two `.silent()` lines, `dividerCount` 8, `SeedNameScanTests`, `ClockUsageTests`/`FailedSavePolicySourceTests` green) | grep `AC-17`, each token | Each spec bullet has a planned assertion: Step 1 (`import`, `Error`, `RestReconcileKey` location), Step 4 (`AVFAudio` confinement, `.live()` once, `.silent()` twice in `HomeGymLogApp.swift`), Step 5 (three `.sensoryFeedback(` lines with `trigger:`, forbidden tokens, `restSkipCue(` < `WorkoutLogStore.skipRest(` < first `restFinishedCount += 1` after it, `chime.play()` twice), Step 6 (`comingSoon` nowhere, key literals once, `@AppStorage(FeedbackCues.*Key)` reader sets, `preferencesRowOrder`, `feedbackToggleRows`, `rowAccessibilityShape` re-bound, `dividerCount` 8, `ReminderHost` `key.sound`), Step 7 (`catch let error as DebugFeedbackError`, `SeedNameScanTests` names, suite writes), Step 8 full `TEST`. Baseline counts verified: `.sensoryFeedback(` 0; `.silent()` 1 (`HomeGymLogApp.swift:71`); `content.sound` at `RestNotifier.swift:26`, `ReminderNotifier.swift:38`, both `.default`; `@AppStorage(` in `WorkoutView.swift` only line 47 `"units"` | covered |
| AC-18 | Step 7 | parser six rows, labelled `unknownValue(argument:value:)` | grep `AC-18`, `"maybe"` | plan §Steps/7 "`DebugFeedbackPreferencesTests` (`#if DEBUG`): the six AC-18 rows, errors compared as `.unknownValue(argument: "-haptics", value: "")` and `(argument: "-sound", value: "maybe")`; plus `["-haptics", "OFF"]` throws" | covered |
| AC-19 | Step 8 | Release compiles with `rest-over.caf` in its bundle; suites green on 17.5 and 26.5 | grep `AC-19`, `TEST26` | plan §Steps/8 "`RELEASE`, then `ls build/DerivedData/Build/Products/Release-iphonesimulator/HomeGymLog.app/rest-over.caf` (exists; else NB5 …), then `TEST26` … `git status` shows no change to `project.pbxproj`" | covered |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| `WorkoutView` has `logSet`, `saveAndLog`, `skipRest`, `observeRestEnd`, a scene-phase handler, `.task(id: state == .summary && !isDiscarding)`, a rest reconcile `.task(id: isDiscarding ? nil : log.restEndsAt)`, `discard` sets `isDiscarding` first, `@AppStorage("units")` only | read | `WorkoutView.swift:275, 255, 312, 139, 122, 108, 117-119, 343` (`isDiscarding = true` then `try WorkoutLogStore.discard`), `:47` | true |
| `WorkoutView`'s outer view is a `Group` with `.onDisappear` last; `#Preview` sets `.environment(\.restNotifier, .silent())` | read | `:67` `Group {`, `:132` `.onDisappear { notifier.cancel() }`, `:361` | true |
| `WorkoutLogStore.logSet` / `saveAndLogSet` / `skipRest` are `@discardableResult … throws -> Bool` | grep | `WorkoutLogStore.swift:200-201, 215-216, 183-184` | true |
| `skipRest` returns true for a stale rest (`RestExtendSkipTests:82-104`) | read | `RestExtendSkipTests.swift:89-99` `skipStale` … `#expect(wrote)`; `:101-106` no-rest → `!wrote` | true |
| `WorkoutFlow.state` maps an empty exercise list to `.summary` | read | `WorkoutFlow.swift:102-115` — `all.isEmpty` gives nil for both indexes, then `return .summary` | true |
| `RestTimer.observeEnd(lastSeenEndsAt:restEndsAt:resting:now:) -> RestEndObservation`; `RestNotificationPlan.decide(restEndsAt:now:)` in `Engine/RestTimer.swift` | read | `RestTimer.swift:58, 75`; `RestEndObservation` at `:21` | true |
| `RestNotificationCenter.add: (_ identifier, _ endsAt, _ interval) async -> Void`; `system().add` builds `content.sound = .default`; `RestNotifier.schedule: (_ endsAt, _ clock) async`; `reconcile(restEndsAt:clock:)` | read | `RestNotifier.swift:11, 22-30, 45, 92` | true |
| `ReminderNotificationCenter.add: (_ request: ReminderRequest) async -> Void` with `content.sound = .default`; `ReminderNotifier.reconcile: (_ desired: [ReminderRequest]) async -> Void`; `.silent(status:)` has `reconcile: { _ in }`; `using` loops `center.add(request)` | read | `ReminderNotifier.swift:15, 34-42, 72, 80, 103-106` | true |
| `ReminderPlan.ReconcileKey` (`enabled, minutes, status, activeTick, pendingDays, workoutInProgress`) and `reconcileKey(enabled:minutes:status:activeTick:pendingDays:workoutInProgress:)` in an `extension` with `nonisolated` members | read | `ReminderPlan.swift:89-96, 110-115`; `enabledKey`/`minutesKey` at `:36-37` | true |
| `ReminderHost` has two `@AppStorage`s, builds the key in `body`, `reconcile(_:)` ends `await notifier.reconcile(desired)` | read | `ReminderHost.swift:22-23, 37-40, 57-63` | true |
| `AppClock.swift` declares `@Entry var restNotifier: RestNotifier = .live()` and `reminderNotifier` | read | `AppClock.swift:25, 28` | true |
| `HomeGymLogApp.init`: seed branch writes `reminderPreferences` into `UserDefaults(suiteName: "seed")`, sets `restNotifier = .silent()` / `reminderNotifier = .silent(status:)`, one `} catch {` with "Unknown -seed argument … `DebugSeed.allCases`", `.transformEnvironment(\.restNotifier)` | read | `HomeGymLogApp.swift:56-73, 79-80, 121-123` | true |
| `SettingsView` owns five `@AppStorage`s; `SettingsContent` has `@Binding reminderEnabled`, `preferencesCard` ends `SettingsDivider(); SettingsComingSoonRow(label: SettingsText.haptics)`; seven `SettingsDivider()` lines | read | `SettingsView.swift:13-17`; `SettingsContent.swift:14, 53-54`; dividers at `:45, 50, 53, 62, 66, 83, 85` = 7 | true |
| `SettingsRows.swift` declares `SettingsValueRow`, `SettingsControlRow`, `SettingsComingSoonRow` (in that order), `SettingsComingSoonRow` uses `Toggle(isOn: .constant(false))`, `.disabled(true)`, `SettingsText.comingSoon` | read | `SettingsRows.swift:5, 28, 46-62` | true |
| `ReminderRows.swift:18-26` is the `Toggle` with a two-line `VStack` label and `.tint(Theme.accent)` | read | `ReminderRows.swift:18-26` | true |
| `SettingsText.haptics = "Sound & haptics"`, `comingSoon = "Coming soon"` | read | `SettingsText.swift:11-12` | true |
| `SettingsScreenSourceTests`: `preferencesRowOrder` tokens `["SettingsText.appearance", "SettingsText.units", "ReminderRows(", "SettingsText.haptics"]`; `dividerCount == 7`; `comingSoonRowsAreInert`; `rowAccessibilityShape` bounded by `struct SettingsComingSoonRow`; `filesScanned` expects exactly five Settings files | read | `SettingsScreenSourceTests.swift:57, 109, 121-133, 140-149, 50-51` | true |
| `RestNotifierSourceTests.silentOnlyInSeedBranch` expects `.silent()` count == 1 in `HomeGymLogApp.swift`; `liveOnlyAsEntryDefault` matches lines containing `RestNotifier`/`restNotifier` | read | `RestNotifierSourceTests.swift:27-28, 44` | true |
| `SeedNameScanTests.names` is the quoted list; each name must exist under `App/DebugSeed/` | read | `SeedNameScanTests.swift:8-13, 39-46` | true |
| `RestNotifierRecorder.recordAdd(endsAt:interval:)`, `added`, `Event.add(endsAt:)`; `recording(into:)` `add: { _, endsAt, interval in … }` | read | `RestNotifierRecorder.swift:56-60, 23, 14, 80` | true |
| `ReminderNotifierRecorder.add(_:)` appends `added`; `recording(into:)` `add: { recorder.add($0) }` | read | `ReminderNotifierRecorder.swift:89-93, 105` | true |
| `RestEndRuleTests.swift:7-10` declares private `t` (`TestCalendar.day(2026, 9, 15) + 12 h`) and `e` (`t + 62`) | read | `RestEndRuleTests.swift:8-9` (`private let t`, `private var e`) | true |
| Existing call sites to update: `App/RestNotifierTests.swift`, `App/RestNotifierEdgeTests.swift`, `Seed/RestSeedFlowTests.swift:44` (rest); `App/ReminderNotifierTests.swift`, `App/ReminderReconcileEdgeTests.swift`, `Engine/ReminderRowStateTests.swift` (reminder) | grep `.reconcile(`, `.schedule(`, `reconcileKey(` across tests | exactly those files (plus `RestTimerEdgeTests`/`RestEndRuleTests`, which only compare `RestNotificationPlan.schedule`, unaffected); `ReminderPermissionTests` uses `recording(into:)` but never `reconcile` | true |
| `ReminderNotifierTests` row 1 uses `ReminderFixtures.weekdayIDs`, pending `rest-timer` + A′, desired A | read | `ReminderNotifierTests.swift:19-21, 40-43` | true |
| `RestText.restOver` / `notificationBody`; `ReminderText.notificationTitle` / `notificationBody` | grep | `RestText.swift:12-13`, `ReminderText.swift:13-14` | true |
| `TEST_HOST` at `project.pbxproj:427`; two `PBXFileSystemSynchronizedRootGroup`s, no `exceptions` | grep | `:427` (and `:454` for the second configuration); `:26, :31`; no `exceptions` hit | true |
| `build/reminder-env.sh` sources `settings-env.sh` and `reminder-shots.sh`, supplying the named functions | read | `reminder-env.sh` (3 lines), `settings-env.sh` defines `DEST … PROTO`, `reminder-shots.sh` defines `SHOTLIST SHOTALL CMPALL`; `build/` is in `.gitignore` | true |
| `DebugSeed.parse(arguments:) throws -> DebugSeed?`, `DebugSeedError.unknownSeed(String)`, `reminderPreferences` | read | `DebugSeed.swift:5-6, 75-80, 197-204` | true |
| INSIGHTS patterns "Deadline-driven UI", "A preference that writes by itself", "DEBUG launch arguments … `@Entry`", "Real-touch probes", "Verify UI on the simulator by screenshot" | grep | `INSIGHTS.md:865, 790, 929, 922, 963` | true |
| gotchas cited: SwiftUI 2026-09-24 (two entries), 2026-09-22 `.task` capture and `-tab`, Audio 2026-09-24, Xcode 2026-09-24/23/22 | read | `gotchas.md:207-214, 178-180, 216-221, 396-398, 402-419` | true |
| Baseline HEAD `49faa75`, 1011 tests | `git log`, `CLAUDE.md` | HEAD is `49faa75`; `CLAUDE.md` M4 reminder line records "1011 tests on iOS 17.5 and 26.5"; no Swift file modified in the working tree | true (not re-run; Step 0 re-counts) |

### Findings

1. **should-fix** — AC-12 is planned weaker than the spec. Evidence: spec AC-12 "the four rows of 5.5 (title, body, `sound == .default` /
   `sound == nil`)"; plan §Steps/2 and §Steps/3 assert "`sound != nil`" for the `true` row, and §5 risk table "Tests assert `!= nil` /
   `== nil`; a stricter `== .default` may be tried and dropped if it fails". A `content.sound = UNNotificationSound(named:)` would pass the
   planned test. Fix: assert `content.sound == UNNotificationSound.default` in both content tests (an `NSObject` class property; `==`
   falls back to `isEqual`), and only if that fails on 17.5 or 26.5 record the reason in the test and fall back to `!= nil` plus a
   `String(describing:)` containing "default". *React:* asserting `toBeTruthy()` where the spec says `toBe(DEFAULT)`.
2. **note** — Stale S1 wording survives in the plan and in the review. Evidence: plan line 116 "(spec §4.2 writes `withSound: key.sound`;
   issue S1)" — the spec now reads `reconcile(desired, key.sound)` at lines 127 and 143; plan §5 lines 338–350 still present S1–S7 as
   "for the main session to fix"; `docs/reviews/m5-haptics-architecture.md:134` "§4.2 already passes `withSound: key.sound`" (a historical
   record). Fix: delete the parenthetical on plan line 116 and retitle §5's list "resolved in the spec 2026-09-24" (leave the review as is,
   or add one line noting the spec's later wording).
3. **note** — Spec AC-17 baseline "`catch` in `HomeGymLogApp.swift` 1" counts 2 by substring: `} catch {` at `:79` and `Result(catching:
   makeContainer)` at `:83`. No planned scan counts `catch` (Step 7 anchors on the `catch let error as DebugFeedbackError` line and the
   "Unknown -seed argument" line), so nothing fails; the spec could say "`} catch {` 1".
4. **note** — `docs/layout.md:247` still describes "the one remaining reserved row (Sound & haptics) stays off and disabled" under
   `SettingsScreenSourceTests`. The plan's doc-writer list names `docs/layout.md` for the new files only. Fix: add that sentence to the
   doc-writer list.
5. **note** — Step 9 is optional work no AC requires as a merge gate (a scratch-copy XCUITest for the request-level half of AC-5–AC-8,
   AC-10). It touches no repo file, follows INSIGHTS "Real-touch probes without touching the repo" (2026-09-13), and is gated on the user
   asking; recorded here as scope, not as a defect.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | plan §Steps/5 for the writer calls | The three writers stay `try WorkoutLogStore.logSet/saveAndLogSet/skipRest` with only `let wrote =` added; counters are view `@State`; no new SwiftData write; §4 "No `@Model` … change" | addressed |
| Delete rules | plan §4 | "No `@Model`, relationship, delete rule, `#Predicate` or migration change" | n/a, stated |
| Units | plan §3–§4 | No weight value is introduced | n/a |
| Date determinism | plan §Steps/1, §Steps/4; `ClockUsageTests` | `FeedbackCues.restSkipCue(restEndsAt:now:…)` takes `now`; `RestChime` reads no clock; Step 5 passes `clock.now()` from the handler; Step 5 verify runs `ClockUsageTests` (`Date()`/`Calendar.current` only in `App/AppClock.swift`) | addressed |
| Concurrency | plan §Steps/4, §Steps/5 | Player in "a main-actor `private static` box" (spec 4.3, plan Step 4); `.sensoryFeedback` closures run on main (researcher Q1 table); no timer added; `.task(id: restKey)` reads `notifier`/`clock` before any await (gotchas 2026-09-22) | addressed |
| Availability | researcher Q1 availability table, plan §Steps/5 | `.sensoryFeedback(trigger:_:)` iOS 17.0; two-parameter `.onChange` iOS 17; `AVAudioSession.setCategory(.ambient)`, `AVAudioPlayer`, `AVAudioFile` predate iOS 17; no `#available` needed; `SensoryFeedback.pathComplete` (17.5) not used | addressed |
| Privacy label | plan §1, researcher "Entitlement and tier" | "No new dependency, entitlement, capability, Info.plist key, background mode, project edit or schema change"; playback needs no usage string (only recording does); no network, analytics, crash reporting | addressed |
| Resume and empty states | spec 5.4/NB8, plan §Steps/5 and §5 risk table | Counters start at 0 on relaunch; `.onChange(of: isSummary)` without `initial:` so a relaunch onto the summary (flag true at mount) cues nothing; empty first query frame is a `true → false` edge; `restKey` is nil while discarding; first run has both preferences default true | addressed |
| Failed save (project rule 2026-09-13) | plan §Steps/5 | Cue decided before `skipRest`, applied only `if wrote, let cue`; set haptics bump only after a `try` that returned true; `FailedSavePolicySourceTests` (`rollback()` only in `StoreCommit`) untouched | addressed |

### Scope creep

- Step 9 (optional scratch-copy XCUITest) — see finding 5; no repo file, no dependency, model or capability.
- `RestChimeTests` "a counting `RestChime(play:)` counts 2 after two calls" and `["-haptics", "OFF"]` throws — one-line additions to
  suites the spec already asks for; not worth a finding.

### Summary

- Covered: 13 of 19 acceptance criteria (AC-1, 2, 3, 4, 11, 13, 14, 15, 16, 17, 18, 19 … and AC-12 partial)
- Partial: AC-12
- Missing: none
- Ambiguous: none
- Out of scope (per plan): AC-5, AC-6, AC-7, AC-8, AC-9, AC-10 (plan lines 15–17; the spec's own §8 marks them "MVP pass, not a merge gate")
- False claims about existing code: 0
- Traceability: plan carries AC numbers (each step names its ACs; §3 "Traceability" table covers all nineteen)

### Questions only the user can answer

- None. The spec §9 "left undecided" defaults (`.impact` at the system weight, no reminder-row hint, the sub-second Skip window cues
  nothing, `prepare` only on a heard lag) are taken as written by the plan; no new decision surfaced.

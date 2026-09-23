VERDICT: PASS WITH FIXES

## Plan Verifier result — docs/plans/m4-reminder.md against docs/specs/m4-reminder.md (round 1, 2026-09-23)

Read first: `CLAUDE.md`, `insights/INSIGHTS.md` (2026-09-23 decisions, 2026-09-22 Settings, 2026-09-14 rest-timer, patterns
"Derived notification schedule" and "A preference that writes by itself"), `insights/gotchas.md` (all), the spec, the plan,
`docs/reviews/m4-reminder-architecture.md`, `docs/reviews/m4-reminder-researcher.md`. Then every file the plan names as
existing (table below). No test run was made: the plan's only "today" claim is the 917 baseline, which Step 0 re-counts.

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | Step 9 | `reminder-on -tab settings` matches `settings`; toggle on, "7:00 AM on training days" | grep `AC-1`, `reminder-on` | plan 291–293: `/design-compare settings` on `reminder-on`, the "Reminder time · 7:00 AM" row the one new deviation | covered |
| AC-2 | Step 8 | `midProgram -tab settings` reads "Off", toggle off, no second row | grep `AC-2` | plan 268–271: `SEEDCLR`, launch `midProgram -tab settings`, `/design-compare settings`, "Off", toggle off and undimmed | covered |
| AC-3 | Step 9 | denied and unasked seeds show their subtitle and action row | grep `AC-3` | plan 293: "spot-check `reminder-denied` and `reminder-unasked`" | covered |
| AC-4 | Steps 7, 8, 10 | every other seeded screen byte-identical to its Step 0 base | grep `AC-4`, `cmp` | plan 47–51 shoots every base; 234–236, 271, 307–308 re-shoot and `cmp` | covered |
| AC-5 | Step 11 (optional) | fresh-install toggle → prompt → `min(30, …)` pending ids; Don't Allow → denied row | grep `AC-5` | plan 16–17: "AC-5–AC-8 need taps and a live clock … They go to the optional Step 11, run in a scratch copy, or else to the MVP pass"; spec AC header 276 permits this | out-of-scope |
| AC-6 | Step 11 (optional) | picker 18:30 → "6:30 PM …"; today's id at 18:30 | grep `AC-6` | same plan line 16–17; Step 11 at 322–324 | out-of-scope |
| AC-7 | Step 11 (optional) | Open iOS Settings lands on the notifications page; allow + return → on row | grep `AC-7` | same; Step 11 at 324–325 (17.5 and 26.5) | out-of-scope |
| AC-8 | Step 6 (code), Step 11 | foreground banner for `reminder-*`, none for `rest-timer`; synthetic `rest-timer` survives a reconcile | grep `AC-8`, `synthetic` | plan 190–191 unit-tests `options(forIdentifier:)` for `reminder-2026-09-16` and `rest-timer`; the banner and the synthetic `rest-timer` (F7) only in optional Step 11 at 326–330 | partial |
| AC-9 | Step 8, Step 11 | VoiceOver reads the four folded switch labels, the picker value, two buttons | grep `AC-9` | plan 272 "AC-9 (structure)" via the `ReminderRows.swift` scan (263–267); spoken labels only in Step 11 at 330–332 or the MVP pass | partial |
| AC-10 | Steps 1, 2 | `desired` rows A–K, edge rules, constants, `validMinutes`, `canSchedule` | grep `AC-10` | plan 75–84: rows A, A′, B, C, D, E, E′, F, G, H, I, J, K with typed first/last/count literals and an independent `weekdayIDs` oracle; B from `MissedDayFixtures.map`; edge suite 81–84 | covered |
| AC-11 | Steps 4, 5 | reconcile over a recorder: four 5.2 rows, event order, cancel adds nothing, `.silent` | grep `AC-11` | plan 150–155 (rows, order, delivered removal, hold-cancel-release, no `.requestAuthorization`, `.silent(status: .denied)`); 175–179 the F1 race | covered |
| AC-12 | Step 3 | subtitle 420/1110/0/720 en_US, en_GB contains "07:00", U+202F and U+00A0 normalised | grep `AC-12`, `00A0`, `07:00` | plan 115–119 normalises only `\u{202F}`; en_GB asserted as `contains " on training days"` and no "AM", never `"07:00"` (spec 311, 219) | partial |
| AC-13 | Step 9 | three seeds = `midProgram` rows, (true, 420), statuses; `reminder-on` → row A ids | grep `AC-13` | plan 284–288: 120 sessions, 10 completed, pair and status per seed, `pendingDays` → `desired` == `weekdayIDs` 09-16…10-27 | covered |
| AC-14 | Steps 4, 6, 8, 9, 10 | the static scans listed in spec AC-14 | grep `AC-14`, each token | every token found: `.silent(status:` once (297–298), key literals (298–299), `@AppStorage` readers (299–300), `notificationSettings(` (300), `UNUserNotificationCenter` (192–193), `UIApplication.` (305), imports/no `Error` (301), `SeedNameScanTests` (288–289), `ClockUsageTests` (306), F1 race (175–179). Not asserted: the toggle row before the "Reminder time / action row" inside `ReminderRows.swift` (263–267 checks presence only; spec 328 lists the order) | partial |
| AC-15 | Step 10 | Release build compiles; suites green on 17.5 and 26.5 | grep `AC-15`, `RELEASE`, `TEST26` | plan 307: `BUILD && TEST; COUNT`, then `RELEASE`, then `TEST26` | covered |
| AC-16 | — | device: notification arrives, tap opens the app | plan §1 | plan 14–15: "AC-16–AC-19 are device checks. They belong to the user's MVP pass … not a merge gate" | out-of-scope |
| AC-17 | — | device: no notification after an early finish; skip/shift days | plan §1 | same line | out-of-scope |
| AC-18 | — | device: denied → iOS Settings → allowed → on row | plan §1 | same line | out-of-scope |
| AC-19 | — | device: in-app banner; none for "Rest over" | plan §1 | same line | out-of-scope |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| `UserNotifications` already linked, `App/RestNotifier.swift:2` | read | `HomeGymLog/App/RestNotifier.swift:2` — `import UserNotifications` | true |
| `build/settings-env.sh` supplies `DEST DEST26 UDID UDID26 APP BUILD TEST ONLY COUNT RELEASE TEST26 BOOT LAUNCH SHOT APPEAR PROTO` | cat | all 16 defined; `DEST='platform=iOS Simulator,name=iPhone 15,OS=17.5'`, `DEST26='…iPhone 17,OS=26.5'`; `PROTO` crops `sips -c 800 290 --cropOffset 2555 4148`; `build/` is gitignored (`.gitignore:2`) | true |
| Baseline HEAD `02e3ff1`, 917 tests | `git log -1`; CLAUDE.md | HEAD is `02e3ff1 Merge pull request #6 from ZhabskyiO/m4-settings`; CLAUDE.md M4 settings line and INSIGHTS 2026-09-22 record 917 at that merge. Not re-run here; Step 0 counts it | true (corroborated) |
| `HomeGymLogApp.swift:59` has the rest `.silent()`; `:107` the `transformEnvironment(\.restNotifier)` shape | read | `:59` `restNotifier = .silent()`; `:107` `.transformEnvironment(\.restNotifier) { value in` | true |
| `DebugSeed.parse(`, `referenceDate` explicit 09-15 arm, `initialDraft`, `makeContainer`, `forcesMissedDayPrompt` via `default:` | read | `DebugSeed.swift:60` parse; `:71–74` the 09-15 arms, `:78` `default:` Aug 31; `:88–101` `initialDraft` (exhaustive switch, no default — new cases must be added, as the plan says); `:104–131` `makeContainer` with `default: break`; `:183–188` `forcesMissedDayPrompt` `default: false` | true |
| `MissedDayFixtures.slots`, `.map(first:range:offset:)`, `.midProgramCompleted`, `.originalDate`, `.restDayCompleted` | read | `Support/MissedDayFixtures.swift:9, 11, 19, 24, 32` | true |
| `ProgressMonthTests:15` uses `MissedDayFixtures.map(first: (7, TestCalendar.day(2026, 9, 15)), range: 11...119, offset: 1)` | read | `Engine/ProgressMonthTests.swift:15` verbatim | true |
| `TestCalendar.calendar` (America/New_York), `TestCalendar.day(_:_:_:)` | read | `Support/TestCalendar.swift:7–17` | true |
| `RestNotifierRecorder` shape (events, hold/release, `waitingCount`, `recording(into:)`) | read | `Support/RestNotifierRecorder.swift:9–83` | true |
| `RestNotifierSourceTests` matches `.silent()` and `"RestNotifier"`/`"restNotifier"`, `files.count > 40` | read | `Static/RestNotifierSourceTests.swift:27, 40, 44` — `.silent(status:` and `reminderNotifier` do not match either filter | true |
| `SettingsSourceTests:58` pins `import UIKit` to `App/RootView.swift`; test `appearanceMechanism` | read | `Static/SettingsSourceTests.swift:53–60`, line 58 `#expect(Self.hits("import UIKit", in: all).map(\.path) == ["App/RootView.swift"])` | true |
| `SettingsScreenSourceTests`: `filesScanned` four files, `preferencesRowOrder` over `SettingsText.` members of `SettingsContent`, `comingSoonRowsAreInert`, 7 dividers, 3 `applyAppearance(` | read | `Static/SettingsScreenSourceTests.swift:47–51, 53–58, 81–86, 96–105, 160–170` — `preferencesRowOrder` will go red once `SettingsText.reminder` leaves `SettingsContent`, as the plan states (384–385) | true |
| `SettingsRows.swift:46` `SettingsComingSoonRow`; `SettingsContent.swift:58–67` restart button style | read | `SettingsRows.swift:46` `struct SettingsComingSoonRow: View`; `SettingsContent.swift:58–67` `Button(action: onRestart) { Text(SettingsText.restart).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)…` | true |
| `SettingsContent` currently has `SettingsComingSoonRow(label: SettingsText.reminder)` and 7 `SettingsDivider()` | read | `SettingsContent.swift:43` and 7 divider lines (37, 42, 44, 53, 57, 74, 76) | true |
| `SettingsView` owns `appearance` / `units` / `policy` bindings, `clock`, `modelContext`; `#Preview` exists | read | `SettingsView.swift:49–59, 16–17, 79–87` | true |
| `SettingsText.reminder`, `.haptics`, `.comingSoon`, `.appearance`, `.units` | read | `Shared/SettingsText.swift:8–12` | true |
| `HomeSnapshotBuilder.sessionPredicate(programID: UUID)`; `MissedPromptHost.swift:37` uses it in `init` | read | `Models/HomeSnapshotBuilder.swift:10–12`; `MissedPromptHost.swift:37` `_sessions = Query(filter: HomeSnapshotBuilder.sessionPredicate(programID: program.id), sort: \PlannedSession.index)` | true |
| `RootView`: a `Group` with three branches, `currentPrograms`, `activeLogs`, 3 `applyAppearance(` lines | read | `RootView.swift:35–47, 12, 14, 55, 59, 82` | true |
| `WorkoutView.swift:361` preview sets `.environment(\.restNotifier, .silent())`; `ShellView` `#Preview` at `:49` | read | `WorkoutView.swift:361`; `ShellView.swift:49–54` (no notifier or permission yet) | true |
| `DebugSeedTests` 09-15 arm and `initialDraft == nil` loop | read | `Seed/DebugSeedTests.swift:16–21, 79–82` — `default:` expects Aug 31, so the three seeds must be added | true |
| `ProgramStore.archive`, `ProgramStore.current`; `MidProgramSeed.populate`, `completedIndexes` | grep | `ProgramStore.swift:117, 10`; `MidProgramSeed.swift:19, 8` | true |
| `PlannedSession.status`, `.scheduledDate`, `.index`, `isMissed` | grep | `PlannedSession.swift:48, 16, 9, 54` | true |
| `Theme.accent`, `SettingsControlRow`, `SettingsDivider` | grep | `Theme.swift:12`; `SettingsRows.swift:28`; `SettingsContent.swift:106` | true |
| `nonisolated enum` / `nonisolated struct … Equatable, Sendable` is the Engine idiom | grep | `Engine/ProgramTabStats.swift:5, 12, 19, 26, 53` | true |
| Suites named in Verify lines exist (`RestNotifierTests`, `SettingsTextTests`, `ClockUsageTests`, `HomeSnapshotBuilderTests`, `RoutingPredicateTests`, `MidProgramSeedTests`, `SeedNameScanTests`, `FailedSavePolicySourceTests`) | ls | all present under `HomeGymLogTests/{App,Shared,Static,Persistence,Seed}` | true |
| Other scans of `HomeGymLogApp.swift` / `AppClock.swift` survive the edits | read | `ProgressSourceTests:64–97`, `MissedPromptSourceTests:24–58`, `SeedNameScanTests:49–92` count only their own tokens; a new stored `let`, a first `init` statement and a new `@Entry` line change none of them | true |

False claims: 0.

### Findings

1. **should-fix** — Step 2 names the row state `notDetermined`; the aligned spec names it `unasked`. Evidence: plan 90
   `nonisolated enum ReminderRowState: Equatable, Sendable { case off, scheduled, denied, notDetermined }`, 102, 246; spec
   §4.3 line 128 "`ReminderRowState` (Engine) | `off`, `scheduled`, `denied`, `unasked`" and 142–144. Fix: rename the case
   to `unasked` in Steps 2, 3 (`rowSubtitle`) and 8 (the `switch state`). (≈ a TypeScript union member spelled differently
   from the type the consumer imports.)
2. **should-fix** — Step 3's test normalises only U+202F; the spec asks for U+202F and U+00A0. Evidence: plan 116–117
   "compared after `.replacingOccurrences(of: "\u{202F}", with: " ")`"; spec §5.3 line 219 "normalises U+202F and U+00A0 to a
   plain space before comparing (F6)". Fix: normalise both before every en_US comparison (and in Step 11's label check, 320).
3. **should-fix** — Step 3's en_GB assertion does not check the spec's "07:00". Evidence: plan 117–118 "en_GB 420
   contains \" on training days\" and no \"AM\""; spec AC-12 line 311 "en_GB 420 contains \"07:00\" and \"on training days\"".
   Fix: assert `contains("07:00")` and `contains("on training days")` (drop or keep the "no AM" check).
4. **should-fix** — Step 4 states only `.ephemeral → .authorized` for `authorization(_:)`; the spec also fixes `@unknown default → .denied`
   at the seam. Evidence: plan 130 `static func authorization(_ status: UNAuthorizationStatus) -> ReminderAuthorization   // .ephemeral → .authorized`;
   spec §4.1 line 96 "`.ephemeral` maps to `.authorized`, `@unknown default` to `.denied`, at the seam, F4". The plan mentions it
   only in §5 F4 (376–377). Fix: add `@unknown default: .denied` to Step 4's signature comment; the test at 155 ("maps all
   five cases") cannot reach it, so a one-line `ReminderSourceTests` check for `@unknown default` in `ReminderNotifier.swift`
   would pin it.
5. **should-fix** — The plan still presents F1–F7 as open spec contradictions and carries an "Open question" the spec has
   answered. Evidence: plan 35–36 "**Open question.** What shows for `enabled && status == nil` … Default: `.scheduled`" while
   spec §2.1 row 2 (line 39) and §4.3 line 128 already say nil → `scheduled`; plan 368–383 quotes pre-alignment wording
   (F2 "`.silent(` on exactly one line", F4 "`ReminderRows(minutes:status:)`") that the spec no longer contains (spec 320–321,
   141–142). Fix: delete the open question; retitle §5's list "Spec gaps F1–F7, resolved in the spec on 2026-09-23" so the
   implementer does not reopen them.
6. **should-fix** — AC-14's row order inside `ReminderRows.swift` is not asserted. Evidence: plan 263–267 checks that the
   file *contains* `SettingsText.reminder`, `ReminderText.timeLabel`, `ReminderText.openSettings`, `ReminderText.allow`;
   spec AC-14 line 328 wants the order "Appearance, Units, Daily reminder, Reminder time / action row, Sound & haptics". Fix:
   in `SettingsScreenSourceTests`, require the line index of `SettingsText.reminder` to precede those of `ReminderText.timeLabel`,
   `ReminderText.openSettings` and `ReminderText.allow` (the same ascending-index check Step 8 already uses for `SettingsContent`).
7. **note** — Step 1's equality on `DateComponents` may fail for a reason unrelated to the plan: on Apple platforms
   `calendar.dateComponents([.year, .month, .day], from:)` (the researcher's sketch, line 193) can return `isLeapMonth == false`,
   while the literal `DateComponents(year: 2026, month: 9, day: 16, hour: 7, minute: 0)` (plan 80) has `isLeapMonth == nil`, and
   `==` compares that field. Unverified here. Safer: build the components field by field in `ReminderPlan` (`var c = DateComponents();
   c.year = …`) or compare `.year/.month/.day/.hour/.minute/.timeZone` individually in the test.
8. **note** — `ReminderRequest` carries `day`, `hour` and `minute` beyond the spec's shape. Evidence: plan 58–59 vs spec
   §4.3 line 129 "`identifier: String` …, `dateComponents: DateComponents`". Harmless (Sendable, Equatable), but the seam and
   the delegate need only `identifier` and `dateComponents`; drop the extras or record why they stay.
9. **note** — `ReminderPlan.time(minutes:on:calendar:)`, `ReminderPlan.minutes(of:calendar:)` (plan 97–98) and
   `ReminderText.rowSubtitle(state:minutes:calendar:locale:)` (113–114) are not in spec §4.3, which places the
   `Binding<Date>` ↔ minutes conversion in `SettingsView` (line 145–146). Pure, tested, and they keep the screen small; fine
   to keep, but the doc-writer should add them to §4.3's roster.
10. **note** — `ReminderTextTests` is marked `@MainActor` (plan 115) while spec AC line 298 says the Shared suite is plain.
   `SettingsTextTests` is already `@MainActor` (`Shared/SettingsTextTests.swift:8`), so this matches the codebase; no action.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | plan §4, Steps 7–8 for store writes | "Nothing writes to the store" (353); both preferences are `@AppStorage`, written on the tap (252–258); the schedule lives in the notification daemon | addressed |
| Delete rules | plan §4 | "No `@Model`, relationship, delete rule, `#Predicate` or migration change" (348) | n/a |
| Units | grep `kg` in plan | none; no weight is touched | n/a |
| Date determinism | Steps 1–3, 7 for `Date()` / `Calendar.current` | `desired(…now:calendar:)` takes both (63–64); the host reads `clock.now()` once inside the pass (216); `ReminderText.subtitle` builds 2001-01-01 in the passed calendar (111–113); Step 10 keeps `ClockUsageTests` green (306) | addressed |
| Concurrency | Step 5–7 for actor isolation and unowned tasks | `ReminderPermission` and the delegate are main-actor under the target's default isolation (164, 182–183); the scene handler spawns an unstructured `Task { await permission.refresh(…) }` (213–214) that only writes root-owned state — harmless if the host is gone | addressed |
| Availability | researcher Q5 table; plan 28–30 | `openNotificationSettingsURLString` iOS 16, `@Observable` iOS 17, two-parameter `onChange` iOS 17, `Date.FormatStyle` iOS 15 — nothing newer than 17 | addressed |
| Privacy label | plan 18, researcher Q9 | "No new dependency, entitlement, capability, Info.plist key, project edit or schema change" | addressed |
| Resume and empty states | plan Step 7, spec §3 | no program → `noProgramID` query, empty reconcile (200–203); relaunch → first status read then reconcile (211–212); mid-workout → host stays mounted on the `ZStack`, `workoutInProgress` drops today (221–222, 216–217) | addressed |
| Ordering / buildability | each step's Verify line | Steps 1→10 introduce types before their users (`ReminderText` before the seam, the seam before `ReminderPermission`, both before the host, `ReminderRowState` before `ReminderRows`); Step 7 adds `DebugSeed.reminderStatus` before Step 9 widens it (227); `DebugSeedTests` and `initialDraft`'s exhaustive switch are edited in Step 9 (283–284) | addressed |
| Commands | Step 0 and Verify lines vs CLAUDE.md | `DEST`/`DEST26` carry `OS=17.5` / `OS=26.5`; `RELEASE` uses `-configuration Release … CODE_SIGNING_ALLOWED=NO`; `TEST26` runs the 26.5 suite; `ONLY` passes `-parallel-testing-enabled NO` | addressed |
| DEBUG-only code | Steps 7, 9 | `DebugSeed` edits inside the existing `#if DEBUG` file; the seed override sits in the `#if DEBUG` branch (224–226); `ReminderQueryTests` and `ReminderSeedTests` are `#if DEBUG` (230, 284); Step 10 runs `RELEASE` | addressed |
| `project.pbxproj` | grep `pbxproj` in plan | only Step 11's scratch copy adds a target: "the repo's `project.pbxproj` is never touched" (316) | addressed |

### Scope creep

- `ReminderRequest.day/hour/minute` (finding 8).
- `ReminderPlan.time` / `minutes(of:)`, `ReminderText.rowSubtitle` (finding 9) — small, pure, tested; keep.
- `ReminderQueryTests`: "After `ProgramStore.archive`, `ProgramStore.current` is nil" (233) duplicates `ProgramArchiveTests`; harmless.
- Step 0's `build/reminder-env.sh` is a gitignored helper, not product code.

### Summary

- Covered: 10 of 19 acceptance criteria (AC-1, 2, 3, 4, 10, 11, 13, 15 fully; AC-8 and AC-9 code halves)
- Partial: AC-8, AC-9, AC-12, AC-14
- Missing: none
- Ambiguous: none
- Out of scope (per plan): AC-5, AC-6, AC-7 (optional Step 11, else MVP), AC-16–AC-19 (device pass)
- False claims about existing code: 0
- Traceability: plan carries AC numbers (per-step "Covers" lines and the §3 table)

### Questions only the user can answer

- Run optional Step 11 (scratch-copy XCUITest for AC-5–AC-9) before the merge, or leave AC-5–AC-9 to the MVP pass as
  the last four slices did? Recommended default: leave to the MVP pass (memory: manual checks deferred to MVP), except AC-8's
  synthetic `rest-timer` coexistence, which only Step 11 can exercise.

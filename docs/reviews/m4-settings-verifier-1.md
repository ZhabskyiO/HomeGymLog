VERDICT: PASS WITH FIXES

## Plan Verifier result — docs/plans/m4-settings.md against docs/specs/m4-settings.md (round 1, 2026-09-22)

Read in order: `CLAUDE.md`, `insights/INSIGHTS.md` (2026-09-22 block), `insights/gotchas.md` (every 2026-09-22 entry), the spec
(status "spec agreed 2026-09-22", §9 "Nothing remains open"), the plan, `docs/reviews/m4-settings-architecture.md`,
`docs/reviews/m4-settings-researcher.md` (+ addendum P1–P4), `docs/layout.md`, then the Swift files the plan touches or cites
(listed in the claims table). Baseline: `xcodebuild … name=iPhone 15,OS=17.5 build` on the current tree → `** BUILD SUCCEEDED **`;
the 807-test count is the recorded m4-progress figure (`CLAUDE.md` Milestones, INSIGHTS 2026-09-16), which Step 0 re-measures.

The four issues the main session settled are all reflected consistently in spec and plan:

1. `-holdBanner` — spec §4.4 line 229 ("parsed by `App/DebugSeed/DebugBannerHold.swift`, the `DebugInitialTab` shape, invoked
   from the root's `#if DEBUG` block") = plan Step 10 and plan §2. `DebugInitialTab` exists at
   `HomeGymLog/App/DebugSeed/DebugProgramSelection.swift:27-32` and is invoked at `HomeGymLogApp.swift:56` outside the seed branch,
   inside `#if DEBUG`; AC-22's "literal only under `App/DebugSeed/`" holds with that shape.
2. AC-21 seed rows — spec AC-21 ("a new suite applies `MissedDay.resolution` and the existing store writers to `missed-several`'s
   rows … 10 · 10 · 120 · 7 560 · week 2 and 0 · 10 · 120 · 7 560 · week 3") = plan Step 5 `Seed/AutomaticPolicySeedTests`
   ("streak 10, completed 10 of 120, week volume 7 560, current week 2; after the skip pass, streak 0, 10 of 120, 7 560, week 3").
   Matches; one wording note (finding 13).
3. Policy control — `Picker` + `.pickerStyle(.menu)` with a `Menu` fallback recorded as an AC-15 deviation is an acceptable risk to
   carry (AC-15 is device-only and the deviation is written down), **provided** the control carries an explicit accessibility label
   and value in either rendering (finding 4); without them neither rendering produces AC-15's spoken shape.
4. `shiftedBanner(name:style:newDate:calendar:)` — spec §4.3 line 189 = plan Step 3 and Step 10; spec §2.6 has no self-reference.

The caller's focus items: the key/retry rule and the task-vs-`onAppear` order (Step 9 keys on `now ?? clock.now()` and writes with
`clock.now()`, matching spec §2.6 and gotcha SwiftUI 2026-09-22), the synchronous skip pass and its failure path (Step 9 `for` loop,
stop at the first throw, `assertionFailure` + return, static scan forbids `await` on the writer lines; Step 10 builds the banner from
"the sessions the pass actually skipped"), the restart order (Step 7 `archive` then `selectedTab = .home`, a throw leaves Settings)
and the third root `@Query` (Step 8, `max(by:)` in Swift, "no `FetchDescriptor` in the file") all agree with the spec and the
architecture review. One step would go red as written (finding 5); the rest of the ordering holds.

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | Step 7 | `settings` frame matches with the listed deviations | grep `AC-1` | plan Step 7 verify: `/design-compare settings` on `-seed midProgram -tab settings` against `build/proto-settings.png`; Step 0 crops 800×290 @ (2555, 4148) per spec §8 header | covered |
| AC-2 | Step 7 | freshProgram "1-month program · 4 days"; `-missedDayPolicy shift` reads "Always shift" | grep `AC-2` | plan Step 7 verify names both launches; `midProgram` keeps the host off (`DebugSeed.forcesMissedDayPrompt` false, `DebugSeed.swift:167-172`) | covered |
| AC-3 | Step 7 | kg: "2.3–23.8 kg", "68 kg stack"; Home kg regression | grep `AC-3` | plan Step 7 verify; `WeightDisplay.text` 5 → "2.3", 52.5 → "23.8", `wholeText` 150 → "68" (`Engine/WeightDisplay.swift:14-31`) | covered |
| AC-4 | Steps 6, 7 | `home-light` by `-appearance light` on a dark simulator; dark on light matches `home`; System still follows | grep `AC-4` | Step 6 verify (Home half, three launches incl. plain `-seed midProgram` on light), Step 7 verify (Settings half) | covered |
| AC-5 | Step 8 | dialog copy, destructive style, chosen appearance on 17.5 and 26.5 | grep `AC-5` | Step 8 verify: `-seed settings-restart -tab settings`, `-appearance dark` on light and `light` on dark, "both also on `$UDID26`" | covered |
| AC-6 | Step 8 | `restarted` matches `ob1` (6 months selected); kg variant | grep `AC-6` | Step 8 `/design-compare ob1` on `-seed restarted` and `-units kg`; `RestartSeedTests` pins the prefill = Step 4's expectation; the Continue spot checks are user/XCUITest per the AC's own text | covered |
| AC-7 | Steps 9, 10 | policy launches match `missed-shifted`/`missed-skipped`; row B Home/Program; four banner shots; no banner on Program | grep `AC-7` | Step 9 checks the state half before the banner exists; Step 10 checks only the `-holdBanner` launches; after Step 10 the non-hold launches show the banner for 3 s while the spec shoots at "≥ 2 s" (finding 2) | partial |
| AC-8 | Step 11 | every base seed unchanged; no `PlaceholderScreen` on any tab | grep `AC-8` | Step 11 re-shoots every `base-*` of Step 0 and `cmp`s; Step 7 deletes `Shared/PlaceholderScreen.swift` (refs only at `ShellView.swift:43`, `AppTab.swift:19`) | covered |
| AC-9 | Steps 6, 12 | Dark/Light/System repaints every surface incl. an open sheet; survives relaunch | grep `AC-9` | Step 6 mechanism = researcher Q1 (window override verified); Step 12 trace 1; DoD "By hand (MVP pass)"; spec §8 says taps are the optional scratch step or the user's pass | covered (user-run) |
| AC-10 | Steps 7, 12 | kg/lb repaints Settings, Home, Program, Progress, workout | grep `AC-10` | Step 7 binds `@AppStorage("units")`; Step 12 trace 2; DoD by-hand line | covered (user-run) |
| AC-11 | Steps 7, 12 | Cancel leaves the program current, tab Settings | grep `AC-11` | Step 7 `.confirmationDialog` with `.cancel`; Step 12 trace 3 | covered (user-run) |
| AC-12 | Steps 7, 8, 12 | confirm → A2 prefilled → Start → shell on Home; Progress spans both | grep `AC-12` | Step 7 `confirmRestart` (archive → `.home`), Step 8 prefill query, Step 12 trace 3 | covered (user-run) |
| AC-13 | Steps 7, 12 | failed archive shows the alert; Settings unchanged; `archivedAt` nil | grep `AC-13` | Step 7 claims `ProgramArchiveRollbackTests` = "store half" (`Persistence/ProgramArchiveRollbackTests.swift:12` covers the writer only); the alert/tab outcome has no test and Step 12 is optional, while the AC offers "or a unit test of the handler's outcome" (finding 3) | partial |
| AC-14 | Steps 9, 10, 12 | policy taps act at once; banner 3 s, tap, Reduce Motion, VoiceOver once | grep `AC-14` | Step 9 `.onChange(of: policyRaw) { silence = nil }` + keyed task; Step 10 banner; Step 12 trace 5; but the timer clears the banner on cancellation (finding 1) and the announcement fires off-Home (finding 6) | partial |
| AC-15 | Step 7 | VoiceOver order; rows as label/value pairs; "Missed a day" pop-up button with value | grep `AC-15` | Step 7 "Rows exactly as spec 2.1–2.4" names no accessibility element/label/value for `SettingsRow` or the picker; `.labelsHidden()` drops "Missed a day" from the control (finding 4); `SegmentedPicker` already adds `.isSelected` (`Shared/SegmentedPicker.swift:36`) | partial |
| AC-16 | Steps 2, 3 | `SettingsText` strings; `bannerDayStyle`; banner strings with the worked values | grep `AC-16` | Step 3 tests: (6,5)/(1,4)/(2,3), `dumbbellRange` derived from `EquipmentKind.dumbbell.minLb/maxLb` **and** compared to literals, `marcyDetail`, `policy`, U+2026; `shiftedBanner` `.today` / Mon 2026-09-21; `skippedBanner` 1/2/3/`[]`; Step 2 `bannerDayStyle` 09-15 vs 09-15 noon, 09-21, 09-14 | covered |
| AC-17 | Step 1 | enum raw round trips, fallbacks, labels, `allCases`, storage keys | grep `AC-17` | Step 1 tests list "sepia", "", "Dark" → fallback, labels, `allCases` order, `storageKey` vs a typed literal | covered |
| AC-18 | Step 2 | `resolution` rows A–D per policy; shuffled skip order; `.none` on shifted/skipped | grep `AC-18` | Step 2 tests: A/B/C/D incl. silenced Ask, `[7, 11, 12]` from shuffled and reversed input, `restDay` data, `[]`; fixtures `MissedDayFixtures.input(completed:skipped:dates:)` exist (`Support/MissedDayFixtures.swift:39`) | covered |
| AC-19 | Step 4 | prefill worked row + every hand case; custom passthrough; `[:]` | grep `AC-19` | Step 4 tests enumerate all eleven hand cases of spec 5.2 verbatim, the 17-key map from `StartingWeights.rows(frequency: 5, sessionLengthMinutes: 45, overrides: [:])` (`Engine/StartingWeights.swift:17`) with the lb literals | covered |
| AC-20 | Step 5 | archive → start round trip; counts unchanged; second archive false; automatic passes over rows | grep `AC-20` | Step 5 `RestartFlowTests` (fresh context, `fetchCount(currentPredicate) == 1`, archived predicate == 1, note count, second archive false + `hasChanges == false`) and `AutomaticPolicyPassTests` (three `true`, case B dates s7 09-17 · s11 09-18 · s12 09-21 · s13 09-22) | covered |
| AC-21 | Steps 5, 8 | seed rows; `restarted` archived 09-15 11:59; prefill order; new resolution suite with Home numbers | grep `AC-21` | Step 8 `RestartSeedTests` (row counts, `archivedAt` == 09-15 11:59, ten completed, `initialDraft` nil, `SplitPlans.exerciseKeys(frequency: 5, sessionLengthMinutes: 45)` order); Step 5 `AutomaticPolicySeedTests` numbers = AC-21's | covered |
| AC-22 | Steps 10, 11 | the static scans | grep `AC-22` | Step 10 `SeedNameScanTests` append (names + `-holdBanner` under `App/DebugSeed/`, two `@Entry`s, one setter line each); Step 11 `SettingsSourceTests` (literals, `@AppStorage` file lists, `preferredColorScheme` nowhere, `overrideUserInterfaceStyle`/`import UIKit` only in `RootView.swift`, `settings` case, no `SettingsSegmentedControl`, no placeholder, no `FetchDescriptor` in `RootView.swift`) + `ClockUsageTests`/`FailedSavePolicySourceTests` in the full run | covered |
| AC-23 | Step 11 | Release build; suites green on 17.5 and 26.5 | grep `AC-23` | Step 11 `RELEASE`, `TEST`, `TEST26` | covered |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| `-holdBanner` parser follows "the `DebugInitialTab` shape" | grep `DebugInitialTab` | `App/DebugSeed/DebugProgramSelection.swift:27` — `enum DebugInitialTab { static func parse(arguments: [String]) -> AppTab?`; called at `App/HomeGymLogApp.swift:56` inside `#if DEBUG`, outside the seed branch | true |
| `ProgressSnapshotBuilder.archivedProgramPredicate` exists, verified on 17.5/26.5 | grep | `Models/ProgressSnapshotBuilder.swift:10` — `static let archivedProgramPredicate = #Predicate<Program> { $0.archivedAt != nil }`; used by `ProgressTabView.swift:16` | true |
| `RootView` owns two `@Query`s, `onAppear` applies `initialTab` once; onboarding branch `OnboardingView(initialDraft: seedDraft ?? OnboardingDraft(units:))` | read | `App/RootView.swift:9-11, 32, 35-42` | true |
| `OnboardingView` copies `initialDraft` once via `State(initialValue:)` | read | `Features/Onboarding/OnboardingView.swift:16-17` — `init(initialDraft:) { _draft = State(initialValue: initialDraft) }` | true |
| `ShellView` routes `default: PlaceholderScreen(tab:)`; nothing else references `PlaceholderScreen` / `placeholderMilestone` | grep | `App/ShellView.swift:43`; `App/AppTab.swift:19`; `Shared/PlaceholderScreen.swift:4,14,29` (its own `#Preview`); no test references | true |
| `MissedPromptHost`: concrete `ZStack(alignment: .bottom)` root, `now ?? clock.now()`, `shouldPrompt` call, `silence` `@State`, `enabled` `@Entry`, shift/skip handlers with `clock.now()` | read | `Features/Home/MissedPromptHost.swift:32-65, 74-90` | true |
| `MissedDay.firstMissed(sessions:today:calendar:)`, `shouldPrompt(missed:silence:today:calendar:)`, `PromptSilence`, `dayLabelStyle` | read | `Engine/MissedDay.swift:20-23, 34-44, 68-72` | true |
| `HomeStats.sessionState` returns `.missed`; `HomeStats.ordered` | grep + read | `Engine/HomeStats.swift:98-106`, `:17`; `WeekStripState` has `missed` (`HomeStatsTypes.swift:82-84`) | true |
| `ProgramStore.archive(_:at:in:) -> Bool` (false when archived, `StoreCommit.commit`), `shift(...) -> [Int: Date]`, `skipMissed(...) -> Bool`, `start(... in:) -> Program?`, `currentPredicate`, `current(in:)` | read | `Models/ProgramStore.swift:7, 10-18, 25-32, 78-94, 100-110, 117-122` | true |
| `SegmentedPicker.Style` has `pill`/`wide`/`chip`, `container` override, `labelSize`/`verticalPadding`/`segmentRadius`/`unselected*` switches | read | `Shared/SegmentedPicker.swift:5-12, 18, 43-47` — present; selected foreground is a hard-coded `Color.white` (`:29`) and horizontal padding / container padding / radius / spacing are ternaries (`:21, 30, 39, 40`) (finding 7) | true (incomplete) |
| `WeightDisplay.text(lb:unit:)` (one decimal) and `wholeText(lb:unit:)` (integer) | read | `Engine/WeightDisplay.swift:14-31` (note: the file is under `Engine/`, not `Shared/`; the plan does not misplace it) | true |
| `HomeText.dayLabel` → "Mon, Sep 21" | read | `Shared/HomeText.swift:10-12` — `weekday(.abbreviated).month(.abbreviated).day()` | true |
| `MissedDayText` (kicker, body, shift, skip, `title`) | read | `Shared/MissedDayText.swift:5-22` | true |
| `ProgramSummaryText.title(months:)` | grep | `Shared/ProgramSummaryText.swift:6` | true |
| `EquipmentKind.dumbbell.minLb / maxLb`, `marcy.maxLb`, `isLoadable(lb:)` | grep | `Engine/Equipment.swift:36-37, 50`; tenths 50/525 and 100/1500 → 5–52.5 lb and 150 lb | true |
| `ProgramGenerator.allowedMonths / allowedFrequencies / allowedSessionLengths`; throws `unknownExerciseKey` / `unloadableStartingWeight` for every key (NB9) | read | `Engine/ProgramGenerator.swift:60-62, 130-132` | true |
| `SplitPlans.defaultWeekdays(frequency:) -> [Int]?`, `exerciseKeys(frequency:sessionLengthMinutes:) -> [String]?` | grep | `Engine/SplitPlans.swift:62, 69` | true |
| `StartingWeights.rows(frequency:sessionLengthMinutes:overrides:)` | grep | `Engine/StartingWeights.swift:17` | true |
| `OnboardingDraft`: `units.didSet` overwrites `bodyWeightUnit` until chosen; `bodyWeightRangeLb`; `step`; `days`; `startingWeightRows` | read | `Features/Onboarding/OnboardingDraft.swift:7-32, 49-51` — `final class`, so a `convenience init` is legal; `frequency`/`days`/`startingWeightsLb` are `private(set)` (settable inside the class) | true |
| `Experience(rawValue:)`, `.intermediate` | grep | `Engine/EngineTypes.swift:67-70` — raw "Beginner"/"Intermediate"/"Advanced" | true |
| `CalendarRules.isSameDay`, `startOfDay` | grep | `Engine/CalendarRules.swift:13, 49` | true |
| `MidProgramSeed.populate` = 6 months, 5 days, [0,1,2,3,4], 45, 180, Intermediate, `startingWeightsLb: [:]`; `completedIndexes` 0–10 minus 7 | read | `App/DebugSeed/MidProgramSeed.swift:8, 19-27`; the generator fills the map (`ProgramGenerator.swift:107-109`) | true |
| `ProgressHistorySeed` shape (`preconditionFailure` on a false `archive`) | read | `App/DebugSeed/ProgressHistorySeed.swift:23-25` | true |
| `DebugSeed`: `referenceDate` switch, `initialDraft` exhaustive switch, `makeContainer` with `default: break`, `workoutSheetPreview`, `forcesMissedDayPrompt` | read | `App/DebugSeed/DebugSeed.swift:62-74, 81-93, 96-121, 143-150, 167-172` | true |
| `HomeGymLogApp`: seed branch reads `seed.workoutSheetPreview` / `forcesMissedDayPrompt` inside `#if DEBUG`; `.environment(...)` lines in `body` | read | `App/HomeGymLogApp.swift:40-61, 88-93` — the `.environment` lines are **outside** `#if DEBUG` (finding 9) | true |
| `AppClock` nil-by-default `@Entry`s (`workoutSheetPreview`, `missedPromptEnabled`, `progressPreselection`) | read | `App/AppClock.swift:37, 41, 45` | true |
| `ProgramView.reset` runs on appear and on every tab change (NB5) | grep | `Features/Program/ProgramView.swift:48-50` | true |
| `AccessibilityNotification.Announcement(RestText.restOver).post()` precedent | grep | `Features/Workout/WorkoutView.swift:144` | true |
| `workoutSheetPreview` applied in `onAppear` (precedent for `settingsRestartPreview`) | grep | `Features/Workout/WorkoutView.swift:46, 103` — `if let sheetPreview { openPreview(...) }` | true |
| `.toolbar(.hidden, for: .navigationBar)` precedent | grep | `Features/Home/HomeView.swift:48` | true |
| Test suites named in `ONLY` lists exist | ls | `MissedDayTests`, `MissedDayEdgeTests`, `MissedDayStatsTests`, `SessionStateTests`, `MissedDayTextTests`, `MissedDayTextEdgeTests`, `ProgramSummaryTextTests`, `ClockUsageTests`, `OnboardingDraftTests`, `OnboardingDraftEdgeTests`, `ExerciseKeysTests`, `ProgramArchiveTests`, `ProgramArchiveRollbackTests`, `MissedDayStoreTests`, `MissedDayStoreEdgeTests`, `RoutingPredicateTests`, `SeedHomeStatsTests`, `DebugSeedTests`, `MidProgramSeedTests`, `MissedPromptSourceTests`, `SeedNameScanTests` — all present under `HomeGymLogTests/` | true |
| `MissedPromptSourceTests` shape: file-walk, `//` stripped, `#expect(files.count > 40)` | read | `Static/MissedPromptSourceTests.swift:9-22, 49-61` | true |
| `SeedNameScanTests` covers names under `App/DebugSeed/` and each appears there | read | `Static/SeedNameScanTests.swift:8-11, 30-41` | true |
| `progressPreselection` scan shape (parse line after `DebugSeed.parse(` and before `#endif`; `@Entry` nil; `.environment` once) | read | `Static/ProgressSourceTests.swift:64-74, 76-95` | true |
| `SeedHomeStatsTests` input helper; `missedSeveral` row currently 0 · 10 · 120 · 7560 · week 3 | read | `Seed/SeedHomeStatsTests.swift:11-17, 33` | true |
| `MissedDayFixtures.input(completed:skipped:dates:)`, `TestCalendar` fixed calendar (America/New_York, en_US_POSIX) | read | `Support/MissedDayFixtures.swift:39`, `Support/TestCalendar.swift:7-13` | true |
| `ProgramArchiveRollbackTests` covers the failed-archive restore | read | `Persistence/ProgramArchiveRollbackTests.swift:12-13` — one test, writer-level only | true |
| `build/progress-env.sh` exists (Step 0 copies its definitions) | ls | `build/progress-env.sh` 2539 bytes, 2026-09-16; `build/` gitignored (`.gitignore:2`) | true |
| iPhone 15 / 17.5 and iPhone 17 / 26.5 simulators exist | `simctl list devices` | `3CAE4D76…` (17.5), `834F0313…` (26.5); the 27.0 runtime also has an iPhone 17 (`OS=` must be given, as CLAUDE.md says) | true |
| Project builds on HEAD | `xcodebuild … OS=17.5 build` | `** BUILD SUCCEEDED **` | true |
| No `import UIKit`, `preferredColorScheme`, `UIColor`, `"appearance"` or `"missedDayPolicy"` in app Swift today | grep | none in `.swift`; `"appearance"` occurs only in `Assets.xcassets/*/Contents.json` (finding 10) | true |
| "nothing outside `ShellView` referenced `PlaceholderScreen`, grepped at plan time" | grep | as above | true |

### Findings

1. **should-fix** — Step 10's banner timer clears the banner on cancellation, not only after 3 s. Evidence: plan Step 10 —
   `.task(id: timerToken) { guard let timerToken else { return }; try? await Task.sleep(for: .seconds(3)); if banner?.token == timerToken { banner = nil } }`.
   When the user leaves Home inside the 3 s, `timerToken` becomes nil, SwiftUI cancels the task, `Task.sleep` throws
   `CancellationError`, `try?` swallows it, the token still matches and the banner is cleared at once; spec §2.7 says
   "auto-dismisses 3 s after it became visible". Fix: `do { try await Task.sleep(for: .seconds(3)) } catch { return }` (or
   `guard !Task.isCancelled`), or state in the plan that leaving Home early drops the banner on purpose. React: a `setTimeout`
   whose `useEffect` cleanup must set a `cancelled` flag the callback checks before touching state.
2. **should-fix** — AC-7's non-`-holdBanner` launches are never re-verified once the banner exists. Evidence: Step 9 verify
   ("`-seed missed -missedDayPolicy shift` / `skip` must match `base-missed-shifted` / `base-missed-skipped`") runs before Step 10
   adds the banner; Step 10 verify names only the four `-holdBanner` launches; Step 11 re-shoots "every `base-*` launch of Step 0",
   which has no `-missedDayPolicy` variant. After Step 10 the plain policy launches show the banner for 3 s while spec §8 shoots at
   "wait ≥ 2 s", so AC-7's "matches `-seed missed-shifted`" would fail or go untested. Fix: in Step 10 (or 11) re-shoot the plain
   `-missedDayPolicy` launches of AC-7 ≥ 4 s after launch (or with the banner rectangle masked) and say so in DoD line 4.
3. **should-fix** — AC-13 has no machine check in the gated steps. Evidence: spec AC-13 offers "scratch-copy test on an
   `allowsSave: false` store, **or a unit test of the handler's outcome**"; plan Step 7 tests "no new unit test" and cites
   `ProgramArchiveRollbackTests` (writer-level, `Persistence/ProgramArchiveRollbackTests.swift:12`), while the alert / tab /
   `archivedAt` outcome sits only in optional Step 12 trace 4. Fix: extract the handler outcome into a testable pure-ish function
   (e.g. a static `restart(program:now:in:) -> RestartOutcome` next to `confirmRestart`, returning `.archived` / `.alreadyArchived` /
   `.failed(message)`) and add a test on the `ProgramArchiveRollbackTests` on-disk `allowsSave: false` fixture asserting
   `.failed(SettingsText.archiveFailedMessage)` and `archivedAt == nil` in a fresh context; or make Step 12's AC-13 case a gate.
4. **should-fix** — AC-15's spoken shape is not in Step 7. Evidence: Step 7 says "Rows exactly as spec 2.1–2.4" and nothing about
   `accessibilityElement` / `accessibilityLabel` / `accessibilityValue`; AC-15 wants "one element 'Current' with value
   '6-month program · 5 days'", "'Missed a day' pop-up button with value 'Ask me each time'" and the equipment rows "as label /
   value pairs"; the planned `Picker` uses `.labelsHidden()`, so VoiceOver would speak the value as the label, and the `Menu`
   fallback would speak neither "Missed a day" nor a value. Fix: give `SettingsRow` `.accessibilityElement(children: .combine)`
   (or `.ignore` + label/value) and give the control `.accessibilityLabel(SettingsText.missedDay)` +
   `.accessibilityValue(SettingsText.policy(policy))`; then the `Menu` fallback's only deviation is the trait, as the plan records.
   React: `aria-label` + `aria-valuetext` on the trigger.
5. **should-fix** — Step 8 turns `DebugSeedTests.parses` red unless the test is edited, and the step does not say so. Evidence:
   `Seed/DebugSeedTests.swift:15-25` switches on every seed with `default: expectedDay = TestCalendar.day(2026, 8, 31)`; the plan
   sets `referenceDate` to 09-15 for `settings-restart` and `restarted`, so both new cases fall into `default` and fail the
   `referenceDate == expectedDay + 12 h` expectation. Step 8's `ONLY … DebugSeedTests …` would fail. Fix: add "extend
   `DebugSeedTests.parses`'s switch with `.settingsRestart, .restarted → 09-15`" to Step 8's test list (the m4-progress plan did the
   same for `progress-history`). Also update the `initialDraft` loop at `:78-80` if it enumerates the nil seeds by name.
6. **should-fix** — The banner's VoiceOver announcement fires when the action runs, not when the banner appears. Evidence: Step 10
   posts `AccessibilityNotification.Announcement(text)` from `.onChange(of: banner?.token)`; the token bumps when the task fires
   on any tab (spec §2.6 "regardless of the selected tab"), while spec §2.7 says the text is "posted as an accessibility
   announcement when it appears" and AC-14 pairs the announcement with the banner showing on Home. Fix: derive
   `visibleToken = selected == .home ? banner?.token : nil` in `body`, announce on its change to non-nil, and set
   `timerToken = missedBannerHold == true ? nil : visibleToken` (the same derived value drives both, and `-holdBanner` still
   announces).
7. **note** — `SegmentedPicker.Style.settings` needs more than the four named switches. Evidence: selected text is hard-coded
   `Color.white` (`Shared/SegmentedPicker.swift:29`); horizontal padding (`:30`, 16/0), container padding (`:39`, 3/4/0), container
   radius (`:40`, 10/14) and spacing (`:21`, 3/6) are ternaries. The `settings` case must set selected `Theme.tx`, padding 5/12, gap 3,
   container padding 3 / radius 9, segment radius 7, 12.5 pt; say whether segments are equal-width (`:32`) — the prototype's are not.
8. **note** — Step 4's `convenience init` ordering: on a `final class`, `bodyWeightUnit.didSet { bodyWeightUnitChosen = true }`
   (`OnboardingDraft.swift:15-17`) fires for every assignment after `self.init`, so `bodyWeightUnitChosen = (bodyWeightUnit != units)`
   must be the **last** statement; the plan lists it last but does not say it must be. React: a setter side effect you have to
   overwrite after the fact.
9. **note** — Step 10's scan wording "exactly one line of `App/HomeGymLogApp.swift` sets each, the `settingsRestartPreview` one
   inside the `DebugSeed.parse(` block" is only satisfiable if the "inside the block" assertion targets the
   `seed.settingsRestartPreview` read (or `DebugBannerHold.parse(` line) and the "exactly one" assertion targets the
   `.environment(\.…` line: the `.environment` modifiers live in `body` outside `#if DEBUG` (`HomeGymLogApp.swift:88-93`), as the
   `forcesMissedDayPrompt` (`MissedPromptSourceTests.swift:24-34`) and `DebugProgressExercise.parse(` (`ProgressSourceTests.swift:64-74`)
   scans already assume. Say which line each assertion reads.
10. **note** — Step 11's `"appearance"` literal scan must keep the `.swift` filter: the literal appears in eight
    `Assets.xcassets/*/Contents.json` files (`"appearance": "luminosity"`). The cited file-walk filters `pathExtension == "swift"`
    (`MissedPromptSourceTests.swift:51`), so it is fine as long as the new suite copies that shape.
11. **note** — Policy control risk (caller's item 3): `Picker(.menu)` ignores `.font` on the menu label on iOS 17 in practice, so
    the `Menu` fallback is the likely outcome; acceptable to carry, since AC-15 is device-only and the deviation is written down,
    provided finding 4's label/value are applied to whichever label view ships.
12. **note** — `-seed settings-restart -tab settings` presents the dialog from `SettingsView.onAppear` during the tab switch that
    `RootView.onAppear` triggers (`RootView.swift:38-41`); the `wo-adjust` precedent (`WorkoutView.swift:103`) presents at the route
    root with no tab switch. If the dialog is dropped on 17.5, present it from `.onChange(of: selected)` / a `.task`; AC-5's shot
    is the probe.
13. **note** — Step 5's `AutomaticPolicySeedTests` should say the pass is driven by `MissedDay.resolution`'s case (as
    `AutomaticPolicyPassTests` does), matching AC-21's "applies `MissedDay.resolution` and the existing store writers"; otherwise
    the suite can pass with hand-typed indexes.
14. **note** — gotcha Swift 2026-09-14: `RestartPrefillTests`' eleven hand cases as one nested-tuple `@Test(arguments:)` literal
    may fail to type-check; use a file-scope typed constant or one test per field.
15. **note** — Step 9's `.task(id:)` also runs at mount with a nil id (P2), so the body must `guard` on the key / resolution case;
    the plan implies this but does not write the guard. Also `RootView` needs a new `@AppStorage("bodyWeightUnits")` reader for the
    prefill (today only `OnboardingView.swift:11` reads it); Step 8 says "from the `units` and `bodyWeightUnits` preferences" without
    naming the property.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | plan §3 for "save" / `StoreCommit` | preferences via `@AppStorage` (immediate); archive one save; each skip one save; shift one save; nothing deferred | addressed |
| Delete rules | plan §4 | "None. No `@Model`, relationship, delete rule or `#Predicate` is added" — matches spec §4.2 "No schema change" | addressed |
| Units | grep `kg` in plan | equipment text through `WeightDisplay`; storage stays lb; `bodyWeightUnits` untouched by the Units control | addressed |
| Date determinism | Engine steps 1, 2, 4 | `resolution`, `automaticActionKey`, `bannerDayStyle`, `RestartPrefill.answers` take `today`/`calendar` or no date; `Task.sleep` lives in the view; `ClockUsageTests` in the full run | addressed |
| Concurrency | Steps 6, 9, 10 | `UIApplication.shared.connectedScenes` from the main-actor view (researcher Q1); `ModelContext` only from `.task` / handlers on the main actor; the 3 s task is owned by the host | addressed |
| Availability | Steps 6–10 | `overrideUserInterfaceStyle` iOS 13, `onChange(of:)` two-param iOS 17, `Task.sleep(for:)` iOS 16, `AccessibilityNotification` iOS 15, `.confirmationDialog` iOS 15, `@Entry` already in use | addressed |
| Privacy label | plan §1 | "No new dependency, entitlement, capability, Info.plist key"; `import UIKit` is an SDK framework | addressed |
| Resume and empty states | spec §3 vs plan | first run: no Settings; kill after archive: onboarding prefilled from rows (Step 8 query); kill mid-onboarding: M2 no-draft rule; automatic policy re-acts on remount (Step 9 task at mount) | addressed |

### Summary

- Covered: 19 of 23 acceptance criteria (AC-9–AC-12 covered as user-run / optional Step 12, per spec §8's own terms)
- Partial: AC-7, AC-13, AC-14, AC-15
- Missing: none
- Ambiguous: none
- Out of scope (per plan): none ("No AC is excluded", plan §1)
- False claims about existing code: 0
- Traceability: plan carries AC numbers

### Questions only the user can answer

- Should a banner that the user leaves Home from within its 3 s be dropped (current plan behaviour by accident, finding 1) or
  survive until it has been visible for a full 3 s? Recommended default: survive (matches spec §2.7 "3 s after it became visible").

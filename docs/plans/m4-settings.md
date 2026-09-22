# M4 slice 3 — Settings tab (appearance, units, program rows, missed-day policy, restart, equipment): implementation plan

**Status: ready for review 2026-09-22.** For `docs/specs/m4-settings.md` (agreed; architecture B1–B3 / NB1–NB10 and the
researcher addendum P1–P4 folded in). Spec §2–6 and §8 are the contract (`AC-1`…`AC-23`); format follows
`docs/plans/m4-progress.md`; `implementer`, one step per build, nothing committed by it.

## 1. Goal and scope

Land the last placeholder screen in dependency order: the two preference enums, the pure missed-day resolution and its
banner day style, the Settings and banner strings, the restart prefill, the persistence round trip, the appearance
applier in `RootView`, the Settings screen (which deletes `PlaceholderScreen`), the two new seeds with the restart
prefill wiring, the prompt host's automatic action, then its banner, then the scans and the regression sweep. Every
step ends green on iPhone 15 / iOS 17.5.

Out of scope (spec §7): the Daily reminder's behaviour and permission status (m4-reminder), Sound & haptics, history or
archive deletion, equipment editing, export, the light-theme audit (M5), CloudKit, schema versioning, a "cancel back to
the old program" after archiving, an undo for automatic actions, a banner for manual shift/skip taps, a single-save
"skip all" writer. **No AC is excluded.** Taps and timing are refused in the repo's
simulator session, so AC-9–AC-14 are the user's MVP pass unless optional **Step 12** verifies them in a scratch copy;
AC-15 (VoiceOver order) is device-only. **No new dependency, entitlement, capability, Info.plist key, project edit or
schema change**; `import UIKit` is an already-linked SDK framework and appears in exactly one file.

## 2. Decisions this plan relies on

- INSIGHTS "2026-09-22 — M4 Settings decisions", **all of it**, including the architecture review's B1 (Equatable key,
  one retry rule, synchronous pass), B2 (third root `@Query`, newest in Swift, draft copied once), B3 (full-size host
  root owning the banner state) and NB1–NB10. Spec §2–§6 is the behaviour contract and is not restated here.
- Researcher addendum (verified 17.5 and 26.5): P1 (a full-size transparent root, even a full-size `Color.clear`,
  intercepts no touch), P2 (`.task(id:)` runs at mount while the host draws nothing; on 26.5 **before** `onAppear`),
  P3 (an alert raised from a confirmation-dialog button action is not dropped), P4 (`-appearance` /
  `-missedDayPolicy` override `@AppStorage` for both suites when the reader sits below `.defaultAppStorage`).
- INSIGHTS Patterns (derived modal overlay on the shell, nil-by-default DEBUG `@Entry`, `.id(model.id)`, a writer
  restores its snapshot, real-touch probes); gotchas SwiftUI 2026-09-22 / 2026-09-15, Swift 2026-09-22 and 2026-09-14,
  SwiftData (rollback order, first fetch by id, container lifetime), Xcode (`OS=`, `BOOT`, sips crops, status bar).

Plan-level choices (challengeable; they fill spec gaps or resolve a spec conflict):

- **`-holdBanner` is parsed by `App/DebugSeed/DebugBannerHold.swift`**, invoked from the root's `#if DEBUG` block: spec
  §4.4 ("parsed only in the root's `#if DEBUG` block") and AC-22 (the literal only under `App/DebugSeed/`) conflict, and
  the `DebugInitialTab` shape satisfies both.
- **`MissedDay.automaticActionKey(resolution:policy:today:calendar:) -> AutomaticActionKey?` is an Engine function**, so
  B1's "nil when `.none` or `.prompt`" is unit-tested rather than buried in the host; the host ANDs it with `enabled`.
- **The banner's 3 s timer is keyed on a derived optional token, never on a `@State` write in `body`**: the key is the
  banner's token while `selected == .home` and the DEBUG hold is off, nil otherwise, so "3 s after it became visible"
  and "held until Home is next visible" fall out of one `.task(id:)`.
- **AC-21's "`SeedHomeStatsTests` rows for `missed-several` after the automatic shift and skip"** is planned as a new
  seed suite that applies `MissedDay.resolution` plus the existing writers to the seed's rows (the automatic action is
  view code and the seeds do not run it); the numbers asserted are the spec's.
- **`SettingsText.marcyDetail(unit:)` uses `WeightDisplay.wholeText`** (integer kg, "68 kg stack") and
  `dumbbellRange(unit:)` uses `WeightDisplay.text` (one decimal, "2.3–23.8 kg"), per spec 5.3.

Open question (planned around the stated default): **the trailing policy control's exact rendering is unverified.**
Default: `Picker(selection:)` + `.pickerStyle(.menu)` + `.labelsHidden()` + `.tint(Theme.mu)`, which VoiceOver reads as
a pop-up button (AC-15); settling probe = the AC-1 screenshot in Step 7. `Picker(.menu)` is reported to ignore `.font`
on its label on 17.5, so the fallback `Menu { Button… } label: { HStack { Text(label); Image(systemName:
"chevron.up.chevron.down") } }` is likely; either way it carries finding 4's explicit label and value, so the only
recorded AC-15 deviation is the trait ("button", not "pop-up button").

## 3. Steps

### Step 0 — shorthands and baselines
Write `build/settings-env.sh` (gitignored; every later command starts `cd /Users/zhabskyi/AppleApps/HomeGymLog &&
source build/settings-env.sh`):
```
# every definition of `build/progress-env.sh` (docs/plans/m4-progress.md Step 0) verbatim — DEST DEST26 BID UDID UDID26
# APP BUILD TEST ONLY COUNT RELEASE TEST26 BOOT LAUNCH SHOT APPEAR — plus:
PROTO() { (cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &); until curl -sf -o /dev/null http://127.0.0.1:8765/; do sleep 0.2; done
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=5600,5600 --virtual-time-budget=20000 \
    --screenshot=build/proto-all-5600.png "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
  sips -c 290 800 --cropOffset 4148 2555 build/proto-all-5600.png --out build/proto-settings.png >/dev/null; sips -c 680 850 --cropOffset 4456 2555 build/proto-all-5600.png --out build/proto-home-light.png >/dev/null; pkill -f "http.server 8765"; }
```
One `xcodebuild` at a time, foreground (timeout 600000); a clone-stuck run retries with `-parallel-testing-enabled NO`;
`error:` lines from the forced-failure suites are expected (judge by `TEST SUCCEEDED` and `COUNT`). Undo = restore by
hand; never `git checkout`, `git stash` or `git clean` (the new files have no commit). On HEAD before any change:
`BUILD && TEST; COUNT` (expect **807**). `BOOT $UDID; APPEAR $UDID dark`, then `LAUNCH $UDID <args>; SHOT $UDID
base-<name>` for `midProgram` (plain, `-tab program`, `-tab progress`), `missed`, `missed-several`, `missed-shifted`,
`missed-skipped`, `restDay`, `freshProgram`, `progress-history -tab progress`, all ten workout seeds, and `midProgram`
on a light simulator → `base-home-light`. Run `PROTO`, **read both crops** before use (sips crops from the centre), and
if one is wrong fix the offsets and report the numbers for the main session to record in the `design-compare` skill.

### Step 1 — Preference enums: `AppearanceMode` (Shared) and `MissedDayPolicy` (Engine)
`Shared/AppearanceMode.swift` (new; **no `import UIKit`**, NB7): `enum AppearanceMode: String, CaseIterable { case
system, dark, light }` with `static let storageKey = "appearance"`, `var label: String` ("System" / "Dark" / "Light")
and `static func from(raw: String) -> AppearanceMode` (unknown → `.system`).
`Engine/MissedDay.swift` (append): `nonisolated enum MissedDayPolicy: String, CaseIterable, Sendable { case ask, shift,
skip }` with `storageKey = "missedDayPolicy"` and `from(raw:)` (unknown → `.ask`); no text on it.
Tests `Shared/AppearanceModeTests.swift` (`@MainActor`) and `Engine/MissedDayPolicyTests.swift` (plain): raw round trip
for all three; `from(raw:)` of "sepia", "" and "Dark" → the fallback; labels verbatim; `allCases` order; each
`storageKey` against a string literal typed in the test.
Verify: `BUILD && ONLY AppearanceModeTests MissedDayPolicyTests MissedDayTests`. **AC-17.**

### Step 2 — Engine: `MissedDay.resolution`, `automaticActionKey`, `bannerDayStyle`
`Engine/MissedDay.swift` (append; total, nothing throws or traps):
```swift
nonisolated enum MissedDayResolution: Equatable, Sendable { case none, prompt(SessionSummary), shift(missedIndex: Int), skip(indexes: [Int]) }
nonisolated enum BannerDayStyle: Equatable, Sendable { case today, date }   // CalendarRules.isSameDay → .today, else .date
nonisolated struct AutomaticActionKey: Equatable, Sendable { let policy: MissedDayPolicy; let missedIndex: Int; let day: Date }
extension MissedDay {
    static func resolution(policy: MissedDayPolicy, sessions: [SessionSummary], silence: PromptSilence?, today: Date, calendar: Calendar) -> MissedDayResolution
    static func automaticActionKey(resolution: MissedDayResolution, policy: MissedDayPolicy, today: Date, calendar: Calendar) -> AutomaticActionKey?
    static func bannerDayStyle(newDate: Date, today: Date, calendar: Calendar) -> BannerDayStyle
}
```
`resolution` (spec 5.5): missed = sessions whose `HomeStats.sessionState` is `.missed`, in `HomeStats.ordered` order;
empty → `.none`; `.ask` → `.prompt(first)` iff `shouldPrompt(first, silence)` else `.none`; `.shift` →
`.shift(missedIndex: first.index)` and `.skip` → `.skip(indexes: missed.map(\.index))`, both ignoring the silence.
`automaticActionKey` → nil for `.none` / `.prompt`, else policy + the case's first index + `startOfDay(today)`.
Tests `Engine/MissedDayResolutionTests.swift` (plain; `MissedDayFixtures.input(completed:skipped:dates:)` + `TestCalendar`):
rows A–D of spec 5.5 — A (`missed`, Tue 09-15): ask → `.prompt(index 7)`, ask with the matching silence → `.none`,
shift → `.shift(7)`, skip → `.skip([7])`; B (`missed-several`, Thu 09-17): ask → `.prompt(7)`, shift → `.shift(7)`,
skip → `.skip([7, 11, 12])` also from shuffled and reversed input; C (shifted and skipped data → `.none` under all
three, `restDay` data → `.prompt(7)` / `.shift(7)` / `.skip([7])`); D (A's map applied, same day → `.none`); `[]` →
`.none`. Keys: A shift → `AutomaticActionKey(.shift, 7, startOfDay(09-15))`, equal to a hand-built value, unequal to
the 09-16 one; skip → index 7; `.prompt` and `.none` → nil. `bannerDayStyle`: 09-15 vs 09-15 noon → `.today`, 09-21 and
09-14 → `.date`. Existing `MissedDay*` suites unchanged.
Verify: `BUILD && ONLY MissedDayResolutionTests MissedDayTests MissedDayEdgeTests MissedDayStatsTests SessionStateTests`.
**AC-18**, part of **AC-16**.

### Step 3 — Shared text: `SettingsText` and the two banner strings
`Shared/SettingsText.swift` (new `enum SettingsText`): every constant of spec 4.3 verbatim (`title` … `marcy`, `restart`
ending in U+2026), plus `currentProgram(months:frequency:)` (`ProgramSummaryText.title(months:) + " · " +
"\(frequency) days"`), `policy(_:)`, `dumbbellRange(unit:)` (`WeightDisplay.text` of `EquipmentKind.dumbbell.minLb` and
`.maxLb`, joined with U+2013, + " " + the unit's raw value) and `marcyDetail(unit:)`
(`WeightDisplay.wholeText(lb: EquipmentKind.marcy.maxLb, unit:)` + " lb/kg stack").
`Shared/MissedDayText.swift` (append): `shiftedBanner(name:style:newDate:calendar:)` ("Shifted Legs to today" for
`.today`, "Shifted Legs to " + `HomeText.dayLabel(newDate)` for `.date`) and `skippedBanner(names: [String]) -> String?`
(one → "Skipped Legs", n ≥ 2 → "Skipped \(n) missed sessions", `[]` → nil).
Tests `Shared/SettingsTextTests.swift` (`@MainActor`): `currentProgram` (6, 5) / (1, 4) / (2, 3); `dumbbellRange(.lb)` /
`(.kg)` built in the test from `EquipmentKind.dumbbell.minLb`/`maxLb` through `WeightDisplay` **and** compared to
"5–52.5 lb" / "2.3–23.8 kg" (U+2013 scalar compared); `marcyDetail` both units; `policy` for all three; every fixed
string against a literal typed in the test, `restart` ending in U+2026. `Shared/MissedDayTextTests.swift` (append):
`shiftedBanner` `.today` and `.date` (Mon 2026-09-21 → "Shifted Legs to Mon, Sep 21"); `skippedBanner` for one, two,
three names and `[]`.
Verify: `BUILD && ONLY SettingsTextTests MissedDayTextTests MissedDayTextEdgeTests ProgramSummaryTextTests ClockUsageTests`.
**AC-16.**

### Step 4 — Engine: `RestartPrefill` and the draft init
`Engine/RestartPrefill.swift` (new): `nonisolated struct OnboardingAnswers: Equatable, Sendable` with `months: Int`,
`frequency: Int`, `trainingWeekdays: [Int]`, `sessionLengthMinutes: Int`, `bodyWeightLb: Double`,
`experience: Experience`, `startingWeightsLb: [String: Double]`; and `nonisolated enum RestartPrefill { static func
answers(months:frequency:trainingWeekdays:sessionLengthMinutes:bodyWeightLb:experience: String,
startingWeightsLb:) -> OnboardingAnswers }`.
Per-field fallback exactly as spec 5.2 (`ProgramGenerator.allowedMonths` / `allowedFrequencies` /
`allowedSessionLengths`, `SplitPlans.defaultWeekdays(frequency:)`, `OnboardingDraft.bodyWeightRangeLb` clamp,
`Experience(rawValue:)`, per-key `ExerciseLibrary` + `kind.isLoadable(lb:)` filter); valid weekdays returned sorted;
never throws.
`Features/Onboarding/OnboardingDraft.swift`: `convenience init(answers: OnboardingAnswers, units: WeightUnit,
bodyWeightUnit: WeightUnit)` setting every field and `step = 1`, with `bodyWeightUnitChosen = (bodyWeightUnit != units)`
as the **last statement** (NB2: both `units.didSet` and `bodyWeightUnit.didSet` fire on every assignment after
`self.init`, so an earlier write is overwritten).
Tests `Engine/RestartPrefillTests.swift` (plain): the worked `midProgram` row of 5.2 (6, 5, `[0, 1, 2, 3, 4]`, 45, 180,
`.intermediate`, plus a weight map built in the test from `StartingWeights.rows(frequency: 5, sessionLengthMinutes: 45,
overrides: [:])` — 17 keys, the lb values of 5.2 asserted as literals); every hand case (months 5 → 1; frequency 6 → 4
with `[0, 1, 3, 4]`; frequency 5 with `[0, 1, 2]` → `[0, 1, 2, 3, 4]`; `[4, 0, 2]` at frequency 3 → `[0, 2, 4]`; length
25 → 45; body weight 20 → 50, 900 → 500; experience "Pro" → `.intermediate`; `["dbBench": 41]`, `["nope": 40]`,
`["latPull": 105]` dropped, `["dbBench": 42.5]` kept); a valid custom input unchanged; `[:]` stays `[:]`. Keep the hand
cases as separate tests or a file-scope typed constant, never one long nested-tuple `@Test(arguments:)` literal
(gotchas Swift 2026-09-14).
`Onboarding/OnboardingDraftTests.swift` (append, `@MainActor`): the draft from the `midProgram` answers with units lb →
`step == 1`, `days == [0, 1, 2, 3, 4]`, `startingWeightRows` count 17; setting `units = .kg` afterwards also moves
`bodyWeightUnit` (not chosen); the same draft built with `units: .lb, bodyWeightUnit: .kg` keeps `.kg` after
`units = .kg` **and** after `units = .lb` (NB2).
Verify: `BUILD && ONLY RestartPrefillTests OnboardingDraftTests OnboardingDraftEdgeTests ExerciseKeysTests`. **AC-19.**

### Step 5 — Persistence: archive → start, and the automatic passes over store rows
No production change: this step pins, with the existing writers, the behaviour restart and the policy rely on.
Tests `Persistence/RestartFlowTests.swift` (new, `#if DEBUG`, `@MainActor`, container held): `MidProgramSeed.populate`;
`archive(program, at: 09-15 11:59)` → true; `ProgramStore.start` with the `RestartPrefill`-derived inputs at 09-15 12:00
→ non-nil; a **fresh** `ModelContext(container)` then reads `current` == the new program, `fetchCount(currentPredicate)`
1, `fetchCount(archivedProgramPredicate)` 1, the archived program's 120 sessions and its completed / log / set /
`ExerciseNote` counts unchanged; a second `archive` → false with `hasChanges == false`.
`Persistence/AutomaticPolicyPassTests.swift` (new, `#if DEBUG`, `@MainActor`): from `DebugSeed.missedSeveral`'s
container and rows, `MissedDay.resolution(policy: .skip, …, today: 09-17 noon)` → `.skip([7, 11, 12])`, and
`ProgramStore.skipMissed` per index in order → three `true`, `hasChanges == false`, a fresh context reading 7, 11, 12
`.skipped` with every date unchanged; the same rows with `.shift(7)` through `ProgramStore.shift` → case B's dates in a
fresh context (s7 Thu 09-17, s11 09-18, s12 09-21, s13 09-22); a second `resolution` on the written rows → `.none`.
`Seed/AutomaticPolicySeedTests.swift` (new, `#if DEBUG`, `@MainActor`, the `SeedHomeStatsTests` input helper): each pass
is driven by `MissedDay.resolution`'s case, never hand-typed indexes (AC-21). After the shift pass on `missed-several`
rows `HomeStats` reads streak 10, 10 of 120, 7 560, week 2; after the skip pass 0, 10 of 120, 7 560, week 3; on
`missed` rows the two passes match the `missed-shifted` and `missed-skipped` seeds' numbers.
Verify: `BUILD && ONLY RestartFlowTests AutomaticPolicyPassTests AutomaticPolicySeedTests ProgramArchiveTests
ProgramArchiveRollbackTests MissedDayStoreTests MissedDayStoreEdgeTests RoutingPredicateTests SeedHomeStatsTests`.
**AC-20**, part of **AC-21**.

### Step 6 — `RootView`: the appearance applier
`App/RootView.swift`: `import UIKit`; `@AppStorage(AppearanceMode.storageKey) private var appearanceRaw =
AppearanceMode.system.rawValue`; a private idempotent `applyAppearance(_ mode: AppearanceMode)` that walks
`UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)` and sets
`window.overrideUserInterfaceStyle` (`.unspecified` / `.dark` / `.light`) through a private `style(for:)` switch (the
app's only `UIUserInterfaceStyle`, NB7), called from the existing `.onAppear` (after the `initialTab` block) and from
`.onChange(of: appearanceRaw)`. `.preferredColorScheme` is used nowhere. Tests: none (Step 11's scans pin placement).
Verify: `BUILD && TEST; COUNT` (no regression), then `/design-compare home-light` on `-seed midProgram -appearance
light` with the simulator **dark** (against `build/proto-home-light.png`); with the simulator **light**, `-appearance
dark` must match `base-home` and plain `-seed midProgram` must match `base-home-light` (System still follows the
simulator); `APPEAR $UDID dark`. **AC-4** (Home half).

### Step 7 — The Settings screen, the shell route, and the end of `PlaceholderScreen`
`Shared/SegmentedPicker.swift`: add `case settings` to `Style` (NB1). It needs **seven** of the file's ternaries and
switches, not four: spacing 3 (`:21`), horizontal padding 12 and vertical 5, selected foreground `Theme.tx` (today a
hard-coded `Color.white`, `:29`) on a `Theme.sf` background with `Theme.mu` elsewhere, segment radius 7, container
padding 3 and radius 9, font 12.5 semibold, and **not** equal-width (`:32` keeps `nil` for `.pill` and `.settings`).
`App/AppClock.swift`: `@Entry var settingsRestartPreview: Bool? = nil` (nil default, `workoutSheetPreview` precedent).
`Features/Settings/SettingsView.swift` (new): `struct SettingsView: View { let program: Program; @Binding var
selectedTab: AppTab }` with the three `@AppStorage` keys, `@Environment(\.appClock)`, `\.modelContext`,
`\.settingsRestartPreview`, `@State private var showsRestartConfirm = false` and `@State private var archiveError:
String?` (NB8). Body: `ScrollView` → `SettingsContent` (second file `Features/Settings/SettingsContent.swift` once the
body passes ~80 lines, with `SettingsRow` / `SettingsCard`), 18 pt sides, 8 pt top, `Theme.bg`, navigation bar hidden;
`.confirmationDialog(SettingsText.restartTitle, isPresented: $showsRestartConfirm, titleVisibility: .visible)` with a
`.destructive`, a `.cancel` and the message closure; `.alert(SettingsText.archiveFailedTitle, isPresented: <derived
from archiveError>)` with one `SettingsText.ok` button and the message; `.onAppear { if settingsRestartPreview == true
{ showsRestartConfirm = true } }` (if 17.5 drops a dialog presented during `RootView`'s `initialTab` switch, present it
from `.onChange(of: selectedTab)`; AC-5's shot is the probe). Rows exactly as spec 2.1–2.4: two
`SegmentedPicker(style: .settings)`, two disabled `Toggle`s with "Coming soon", the Program card (Current, the policy
picker, the restart button), the Equipment card (`EquipmentKind` through `SettingsText`, never literals).
**Accessibility (AC-15):** a **read-only value row** is one element (`.accessibilityElement(children: .combine)`); a row holding a control (the two segmented pickers, the two disabled toggles, the policy picker) is never combined, or the control would fold into it and AC-15's order would break (finding 17). The policy
control carries `.accessibilityLabel(SettingsText.missedDay)` + `.accessibilityValue(SettingsText.policy(policy))`
whichever rendering ships (`.labelsHidden()` alone speaks the value as the label); `SegmentedPicker` adds `.isSelected`.
`Features/Settings/RestartAction.swift` (new, so AC-13 is a gate, not an optional tap): `@MainActor enum RestartAction
{ enum Outcome: Equatable { case archived, alreadyArchived, failed(String) }; static func run(program: Program, at:
Date, in context: ModelContext) -> Outcome }` — `ProgramStore.archive` true → `.archived`, false → `.alreadyArchived`,
a throw → `.failed(SettingsText.archiveFailedMessage)` with **no assert inside `run`** (finding 16: an assert there would trap the `allowsSave: false` test in Debug; the `assertionFailure` belongs in `confirmRestart()`'s `.failed` case). `confirmRestart()` switches on it:
`.archived` / `.alreadyArchived` (harmless, NB6) set `selectedTab = .home` **after** the save, `.failed(message)` sets
`archiveError = message`, `assertionFailure`s, and leaves the tab on Settings.
`App/ShellView.swift`: `case .settings: SettingsView(program: program, selectedTab: $selected).id(program.id)`; the
`default:` arm goes away (the switch is exhaustive). Delete `Shared/PlaceholderScreen.swift` and
`AppTab.placeholderMilestone` (nothing else references them).
Tests `Persistence/RestartActionTests.swift` (new, `@MainActor`): in memory, `run` → `.archived` with `archivedAt` ==
the passed date, a second `run` → `.alreadyArchived` with `hasChanges == false`; on the `ProgramArchiveRollbackTests`
on-disk `allowsSave: false` fixture shape (its helper is `private`, so copy the shape rather than calling it), `run` → `.failed(SettingsText.archiveFailedMessage)` and a fresh context reads
`archivedAt == nil` (then `context.rollback()` before the store file is removed, gotchas SwiftData 2026-09-14).
Verify: `BUILD && ONLY RestartActionTests ProgramArchiveRollbackTests; TEST; COUNT` (no regression), then
`/design-compare settings` with `-seed midProgram -tab settings` against `build/proto-settings.png` (**AC-1**, listed
deviations only); `-seed freshProgram -tab settings` → "1-month program · 4 days", `-missedDayPolicy shift` → "Always
shift" (**AC-2**); `-units kg` → "2.3–23.8 kg", "68 kg stack", Current unchanged, plus the `-seed midProgram -units kg`
Home regression (**AC-3**); `-appearance light` on a dark simulator → light Settings, "Light" selected (**AC-4**).
**AC-1–AC-4**, **AC-13** (outcome + store; the alert's pixels stay Step 12 / the user), **AC-15** (structure only).

### Step 8 — Seeds `settings-restart` and `restarted`, and the restart prefill in `RootView`
`App/DebugSeed/RestartSeed.swift` (new, whole file `#if DEBUG`): `enum RestartSeed { static func populate(in context:
ModelContext, calendar: Calendar) throws }` — `MidProgramSeed.populate`, then `ProgramStore.archive(program, at: Tue
2026-09-15 11:59, in:)`, `preconditionFailure` when it returns false (the `ProgressHistorySeed` shape).
`App/DebugSeed/DebugSeed.swift`: `case settingsRestart = "settings-restart"` and `case restarted`; `referenceDate` →
09-15 12:00 for both; `initialDraft` → nil for both; `makeContainer` → `MidProgramSeed.populate` for
`settings-restart`, `RestartSeed.populate` for `restarted`; `forcesMissedDayPrompt` false for both; new
`var settingsRestartPreview: Bool? { self == .settingsRestart ? true : nil }`.
`App/HomeGymLogApp.swift`: the `seed.settingsRestartPreview` read sits inside the `#if DEBUG` seed branch, its local is
passed by one `.environment(\.settingsRestartPreview, …)` line in `body` (the `missedPromptEnabled` shape, finding 9).
`App/RootView.swift`: `@Query(filter: ProgressSnapshotBuilder.archivedProgramPredicate) private var archivedPrograms:
[Program]` (B2; **no sort descriptor on the optional `archivedAt`**, no `FetchDescriptor` in the file); a private
`prefillDraft() -> OnboardingDraft?` takes `archivedPrograms.max(by: { ($0.archivedAt ?? .distantPast) < ($1.archivedAt
?? .distantPast) })`, feeds its scalars to `RestartPrefill.answers` and returns `OnboardingDraft(answers:units:
bodyWeightUnit:)` from `unitsRaw` and a **new** `@AppStorage("bodyWeightUnits") private var bodyWeightUnitsRaw` (only
`OnboardingView` reads that key today); the branch becomes `OnboardingView(initialDraft: seedDraft ?? prefillDraft() ?? OnboardingDraft(units:))`, **no `.id`**.
Tests `Seed/DebugSeedTests.swift` (edit, or the step goes red): its `referenceDate` switch ends in `default:` = Aug 31,
so add `case .settingsRestart, .restarted:` → `TestCalendar.day(2026, 9, 15)`, and add both seeds to the
`initialDraft == nil` loop. `Seed/RestartSeedTests.swift` (new, `#if DEBUG`, `@MainActor`, container held): the row
counts equal `midProgram`'s (120 sessions, 10 finished logs), `forcesMissedDayPrompt == false`,
`settingsRestartPreview == true` and nil for every other seed (`DebugSeed.allCases`); `restarted` — `ProgramStore
.current` nil, exactly one archived program with `archivedAt` == Tue 2026-09-15 11:59 and ten completed sessions,
`initialDraft(calendar:)` nil, and `RestartPrefill.answers` from its scalars equals Step 4's `midProgram` expectation
with the weight keys in `SplitPlans.exerciseKeys(frequency: 5, sessionLengthMinutes: 45)` order.
Verify: `BUILD && ONLY RestartSeedTests DebugSeedTests MidProgramSeedTests SeedHomeStatsTests RestartPrefillTests;
TEST; COUNT`, then `-seed settings-restart -tab settings` (dialog copy, destructive red, Settings unchanged behind it),
the same with `-appearance dark` on a **light** simulator and `-appearance light` on a dark one, both also on `$UDID26`
(**AC-5**), and `/design-compare ob1` on `-seed restarted` plus `-units kg` (**AC-6**). **AC-5, AC-6, AC-21.**

### Step 9 — The prompt host acts automatically
`Features/Home/MissedPromptHost.swift`: add `@AppStorage(MissedDayPolicy.storageKey) private var policyRaw =
MissedDayPolicy.ask.rawValue`. In `body`, derive the policy and `let resolution = enabled == false ? .none :
MissedDay.resolution(policy:sessions:silence:today:calendar:)`, and draw the prompt only for `case .prompt` (the
resolution replaces the `shouldPrompt` call; the card reads the associated value). The root becomes full-size
(`ZStack(alignment: .bottom) { … }.frame(maxWidth: .infinity, maxHeight: .infinity)`; P1: still intercepts no touch).
Add `.task(id: enabled == false ? nil : MissedDay.automaticActionKey(resolution:policy:today:calendar:))`; its body
**guards on the resolution's case first** (P2: the task also runs at mount with a nil id), then runs **synchronously,
no `await`**: `.shift(index)` → one `ProgramStore.shift(…, today: clock.now(), …)`; `.skip(indexes)` → a `for` loop of
`ProgramStore.skipMissed(sessionIndex:…, today: clock.now(), …)` earliest first, stopping at the first throw, each
`catch` `assertionFailure`ing and returning. `today` for the key is `now ?? clock.now()` (never `onAppear`-written
state, P2). Add `.onChange(of: policyRaw) { silence = nil }` (NB3). No Program-tab hook (NB5).
Tests `Static/MissedPromptSourceTests.swift` (append): `@AppStorage(MissedDayPolicy.storageKey)` in exactly
`["Features/Home/MissedPromptHost.swift", "Features/Settings/SettingsView.swift"]`; the host contains
`MissedDay.resolution(` and `.task(id:`, and no line containing `ProgramStore.skipMissed(` or `ProgramStore.shift(` in
that file also contains `await` (stable tokens only).
Verify: `BUILD && ONLY MissedPromptSourceTests AutomaticPolicySeedTests; TEST; COUNT`, then `-seed missed
-missedDayPolicy shift` / `skip` must match `base-missed-shifted` / `base-missed-skipped`, `-seed missed` alone still
matches `base-missed`, `-seed missed-several -missedDayPolicy shift` / `skip` show spec 5.5 row B's Home and, with
`-tab program`, the repaired schedule, while `-seed midProgram -tab settings -missedDayPolicy shift` writes nothing (Step 7's shot). **AC-7** (state half).

### Step 10 — The Home banner
`App/DebugSeed/DebugBannerHold.swift` (new, `#if DEBUG`): `enum DebugBannerHold { static func parse(arguments:
[String]) -> Bool? }` → `true` iff `"-holdBanner"` is present, else nil. `App/AppClock.swift`: `@Entry var
missedBannerHold: Bool? = nil`; `App/HomeGymLogApp.swift`: one parse line in the root's `#if DEBUG` block, one
`.environment(\.missedBannerHold, …)` line in `body`.
`Features/Home/MissedActionBanner.swift` (new): `struct MissedDayBanner: Equatable { let text: String; let token: Int }`
and `struct MissedActionBanner: View { let text: String; let onTap: () -> Void }` — `sf`, radius 12, 1 pt `bd` border,
the pill's shadow, 13 pt semibold `tx`, one line tail-truncated, 8 pt accent dot leading, padding 12/14, one
accessibility element with `.isButton` labelled by the text.
`Features/Home/MissedPromptHost.swift`: `@State private var banner: MissedDayBanner?` and `bannerToken = 0`; the Step 9
task sets `banner = MissedDayBanner(text: …, token: bannerToken + 1)` from `MissedDayText.shiftedBanner(…)` (name and
date from the applied map, style from `MissedDay.bannerDayStyle`) or `MissedDayText.skippedBanner(names:)` over the
sessions the pass actually skipped, and bumps the token; nothing on a throw or an empty result. Draw it in
`.overlay(alignment: .top)` on the full-size root when `selected == .home`, 18 pt sides, 8 pt below the top safe area,
`.move(edge: .top).combined(with: .opacity)` animated 0.25 s unless
`@Environment(\.accessibilityReduceMotion)`. **One derived token drives both the announcement and the timer** (read in
`body`, never written there; gotchas Swift 2026-09-22): `let visibleToken: Int? = selected == .home ? banner?.token :
nil` and `let timerToken: Int? = missedBannerHold == true ? nil : visibleToken`. Announce
`AccessibilityNotification.Announcement(text).post()` from `.onChange(of: visibleToken)` when the new value is non-nil
(the `RestText.restOver` precedent), so it fires when the banner *appears on Home*, not when the action runs elsewhere. Auto-dismiss: `.task(id: timerToken) { guard let timerToken else { return }; do { try await
Task.sleep(for: .seconds(3)) } catch { return }; if banner?.token == timerToken { banner = nil } }` — **the `catch`
`return` is the point**: leaving Home cancels the task and the banner must survive, so it is cleared only after a full
3 s of visibility (returning to Home restarts the 3 s and re-announces the same text). A tap sets `banner = nil`.
Tests `Static/SeedNameScanTests.swift` (append): `"settings-restart"`, `"restarted"` and `"-holdBanner"` appear only
under `App/DebugSeed/`, and each appears there; `App/AppClock.swift` declares `missedBannerHold` and
`settingsRestartPreview` as nil-by-default `Bool?` `@Entry`s on one line each (the `workoutSheetPreview` scan shape,
`Bool?` with or without `= nil`); in `App/HomeGymLogApp.swift` exactly one line carries `.environment(\.missedBannerHold`
and one `.environment(\.settingsRestartPreview` (both live in `body`, **outside** `#if DEBUG`, like
`missedPromptEnabled`), while the line reading `seed.settingsRestartPreview` sits inside the `DebugSeed.parse(` block
before its `#endif` (the `MissedPromptSourceTests` / `ProgressSourceTests` shape).
Verify: `BUILD && ONLY SeedNameScanTests MissedPromptSourceTests; TEST; COUNT`, then `-seed missed -missedDayPolicy
shift -holdBanner` ("Shifted Legs to today" over the `missed-shifted` Home, tab pill uncovered), `skip -holdBanner`
("Skipped Legs"), `missed-several … skip -holdBanner` ("Skipped 3 missed sessions") and `missed-several … shift
-holdBanner -tab program` (**no** banner). Then **re-shoot Step 9's four plain `-missedDayPolicy` launches ≥ 4 s after
launch** (`SHOT` sleeps 3 s; use `sleep 5` or a second shot) so the banner has gone, and confirm they still match
`base-missed-shifted` / `base-missed-skipped` and row B: the banner covers the top of Home for its first 3 s, which
spec §8's "wait ≥ 2 s" would otherwise catch. **AC-7** (banner half, plus the state half re-checked).

### Step 11 — Static scans, regression sweep, Release and 26.5
`Static/SettingsSourceTests.swift` (new; the `MissedPromptSourceTests` file-walk — `pathExtension == "swift"` only, so
the eight `Assets.xcassets/*/Contents.json` `"appearance"` keys are out of scope — `//` comments stripped,
`#expect(files.count > 40)` so an empty scan fails): `"appearance"` / `"missedDayPolicy"` only on the two `storageKey`
lines (`Shared/AppearanceMode.swift`, `Engine/MissedDay.swift`); `@AppStorage(AppearanceMode.storageKey)` in exactly
`["App/RootView.swift", "Features/Settings/SettingsView.swift"]`; `preferredColorScheme` nowhere;
`overrideUserInterfaceStyle` and `import UIKit` only in `App/RootView.swift`; a `settings` case on
`SegmentedPicker.Style`, no `SettingsSegmentedControl`, no `PlaceholderScreen`, no `placeholderMilestone`, no `FetchDescriptor` in `App/RootView.swift`.
Verify: `BUILD && TEST; COUNT` (full suite), `RELEASE`, `TEST26`; then re-shoot every `base-*` launch of Step 0 and
`cmp` each against its baseline (a status-bar-corner-only diff is the known Xcode artifact). **AC-8, AC-22, AC-23.**

### Step 12 (optional) — scratch-copy XCUITest for the tap- and time-dependent criteria
Only if the user wants AC-9–AC-14 machine-checked before the MVP pass (AC-13's outcome is already gated in Step 7).
Copy the repo to the scratchpad, add a UI-test target **to the copy's project**, change its bundle id (INSIGHTS
"Real-touch probes"); the repo's `project.pbxproj` is untouched and the step is skipped by deleting the copy. Taps are
traced through the state machine first (a policy change re-renders the host in the same frame; the dialog covers the
rows; the banner draws above the content and blocks nothing):
1. **AC-9** from `-seed midProgram -tab settings`, simulator light: assert "System" selected, tap "Dark", sample a dark
   pixel on Settings and on Home (via the pill), open Home's ⓘ sheet and sample it, tap "Light" from a dark simulator,
   tap "System" back. **AC-10**: tap "kg", assert "2.3–23.8 kg" and a kg Home row, tap "lb", assert "5–52.5 lb".
2. **AC-11 / AC-12**: tap "Build a new program…", assert the dialog title, tap "Cancel", assert Current still reads
   "6-month program · 5 days"; relaunch, confirm, assert A2 with "6 months", walk Continue to "Start program", then
   assert the Home pill is selected (not Settings) and the header date. **AC-13** (pixels): on an `allowsSave: false`
   store, confirm, assert the alert title, tap OK, assert Settings still shows with Current unchanged.
3. **AC-14**: from `-seed missed -tab settings` pick "Always shift", switch to Home, assert the Today card reads "Legs"
   and the banner "Shifted Legs to today" exists, then that it is gone after 4 s (the positive assertion comes first in
   the same launch, so the absence check can fail); leave Home inside the 3 s and return — the banner is still there, and gone 3 s after the return
   (finding 1); relaunch with `-holdBanner`, tap the banner, assert it is gone; with the banner up, tap Home's ⓘ (sheet
   opens) and the Program pill (tab switches) — the P1 regression check — and repeat those two taps on `-seed midProgram`.
Report pass/fail per AC; nothing in the repo changes. **AC-9, AC-10, AC-11, AC-12, AC-13, AC-14.**

## 4. Data model changes

**None.** No `@Model`, relationship, delete rule or `#Predicate` is added or altered: no migration impact. The only
SwiftData addition is a *read*, a third `@Query` in `RootView` on the existing
`ProgressSnapshotBuilder.archivedProgramPredicate` (`#Predicate<Program> { $0.archivedAt != nil }`, verified on 17.5
and 26.5 by m4-progress). Writes reuse `ProgramStore.archive` / `shift` / `skipMissed` unchanged, each one
`StoreCommit.commit` save; Step 5 is the iOS 17.5 persistence test for the archive → start round trip and the
automatic passes, `ProgramArchiveRollbackTests` still covers the failed-archive restore, and every preference
(`appearance`, `units`, `bodyWeightUnits`, `missedDayPolicy`) stays in `UserDefaults` via `@AppStorage`.

## 5. Risks and gotchas

| Risk | Mitigation |
|---|---|
| `.task` runs before `onAppear` on 26.5 (gotchas SwiftUI 2026-09-22) | The key and the task body read `now ?? clock.now()` and `clock.now()`, never `@State` that `onAppear` writes (Step 9) |
| An `await` inside the skip pass cancels the task after the first save and mis-labels the banner (B1) | The pass is one synchronous loop; the static scan in Step 9 keeps `await` out of it |
| The banner's environment read after an `await` would be stale (gotchas Swift 2026-09-22) | `missedBannerHold` is read in `body` and captured before the sleep (Step 10) |
| A full-size host root blocking every tap | Verified by P1 on both runtimes; Step 12 re-checks it; fallback (B3) is a shell-drawn banner from a `Binding` the host writes |
| A cancelled 3 s task clearing a banner the user only navigated away from | The timer's `catch { return }` and the `selected == .home` token make the 3 s *visible* time (Step 10, finding 1); Step 12 trace 3 checks it |
| `.preferredColorScheme` (fails on 17.5 alerts) or a `UIColor(named:)` resolved outside a body (ignores the override) | Step 11 scans for both; Theme is all `Color("name")` |
| `simctl ui appearance` is the *system* appearance; launch arguments must reach the seed suite | Every recipe states the stored **and** the simulator mode; only readers below `.defaultAppStorage` are added (`RootView`, `SettingsView`, `MissedPromptHost`), never `HomeGymLogApp`'s own body (P4) |
| `sips --cropOffset` misbehaving; stale baselines after an Xcode update; a DEBUG type used outside `#if DEBUG` | Step 0 reads both crops before use; Step 11 treats a status-bar-only diff as the known artifact and runs the Release build (nothing outside `ShellView` referenced `PlaceholderScreen`, grepped at plan time) |
| The `restarted` seed's prefill silently regressing when the draft is rebuilt on a later root render | `OnboardingView` copies `initialDraft` once via `State(initialValue:)`; no `.id` is put on the onboarding branch (B2) |
| Two presentations on one screen; the policy control's rendering | Dialog and alert never coexist (P3, NB8), so the alert is raised straight from the dialog's button action; the control is settled by the AC-1 screenshot with the fallback written down |

## 6. Definition of done

- [ ] `-seed midProgram -tab settings` matches the prototype's `settings` frame with only the listed deviations, the
      pill highlights Settings and no placeholder text remains on any tab; `-seed freshProgram -tab settings` reads
      "1-month program · 4 days", `-units kg` shows "2.3–23.8 kg" / "68 kg stack", `-missedDayPolicy shift` "Always shift".
- [ ] Simulator dark: `-seed midProgram -appearance light` matches `home-light`, its Settings variant is light with
      "Light" selected; simulator light: `-appearance dark` matches `home`, plain `-seed midProgram` still follows;
      `-seed settings-restart -tab settings` shows the dialog in the chosen appearance on 17.5 and 26.5, and
      `-seed restarted` opens onboarding at A2 with "6 months" selected.
- [ ] `-seed missed -missedDayPolicy shift` / `skip` reproduce `missed-shifted` / `missed-skipped` with no prompt once
      the banner has gone (shot ≥ 4 s after launch), the `missed-several` variants (including `-tab program`) show the
      repaired schedule, and `-holdBanner` shows the three banner texts over Home and none on the Program tab.
- [ ] By hand (MVP pass): Dark/Light/System repaints every tab, sheet, alert and dialog; kg/lb repaints every weight;
      Cancel leaves the program current; "Archive and start over" lands on Home with the new program while Progress
      keeps the old history; a policy picked while a prompt is up acts at once; the banner goes after ~3 s and on tap;
      VoiceOver reads AC-15's order.
- [ ] Full suite green on iPhone 15 / iOS 17.5 **and** iPhone 17 / iOS 26.5, Release build green, every `base-*`
      screenshot unchanged, `project.pbxproj` untouched.

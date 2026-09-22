# m4-settings architecture review (spec `docs/specs/m4-settings.md`, 2026-09-22)

**Verdict: approve with changes.** Every settled decision holds: pounds canonical (equipment text through `WeightDisplay`),
preferences in `UserDefaults`, no schema change, no new store writer (restart reuses `ProgramStore.archive`, the automatic
policy reuses `shift` / `skipMissed`), routing stays a live `@Query` flip, `import UIKit` is an SDK framework with no
capability, pure `MissedDay.resolution` and `RestartPrefill` in Engine, every string in Shared, DEBUG additions under
`App/DebugSeed/` behind nil-by-default `@Entry` values. Three items must change before the planner starts: the automatic
action's task key contradicts the spec's own retry rule, the restart prefill has no stated owner (and the obvious shortcut is
a fetch in `body`), and the banner's placement needs the prompt host's root to change shape on an unverified assumption.

Sources read: the spec, `docs/reviews/m4-settings-researcher.md` (facts treated as binding), `insights/INSIGHTS.md`,
`insights/gotchas.md`, `Features/Home/MissedPromptHost.swift`, `App/ShellView.swift`, `App/RootView.swift`,
`App/HomeGymLogApp.swift`, `App/AppClock.swift`, `App/AppTab.swift`, `App/DebugSeed/*`, `Models/ProgramStore.swift`,
`Models/StoreCommit.swift`, `Models/Program.swift`, `Engine/MissedDay.swift`, `Engine/ProgramGenerator.swift` (validation),
`Features/Onboarding/OnboardingDraft.swift`, `Features/Onboarding/OnboardingView.swift`, `Features/Program/ProgramView.swift`,
`Features/Home/HomeView.swift`, `Features/Progress/ProgressTabView.swift` (archived query precedent), `Shared/MissedDayText.swift`,
`Shared/SegmentedPicker.swift`, `HomeGymLogTests/Static/{MissedPromptSourceTests,ClockUsageTests,SeedNameScanTests}.swift`.

---

## Blocking

**B1 — The task key cannot deliver the retry rule the spec states (§2.6 "Idempotent", §5.5 last paragraph, §6 "Automatic skip
fails on the second of three", "Automatic action across midnight in the foreground").**
§5.5 keys the task on `(policy, first.index, startOfDay(now))` and says a failed write "leaves the same key → no re-run until
`now` refreshes (appear, scene-active, tab change)". Within one calendar day every refresh of `now` yields the same
`startOfDay`, so the key does not change and `.task(id:)` does not re-run: scene-active and tab changes never retry. Also, the
host refreshes `now` only when the tab becomes Home (`MissedPromptHost.swift:62-64`), not on "a tab change". The two sentences
describe different mechanisms; the planner cannot implement both.
*Change (recommended):* keep the minimal key and state the retry points that the key actually gives: **shell mount** (`.task`
runs at mount; covers relaunch and the remount after a workout), **a policy change**, **a new calendar day** (via `now`
refreshed on scene-active or the Home tab), and **a different first-missed index**. A failed write is Debug-asserted and the
Program card's manual buttons are the fallback until one of those happens; drop "the next refresh point retries". If a same-day
retry is wanted instead, add a `refreshToken` bumped in the three `now` handlers to the key and say so; that re-runs a no-op task
on every return to Home (harmless, resolution `.none`). Either way the spec must also say: (a) the key is a small `Equatable`
struct (a tuple is not `Equatable`, so `.task(id:)` will not accept it), nil when `enabled == false` or the resolution is `.none`
or `.prompt`; (b) the shift or the whole skip pass runs **synchronously inside one task body with no `await`**, so the query
cannot re-fetch between the three skip saves and change the key mid-pass (an `await` between saves would cancel the task after
the first save, restart it keyed on index 11, and the banner would read "Skipped Legs" instead of "Skipped 3 missed sessions");
(c) `today` for the write is `clock.now()` at fire time (M3 rule), `today` for the resolution is the host's `now ?? clock.now()`
as for the prompt.
*React:* `useEffect(fn, [policy, firstIndex, day])` — the effect re-runs only when a dependency changes; "a refresh" that leaves
every dependency equal is not a re-run.

**B2 — The restart prefill has no stated reader shape; the root must not fetch in `body` (§4.1 "Restart prefill", §4.4, seed
`restarted`, AC-6).** §4.1 says the newest archived program is "read by the root when no current program exists and no seed draft
was given" and stops there. `RootView` today owns two `@Query`s and reads nothing else; the natural shortcut, a
`FetchDescriptor` inside the onboarding branch of `body`, breaks the "`@Query` for persisted reads" rule and runs on every root
render (every save re-runs a query owner's `body`, gotchas 2026-09-13).
*Change:* a third root query, `@Query(filter: ProgressSnapshotBuilder.archivedProgramPredicate) private var archivedPrograms`
(the predicate already exists and is verified on 17.5 and 26.5; the row count is the number of restarts, a handful). Pick the
newest **in Swift** (`max(by: archivedAt)`), never through a sort descriptor on the optional `archivedAt` (unverified on 17.5;
`ProgressTabView` sorts its archived query by the non-optional `createdAt`). The onboarding branch becomes
`OnboardingView(initialDraft: seedDraft ?? archivedPrograms.newest.map(prefillDraft) ?? OnboardingDraft(units:))`, where
`prefillDraft` reads the row's scalar fields (`months`, `frequency`, `trainingWeekdays`, `sessionLengthMinutes`, `bodyWeightLb`,
`experience`, `startingWeightsLb`) into `RestartPrefill.answers` and then `OnboardingDraft(answers:units:bodyWeightUnit:)`.
Say in §4.4 that this is safe because `OnboardingView` copies `initialDraft` into `@State` once (`State(initialValue:)`,
`OnboardingView.swift:16-18`): later root re-renders rebuild the draft value and SwiftUI ignores it, so answers typed after the
restart cannot be reset by a save or a query refresh. No `.id` on the onboarding branch (a key change would wipe the answers).
*React:* `useState(initialProp)` ignores later prop values; that is the behaviour the prefill relies on.

**B3 — A top-of-screen banner changes the prompt host's root geometry, and "intercepts touches only inside its own frame" is
unverified (§2.7 "Placement", §4.3 proposed files, AC-7 banner checks, AC-14 "Banner").** The host's root is
`ZStack(alignment: .bottom) { if shows { … } }` inside `ShellView`'s `.overlay` (`MissedPromptHost.swift:40-57`): with nothing
to show it is zero-sized at the overlay's centre, which is why it intercepts no touch (researcher addendum P1 probed exactly
that). A banner "8 pt below the top safe area" cannot be positioned from a zero-sized, centred root: the root must become
full-size (`.frame(maxWidth: .infinity, maxHeight: .infinity)`) with the banner in `.overlay(alignment: .top)`, or the banner must
live outside the host. A full-size transparent SwiftUI container is expected not to hit-test (no drawn content, no
`contentShape`), but nothing in the researcher reports or gotchas proves it, and a wrong guess blocks every tap on every tab.
*Change:* pick the full-size root and state it in §4.4; mark "a full-size transparent host root intercepts no touch (17.5 and
26.5)" as **unverified**, settled by the first plan step: a scratch-copy XCUITest on `-seed missed-several -missedDayPolicy shift
-holdBanner` that coordinate-taps Home's ⓘ (info sheet opens) and the Program pill (tab switches) with the banner up, and the
same on `-seed midProgram` (host empty but full-size). Fallback if it fails: the banner state stays in the host but is drawn by
`ShellView` from a `Binding` the host writes (`.overlay(alignment: .top)` as a second shell overlay; `ShellView` gains one
`@State`, not a query, so the "shell never owns a query" rule holds). Also keep the banner's tap handler on the banner view itself
and give the host's spec text the banner state shape: one `@State banner: MissedDayBanner?` (text + a token bumped per result +
`visibleSince: Bool`), shown when `selected == .home`, cleared by a `.task(id: token)` sleeping 3 s (skipped when the DEBUG
`missedBannerHold == true`; read the environment value before the `await`, gotchas Swift 2026-09-22), dropped with the host.
*React:* the modal root is `position: fixed; inset: 0` with `pointer-events: none` on the container and `auto` on the card; the
question is whether SwiftUI gives you the `pointer-events: none` for free.

---

## Non-blocking

**NB1 — Fourth `SegmentedPicker` style, not a `SettingsSegmentedControl` (§4.3 proposed files).** The prototype's Settings
control (`sf2` container, selected segment `sf` + `tx`, others `mu`, 12.5 pt) differs from the three existing styles only in
colours and padding; `SegmentedPicker` already takes a `Style` and a `container` override. A second segmented control type with one
screen using it is the one-conformer abstraction the checklist flags. Add `case settings` to `SegmentedPicker.Style`.

**NB2 — Draft init from the prefill: mark the body-weight unit as chosen when the two preferences differ (§4.3
`OnboardingAnswers`, §5.2 last sentence).** `OnboardingDraft.units.didSet` overwrites `bodyWeightUnit` until
`bodyWeightUnitChosen` is set (`OnboardingDraft.swift:11-18`). A user who chose kg body weight with lb units would lose that on the
first A1 toggle after a restart. In the new init set `bodyWeightUnitChosen = (bodyWeightUnit != units)`.

**NB3 — "Switching back to Ask shows the prompt again" is true unless the user silenced that session today (§2.6 "Silence").**
The silence `@State` survives the policy round-trip (same host mount). Say "unless silenced for that session and day", or reset
`silence` when the policy changes. Reset is simpler and matches "silence applies to the prompt only".

**NB4 — Engine decides "today or a date" for the shift banner, Shared only formats (§4.3 `MissedDayText.shiftedBanner`).**
`shiftedBanner(name:newDate:today:calendar:)` puts a same-day comparison in Shared. Mirror the existing split
(`MissedDay.dayLabelStyle` → `MissedDayText.title`): an Engine `MissedDay.bannerDayStyle(newDate:today:calendar:) -> .today |
.date` or reuse `CalendarRules.isSameDay` from Shared; either keeps one home for calendar logic.

**NB5 — An automatic shift while the Program tab is showing does not follow today (§2.6, AC-7 `-tab program`).** The manual
Program-card shift sets `.followToday` + `now` + the scroll token (`ProgramView.swift:83-95`); the host's automatic shift cannot
reach that state. AC-7's `-tab program` expectation still holds because `reset` runs on appear and on every tab change, and a
foreground shift across midnight on the Program tab merely leaves the selection where it was. State this in §2.6 so nobody adds a
cross-feature hook for it.

**NB6 — Restart handler order is right; say why in §5.4.** `archive` saves synchronously, `selectedTab = .home` follows in the
same handler, and the route flip renders on a later turn, so no frame of the old shell on Home is possible and a thrown archive
leaves the tab on Settings. The `finish` precedent writes the tab first only because the shell remounts in the same route.
A returned `false` (already archived) may still set Home; harmless.

**NB7 — `AppearanceMode` stays UIKit-free (§4.3, AC-22).** The researcher's sample puts `import UIKit` and `interfaceStyle` on
the enum; the spec's AC-22 wants `import UIKit` only in `RootView.swift`. Keep the `UIUserInterfaceStyle` switch as a private
function in `RootView`; `AppearanceMode` in Shared holds raw values, labels and `from(raw:)` only. The root's `Group.onAppear`
re-runs `applyAppearance` on every route switch (`RootView.swift:35-42`); it is idempotent, fine.

**NB8 — Two presentation flags on the Settings screen are acceptable.** A confirmation dialog Bool plus an optional alert message
never coexist (the dialog closes before the alert opens) and match the M3 precedent of a sheet enum plus a separate exit-dialog
flag; no enum needed for two `isPresented` Bindings.

**NB9 — Extra starting-weight keys are validated by the generator, so the per-key drop in §5.2 is the right guard.**
`ProgramGenerator` throws `unknownExerciseKey` / `unloadableStartingWeight` for every key in the map, used or not
(`ProgramGenerator.swift:130-132`). The prefill's filter keeps onboarding from ever reaching that throw; keys the new program does
not use (frequency or length changed in A3/A4) pass validation and are simply unused. Worth one sentence in §5.2.

**NB10 — AC-22's file-count scans should name the Settings screen file.** "the Settings screen" is not a path; give the planner
`Features/Settings/SettingsView.swift` so the static test has a stable target like `RootView.swift`.

---

## Unverified platform claims (with the settling probe)

1. **A full-size transparent host root intercepts no touch** (B3): never probed; scratch-copy XCUITest taps through it on 17.5
   and 26.5 as the first plan step; fallback is the shell-drawn banner.
2. **`.task(id:)` on the overlay host runs at mount while it draws nothing.** Addendum P1 proved `onAppear` on the concrete
   `ZStack` root; `.task` shares that lifecycle but was not probed. AC-7 `-seed missed -missedDayPolicy shift` (Home shows the
   shifted state with no prompt) is the probe; if it fails, run the action from `onAppear` plus `onChange(of: key)` instead.
3. **An alert presented from a confirmation dialog's button action on the same view** (§2.3 "Failed save"): the M2 start-failure
   alert has no dialog before it; SwiftUI is expected to queue the second presentation. AC-13's scratch-copy `allowsSave: false`
   test settles it; fallback is presenting the alert from a `.task` after the dialog flag drops.
4. **`-appearance` / `-missedDayPolicy` launch arguments override the seed suite**: the NSArgumentDomain mechanism is verified for
   `-units` (gotchas 2026-09-11); the new keys are not until they exist. AC-2 and AC-4 are the probes.
5. **Sorting a `@Query` by the optional `archivedAt`** (avoided by B2's `max(by:)`): no probe needed if B2 is followed.

---

## Decisions missing from `insights/INSIGHTS.md`

- **Automatic missed-day action lifetime**: runs from the host's `.task(id:)` keyed on `(policy, first missed index, day)`;
  retries on shell mount, policy change, new day, or a different first-missed index only; the pass is synchronous; a failed write
  is Debug-asserted with the Program card as the manual fallback (B1's outcome).
- **The prompt host's root is full-size** and draws the banner top-aligned; banner state (text, token, visible) is host `@State`
  with shell-mount lifetime, like the silence (B3's outcome, plus the probe result).
- **Restart prefill is a third root `@Query` on `archivedProgramPredicate`, newest picked in Swift**; the onboarding draft is
  copied once by `State(initialValue:)`, so root re-renders cannot reset answers (B2).
- **`SegmentedPicker` gains a `settings` style** rather than a second control (NB1).
- **Engine may carry a preference key constant** (`MissedDayPolicy.storageKey`, alongside `WeightUnit`'s raw-value contract) so
  the literal appears once; the reader is always a view's `@AppStorage`.

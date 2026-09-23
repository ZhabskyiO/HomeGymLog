# m4-settings Swift review (branch `m4-settings`, uncommitted tree, 2026-09-22)

**Verdict: ship.** No data-loss, logic or SwiftUI-state finding blocks the merge. 866 tests on 17.5 and 26.5 and the
Release build were verified in the main session and were not re-run here (no finding needed it).

Read: `git diff` plus every untracked file under `HomeGymLog/` and `HomeGymLogTests/`, `docs/plans/m4-settings.md`,
`docs/specs/m4-settings.md` (§2.6, §2.7, §4.4, §5.4, §5.5, §6), `docs/reviews/m4-settings-{architecture,researcher,verifier-3}.md`,
`CLAUDE.md`, INSIGHTS "2026-09-22 — M4 Settings decisions", `insights/gotchas.md`, and the unchanged writers
`Models/ProgramStore.swift`, `Models/StoreCommit.swift`, `Engine/ProgramGenerator.swift` (validation), `Engine/Equipment.swift`.

---

## What was checked, and holds

### `Features/Home/MissedPromptHost.swift` — the only untapped writer in the app

- **Key and retry rule (B1).** `.task(id: MissedDay.automaticActionKey(...))` (line 82) is keyed on `(policy, first missed index,
  startOfDay(now ?? clock.now()))`, nil for `.none` / `.prompt` and when the DEBUG `enabled == false`. It re-runs exactly at shell
  mount, a policy change, a new calendar day and a different first-missed index, as the spec states. A same-day re-render with the
  same key never re-runs it. Neither the key nor the task body reads `@State` that `onAppear` writes (`now ?? clock.now()` in the
  key, `clock.now()` inside the writers), so the 26.5 task-before-onAppear order is safe.
- **No loop, no repeat per render.** After a successful shift or skip pass the query re-fetches, the resolution is `.none`, the key is
  nil, and the nil-keyed task returns on the `.none` case. A failed write leaves the same key, so nothing re-runs until one of the
  four points. The one bounded retry is the spec'd partial skip pass: 7 lands, 11 fails → key `(skip, 11, day)` → one re-run → 11 fails
  again → key unchanged → stop.
- **Idempotence under a cancelled-but-running task.** If the key changes before a scheduled task body has started, Swift still runs
  the old closure (cancellation is cooperative and `runAutomatic` never checks it). That is harmless here: `ProgramStore.shift`
  returns `[:]` and `skipMissed` returns `false` for a row that is no longer missed, the pass counts only `true` results, and
  `skippedBanner(names: [])` is nil, so a second run neither writes nor shows a banner.
- **Synchronous pass.** `runAutomatic` (lines 131–149) has no `await`; the `@Query` cannot re-fetch between the skip saves and the
  guarded static scan (`MissedPromptSourceTests.automaticPassIsSynchronous`) keeps it that way. `skip(index)` returning `Bool?` and
  `shift` returning `[Int: Date]?` separate "no-op" from "failed" correctly: `nil` breaks the pass keeping what landed, `false` is
  skipped silently, `true` is named.
- **`rows: sessions`** is the host's complete, index-sorted session set for the program, which `ProgramStore.shift` requires (NB4).
- **Banner timer.** `.task(id: timerToken)` (lines 93–101) is keyed on the *visible* token (`selected == .home ? banner?.token : nil`,
  nil under `-holdBanner`). Leaving Home flips the id to nil → the sleeping task is cancelled → `catch { return }` clears nothing →
  the banner survives; returning restarts 3 s. A newer result bumps the token and restarts the countdown; a tap sets `banner = nil`
  and the `banner?.token == timerToken` guard makes a late wake-up a no-op. The DEBUG `bannerHold` environment value is read in
  `body` (through `timerToken`) before the `await`, so the "stale environment after await" gotcha does not apply.
- **VoiceOver.** `.onChange(of: visibleToken)` posts the announcement only when the token becomes non-nil, i.e. when the banner
  first shows on Home or shows again after a return, never when the action ran on another tab. Matches spec §2.7.
- **Silence.** Reset on `policyRaw` change (NB3); an automatic policy ignores it in `MissedDay.resolution`.

### `App/RootView.swift`

- `import UIKit` is confined to this file (`SettingsSourceTests.appearanceMechanism` scans it). `applyAppearance` sets
  `overrideUserInterfaceStyle` on every window of every connected scene from `onAppear` and `onChange(of: appearanceRaw)`; it is
  idempotent so the `Group`'s per-route `onAppear` costs nothing. The cold-launch first frame was probed by the researcher (Q1).
- Third `@Query` on `archivedProgramPredicate`, unsorted, newest chosen with `max(by:)` over `archivedAt ?? .distantPast` (B2).
  `prefillDraft()` runs only in the onboarding branch, over a handful of rows; no fetch in `body`
  (`SettingsSourceTests.rootViewHasNoFetch`).
- The draft is copied once: `OnboardingView.init` does `State(initialValue:)`, and the branch has no `.id`. A first run (no archived
  row) falls through to the default draft.

### `Features/Settings/RestartAction.swift` + `SettingsView.swift`

- `run` is assert-free (verifier finding 16); the assert sits in `confirmRestart`'s `.failed` case with the alert message, matching
  the M2 start-failure pattern. `RestartActionTests.failedSave` drives it on an `allowsSave: false` store.
- Order: `archive` (one synchronous `StoreCommit.commit` save) → `selectedTab = .home` in the same handler → the route flip renders
  later, so no frame of the old shell on Home; a throw leaves the tab on Settings. `.alreadyArchived` also resets the tab, harmless.
- The dialog Bool and the optional alert message never coexist (P3 verified the alert-from-dialog-action presentation).

### Data-loss checks around `archive`, `shift`, `skipMissed`, `StoreCommit`

- No writer changed. `archive` writes one field and reverts it through `StoreCommit.commit`; sessions, logs, sets and notes stay
  (`RestartFlowTests` counts them after archive → start). The workout replaces the shell, so archive cannot run with an open log.
- `RestartPrefill.answers` filters `startingWeightsLb` with the same `exercise.kind.isLoadable(lb:)` the generator throws on
  (`ProgramGenerator.swift:131-132`), so a restarted onboarding cannot reach `unloadableStartingWeight`; weekdays are kept only when
  exactly `frequency` distinct values in 0…6. Onboarding never traps on a hand-edited archived row.
- `OnboardingDraft(answers:units:bodyWeightUnit:)` sets `bodyWeightUnitChosen` last (NB2), covered by `OnboardingDraftTests`.

### Implementer deviations (D1–D4 in code)

| Deviation | Judgement |
|---|---|
| `Menu { Picker }` instead of `Picker(.menu)` | Right call. `Picker(.menu)` ignoring `.font` on 17.5 is recorded in gotchas; the `Menu` keeps the system check mark, the explicit `.accessibilityLabel` / `.accessibilityValue` give VoiceOver "Missed a day, Always shift"; the AC-15 trait "button" instead of "pop-up button" is a cosmetic deviation. |
| `MissedActionBanner` without `.accessibilityElement(children: .ignore)` | Correct: a `Button` with a text label is one element already; the duplicate-element gotcha is recorded. |
| Extra `Features/Settings/SettingsRows.swift` | Fine; keeps `SettingsContent` under the ~80-line body rule, and each row type is a small named view. |
| "Coming soon" rows as a disabled `Toggle` with a two-line label | Fine; `.disabled(true)` dims the label and VoiceOver reads "dimmed, switch button, off"; nothing is stored. |

### The `-tab settings` + `-missedDayPolicy shift` nuance

Debug-only noise; keep the held-banner rule as it is. By code reading the banner should *already* survive a launch-time flip: a
`selectedTab` change re-renders `ShellView` and the host with the new `selected`, `timerToken` becomes nil, the sleeping task is
cancelled and returns without clearing, exactly as for a user's tab switch (plan Step 12 trace 3, reported machine-checked). If
`initialTab` is applied before the host's task fires (17.5 order), the action runs with `selected == .settings`, no timer starts
and the banner is held. Production has no launch-time flip: `initialTab` is DEBUG, restart resets to Home *before* the shell
remounts, and a finished workout remounts on the tab the root already holds. Screenshots use `-holdBanner`, which exists. If the
scratch XCUITest really observed the banner gone on the first Home visit after `-tab settings`, that contradicts trace 3 and is worth
one cheap probe (`-seed missed -missedDayPolicy shift -tab settings`, wait 4 s, tap Home, assert the banner exists), because the same
mechanism carries the production "leave Home within 3 s" rule; it does not block the merge.

---

## Findings (none blocking)

### F1 — Low, unverified: the live restart flip depends on two root `@Query`s re-fetching in the same body

`App/RootView.swift:40-45`. After `archive` saves, `currentPrograms` must read empty *and* `archivedPrograms` must already contain the
just-archived row in the same body evaluation, because `OnboardingView` copies `prefillDraft()` once. If SwiftData ever re-fetched the
two queries on different turns, the first onboarding render could see the old archived set (or none) and open at A0 with defaults,
with no later render able to correct it. Both queries share one `mainContext` and one save notification, and `DynamicProperty.update()`
runs for every query before `body`, so this is expected to be consistent; the `restarted` seed proves only the static launch, not the
transition. **Probe that settles it:** plan Step 12 item 2 in the scratch copy (`-seed midProgram -tab settings` → "Build a new
program…" → "Archive and start over" → assert A2 with "6 months" selected), on 17.5 and 26.5. If it ever fails, the fallback is
`.id(newestArchivedID)` on the onboarding branch — safe because no archive can happen during onboarding, so the key cannot change
while the user types — but that alternative is **unverified** and contradicts the B2 wording, so only apply it on a failed probe.
React: two `useSelector`s that must observe the same store snapshot; the concern is whether the framework can hand one view two
snapshots from different commits.

### F2 — Low: the automatic pass makes the Debug assert reachable with no tap

`Features/Home/MissedPromptHost.swift:175` and `:188`. `shift` / `skip` `assertionFailure` on a failed save. Before this slice that
trap followed a user tap; now, under "Always shift" / "Always skip", the key at shell mount re-runs the pass on every launch, so a
persistently failing store (disk full) turns a Debug build — the configuration `/device-install` puts on the user's phone — into a
crash at launch on every relaunch, whereas "Ask me each time" would just keep showing the prompt. The spec (§2.6 "Failed write") chose
"Debug asserts", so this is a note, not a defect; if it ever bites, pass a flag from `runAutomatic` and assert only on the tapped path:

```swift
private func shift(_ index: Int, assertOnFailure: Bool = true) -> [Int: Date]? {
    do { return try ProgramStore.shift(...) }
    catch {
        if assertOnFailure { assertionFailure("Shift failed: \(error)") }
        return nil
    }
}
// runAutomatic: shift(missedIndex, assertOnFailure: false)
```
No simulator mechanism forces a failing-then-succeeding save (gotchas 2026-09-14), so this stays a code-reading item.

### F3 — Minor: redundant discard on the card's handlers

`MissedPromptHost.swift:62-63` write `_ = shift(...)` / `_ = skip(...)` while both functions are already `@discardableResult`
(`:169`, `:182`). Keep one or the other; `onShift: { shift(missed.index) }` reads cleaner for a newcomer.

---

## Questions for the caller

1. Was plan Step 12 item 2 (live confirm → A2 "6 months") run in the scratch copy? If yes, F1 is settled and can be struck.
2. Was the `-tab settings` banner observation made through the XCUITest with an outcome assertion, or from a screenshot recipe? A
   screenshot taken > 3 s after the Home tap would show exactly what was described without any rule being wrong.

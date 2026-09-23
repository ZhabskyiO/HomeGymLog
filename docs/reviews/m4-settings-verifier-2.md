VERDICT: FAIL

## Plan Verifier result — docs/plans/m4-settings.md against docs/specs/m4-settings.md (round 2, 2026-09-22, scoped to round-1 findings 1–15)

Re-read: the revised plan in full, spec §2.7 (Lifetime, VoiceOver), §4.4 (host shape), AC-13–AC-15, AC-22, and the code the
fixes cite (`build/progress-env.sh:12-13`, `HomeGymLogTests/Seed/DebugSeedTests.swift:15-25, 76-86`,
`HomeGymLogTests/Persistence/ProgramArchiveRollbackTests.swift:21-44`, `HomeGymLogTests/Static/{FailedSavePolicySourceTests,
StoreCommitSourceTests}.swift`, `grep assertionFailure HomeGymLog/Models HomeGymLog/Engine` → no hits).

All fifteen round-1 findings are addressed in the plan text, and the plan and the edited spec agree on the banner lifetime
(visible time, cancel on leaving Home, survive, restart and re-announce on return). One fix introduces a step whose gate cannot
pass as written (finding 16), which is what makes this round a FAIL; it is a one-line move. One fix is over-broad (finding 17).

### Round-1 findings, status

| # | round-1 finding | where fixed | evidence | status |
|---|-----------------|-------------|----------|--------|
| 1 | timer cleared the banner on cancellation | Step 10; spec §2.7 Lifetime | plan Step 10 — `do { try await Task.sleep(for: .seconds(3)) } catch { return }; if banner?.token == timerToken { banner = nil }`, "the `catch` `return` is the point"; spec line 125 — "3 s of visible time — leaving Home cancels the countdown, the banner survives, and returning to Home restarts the 3 s"; §5 risk row added; Step 12 trace 3 checks it | addressed |
| 2 | AC-7 plain policy launches never re-shot after the banner exists | Step 10 last paragraph; DoD line 3 | "re-shoot Step 9's four plain `-missedDayPolicy` launches ≥ 4 s after launch (`SHOT` sleeps 3 s; use `sleep 5` or a second shot)"; `build/progress-env.sh:13` — `SHOT() { sleep 3; …}` confirms the claim; DoD — "once the banner has gone (shot ≥ 4 s after launch)" | addressed |
| 3 | AC-13 had no gated test of the handler's outcome | Step 7 `RestartAction` + `Persistence/RestartActionTests.swift` | `run(program:at:in:) -> Outcome` (`.archived` / `.alreadyArchived` / `.failed(String)`), tested in memory and on the `allowsSave: false` fixture, `archivedAt == nil` in a fresh context, `rollback()` before the file is removed; Step 7 verify `ONLY RestartActionTests ProgramArchiveRollbackTests` | addressed, but see finding 16 |
| 4 | AC-15 spoken shape absent | Step 7 "Accessibility (AC-15)"; plan §2 | `.accessibilityLabel(SettingsText.missedDay)` + `.accessibilityValue(SettingsText.policy(policy))` on the control "whichever rendering ships"; `SettingsRow` `.accessibilityElement(children: .combine)` | addressed, but see finding 17 |
| 5 | `DebugSeedTests.parses` would go red in Step 8 | Step 8 "Tests `Seed/DebugSeedTests.swift` (edit, or the step goes red)" | "add `case .settingsRestart, .restarted:` → `TestCalendar.day(2026, 9, 15)`, and add both seeds to the `initialDraft == nil` loop"; matches `DebugSeedTests.swift:15-25` (`default:` = Aug 31) and `:78-81` (hand-listed loop) | addressed |
| 6 | announcement fired off-Home | Step 10; spec §2.7 VoiceOver | `let visibleToken: Int? = selected == .home ? banner?.token : nil`, `let timerToken = missedBannerHold == true ? nil : visibleToken`; announce from `.onChange(of: visibleToken)` when non-nil; spec line 129 — "each time it appears on Home (so leaving and returning within its lifetime re-posts the same text)" | addressed |
| 7 | `SegmentedPicker` needed more than four switches | Step 7 | "needs **seven** of the file's ternaries and switches, not four": spacing `:21`, padding 12/5, foreground `Theme.tx` (`:29`), `sf` background, radius 7, container padding 3 / radius 9, 12.5 pt, not equal-width (`:32`) | addressed |
| 8 | `bodyWeightUnitChosen` must be last | Step 4 | "`bodyWeightUnitChosen = (bodyWeightUnit != units)` as the **last statement** (NB2: both … `didSet` fire on every assignment after `self.init`)" | addressed |
| 9 | which line each scan assertion reads | Steps 8, 10 | Step 8 — "the `seed.settingsRestartPreview` read sits inside the `#if DEBUG` seed branch, its local is passed by one `.environment(…)` line in `body`"; Step 10 — `.environment` lines "live in `body`, **outside** `#if DEBUG`", the read "inside the `DebugSeed.parse(` block before its `#endif`" | addressed |
| 10 | `"appearance"` in asset JSON | Step 11 | "`pathExtension == "swift"` only, so the eight `Assets.xcassets/*/Contents.json` `"appearance"` keys are out of scope" | addressed |
| 11 | policy control rendering risk | plan §2 open question | "`Picker(.menu)` is reported to ignore `.font` … the fallback … is likely; either way it carries finding 4's explicit label and value, so the only recorded AC-15 deviation is the trait" | addressed |
| 12 | dialog presented during the `-tab settings` switch | Step 7 | "if 17.5 drops a dialog presented during `RootView`'s `initialTab` switch, present it from `.onChange(of: selectedTab)`; AC-5's shot is the probe" | addressed |
| 13 | seed suite should be driven by `resolution` | Step 5 | "each pass is driven by `MissedDay.resolution`'s case, never hand-typed indexes (AC-21)" | addressed |
| 14 | nested-tuple `@Test(arguments:)` gotcha | Step 4 | "separate tests or a file-scope typed constant, never one long nested-tuple `@Test(arguments:)` literal (gotchas Swift 2026-09-14)" | addressed |
| 15 | nil-id guard; `bodyWeightUnits` reader | Steps 9, 8 | Step 9 — "its body **guards on the resolution's case first** (P2: the task also runs at mount with a nil id)"; Step 8 — "a **new** `@AppStorage("bodyWeightUnits") private var bodyWeightUnitsRaw` (only `OnboardingView` reads that key today)" | addressed |

### Spec ↔ plan agreement on the banner (checked after the three spec edits)

| point | spec | plan | agree |
|---|---|---|---|
| 3 s = visible time; leaving Home cancels, banner survives, return restarts | §2.7 Lifetime (line 125) | Step 10 timer keyed on `timerToken` (nil off Home), `catch { return }` | yes |
| announcement on every appearance on Home | §2.7 VoiceOver (line 129) | `.onChange(of: visibleToken)` non-nil | yes |
| leave at ~1 s and return: still there, gone 3 s later | AC-14 (line 426) | Step 12 trace 3 "leave Home inside the 3 s and return — the banner is still there" | yes |
| held until Home is next visible; `-holdBanner` never clears but still announces | §2.7 "Action on another tab", §4.4 | `visibleToken` non-nil under hold, `timerToken` nil | yes |
| §4.4 wording: "`visibleSince: Bool` set when Home shows it … cleared by a `.task(id: token)` that sleeps 3 s" | §4.4 (lines 223-225) | plan §2 replaces `visibleSince` with the derived token and keys the task on `timerToken`, not `token` | equivalent behaviour; stale wording only (finding 19) |

### Findings (numbered on from round 1)

16. **blocking** — Step 7's `RestartActionTests` gate traps in Debug as written. Evidence: Step 7 — "`static func run(program:at:in:)
    -> Outcome` … a throw → `assertionFailure` + `.failed(SettingsText.archiveFailedMessage)`", then "on the `ProgramArchiveRollbackTests`
    on-disk `allowsSave: false` fixture, `run` → `.failed(…)`" and "Verify: `BUILD && ONLY RestartActionTests …`". The test target runs
    the Debug configuration, where `assertionFailure` stops the process (`ProgramArchiveRollbackTests.swift:36-38` only ever calls the
    non-asserting `ProgramStore.archive`, and `grep assertionFailure HomeGymLog/Models HomeGymLog/Engine` finds none: every failure
    path a test exercises is assert-free by convention, the asserts live in view handlers). Fix: `RestartAction.run` returns
    `.failed(message)` without asserting; `confirmRestart()` does `case .failed(let message): assertionFailure(…); archiveError = message`.
    React: throw from the pure function, `console.assert` in the event handler.
17. **should-fix** — `.accessibilityElement(children: .combine)` on every `SettingsRow` would swallow the controls. Evidence: Step 7 —
    "`SettingsRow` is one element (`.accessibilityElement(children: .combine)`)"; AC-15 wants "Appearance" then **three buttons**
    "System" / "Dark" / "Light" (the selected one "selected"), "lb" / "kg" buttons, the toggles as "switch button, off, dimmed", and a
    "Missed a day" pop-up button with a value. Combining a row that contains a `SegmentedPicker`, `Toggle` or the picker folds those
    children into one element (their buttons become custom actions), which breaks AC-15's order and the `.isSelected` trait the plan
    relies on (`SegmentedPicker.swift:36`). Fix: apply `.combine` only to the read-only value rows (Current, Dumbbells, Bench, Marcy);
    leave the control rows' children as they are (the toggle's own label gives "Daily reminder, Coming soon, switch button"; the
    Appearance / Units labels stay static text before their buttons). React: `aria-label` on a `<li>` vs leaving the inner `<button>`s
    focusable.
18. **note** — `ProgramArchiveRollbackTests.failedArchive(storeAt:)` is `private` (`:21`); `RestartActionTests` copies the fixture
    shape (writer container, `allowsSave: false` container, `defer { context.rollback(); withExtendedLifetime … }`) rather than calling
    it. Say "copies" so the test-writer does not widen the helper's access.
19. **note** — Spec §4.4 still describes the banner state as `visibleSince: Bool` and "cleared by a `.task(id: token)`" (lines 223-225);
    the plan's derived `visibleToken` / `timerToken` is behaviourally identical and declared a plan-level choice in §2. Worth a one-line
    spec touch by the doc-writer so §2.7, §4.4 and the code use one vocabulary. Likewise AC-14's "announces the text once" now means
    "once per appearance" per §2.7; harmless, but a reader without §2.7 open could take it as "once per action".
20. **note** — Step 12 trace 3 now says "leave Home inside the 3 s and return — the banner is still there (finding 1)"; add "and gone
    3 s after the return" so the trace matches AC-14's full sentence.

### Summary

- Round-1 findings addressed: 15 of 15 in the plan text
- New: 1 blocking (finding 16, Step 7 test traps on `assertionFailure`), 1 should-fix (finding 17, `.combine` scope), 3 notes
- Coverage after this round: AC-13 covered once finding 16 is applied; AC-15 partial until finding 17 is applied; AC-7 and AC-14
  now covered (AC-14 user-run / Step 12); all others unchanged from round 1 (no AC lost coverage, no new contradiction found)
- Spec ↔ plan banner lifetime: consistent (§2.7, AC-14, Step 10, Step 12, DoD); §4.4 wording stale but not contradictory
- False claims about existing code: 0 (the `SHOT` 3 s claim, the `DebugSeedTests` `default:` claim and the private fixture all verified)
- Traceability: plan carries AC numbers

### Questions only the user can answer

- none

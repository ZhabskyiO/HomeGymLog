VERDICT: PASS

## Plan Verifier result — docs/plans/m4-settings.md against docs/specs/m4-settings.md (round 3, 2026-09-22, scoped to round-2 findings 16–20)

Re-read: plan Step 7 (lines 197-236), Step 12 trace 3 (line 352), spec §4.4 host-shape paragraph (lines 218-227), plus a grep of every
`assertionFailure` and `combine` mention in both documents to make sure no stale sentence survived.

### Round-2 findings, status

| # | round-2 finding | where fixed | evidence (verbatim) | status |
|---|-----------------|-------------|---------------------|--------|
| 16 | `RestartAction.run` asserted on a throw, so the `allowsSave: false` test would trap in Debug | plan Step 7, both sentences | line 221 — "a throw → `.failed(SettingsText.archiveFailedMessage)` with **no assert inside `run`** (finding 16: an assert there would trap the `allowsSave: false` test in Debug; the `assertionFailure` belongs in `confirmRestart()`'s `.failed` case)"; line 223 — "`.failed(message)` sets `archiveError = message`, `assertionFailure`s, and leaves the tab on Settings". The only other `assertionFailure` in the plan (line 277) is Step 9's host handler, view code no test calls | addressed |
| 17 | `.combine` on every `SettingsRow` would fold the controls | plan Step 7 accessibility clause | line 215 — "a **read-only value row** is one element (`.accessibilityElement(children: .combine)`); a row holding a control (the two segmented pickers, the two disabled toggles, the policy picker) is never combined, or the control would fold into it and AC-15's order would break". The label/value on the policy control and `SegmentedPicker`'s `.isSelected` are unchanged | addressed |
| 18 | the rollback fixture helper is `private` | plan Step 7 tests | line 228-229 — "on the `ProgramArchiveRollbackTests` on-disk `allowsSave: false` fixture shape (its helper is `private`, so copy the shape rather than calling it)" | addressed |
| 19 | spec §4.4 still said `visibleSince: Bool` / `.task(id: token)` | spec §4.4 | lines 223-225 — "one `@State banner: MissedDayBanner?` (text and a token bumped per result), drawn when `selected == .home`, cleared by a `.task` keyed on the **visible** token (`selected == .home ? banner?.token : nil`) that sleeps 3 s and returns without clearing when cancelled, so the 3 s counts visible time (2.7) (skipped when the DEBUG `missedBannerHold == true` …)". No `visibleSince` remains in the spec; §2.7, §4.4 and plan Step 10 now use one vocabulary | addressed |
| 20 | Step 12 trace 3 lacked the "gone after the return" half | plan Step 12 | line 352 — "leave Home inside the 3 s and return — the banner is still there, and gone 3 s after the return" | addressed |

### Nothing new broke

- Step 7's gate (`ONLY RestartActionTests ProgramArchiveRollbackTests`) is now runnable in Debug: `run` is assert-free on the failing store.
- `RestartAction.swift` lives under `Features/Settings/`, so the two source scans that count writer tokens are untouched:
  `FailedSavePolicySourceTests` counts `StoreCommit.commit(` lines in `Models/ProgramStore.swift` only (`:46`), and `StoreCommitSourceTests`
  counts `ModelContext(` in `Models/*.swift` only (`:22-28`).
- The AC-15 clause keeps the toggle rows' native "switch button, off, dimmed" reading and the segmented buttons' `.isSelected` trait; the
  read-only rows (Current, Dumbbells, Bench, Marcy) get the one-element label/value shape AC-15 asks for.
- Spec §2.7 Lifetime / VoiceOver, §4.4, AC-14, plan Step 10, Step 12 trace 3 and DoD line 3 all describe the same banner lifetime (visible
  time, survive a cancelled countdown, restart and re-announce on return, `-holdBanner` never clears but still announces).
- Ordering is unchanged from round 1 (Steps 1 → 11 still introduce every type before its first use); no step's verify list changed except
  Step 7's, which only added `RestartActionTests`.

### Summary

- Round-2 findings addressed: 5 of 5
- Coverage: 23 of 23 ACs covered (AC-9–AC-12 and AC-14 as user-run / optional Step 12 per spec §8's own terms; AC-15 structurally, device
  check per spec); AC-13 now gated by `RestartActionTests`; AC-7 re-shot after the banner exists
- Partial / Missing / Ambiguous / Out of scope: none
- False claims about existing code: 0 (unchanged from rounds 1 and 2)
- Open should-fix findings: none; blocking: none
- Traceability: plan carries AC numbers

### Questions only the user can answer

- none

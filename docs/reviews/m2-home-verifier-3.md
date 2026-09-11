# Plan verifier — m2-home, round 3 (scoped), 2026-09-11

VERDICT: PASS WITH FIXES

Scope: the parts rewritten after `docs/reviews/m2-home-researcher.md` (Step 3, Step 4 `SeedHomeStatsTests`, Step 5
annotation, Step 6 sketch, Step 9 note, sections 2/4/5/6), agreement with spec §4.1 and INSIGHTS "M2 Home
architecture", and AC-16 / AC-21 coverage. Steps 1–4 already existed on the branch and were read as evidence.

## Result

- Every plan claim about Steps 1–4 matched the branch (predicate, summaries, finishedLogs guard, fingerprint format,
  the 120/10 log counts, the 7 560 / 49 320 / 0 week volumes, `HomeStatsInput` throwing init, seeds).
- Plan Step 6, spec §4.1 and INSIGHTS agree on the query-owned data flow.
- AC-16 and AC-21: covered. False claims about existing code: 0. Blocking: 0.

## Findings

1. **should-fix** — Spec §4.3 / AC-21 and INSIGHTS still named `HomeStatsInput(program:)`, which no longer exists.
   Fixed: spec cell and AC-21 now name `HomeSnapshotBuilder` + `HomeStatsInput(sessions:logs:)`; INSIGHTS line reworded.
2. **should-fix** — Step 6 read the clock while rendering and never wrote `now` on appear, contradicting spec §3/§6
   ("set on appear and scene-active only"). Fixed: `HomeView` adds `.onAppear { now = clock.now() }`; the
   `now ?? clock.now()` fallback covers only the pre-appear frame.
3. **note** — `now ?? clock.now()` passes `ClockUsageTests` (it forbids `Date()` / `Calendar.current`, not `clock.now()`).
4. **note** — `fingerprint` omits set-level fields by design; finished sets never change in v1. If M4 ever edits finished
   sets, widen the fingerprint. Record in INSIGHTS when M3 lands.

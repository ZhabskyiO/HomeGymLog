VERDICT: PASS

## Plan Verifier result — docs/plans/m5-live-activity.md against docs/specs/m5-live-activity.md

## Round 2 (2026-10-02, scoped to round-1 findings F1–F7; round 1 is `docs/reviews/m5-live-activity-verifier-1.md`)

Re-read only the amended passages and grepped spec, plan and `insights/INSIGHTS.md` for each old wording.

| finding | sought | evidence | status |
|---------|--------|----------|--------|
| F1 AC-10 write events | grep `write, update`, `logged by a hook`, `12:02:02` in spec and plan | spec:376 "(activity, then notification — … the write's order is proven by the values the events carry …)"; spec:381 "the event sequence is exactly `update(12:01:32), schedule(12:01:32), update(12:02:02), schedule(12:02:02)`"; plan:240-241 the same four events; no "write, update" or "logged by a hook" left. spec:308 (§6 prose "the second run's write, update and schedule all follow the first's") describes behaviour, not a recorder event, and stays correct | resolved |
| F2 one suite assigns the hook | grep `only suite`, `LiveActivityIntentHookTests` | spec:387 "`LiveActivityIntentHookTests` is the **only** suite that assigns `LiveActivityIntentHooks.handler`, so the B1 hook-driven test of AC-10 lives in it too"; plan:239 "this one test lives in `App/LiveActivityIntentHookTests.swift` (the only suite that assigns `LiveActivityIntentHooks.handler`, F2), not in the handler suite"; Step R (plan:361) still deletes that file | resolved |
| F3 `start…end` in §2.2 | sed 53, 55; grep `start…end` / `start...end` | spec:53 `ProgressView(timerInterval: state.interval, …)`, spec:55 `Text(timerInterval: state.interval, …)`; the only remaining `start...end` is spec:265's description of the trap the clamp avoids, and plan:113's test literal — both correct | resolved |
| F4 S5 wording | read plan:15 | "→ drop its `private` (make it internal)" | resolved |
| F5 call-site count | grep `63 `, `70 ` near `makeContainer` | spec:446 "the 70 `makeContainer(calendar:)` call sites (63 in tests, 7 in the app including six `#Preview`s; overload kept)"; **plan:327 still reads "(the 63 call sites unchanged)"**; INSIGHTS has no count | one leftover (F8) |
| F6 Step R vs AC-25 | read plan:363 | "Verify as Step 14 **minus the AC-25 `Metadata.appintents` check**, which must fail once the intents are deleted (… assert its absence instead)" | resolved |
| F7 handler row reads | grep `exercisePredicate`, `log.exercises` in plan | plan:221 "fetch the rows through `WorkoutSnapshotBuilder.exercisePredicate` / `setPredicate` as the screen and `RestSeedFlowTests` do (NB3, F7), never `log.exercises` hops" | resolved |

### Findings

8. **note** — plan:327 (Step 13) still says "`makeContainer(calendar:)` delegates with `referenceDate(calendar:)` (the 63 call sites unchanged)";
   the spec (spec:446) now says 70. Fix: "(all 70 call sites unchanged)". No step depends on the number.

### Summary

- Round-1 findings resolved: F1–F4, F6, F7; F5 resolved in the spec, one stale count left in the plan (F8, note).
- Covered: 27 of 34 acceptance criteria (AC-10 moves from partial to covered); out of scope per plan:29: AC-26–AC-32.
- No blocking or should-fix findings remain; verdict PASS.

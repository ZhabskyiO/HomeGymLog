# m2-home — architecture review (2026-09-10)

**Verdict: approve with changes.** Conforms to all settled decisions; no schema change; every §5 number computed.

## Blocking
- **B1 Data source**: pass the router's `Program` down (`RootView` → `ShellView(program:)` → `HomeView(program:)`);
  no second `@Query`. Map `@Model → HomeStatsInput` inside `body` so Observation tracks nested reads. Fallback if the
  researcher's probe shows no re-render through relationships on 17.5: `@Query(sort: \PlannedSession.index)` with no
  relationship predicate, filtered in memory by `persistentModelID`, plus `@Query` on `WorkoutLog.finishedAt != nil`.
- **B2 Foreground refresh**: allow one `@State today` set on appear and on scene-active; `clock.now()` never read in `body`.
- **B3 Streak ambiguity**: skipped before today breaks the streak; skipped dated today is stepped over like pending.

## Non-blocking (adopted)
One mapping function `Models/HomeStatsInput.swift` (`init(program:)`) as the only throwing step; `HomeStats` functions
non-throwing over validated input; drop `unknownExerciseKey`. Keep `SessionSlot` separate. Engine text-free: `greeting`
returns an enum, strip letters computed in the view. `WeightDisplay.whole(lb:unit:) -> Int`; `kfmt` in Shared.
`.sheet(item:)` with `@State infoExercise: Exercise?`, detents 0.78, corner radius 28, drag indicator hidden. "Progress ›"
via `@Binding selectedTab` from ShellView. Seeds: `MidProgramSeed.populate(in:calendar:completedIndexes:)`, `restDay` =
[0…14] − [7]; `freshProgram` from `OnboardingDraft()`; `referenceDate` gains `.restDay`. All `restDay` numbers derived
(7 · 14/120 · 49 320 → "49.3k"; PRs chestPress 100, skull 27.5, latPull 110, lowRow 100; week 4 Foundation). Mapping in
`body` faults ~2 500 rows at most; no memoization now. ShellView becomes a per-tab switch; its preview needs a seeded
container.

## Decisions to record
Program passed as a prop; `@State today` pattern; streak/skip rule; stats scoped to the current program (restart resets
the PR baseline); week volume attributed to the session's `scheduledDate`; one optional sheet item per screen; tab
selection owned by ShellView as a Binding; seed recipe reuse.

VERDICT: PASS

## Plan Verifier result, round 3 (scoped to round-2 findings 1 and 2) — /Users/zhabskyi/AppleApps/HomeGymLog/docs/plans/m3-exercise-tools.md, Step 12 `test7_pill` (line 319)

| check | evidence | result |
|---|---|---|
| Round-2 finding 1: "Skip rest" inserted between the rating and Next ×3 | line 319: `"7" → no label BEGINSWITH "Up "; then, same launch …: "Skip rest" (the rating started a 75 s rest whose card hides the bar; as in test3_swapEnabled) → Next exercise ×3` | fixed |
| Path reaches exercise 4 with Swap enabled | After "7", `setRPE` starts the 75 s rest (`Models/WorkoutLogStore.swift:277-279`). "Skip rest" matches `RestText.skipAccessibility = "Skip rest"` (`Shared/RestText.swift:10`) and `skipRest` clears both instants (`WorkoutLogStore.swift:197-203`), so the bar with "Next exercise ›" is back in the tree (`Features/Workout/WorkoutLoggingContent.swift:71-83`). Next 1: E1 has set 1 done and rated, sets 2–3 pending, none awaiting a rating → `nextExercise` skips 2–3 and calls `clearRest` (`WorkoutLogStore.swift:299-312`), starting no new rest. Next 2 and 3 skip E2 and E3 (all pending). Displayed exercise is E4 (rdl), `logging(3, 0)`, all three sets pending → `canSwap` true → header Swap enabled (Step 11 `swapEnabled: exercise.map(WorkoutFlow.canSwap) ?? false`). Pill before the pick: rdl last top 50 (s6, `MidProgramSeed.topWeightLb` index 6 → target), current 52.5 → `pillSpoken` "Up 2.5 lb from your last Dumbbell Romanian Deadlift" (Step 3, line 128 format) | reaches exercise 4; assertions hold |
| Round-2 finding 2: candidate query uses the full accessibility label | line 319: `buttons["Goblet Squat, Dumbbell, 52.5 lb"]`; Step 3 line 130 defines `candidateAccessibilityLabel(name:equipment:lb:unit:)` → "Goblet Squat, Dumbbell, 52.5 lb"; Step 11 line 283 applies it to each row; goblet's equipment string is "Dumbbell" (`Engine/ExerciseLibrary.swift:47`) and its week-3 weight is 52.5 (50 + 2.5, capped at 52.5); `test4_pick` line 314 uses the identical string | fixed; format matches |
| After the pick the "no `Up `" clause can fail for the right reason | goblet tops 47.5 (s2), 47.5 (s4), 52.5 (s9) → last 52.5; current 52.5 → no delta; a stale deadlift baseline (50) or a key mismatch would show "Up 2.5 lb …" and fail; the deadlift-label assertion one tap earlier proves the pill was live | yes |
| Nothing else broke | Step 12 lines 304–328 otherwise unchanged (test1–test8, skip condition, uninstall lines, `git diff --quiet -- HomeGymLog.xcodeproj`); §7 traceability row "9–16 \| 12 (optional), 13 (user) \| … test7 · test8" intact (line 383); no artifact renamed (`test7_pill`, `test4_pick`, `candidateAccessibilityLabel` each resolve to one definition) | intact |

### Findings

None remaining. Round-1 F1–F4, F9, F10 and round-2 findings 1–2 are all applied and correct; no blocking or should-fix item is open.

### Summary

- Covered: 30 of 30 acceptance criteria (AC-9–AC-19 user-run per the spec, with Step 12 optional; AC-12's pill clause now in `test7_pill`)
- Partial / Missing / Ambiguous / Out of scope: none
- False claims about existing code: 0
- Traceability: plan carries AC numbers

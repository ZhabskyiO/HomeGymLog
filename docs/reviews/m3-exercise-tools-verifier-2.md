VERDICT: PASS WITH FIXES

## Plan Verifier result, round 2 (scoped to F1–F4, F9, F10) — /Users/zhabskyi/AppleApps/HomeGymLog/docs/plans/m3-exercise-tools.md

| finding | plan location | edit present | correct | evidence |
|---|---|---|---|---|
| F1 | Step 12, lines 314 and 319 | yes | **partly** (see finding 1) | line 314: test4 drops the "no pill" clause, pointing at test7; line 319: test7 continues in the same launch: "Next exercise ×3 → label 'Up 2.5 lb from your last Dumbbell Romanian Deadlift' present → Swap → 'Goblet Squat' → no label `BEGINSWITH "Up "`", with the recompute instruction |
| F2 | Step 6, line 201 | yes | yes | `candidates(for: "rdl", …context…)` on the pre-swap log starts with goblet 42.5. Recomputed: start 40 → 400 tenths ≥ 157.5 (dumbbell threshold), so slow regime from week 1 (`WeightFormula.swift:12`); week 2 no step, week 3 +25 tenths → 425 → ×1.0 Foundation, rounds to 425 → 42.5 |
| F3 | Step 1, line 84 | yes | yes | "called once (the only clause here that can fail; name the test for it, e.g. `rehearseInsertCallsBodyOnce`, and add no further vacuous clauses)" |
| F4 | Step 13, lines 333–334 | yes | yes | `grep -rn 'ModelContext(' HomeGymLog/Models \| grep -vE '^[^:]+:[0-9]+:[[:space:]]*//';   # code lines only`; the `#` comment ends at the newline and line 334 begins a new command (leading space is harmless), so the block parses. I ran the filter on synthetic `path:line:` input with one code line and two comment lines: only the code line printed, exit 0. Line 341's expectation ("only `StoreCommit.swift`") matches |
| F9 | Step 4, line 150 | yes | yes | comment: "the delete stays inside the revert closure, which runs before rollback(); never move it after" — matches `WorkoutLogStore.swift:96-102` and `commit`'s order (revert, then `rollback()`, `WorkoutLogStore.swift:71-79`) |
| F10 | §2, line 36 | yes | yes | "Group with a loop keyed on `workout?.id` or `Dictionary(grouping:)`, never `Dictionary(uniqueKeysWithValues:)`" |

Nothing else changed: the §7 traceability table (lines 376–390) is intact, row "9–16" still names test1–test8, no artifact was renamed (grep for `test4_pick`, `test7_pill`, `SwapContextTests`, `StoreCommitTests`, `finishedTops` each resolves to one consistent definition), and Steps 1–11 are otherwise as verified in round 1.

### F1 in detail: does the new test7 clause fail when the pick's pill is wrong, and does the path reach exercise 4?

Fails for the right reason: yes. The clause is preceded by a positive assertion ("Up 2.5 lb from your last Dumbbell Romanian Deadlift" present on exercise 4, recomputed from spec 5.2: rdl last top 50 at s6, target 52.5), so the pill machinery is proven live one tap before the pick; after the pick, goblet's tops are 47.5 (s2), 47.5 (s4), 52.5 (s9) → last 52.5, current 52.5 → no delta. A stale baseline (the deadlift's 50 against goblet's 52.5 → "+2.5"), a key mismatch, or a best/last error would all produce an "Up …" label and fail the assertion.

Path: partly broken. Sequence on `-liveReset -liveHistory`, session 11: pill "+10" → left drag set 1 → weight − twice (110 → 90) → "Save & log set" (set 1 done at 90, sets 2–3 carried to 90) → RPE card → "7". `setRPE` then starts a 75 s rest because a pending set remains (`WorkoutLogStore.swift:277-279`, `startRestIfSetFollows`; session 11 `restSeconds` 75), and while resting the rest card replaces the bottom bar, so "Next exercise ›" is not in the tree (`WorkoutLoggingContent.swift:71-83`; INSIGHTS rest-timer: "'Next exercise ›' is blocked during rest"). The plan's test7 goes straight from "7" to "Next exercise ×3", so the first Next tap finds no button for up to 75 s. test3 (line 313) already shows the right shape: `tap "7" → … "Skip rest"; Next exercise ×3`. After "Skip rest" the bar returns; `nextExercise` clears any rest and starts none (`WorkoutLogStore.swift:310`), so the second and third Next taps need no further skip. Exercise 4 (rdl) is then all-pending, Swap is enabled, and the rest of the clause holds.

### Findings

1. **should-fix** — Step 12, line 319 (`test7_pill`): insert `"Skip rest"` (the `RestText.skipAccessibility` label, `Shared/RestText.swift:10`) between `"7" → no label BEGINSWITH "Up "` and `Next exercise ×3`, exactly as `test3_swapEnabled` does on line 313. Without it the added clause cannot reach exercise 4 inside the XCUITest timeout, so the AC-12 pill check would fail for a harness reason, not a product one.

2. **note** — same line: the pick is written as `Swap → "Goblet Squat"`. The candidate row's accessibility label is the full `"Goblet Squat, Dumbbell, 52.5 lb"` (Step 11 `candidateAccessibilityLabel`; test4 on line 314 already queries that full string), so `buttons["Goblet Squat"]` would not match the row before the pick (it matches the name button only after it). Spell the candidate query as in test4.

### Summary

- F2, F3, F4, F9, F10: fixed as described.
- F1: the vacuous clause is gone and the new clause can fail for the right reason, but its path needs one `"Skip rest"` tap (finding 1) and the candidate query label (finding 2).
- No other step or the traceability table was affected.

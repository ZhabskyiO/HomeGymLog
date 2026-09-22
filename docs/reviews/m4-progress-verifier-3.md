VERDICT: PASS

## Plan Verifier result — docs/plans/m4-progress.md against docs/specs/m4-progress.md (round 3)

Round 3 (final), 2026-09-16, scoped to round-2 findings 1–4 (`docs/reviews/m4-progress-verifier-2.md`) plus the coordinator's question: does any AC or test for the fallback Best / empty state now need an `isLoading == false` condition stated? Re-read: plan §2, Step 6, Step 8, §5; spec §2.2, §3, §6, AC-23, AC-24. Grep evidence in both files: `DebugProgressSelection` → nothing; `#Predicate` → only the two reasons-why lines (plan §2 "`#Predicate.evaluate` needs iOS 17.4", spec §4.1 the same) and the `archivedProgramPredicate` comment; `separate one-hop` → nothing; `isLoading` → plan §2, Step 8 (twice), §5. Rows not named below are unchanged from rounds 1–2 (covered).

### Round-2 findings, re-checked

| round-2 id | fix claimed | evidence | status |
|---|---|---|---|
| 1 (should-fix) — F4 not propagated into Step 8 / §5 | `ProgressChartCard` gains `isLoading`; empty line gated; Best "—" while loading; §5 rewritten | plan Step 8 — "`ProgressChartCard.swift` (`name`, `points`, `fallbackLb`, `unit`, `calendar`, `isLoading` = `held?.key != effectiveKey`, passed through `ProgressContent`; verifier F4)"; "`if points.isEmpty && !isLoading { Text(ProgressText.empty) … }`; while `isLoading` the chart draws the rules only and Best reads `none` (no fallback)"; plan §5 — "a chip tap shows the rules only (`isLoading`, Best "—") for the frame before its fetch, never the previous line nor the empty state (B3, verifier F4)" | resolved |
| 2 (should-fix) — spec AC-23 old parser name | renamed | spec AC-23 (line 372) — "`DebugProgressExercise.parse` (the `-progressExercise` parser): value, missing, trailing flag"; plan Step 7 / §7 / Files unchanged (`DebugProgressExercise`, `DebugProgressExerciseTests`) | resolved |
| 3 (should-fix) — stale §5 "separate one-hop predicate" | rewritten | plan §5 — "**Predicate composition via `evaluate` (17.4+)** → the existing `sessionPredicate(programID:)` per archived program, `status == .completed` filtered in Swift inside the task (F2)"; agrees with §2, Step 6 `archivedCompletedSessions` and §4 | resolved |
| 4 (note) — dead `#Predicate` allowance in the AC-24 scan | dropped from spec AC-24, plan §2 and Step 6 | spec AC-24 (line 378) — "appears only inside `tops(key:`; none under `Features/Progress/`"; plan §2 — "`tops(key:` is the only permitted hop site (Step 6)"; plan Step 6 `builderHops` — "every hop line is inside `func tops(key:`'s body (brace-matched from the token), and at least one hop exists inside `tops(`" | resolved |

### Consistency check: does `isLoading` change any AC or test?

| surface | what it says | with `isLoading` | needs a change? |
|---|---|---|---|
| Spec §2.2 "Best": "empty history: the planned target … or "—"" and "Empty line … only when no points" | settled-state rules | Both hold once the key's fetch has completed (`held.key == effectiveKey`). While loading, Best reads "—" and the line is absent for one frame; no AC observes a single frame | no (see note 1 for an optional spec sentence) |
| Spec §3 "Empty for the key (`freshProgram` …)": Best = planned target ("40 lb"), the empty line | state table | AC-2 screenshots after "wait ≥ 2 s" (spec §8 preamble); the task has run by then, so `-seed freshProgram -tab progress` shows "40 lb" and the line (plan Step 8 s8-fresh "Best 40 lb, "—" `mu`, rules only, no from/to, empty line") | no |
| Spec §6 "Failed per-key fetch: … the card shows the empty state for that key" | catch path | Plan Step 8 `load` — "catch → assertionFailure + held with empty tops and sessions": the held value carries the fetched key, so `held?.key == effectiveKey`, `isLoading == false`, and the empty state shows as the spec says (the implementer must set `held.key` in the catch path too, which "held with empty tops" implies) | no |
| Spec §6 "Stale selected key … a held result for another key is not drawn" | the B3 rule | Unchanged: `heldTops` still returns `[]` for a mismatched key; `isLoading` only decides what the card draws in that frame | no |
| Plan Step 2 `heldTops` tests (AC-20 row) | Engine test of the same condition | `isLoading = held?.key != effectiveKey` is the negation of `heldTops`' "draw" condition; the four `heldTops` cases (match, other key, nil held, both nil) already pin it. A second pure function would duplicate the test | no |
| Plan Step 8 s8-nope (`-progressExercise nope`) | screenshot | `effectiveKey` = dbBench; the task fetches dbBench; after it `isLoading == false` → identical to s8-mid, as the plan says | no |
| Plan Step 10 `test1_chipTap`, `test3_doneOnSummary` | XCUITest after a chip tap | The dots appear after the task; XCUITest queries re-evaluate on access, and the tests assert presence, not a single frame | no (test-writer may add `waitForExistence`, routine) |
| AC-13 chart container label while loading | `chartEmptySummary` with no points | A one-frame label change; VoiceOver never announces it. Not an AC | no |

Edge read: `effectiveKey == nil` (no chips) with `held == nil` gives `isLoading == false` (nil == nil), so the card shows Best "—" and the empty line rather than a permanent loading frame; unreachable with a current program (every program has sessions), but the behaviour is the right one anyway.

### Findings

1. **note** — Optional spec sentence for the loading frame. The plan now defines a presentation state the spec does not name (rules only, Best "—", no empty line while `held?.key != effectiveKey`). Every AC and screenshot is taken after the task has run, so nothing is unchecked, but a reader of the spec alone would expect the empty line "only when no points" to be unconditional. Recommended, not required: append to spec §6 "Stale selected key" — "until the effective key's fetch completes the card draws the rules only with Best "—" (no fallback, no empty line); the empty state is the settled state of a key with no points (plan Step 8, `isLoading`)".

No should-fix or blocking findings remain.

### Summary

- Covered: 25 of 25 acceptance criteria (AC-9–AC-12 and AC-14 conditional on optional Step 10 or the user's MVP pass per spec §8; AC-13's VoiceOver order is the user's device check)
- Partial: none
- Missing: none
- Ambiguous: none
- Out of scope (per plan): none
- False claims about existing code: 0
- Traceability: plan carries AC numbers
- Round-2 findings 1–4: all resolved; `isLoading` introduces no AC or test that needs an `isLoading == false` condition (table above)

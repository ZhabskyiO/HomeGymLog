VERDICT: PASS WITH FIXES

## Plan Verifier result — docs/plans/m4-progress.md against docs/specs/m4-progress.md (round 2)

Round 2, 2026-09-16, scoped to the eight round-1 findings (`docs/reviews/m4-progress-verifier-1.md`) plus the consistency sweep the coordinator asked for: leftover references to the removed predicate, the renamed parser type, and the AC-24 scan wording. Re-read: the whole plan, spec §4.1, §4.4 (DEBUG), §6 and AC-22–AC-24, `.claude/skills/design-compare/SKILL.md` lines 24–40. Grep evidence: `archivedCompletedPredicate`, `completedRaw`, `6 tops`, `verified shape` return nothing in the plan; `DebugProgressSelection` returns nothing in the plan and one line in the spec. Matrix rows not named below are unchanged from round 1 (covered).

### Round-1 findings, re-checked

| round-1 id | fix claimed | evidence | status |
|---|---|---|---|
| F1 (should-fix) — wrong count "6 tops" | Step 6 expects 4 | plan Step 6 — "`tops("dbBench", map)` on A+B → 4 tops (A: s0, s5, s10; B: s0; `SplitPlans.swift:30`, verifier-1 F1)"; the A-filtered literals unchanged | resolved |
| F2 (should-fix) — unprobed predicate called verified | existing `sessionPredicate(programID:)` + Swift status filter; predicate removed; spec/plan aligned | plan §2 — "the existing `HomeSnapshotBuilder.sessionPredicate(programID:)` plus a Swift `status == .completed` filter (… a new `statusRaw` predicate would be an unprobed shape)"; Step 6 signature list has no `archivedCompletedPredicate`, `archivedCompletedSessions` doc reads "one fetch per program with the existing HomeSnapshotBuilder.sessionPredicate(programID:) … `status == .completed` filtered in Swift"; §4 — "(no new session predicate; verifier-1 F2)"; spec §4.1 — "the existing `sessionPredicate(programID:)` (composing it with a status clause needs `#Predicate.evaluate`, iOS 17.4), `status == .completed` filtered in Swift" | resolved, one stale line left (finding 3 below) |
| F3 (should-fix) — geometry invariant over 7 lists | loops all 11 keys plus hand lists | plan Step 3 — "for every weight list of AC-16/17 (all 11 keys via `ProgressFixtures.tops(midProgram, key)`, plus history 7, `[50, 47.5]`, `[40]`, `[]`; verifier-1 F3)" | resolved |
| F4 (note) — empty state flashes for one frame | rules-only card while `held?.key != effectiveKey` | plan §2 note — "while `held?.key != effectiveKey` (one frame after a chip tap) the chart card draws the rules only, not the empty-state line or fallback Best (`isLoading`, F4)"; but Step 8 and §5 were not updated (finding 1 below) | partially applied |
| F5 (note) — skill lacked the progress crop | recorded in the skill (Row D), prerequisite marked done | `SKILL.md:33-36` — "Row D `progress` sits past the 3000-px right edge: render with `--window-size=4400,5600 …` and crop progress 2340×2330 @ (2540, 1620) … Progress seeds: … `-progressExercise <key>` …"; same numbers as plan Step 0 `PROTO` (`sips -c 2340 2330 --cropOffset 2540 1620`) and spec §8; plan Step 0 — "Prerequisite (done by the main session 2026-09-16; if Step 0 finds a different crop, report it …)"; the offsets follow the skill's existing `--cropOffset <y> <x>` convention (Row D program @ (2530, 30)) and Step 0 still reads the PNG before use | resolved (offsets unrendered until Step 0, guarded) |
| F6 (note) — parser name one letter from `DebugProgramSelection` | renamed `DebugProgressExercise` | plan Step 7, traceability, Files: `DebugProgressExercise` / `DebugProgressExerciseTests` throughout; `grep DebugProgressSelection docs/plans/m4-progress.md` → nothing; spec AC-23 still says `DebugProgressSelection.parse` (finding 2 below) | resolved in the plan, not in the spec |
| F7 (note) — locale for `monthTitle` | `calendar.locale ?? .current` | plan Step 4 — "`Date.FormatStyle(locale: calendar.locale ?? .current, calendar:timeZone:)` `.month(.wide).year()`, like `HomeText.swift:5-7`; no `Date()`" | resolved |
| F8 (note) — unapplied `@MainActor` references | closure-literal note | plan §2 — "use closure literals, not unapplied `@MainActor` function references (Xcode 27 `[#ActorIsolatedCall]`, gotchas 2026-09-14)" | resolved |

### Traceability matrix (rows that changed)

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-21 | Step 3, 4 | geometry invariant over every AC-16/17 input; text strings | grep `verifier-1 F3` | Step 3 loops all 11 keys + hand lists (row above) | covered |
| AC-22 | Step 6 (+ 11) | per-id archived fetch returns exactly the archived program's completed rows; tops across programs | grep `4 tops`, `sessionPredicate` in Step 6 | count corrected to 4; the fetch uses the production predicate `HomeSnapshotBuilder.sessionPredicate(programID:)` (`HomeSnapshotBuilder.swift:11`) with a scalar `status == .completed` filter, so no unprobed shape remains; Step 6 tests still assert "no orphan, no pending, no skipped s11" | covered |
| AC-23 | Step 5, 7 | seeds, `archive`, and the `-progressExercise` parser tests | grep `DebugProgressExercise` in plan and spec | plan Step 7 `DebugProgressExerciseTests` (value / absent / trailing / raw); spec AC-23 line 372 names `DebugProgressSelection.parse` — same artifact, stale name | covered (spec wording stale, finding 2) |
| AC-24 | Step 5–8 | static scans incl. builder hop only in `tops(key:` | read spec AC-24, plan §2 and Step 6 | plan Step 6 `builderHops` — "every hop line is inside `func tops(key:`'s body or inside a `#Predicate` body"; the builder now declares no `#Predicate` containing a `.program` token (`archivedProgramPredicate` is `$0.archivedAt != nil` on `Program`; the session predicate lives in `HomeSnapshotBuilder`), so the `#Predicate` allowance is dead wording in both spec and plan (finding 4) | covered |

### Findings

1. **should-fix** — F4 lives only in the §2 note; Step 8 and §5 still describe the empty-state flash. Evidence: plan Step 8 `ProgressChartCard` "(`name`, `points`, `fallbackLb`, `unit`, `calendar`)" and "`if points.isEmpty { Text(ProgressText.empty) 13 mu .padding(.top, 8) }`", with Best falling back to `fallbackLb` whenever `points` is empty; `ProgressTabView.body` passes only `heldTops(...)` (an empty array while `held?.key != key`), so the card cannot tell "loading" from "no sessions"; plan §5 — "a chip tap shows the empty state for the frame before its fetch (B3 accepts: never the previous line)". The implementer builds from Step 8, not from the §2 note. Fix: in Step 8 add `isLoading: held?.key != key` to `ProgressContent` → `ProgressChartCard`; gate the empty line and the planned-fallback Best on `!isLoading` (Best "—", no from/to, rules only while loading; `chartEmptySummary` may stay); rewrite the §5 bullet to "a chip tap draws the rules-only card for the frame before its fetch (F4)". React note: `isLoading` is the `status === 'pending'` branch you render before the query resolves, distinct from an empty result.

2. **should-fix** — Spec AC-23 still names the old parser type. Evidence: `docs/specs/m4-progress.md:372` — "`DebugProgressSelection.parse` (the `-progressExercise` parser): value, missing, trailing flag"; plan Step 7 / §7 / Files use `DebugProgressExercise` and `DebugProgressExerciseTests` everywhere. Fix: change the one spec token to `DebugProgressExercise.parse`, so AC-23's artifact name matches the plan and the eventual test file.

3. **should-fix** — One stale §5 bullet still prescribes the removed predicate. Evidence: plan §5 — "**Predicate composition via `evaluate` (17.4+)** → a separate one-hop predicate", which contradicts §2 ("the existing `HomeSnapshotBuilder.sessionPredicate(programID:)` plus a Swift `status == .completed` filter … a new `statusRaw` predicate would be an unprobed shape"), Step 6's `archivedCompletedSessions` doc and §4 ("no new session predicate"). An implementer reading §5 could reintroduce the shape F2 removed. Fix: "→ the existing `sessionPredicate(programID:)` per archived program, `status == .completed` filtered in Swift inside the task (F2)".

4. **note** — The AC-24 builder scan keeps a `#Predicate` allowance that nothing uses any more. Evidence: spec AC-24 (line 378) — "appears only inside `tops(key:` or inside a `#Predicate` body"; plan §2 — "allow it inside `#Predicate` bodies (Step 6)"; plan Step 6 `builderHops` — "inside `func tops(key:`'s body or inside a `#Predicate` body". After F2 the only `#Predicate` in `ProgressSnapshotBuilder.swift` is `archivedProgramPredicate` (`$0.archivedAt != nil` on `Program`, no `.program` token), and the session predicate is `HomeSnapshotBuilder`'s. The allowance is harmless (the Features scan has none, and the `body`-never-hops intent is still enforced) but it would let a future builder `#Predicate` hop `.program` unnoticed. Recommended: drop "or inside a `#Predicate` body" from spec AC-24, plan §2 and Step 6, leaving `tops(key:` as the only permitted hop site. Not required for PASS.

5. **note** — The recorded progress crop (2340×2330 @ (2540, 1620)) has not been rendered yet; Step 0's "read `build/proto-progress.png` (if cut or offset, fix the crop … and re-run)" plus the "report it so the main session fixes the skill" clause cover it. The offsets use the same `--cropOffset <y> <x>` convention as the skill's other rows (`SKILL.md:27-32`), consistent with the `sips` centre-offset gotcha (2026-09-11) as those rows were recorded.

### Implicit requirements

Unchanged from round 1 (all addressed). F2's Swift-side filter runs inside the fingerprint task on scalar `statusRaw` reads (≈ 7 µs/row on 17.5 per researcher addendum Q3, ≤ 120 rows), so the "no `program` hop in `body`" rule and the per-render cost are untouched.

### Summary

- Covered: 25 of 25 acceptance criteria (AC-9–AC-12 and AC-14 conditional on optional Step 10 or the user's MVP pass per spec §8; AC-13's VoiceOver order is the user's device check)
- Partial: none
- Missing: none
- Ambiguous: none
- Out of scope (per plan): none
- False claims about existing code: 0
- Traceability: plan carries AC numbers
- Round-1 findings: F1, F3, F5, F7, F8 resolved; F2 resolved with one stale §5 line (finding 3); F4 applied as a §2 note only (finding 1); F6 resolved in the plan, spec AC-23 not updated (finding 2)

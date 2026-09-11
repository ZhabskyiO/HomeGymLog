# plan-verifier — m2-program-tab, round 1, 2026-09-11

**VERDICT: PASS WITH FIXES.** 25 of 26 ACs covered, AC-12 partial, none missing. Every spec table the plan copies
(5.1 windows, 5.2 chips, 5.3 initial week, 5.4 default day, 5.5 cells, 5.7 card targets, 5.8 kg texts, AC-18a day
counts) was recomputed from the Engine and seed code and agrees. 24 claims about existing code checked; one false in a
date only (session 7 is Wed 09-09, not 09-10; expectation unaffected). Sketches compile in principle (nonisolated
Engine value types, `@MainActor` suites for app-target types, no new `#Predicate`, iOS 17 `onChange` form, `@Entry`
already in use). DEBUG isolation and the single-write-path reset design verified.

## Should-fix (applied to the plan in the main session, 2026-09-11)

1. Step 6 sketched `SessionCard(…)`, introduced only in Step 7 → Step 6 uses `EmptyView()` until Step 7 replaces it.
2. Step 8 probe ended with `git checkout --` on an untracked file → restore the commented line by hand (`cp` aside first);
   `DEST26`/`UDID26` shorthands added for the 26.5 leg.
3. AC-12 "store unchanged after every tap" had no failing check → static grep for any SwiftData writer symbol under
   `Features/Program` and `ProgramTabText.swift`, must print nothing.
4. Session 7 date corrected to Wed 09-09.

## Notes (adopted where cheap)

5. AC-23's raw grep also catches comments naming the flags → noted next to the scan.
6. `CalendarRules.days(from:to:calendar:)` carries the `calendar:` label the spec omits → grep spec/INSIGHTS after implementation.
7. AC-7/AC-8 reached by preselection, tap mechanics covered by AC-9 → acceptable.
8. 26.5 shorthands (see 2).
9. Optional `dayCells` test across the 2026-11-01 fall-back week (WK 9) → add if cheap during Step 2.
10. `WeekChipRow.onAppear` scroll precedes the parent's reset (harmless; token path suffices).
11. Prototype crop offset for `program` treated as a starting guess (it was verified visually in the main session: row D1 at (2530, 30)).

User question (finding 2 default taken): probe runs before any commit on the branch; the line is restored by hand.

## Round 2 (scoped, same agent) — PASS

All seven applied items confirmed on the exact plan lines; 26 of 26 ACs covered, false claims 0. Notes 6, 7, 10, 11
stand as notes.

# m2-home — plan verification, round 1 (2026-09-11)

**VERDICT: PASS WITH FIXES.** 19 of 23 ACs covered, 4 partial (AC-9, 14, 18, 20), 0 false claims about existing
code, traceability intact, step order builds green in principle.

## Findings
1. should-fix — Step 1 uses an undeclared fresh-program fixture; add `HomeFixtures.freshProgramInput()`.
2. should-fix — Step 2 worked number wrong: 49 320 lb → 22 371 kg (not 22 372).
3. should-fix — Models `init(program:)` on a nonisolated Engine type needs `@MainActor extension`.
4. should-fix — AC-20 expected PR list must be spelled in the 5.9 sort order (date desc, index desc, order asc).
5. should-fix — §5 claims a two-sessions-one-day test Step 1 does not plan; add it.
6. should-fix — Step 7 row sketch hardcodes " lb"; use the unit parameter.
7. note — FreshProgramSeedTests lacks the in-memory assertion.
8. note — 17.5 observation probe deferred to M3's plan; record when known.
9. note — `try!` in Engine `HomeStatsInput.empty`; prefer a non-throwing private init.
10. note — INSIGHTS "single validating step" wording: Models init delegates to Engine `init(sessions:logs:)`.
11. note — ">200 tests" unverified (165 @Test attributes today).
12. note — size stat tiles/strip columns with `.frame(maxWidth: .infinity)`, not containerRelativeFrame.

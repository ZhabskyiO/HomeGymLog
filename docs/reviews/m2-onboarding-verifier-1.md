# m2-onboarding — plan verification, round 1 (2026-09-10)

**VERDICT: PASS WITH FIXES.** 26 of 27 ACs covered, AC-15 partial, 0 false claims about existing code, traceability
intact. Seed ↔ snapshot pairings match spec §8. Step order builds cleanly (Engine → Models → draft → clock/seed/rename
→ router and views). Current tree passes its suite (82 `@Test` declarations).

## Findings
1. **should-fix** — Step 6 `RootView.body` uses a ternary between two View types; use `if/else` in the `@ViewBuilder` body.
2. **should-fix** — AC-15's test is tautological after Step 1 makes the generator's `usedKeys` come from
   `SplitPlans.exerciseKeys`; also assert `Set(generated.sessions.flatMap { $0.exercises.map(\.exerciseKey) }) ==
   Set(SplitPlans.exerciseKeys(...)!)` for all 12 pairs (the session lists are still built independently).
3. **note** — §2 says only `App/AppClock.swift` may call `Date()`/`Calendar.current`, but Step 5's `App.init` sketch reads
   `Calendar.current`; reconcile, and extend the Step 10 grep to `Date\(\)|Date\.now|Calendar\.(current|autoupdatingCurrent)`.
4. **note** — Seeder writes `LoggedSet` fields directly (spec 4.4 allows it); INSIGHTS "only store functions and model
   inits" should say "…and direct `LoggedSet` mutations, as M3's swipe will".
5. **note** — Step 5 is the largest diff; split into 5a (clock + rename + App wiring) and 5b (DebugSeed + tests).
6. **note** — `DebugSeed.parse` with a trailing `-seed` and no value is unspecified; recommend throwing `unknownSeed("")` and a test.
7. **note** — `ProgramSummaryTextTests` expects "Mon, Aug 31" under the `en_US_POSIX` fixture; pass `Locale(identifier: "en_US")` in that test if needed.
8. **note** — Step 4's Verify claims an AC-10 draft assertion the test list lacks; add `draft.units = .kg` leaves
   `bodyWeightLb` and `startingWeightsLb` unchanged.

Verified claims include: `usedKeys` accumulation at ProgramGenerator.swift:77-107; exactly five `= Date()` model
defaults; `RootView` referenced only by HomeGymLogApp and its preview; `@Entry` macro has no availability gate;
`@Query(filter:)` takes a plain `Predicate<Element>?`; `.defaultAppStorage` iOS 14; tests build Debug.

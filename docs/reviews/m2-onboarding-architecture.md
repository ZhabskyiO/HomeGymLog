# m2-onboarding — architecture review (2026-09-10)

**Verdict: approve with changes.** Conforms to every settled decision; no schema change needed. `midProgram` dataset
(spec 4.4) verified by hand against WeightFormula and SplitPlans: all top-weight rows, session dates, week-3 volume
7 560, session-0 volume 6 120, PRs, streak 3, current week 3 Foundation; every seeded weight loadable. kg table correct.

## Blocking
- **B1** Spec 5.1 starting-weight rows wrong for (5, 20) and (5, 60). Correct: (5,20) 12 rows `dbBench, inclineDb,
  shoulderPress, latPull, lowRow, dbRow, goblet, rdl, legExt, chestPress, split, legCurl`; (5,60) 18 rows `dbBench,
  inclineDb, shoulderPress, pecDeck, latRaise, pushdown, latPull, lowRow, dbRow, rdl, curl, goblet, legExt, legCurl,
  split, lunge, chestPress, skull`. (3,20), (4,45), (5,45) correct.
- **B2** The seeder would be a second writer of the completed-status invariant. Add
  `WorkoutLogStore.finish(_ log:, at:, in:) throws` in this slice (sets `finishedAt`, `session.status = .completed`, one
  save); M3 reuses it. Seeder builds logs/exercises/sets via model inits only; never touches `statusRaw`/`finishedAt`.
  Seeded done sets get non-nil `loggedAt`. Persistence test for `finish`.
- **B3** Frozen "today" needs one injection point: a SwiftUI environment value `AppClock { now: () -> Date; calendar }`
  set at the root from the seed; nothing below the root calls `Date()`/`Calendar.current`.
- **B4** "Start program" and the AC-22 guard are model-layer: `ProgramStore.current(in:)` and
  `ProgramStore.start(inputs, bodyWeightLb:, experience:, now:, calendar:, in:) throws -> Program?` (nil without
  writing when a current program exists). The view calls `start` and writes the unit preference only.

## Non-blocking (adopted unless noted)
- Router view under `.modelContainer` with `@Query(filter: archivedAt == nil)`; body switches on `isEmpty`; no
  navigation state. M3 folds the in-progress-log route in later.
- Seeded container: `Result { try DebugSeed.parse(...).map { try $0.makeContainer(calendar:) } ?? AppSchema.makeContainer(inMemory: false) }`,
  seed branch under `#if DEBUG`; everything below `.modelContainer` identical.
- Seeded launches discard preferences via `.defaultAppStorage(UserDefaults(suiteName: "seed")!)` with the suite cleared
  at launch; `@AppStorage` never in the `App` struct.
- `App/DebugSeed/DebugSeed.swift` entirely inside `#if DEBUG`: `enum DebugSeed: String, CaseIterable`, `parse`,
  `referenceDate`, `initialDraft`, `makeContainer`. Tests build Debug so it is testable.
- One `@Observable final class OnboardingDraft` owned by the flow root; clamped mutations on the draft; A6 preview
  computed once on the 4→5 transition and held as `preview: GeneratedProgram?`.
- `SplitPlans.exerciseKeys(frequency:sessionLengthMinutes:)` (first-appearance walk) shared by the generator's
  `usedKeys` and the starting-weight rows; small `StartingWeightRow` value.
- `ProgramSummary` value in Engine; text formatting in Shared.
- `WeightUnit: String { lb, kg }` stored by `@AppStorage("units")`; `WeightDisplay.text/bodyWeightText/volumeText` in Engine.
- 4.4 nit: `createdAt` 06:00 so the first workout does not precede the program.
- Optional: `WorkoutLogStore.start(session:at:)` now so the seeder uses no model inits (adopted: it gives M3 a tested start).

## Decisions to record
Router view; environment clock; seed preference suite; `finish` as the single writer (amend "one writer" entry);
`ProgramStore.start` owns "at most one current" on the create side; draft ownership; row-order rule; `units` key;
DebugSeed location and testability.

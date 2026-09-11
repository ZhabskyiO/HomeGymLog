# m2-onboarding — swift-reviewer report (2026-09-10)

Read the full diff, all new files, the new suites, and ran both a Debug build (zero warnings) and a Release build.

## Findings, most severe first (all applied the same day)
1. **Release configuration did not compile**: `App/HomeGymLogApp.swift` named `DebugSeed` (a `#if DEBUG`-only type)
   outside the guard. Fix applied: plain locals (`makeContainer`, `clock`, `defaults`, `seedDraft`) decided first, the
   seed branch entirely inside `#if DEBUG`, `Result(catching: makeContainer)`. A Release build line was added to
   `/ship-check` and CLAUDE.md so this class of leak is caught every time.
2. **`WorkoutLogStore.start` reassigned `session.workoutLog`** on a second call, orphaning the first log and every
   swiped set (unreachable, and `.cascade` does nothing on iOS 17). Fix applied: return the existing log (resume).
   Test added for the double call.
3. **Start-program save failures were invisible in Release** (`catch { assertionFailure }`). Fix applied: keep the
   assertion, add a plain alert in Release.
4. `isStarting` was inert (synchronous call, `defer` reset before the route flip). Fix applied: reset only on failure
   so the CTA stays disabled until the shell appears.
5. `ProgramStore.start` overwrites `inputs.generatedOn` with `now`; documented as intentional (generated for the day it
   is started, `createdAt` the same instant).
6. Readability: `where seen.insert(key).inserted` rewritten as a plain loop; `Int(rawValue.dropFirst(2))!` in
   `DebugSeed` replaced by an explicit `onboardingSteps` switch. `SegmentedPicker`'s labelled-tuple options left as is.

## Checked and sound
Router + `@Query` + `@AppStorage` identity; `ProgramStore.start` single save; seeder only via store functions;
in-memory seeded container and cleared defaults suite; every SwiftUI API iOS 17.0 (`@Entry` back-deploys,
`defaultAppStorage` iOS 14); `Date()`/`Calendar.current` only in `AppClock.swift` (`Locale.current` fallback in
`ProgramSummaryText` is locale, not clock); `Date.distantPast` defaults, `Equipment.stepped`, `WeightDisplay`
rounding, shared `exerciseKeys` all correct and tested.

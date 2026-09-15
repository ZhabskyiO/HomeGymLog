# Swift review — m4-missed-day (uncommitted, branch `m4-missed-day`)

**Verdict: ship.** No blocking findings. Reviewed by reading only (no `xcodebuild`, per the brief); the caller's gate (671/671 on 17.5 and 26.5, Release green) stands as the build evidence. The writers, the Engine rules, the host and the card all match the spec, the architecture items B1–B6 / NB1–NB9, and the probe-settled shapes (P1 concrete `ZStack` root, P2 `.highPriorityGesture` after `.offset`, overlay after `.safeAreaInset`). The new tests are non-vacuous: expected maps come from `MissedDayFixtures.originalDate` (calendar arithmetic, never `Reslot`), the failed-save suite reads first through a same-context fetch by id, keeps both containers bound, and calls `rollback()` before the temp store is removed.

## Blocking

None.

## Non-blocking

1. **`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Home/MissedPromptHost.swift:52-54` — `.isModal` is on the inner container, whose only siblings are inside the host.** VoiceOver's modal rule excludes *siblings* of the modal element; the TabView and floating bar are siblings of the host's outer `ZStack` (the overlay pairing), one level up. This is exactly what AC-17 leaves to the device pass, so nothing to change now. If the device check shows focus escaping to "Start workout" or the "Program" tab button, the alternative is to put the trait on the outer root only while showing — **unverified** (no probe covered it; XCUITest cannot see the trait): `ZStack(alignment: .bottom) { … }.accessibilityAddTraits(shows ? .isModal : [])` — proven only by VoiceOver on the phone: swipe right past "Skip it · stay on schedule" and confirm focus stays in the card, on both runtimes if a 26.x device is available.

2. **`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Home/MissedSessionCard.swift:56-58` — `dragY` is left at the drag distance after `onDismiss()`.** Harmless today because the host removes the card once the silence is set, but the card's correctness then depends on the host's behaviour, and after a Skip on `missed-several` the same card instance re-renders in place with its `@State` intact. A one-line reset removes the coupling:
   ```swift
   if value.translation.height >= 80 {
       onDismiss()
       dragY = 0
   } else { … }
   ```
   (≈ resetting a `useState` drag offset in the same handler that fires the callback, instead of relying on the parent unmounting the component.)

3. **`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Home/MissedPromptHost.swift:35` — `enabled != false` reads as "enabled is true" to a newcomer, but `nil` also passes.** The property's doc comment explains it; a named local makes the three-valued rule visible at the use site:
   ```swift
   let promptAllowed = enabled ?? true   // nil = normal (Release, unseeded); false only from a DEBUG seed
   let shows = promptAllowed && selected == .home && MissedDay.shouldPrompt(…)
   ```
   (≈ `const promptAllowed = props.enabled ?? true` for an optional prop.)

Everything else checked reads as intended:
- `ProgramStore.shift` / `skipMissed` (`/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Models/ProgramStore.swift:78-110`): the map is computed before any row is touched; an empty map or `false` writes nothing and leaves `hasChanges == false` (tested); the snapshot is a loop over `rows` (no `Dictionary(uniqueKeysWithValues:)`); one `StoreCommit.commit` per writer (rollback → restore → rethrow); a kill before the save loses nothing because every change is in-memory until that one save. `skipMissed` restores `statusRaw`, the field `skip(_:)` actually writes.
- `Engine/MissedDay.swift` is total: the `isMissed` guard, the `0...6` weekday guard in front of `CalendarRules.firstTrainingDay`'s precondition, `[:]` for an index before the first session, and every date step through `CalendarRules` (tested across the 2026-11-01 fall-back). `isMissed` is pinned equal to `HomeStats.sessionState == .missed` over 120 sessions at four instants, so the prompt and the Program card cannot disagree.
- Host: query ownership (its own `@Query`, `.id(program.id)` in `ShellView`), `now` written only in the three handlers, the silence keyed on the rendered `today` (not the tap's clock), "show it" derived every render, handlers call the writers with `clock.now()`, the failed-save path leaves the prompt up (rows unchanged) and only asserts in Debug. The route flip unmounts the shell and the host with it; the program-delete path (m4-settings) empties the query before `RootView` swaps routes, and the body reads nothing from `program`, so no deleted-object read.
- `ProgramView.shift`: follow-today only on a non-empty map, `selection`/`now`/`scrollToken` written in the handler, never `reset`. `SessionCard` derives the two buttons from `state == .missed` (no second flag).
- DEBUG: `forcesMissedDayPrompt` is read on one line inside the `#if DEBUG` seed branch; the `@Entry` is nil by default; `MissedDaySeed` and the three new cases are under `#if DEBUG`; the `preconditionFailure`s are DEBUG-only. Release fallbacks are `assertionFailure` in `catch` after the store has already restored, so no blank or stuck screen.
- Views: `MissedPromptHost.body` ~33 lines, `MissedSessionCard.body` ~35, `SecondaryActionButton` matches `StartWorkoutButton` by construction. React mappings are present for `@Query`, `.id`, `useState`, `aria-modal`, the capture-phase gesture, and the reducer analogy in `MissedDay`.
- Tests: `MissedDayRollbackTests` throws-assertion fails if the writer silently succeeds or writes nothing; `MissedDayStoreTests` reads through a fresh `ModelContext(store.container)` and holds `TestStore`; `MissedSeedTests` pins `mainContext.hasChanges == false`; `DebugSeedTests` loops `allCases` for `forcesMissedDayPrompt`; `MissedPromptSourceTests` mirrors `RestNotifierSourceTests` with stable tokens.

## Questions

1. AC-17 (item 1 above): does the device pass want the fallback shape recorded in the plan now, or only if VoiceOver escapes the card?
2. After a drag-dismiss the card disappears at its dragged offset with no animation (no `withAnimation` around the silence write). The spec does not ask for one; is that intended for this slice, or should a `withAnimation(.easeOut)` around `silence = …` in `MissedPromptHost.dismiss` be added in a later polish pass (M5 haptics/polish)?

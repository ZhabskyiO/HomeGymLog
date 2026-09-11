# swift-reviewer — m2-home, 2026-09-11

Release build succeeded with zero project warnings; no DEBUG-only type leaks past its guard. No data-loss or
corruption issue: Home writes nothing, every unwrap on model data is `if let`/`guard let`, and the `@Query`-per-screen
pattern matches the iOS 17.5 findings.

## Findings (most severe first) and what was done

1. **`personalRecords` could trap on input `HomeStatsInput` accepted** — `Dictionary(uniqueKeysWithValues:)` traps on two
   logs sharing a `sessionIndex`; the input validator checked session uniqueness and log membership but not log uniqueness.
   Unreachable from the app today (`PlannedSession.workoutLog` is to-one). **Fixed both ways**: `HomeStatsInput.init`
   now throws `HomeStatsInputError.duplicateLogIndex`, and `personalRecords` uses `uniquingKeysWith:` as a belt-and-braces.
2. **`HomeView.input` fell back to a blank Home, and `@State logs` could outlive its program** — in Release an
   `assertionFailure` is a no-op, so a validation error rendered `.empty` (0 · 0/0 · 0, no cards). And if the current
   program ever changes without RootView's branch flipping, `logs` (state) holds the old program's values for one frame
   → `unknownSessionIndex`. **Fixed**: fallback is now sessions-only (header, tiles, strip and cards stay correct; only
   PRs/volume drop for that frame), and `ShellView` gives `HomeView` `.id(program.id)` so all state resets with the
   program (React: `key={program.id}`).
3. **Streak walk filter was a double negation** — `!( !isBeforeToday && !isToday )`, and the same "not after today" was
   spelled three ways. **Fixed**: one `isAfterToday` helper used in `streak`, `currentWeek`, `nextSession`.

## Minor observations

- `weekVolumeLb` compared raw `scheduledDate` against the week window while everything else normalises through
  `startOfDay`. **Fixed** (normalised).
- `RecentRecords` is a fixed `HStack` of four equal cards, not the spec's horizontal scroll with min width 130.
  Accepted: matches the prototype; spec §2.6 wording is the one that is off (noted for doc-writer).
- `.task(id:)` in `HomeView` contains no `await`, so it is a synchronous memo keyed on the fingerprint. If
  `finishedLogs` ever grows an `await`, check `Task.isCancelled` before the `logs =` write.

Everything else checked out: `.sheet(item:)` with one optional `Identifiable`, `now` written only on appear/scene-active,
`weekStrip` day arithmetic through `CalendarRules.day` (DST-safe), `kfmt` rounding after unit conversion, ties excluded
from PRs, `@Relationship` delete rules unchanged, seeds write only through the stores.

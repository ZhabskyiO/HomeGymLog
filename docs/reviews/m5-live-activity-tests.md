# m5-live-activity — test-writer gap pass (2026-10-03)

Scope: Engine and persistence code added by the slice (`RestActivityPlan`, `RestTimer.next`, `ContentState.interval`, the
ninth backup key, `RestActivityHandler`). Only `HomeGymLogTests/` was touched; no production file changed.

## Added (31 test functions, 43 cases with parameterized arguments expanded)

| File | Tests (cases) | Covers |
|---|---|---|
| `HomeGymLogTests/Engine/RestActivityPlanGapTests.swift` | 9 (11) | clock moved back (`now < restStartedAt`: 11:59:46, 11:00, the day before) → request, and a matching activity is kept; 12:01:01 still live; foreign + changed match in both orders → end foreign, update match; end order foreign-then-duplicates (`[b,x,a,y]` → `[x,y,a]`, update `b`); a start-only content change → update; `stranded` leaves a foreign id to the screen, ends all in order when no workout |
| `HomeGymLogTests/Engine/RestTimerNextGapTests.swift` | 7 (12) | before the last set of the last exercise → set 3 of 3; after it is rated → summary → nil; logged but unrated → RPE pending → nil; swapped exercise → new key; swapped exercise with 2 / 4 sets → count from its own sets; empty list → nil for five states; index 5 (one past) nil vs 4 |
| `HomeGymLogTests/Shared/RestActivityContentStateGapTests.swift` | 3 | equal instants → `t...t`; end a day before start → `start...start`; a 1 ms rest is not clamped |
| `HomeGymLogTests/Engine/BackupLiveActivityRoundTripTests.swift` | 4 (9) | whole-file `BackupCodec.encode` → `read`: the key present (false, true), absent beside eight non-default keys (resolves on, others kept), wrong JSON types (`"false"`, `"no"`, `null`, `[]`, `{}`) → nil → on, file still reads, Sound stays off; no preferences object |
| `HomeGymLogTests/Seed/RestActivityHandlerFailedSaveTests.swift` | 4 | read-only on-disk store: a refused +30s leaves the store (fresh context on the writable container) at 11:59:47 → 12:01:02; a refused Skip leaves the same-context row (first fetch, by id) and the store with both instants, ends no activity, re-schedules at 12:01:02. `rollback()` in a `defer` right after the writing context; both containers bound for the test |
| `HomeGymLogTests/Seed/RestActivityHandlerShownTests.swift` | 4 | handler on `wo-rest` in memory: foreign + match → `[end x, update a, schedule]`; duplicates → `[end b, update a, schedule]`; nothing shown → request with the stored 12:01:32; preference off with nothing shown → schedule only |

Already covered by the implementer's suites, so not duplicated: every §5.1 row, `enabled` false with nothing shown,
`stranded`'s four spec rows, all six `rowState` combinations, Skip/+30s/no-log handler paths, the refused +30s's
same-context read and events.

## Runs (iOS 17.5, iPhone 15)

- Focused: `xcodebuild … -only-testing:HomeGymLogTests/<each of the six suites> test` under the gotchas watchdog: TEST SUCCEEDED.
- Full: `rm -rf build/tests.xcresult && xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult test`;
  `xcrun xcresulttool get test-results summary`: **totalTestCount 1301, passed 1301, failed 0** (was 1270).

## Production defects

None found. Every new test passed on the first run; the refused-Skip event test doubles as a control that the read-only
save really throws (a successful save would record `[end a, cancel]`).

## Untestable without a change (report only)

- The restore's preference write (`HomeGymLog/App/RootView.swift:158-168`, now including `liveActivityEnabled`) assigns
  nine `@AppStorage` properties inside a view; no test can assert the ninth key lands in `UserDefaults` after a restore.
  Smallest change: a `ResolvedPreferences.write(to defaults: UserDefaults)` (or a static in the Models layer) that
  `performRestore` calls, testable with a throwaway suite.

## Assertions that cannot meaningfully fail

- `HomeGymLogTests/Engine/RestActivityKeyTests.swift:18` and `:19-20`: `#expect(Self.key() == Self.key())` compares two
  identical constructions under synthesized `Equatable`; it can only fail if a field were NaN-like. It is a positive
  control for the `!=` test below it, so keep it, but a stronger form pins one field change that must *not* matter
  (none exists here) or compares against a literal-built key: `#expect(Self.key() == RestActivityKey(logID: "L",
  restStartedAt: t, restEndsAt: t.addingTimeInterval(62), nextText: "Next: set 2 of 3", enabled: true, activeTick: 0, endedCount: 0))`.
- `HomeGymLogTests/Seed/RestActivityHandlerRollbackTests.swift:58-64`: the per-event loop is subsumed by the exact
  `outcome.events == [.schedule(original, withSound: true)]` on line 66 (redundant, not unfailable); it could be removed.

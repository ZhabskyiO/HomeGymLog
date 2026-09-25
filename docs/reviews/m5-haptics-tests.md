# m5-haptics: test-writer coverage review (2026-09-24)

Scope: spec ACs 11–18, the Engine and notifier edges, and the weak tests the implementer's suite already had. I changed
only test files. No production defects found.

## Result

- Command: `xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath build/DerivedData test`
  (run without `-resultBundlePath`, per the test-writer rule. I counted from the log instead.)
- `** TEST SUCCEEDED **`. **1080 test functions**, up from 1066 (15 added, 1 removed). That is **1775 test cases** once
  each parameterized argument counts as its own case. **0 failures.**
- Only iOS 17.5 was run, as the task asked. I did not re-run iOS 26.5.

## Files

Created:
- `HomeGymLogTests/Engine/FeedbackCueEdgeTests.swift` (10 tests):
  - `restSkipCue` 1 ms before the end, exactly at the end, a day after it, and a day before it
  - `restSkipCue` with every preference pair, on a live rest and on a stale or absent rest
  - `restEndCue` with a non-announcing observation under all four preference pairs (always nil)
  - `restEndCue` with an announcing observation under each pair
  - `RestReconcileKey` when there is no rest: the keys differ on `withSound` alone
  - `RestReconcileKey` with ends 1 ms apart: the keys differ
- `HomeGymLogTests/Seed/DebugFeedbackPreferencesEdgeTests.swift` (5 tests, DEBUG):
  - a repeated argument: the first occurrence wins
  - a bad second occurrence is never read
  - a bad first occurrence throws
  - `-haptics -sound off` throws `unknownValue("-haptics", "-sound")`
  - `[]` gives (nil, nil)

Changed:
- `HomeGymLogTests/App/ReminderNotifierSoundTests.swift`: **removed `silent(withSound:)`**. `.silent(status:)` receives no
  center, so its recorder was never connected and `events.isEmpty` / `addedWithSound.isEmpty` held no matter what the
  code did. The doc comment now gives the reason.
- `HomeGymLogTests/App/ReminderNotifierTests.swift:121` (`silent(status:)`): now also runs a pass with `withSound: false`.
  This test can fail: the status must survive a pass with either flag.
- `HomeGymLogTests/App/RestChimeTests.swift` (`smoke`): dropped `#expect(built.count == 3)`. `(0..<3).map` always
  returns 3 elements, so the assertion could not fail. The test now calls `.live()` three times with no expectation and
  says so. As AC-14 says, it is a smoke test and fails only on a trap.
- `HomeGymLogTests/Engine/FeedbackCuesTests.swift` (`tableIsComplete`): it checked only `count == 12`. It now also checks
  that each of the 12 (event, Haptics, Sound) combinations appears exactly once, so a duplicated row that hides a missing
  one fails.

## AC coverage

| AC | Covered by |
|---|---|
| 11 | `FeedbackCuesTests` (5.1 table, keys), `FeedbackRestCueTests` (5.2 and 5.3 rows, key equality), `FeedbackCueEdgeTests` (edges), `FeedbackSourceTests.feedbackCuesIsPure` |
| 12 | `RestNotificationContentTests`, `ReminderNotificationContentTests` |
| 13 | `RestNotifierSoundTests`, `ReminderNotifierSoundTests`, `ReminderRowStateTests.soundCounts` / `nilStatusEitherSound`, `ReminderNotifierTests.silent` |
| 14 | `RestChimeTests` (smoke only, by design) |
| 15 | `SettingsTextTests` |
| 16 | `RestChimeAssetTests`, `FeedbackSourceTests` audio confinement |
| 17 | `FeedbackSourceTests`, `SettingsScreenSourceTests`, `RestNotifierSourceTests`, `SeedNameScanTests` |
| 18 | `DebugFeedbackPreferencesTests` and the new edge suite |

This slice changed no model-layer writer, so no new failed-save case applies. The existing
`WorkoutCommitRollbackTests` and `ExerciseNoteSaveTests` pass.

## Other weak or duplicate assertions (left as they are)

- `HomeGymLogTests/App/RestChimeAssetTests.swift:15`: `#expect(duration < 1)` is implied by
  `duration <= 0.21` on line 14. It can fail, but it adds nothing. It can go, or stay as the spec's literal wording.
- `HomeGymLogTests/Engine/FeedbackRestCueTests.swift:66-72` (`lifecycleNil`): `relaunch` and `returned` use the same
  inputs `(nil, e, resting: false, now: at(70))`, so the second check repeats the first. To cover a different path,
  make `returned` the scene-active pass with `resting: true` → `false`, or delete it.

## Observations (not defects)

- `DebugFeedbackPreferences.parse` reads only the first occurrence of each argument, so
  `-haptics off -haptics maybe` parses without an error. The spec does not cover repeated arguments. The new tests
  record this behaviour so a change is deliberate.
- The B1 guarantee ("apply the cue only if the save wrote") lives in `WorkoutView.skipRest`, and only a static
  line-order scan checks it (`FeedbackSourceTests.skipOrder`). No behaviour test covers it. The smallest change that
  would make it testable: move `if wrote, let cue { … }` into a pure Engine function, for example
  `FeedbackCues.applied(_ cue: FeedbackCue?, wrote: Bool) -> FeedbackCue?`, and test it with a table.

React analogy: `@Test(arguments:)` is Jest's `test.each`. Each argument row is its own reported case, which is why the
1080 functions produce 1775 cases.

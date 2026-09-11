---
name: run-tests
description: Run the HomeGymLog unit tests (Swift Testing, HomeGymLogTests target) on the simulator and summarize passes and failures with expected vs actual. Use when asked to run tests, or after Engine or model changes. Accepts an optional test filter argument.
---

Run the test suite and report results honestly. Never edit production code from this skill.

## Steps

1. If no `*.xcodeproj` exists, stop and say so.
2. Choose a simulator the same way `build-and-run` does (booted first, else newest iPhone). A test run on another
   runtime can shut down other booted simulators; after the run, re-boot the one used for screenshots
   (`xcrun simctl boot <udid>; xcrun simctl bootstatus <udid> -b`) before any install or screenshot.
3. Run. If an argument was given, treat it as a filter for `-only-testing:` (e.g. `HomeGymLogTests/ProgramGeneratorTests`).
   ```
   xcodebuild test -scheme HomeGymLog -destination "platform=iOS Simulator,name=<name>" \
     -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult \
     [ -only-testing:<filter> ] 2>&1 | tee build/last-test.log | grep -E "✔|✘|Test Suite|Executed|error:|TEST (SUCCEEDED|FAILED)"
   ```
   Delete a stale `build/tests.xcresult` first; xcodebuild refuses to overwrite it.
4. If the build itself failed, report compiler errors as `path:line: message` and stop.
5. For each failing test, pull the failure message from the log (`#expect` prints expected and actual).
   If the log is unclear, inspect the bundle:
   `xcrun xcresulttool get test-results tests --path build/tests.xcresult 2>/dev/null | head -100`.

## Report

- Counts: passed, failed, skipped, and the wall time.
- Every failure: test name, file:line, expected vs actual, and a one-line diagnosis stating whether the
  test or the production code looks wrong. Do not fix production code here; say what you found.
- If everything passed, say so in one line. No list of passing tests unless asked.

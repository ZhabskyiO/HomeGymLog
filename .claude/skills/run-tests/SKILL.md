---
name: run-tests
description: Run the HomeGymLog unit tests (Swift Testing, HomeGymLogTests target) on the simulator and summarize passes and failures with expected vs actual. Use when asked to run tests, or after Engine or model changes. Accepts an optional test filter argument.
---

Run the test suite and report results honestly. Never edit production code from this skill.

## Steps

1. If no `*.xcodeproj` exists, stop and say so. If `xcodebuild -version`, `xcrun` or `git` print "You have not agreed to
   the Xcode license agreements" (Xcode updated itself), stop: ask the user to run `sudo xcodebuild -license accept` and
   `sudo xcodebuild -runFirstLaunch` in Terminal, then re-check `xcrun simctl list runtimes` and `xcodebuild -showsdks`.
2. Choose a simulator the same way `build-and-run` does (booted first, else newest iPhone), and always pass its OS in the
   destination (`name=iPhone 15,OS=17.5`, `name=iPhone 17,OS=26.5`): names repeat across runtimes. A test run on another
   runtime can shut down other booted simulators; after the run, re-boot the one used for screenshots
   (`xcrun simctl boot <udid>; xcrun simctl bootstatus <udid> -b`) before any install or screenshot.
3. Run. If an argument was given, treat it as a filter for `-only-testing:` (e.g. `HomeGymLogTests/ProgramGeneratorTests`).
   ```
   xcodebuild test -scheme HomeGymLog -destination "platform=iOS Simulator,name=<name>,OS=<os>" \
     -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult \
     [ -only-testing:<filter> ] 2>&1 | tee build/last-test.log | grep -E "✔|✘|Test Suite|Executed|error:|TEST (SUCCEEDED|FAILED)"
   ```
   Delete a stale `build/tests.xcresult` first; xcodebuild refuses to overwrite it. If the run fails before any test
   with "Failed to clone device … stuck in creation state", re-run with `-parallel-testing-enabled NO`. CoreData/SQLite `error:` lines and "save failed … Code=513" come from the
   suites that force a failed save on purpose; judge the run by `TEST SUCCEEDED` and the result-bundle counts.
4. If the build itself failed, report compiler errors as `path:line: message` and stop.
5. For each failing test, pull the failure message from the log (`#expect` prints expected and actual).
   If the log is unclear, inspect the bundle:
   `xcrun xcresulttool get test-results tests --path build/tests.xcresult 2>/dev/null | head -100`.

## Report

- Counts: passed, failed, skipped, and the wall time.
- Every failure: test name, file:line, expected vs actual, and a one-line diagnosis stating whether the
  test or the production code looks wrong. Do not fix production code here; say what you found.
- If everything passed, say so in one line. No list of passing tests unless asked.

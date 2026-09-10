---
name: build-and-run
description: Build the HomeGymLog iOS Simulator target, launch it on a booted iPhone simulator, and report compiler errors as file:line. Use when asked to build, run, or "check it compiles".
---

Build and run HomeGymLog on the iOS Simulator. Report the outcome faithfully: a failed build is a failed
build, with the errors.

## Steps

1. Locate the project: `ls *.xcodeproj *.xcworkspace 2>/dev/null`. If none exists, stop and say the
   Xcode project has not been created yet.
2. Confirm the scheme: `xcodebuild -list -json | jq -r '.project.schemes[]'`. Use `HomeGymLog` unless it
   is missing; then report the available schemes and stop.
3. Pick a simulator. Prefer a booted one: `xcrun simctl list devices booted -j | jq -r '.devices[][] | .name' | head -1`.
   If none is booted, boot the newest available iPhone:
   `xcrun simctl list devices available -j | jq -r '.devices[][] | select(.name|test("^iPhone")) | .name' | tail -1`
   then `xcrun simctl boot "<name>"` and `open -a Simulator`.
4. Build:
   ```
   xcodebuild -scheme HomeGymLog -destination "platform=iOS Simulator,name=<name>" \
     -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log | grep -E "error:|warning: .*(unused|deprecated)|BUILD (SUCCEEDED|FAILED)"
   ```
   `build/` is gitignored.
5. On failure: list every `error:` line as `path:line: message`, grouped by file, and stop. Do not retry
   with different flags. If the error matches an entry in `insights/gotchas.md`, cite it. If it took more
   than a few minutes to understand, add an entry there.
6. On success, install and launch:
   ```
   APP=$(find build/DerivedData/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "*.app" | head -1)
   xcrun simctl install booted "$APP"
   xcrun simctl launch --console-pty booted com.zhabskyi.homegymlog
   ```
   Report the app launched, or the launch error verbatim.

## Report

Three lines at most on success: simulator used, build time if visible, "launched". On failure, the
error list. Warnings only if they are new compared to `build/last-build.log` from the previous run.

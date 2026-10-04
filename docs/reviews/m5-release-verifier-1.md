VERDICT: PASS WITH FIXES

## Plan Verifier result — docs/plans/m5-release.md against docs/specs/m5-release.md

Round 1, 2026-10-03. Read in order: `CLAUDE.md`, `insights/INSIGHTS.md` (top entry "2026-10-03 — M5 release decisions", every
bullet), `insights/gotchas.md` "Xcode / build", the spec, the plan, `docs/reviews/m5-release-architecture.md` (B-1–B-3,
NB-1–NB-6), `docs/reviews/m5-release-researcher.md` (Q1–Q9), then every file the plan touches or claims exists. The plan
carries AC numbers on every step and a traceability table; traceability is intact. No blocking finding: every code claim
is true, no step edits `project.pbxproj` by an agent, no command line carries `INFOPLIST_FILE=` or `INFOPLIST_KEY_*`, the
only new plist sits in `HomeGymLogSupport/` at the repo root (outside every synchronized folder), no dependency, model,
entitlement or seed is added, and every B/NB item of the architecture review is honored. Two should-fix findings
(a screenshot-script recipe bug that would abort Step 6 on its success path, and one AC-13 predicate the planned
`StoreMetadataTests` omit), plus notes.

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | Step 4 | ob0 matches prototype; tile is the icon artwork, same 44 pt slot, radius 12 | grep `AC-1`, `WelcomeTile`, `decorative` in plan | plan Step 4: `Image(decorative: "WelcomeTile").resizable().scaledToFit().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12))` replaces `WelcomeStep.swift:9–13` (verified: lines 9–13 are the `Text("H")` block); `/design-compare ob0` against `build/rel/proto-ob0.png`, `RCMP s4` span ≤ 132 rows; reads the shot | covered |
| AC-2 | Step 4 | ob3 subtitle reads "Session length sets how many exercises you do." | grep `Session length` in plan | plan Step 4: `AboutYouStep.swift:9` (verified: today `subtitle: "Used to size sessions and starting loads."`); `/design-compare ob3`; DIFF rows confined to the subtitle band | covered |
| AC-3 | Steps 4, 9 | 13 named screens unchanged outside status bar / home indicator | grep `RCMP`, `RLIST` | Step 0 `RLIST` holds the 13 names plus ob0/ob3; baselines `build/shot-rel-base-*`; `RCMP s4` and `RCMP s9` expect `same` for all 13; `CMPX … 150` skips the status band and the helper ignores the bottom 60 rows | covered |
| AC-4 | Step 2 | `AppIcon` Contents.json: three universal/ios/1024 entries with filenames, zero `mac` | grep `AC-4`, `mac` | Step 2(b) decoders `IconSet`/`IconImage`, exactly three images, `appearances` per filename, zero `mac`; (c) hand-edits the JSON (today: 3 ios entries without `filename`, 10 `mac` objects, verified `grep -c '"mac"'` = 10); tests run red first | covered |
| AC-5 | Step 2 | three PNGs 1024×1024 via `CGImageSource`; light `HasAlpha != true` | grep `HasAlpha`, `1024` | Step 2(b) `pixelInfo(_:)` over `CGImageSourceCopyPropertiesAtIndex`, `kCGImagePropertyHasAlpha as? Bool != true` on the light image only; `file`/`sips -g hasAlpha` cross-check; red first (no PNGs today, verified `ls AppIcon.appiconset` = `Contents.json` only) | covered |
| AC-6 | Step 2 | WelcomeTile.svg byte-equal to source; Contents.json shape; hex = AccentColor; no `<text`; four rect pins ×3 SVGs | grep `byte`, `preserves-vector`, `x="160"` | Step 2(b) lists every predicate; verified against the files: `x="160" y="464"`, `x="220" y="232"`, `x="628" y="232"`, `width="704" height="96"` each occur exactly once in all three `design/icon/*.svg`; `<text` 0 ×3; `#E11D48` present in the light SVG; `AccentColor.colorset` single entry `0xE1 0x1D 0x48` | covered |
| AC-7 | Steps 3 (+ 2 svg half) | manifest four keys; none in widget/shared; Support/Info.plist one key; no Info.plist under HomeGymLog/; resource surface = {rest-over.caf, PrivacyInfo.xcprivacy}; only .svg = WelcomeTile.svg | grep `AC-7`, `NB-2` | Step 3 tests list all six predicates (`[String: Any]` cast for `UILaunchScreen`, U10); Step 2(b) the `.svg` half; today's surface verified: `find HomeGymLog -type f ! -name "*.swift" ! -path "*/Assets.xcassets/*"` → `HomeGymLog/rest-over.caf` only, no `.svg` | covered |
| AC-8 | Step 8 | `Bundle.main` manifest URL at bundle root, bytes equal source | grep `AC-8` | Step 8 `ReleaseBundleTests`: non-nil URL, parent (symlinks resolved) == `bundleURL`, `Data` == `appSourceRoot/PrivacyInfo.xcprivacy`; plain `#expect`; created after Step 7 | covered |
| AC-9 | Step 8 | `UIImage(named: "WelcomeTile")` size 1024×1024 | grep `AC-9` | Step 8: `UIImage(named: "WelcomeTile")?.size == CGSize(width: 1024, height: 1024)`, `@MainActor`, `import UIKit`; U14 runtime probe with the Step 2 fallback named | covered (see finding 3) |
| AC-10 | Step 8 | infoDictionary: portrait array, encryption false, UILaunchScreen.UIColorName "bg", 1.0 / 1, LiveActivities true | grep `AC-10` | Step 8 six predicates, `(info["UILaunchScreen"] as? [String: Any])?["UIColorName"] as? String == "bg"`; plain `#expect`, after the checkpoint (B-3) | covered |
| AC-11 | Step 4 | new subtitle once; "Used to size" nowhere; no `Text("H")`; one `"WelcomeTile"` line with `Image(decorative:`; no other `Image("` literal | grep `AC-11`, `ReleaseCopyTests` | Step 4 `ReleaseCopyTests` with the five predicates over `FeedbackSourceTests.codeLines`/`appFiles`; red first; verified today: no `Image("`/`Image(decorative` in the app, no test pins `Text("H")` or the old subtitle | covered |
| AC-12 | Step 5 | five fenced blocks, limits, keyword terms ≥ 3, banned words, name == HomeGymLog | grep `AC-12`, `violations` | Step 5 `StoreMetadataTests.blocks(in:)` + `violations(_:)` with every AC-12 rule; a checker control proving three violations | covered |
| AC-13 | Step 5 | pages ≥ 400 bytes with `<contact email>`/`@`; privacy page has `<effective date>` (or `20` year); checklist has `xcodebuild archive`, `Validate App` | grep `effective`, `AC-13` | Step 5 AC-13 bullet: size, `<contact email>` or `@`, the two checklist strings — the `<effective date>` predicate is absent (grep `effective` in the plan hits only F5 and the file-content line 235, not the test) | partial |
| AC-14 | Step 8 | semantic pbxproj pins: orientation 2 lines Portrait-only, encryption 2 × NO, INFOPLIST_FILE 4 (2 Support, 2 Widgets), versions ×6, LiveActivities ×2 | grep `AC-14` | Step 8 `ReleaseProjectTests` over `LiveActivityProjectTests.lines()`, every pin as token-and-value (B-2), `GENERATE_INFOPLIST_FILE` excluded (F1); "every predicate was false on Step 0's values" — verified today: Landscape count 2, encryption 0, INFOPLIST_FILE 2 | covered |
| AC-15 | Steps 1, 3, 9 | Release build 0 warnings; manifest in .app; plist read-back; appex keeps `NSExtensionPointIdentifier` | grep `RELEASEW`, `plutil` | Step 1 `RELEASEW` → `BUILD SUCCEEDED, 0` (today 12 lines = 6 diagnostics ×2); Step 3 `ls -a $REL`; Step 9 the three `plutil -p` lines after the checkpoint and the appex line | covered |
| AC-16 | Step 6 | five 1320×2868 RGB screenshots; script with `mktemp -d`, `trap … status_bar clear`; override cleared | grep `AC-16`, `trap` | Step 6 recipe with both SVG namespaces (F4), `trap 'rm -rf "$TMP"; xcrun simctl status_bar "$UDID" clear' EXIT`, failure-path probe with `/nonexistent.app`, `status_bar … list`, every image read; udid verified available (`iPhone 17 Pro Max (5236ED20-CDE1-441F-9F48-54E856A3FB90) (Booted)`); seeds `midProgram`, `wo-swipe`, `wo-rest`, `progress-history` and tabs `progress`/`program` exist | covered (see finding 1 for the recipe bug) |
| AC-17 | Step 10 | archive succeeds; dSYMs; appex under PlugIns; both identifiers + team; manifest; three plist values; no -exportArchive | grep `archive`, `exportArchive` | Step 10 command byte-equal to researcher Q5 #2 (signed, no `CODE_SIGNING_ALLOWED=NO`); `-allowProvisioningUpdates` only as a retry; checks match §5.8; `-exportArchive` appears in the plan only in "no `-exportArchive`" | covered |
| AC-18 | Step 9 | full suite green on 17.5 and 26.5 incl. `ReleaseBundleTests`; icon rerun byte-identical by `shasum` | grep `TEST26S`, `shasum` | Step 9 `BUILD && TEST; CNT` then `TEST26S; CNT26` (boot first, `-parallel-testing-enabled NO`, gotcha 2026-10-03); `shasum $ICON` before/after `make-app-icon.py` → `identical` (F2) | covered |
| AC-19 | Step 7 | user performs GUI steps 1–3; §4.3 greps read as listed; observed lines to gotchas | read plan Step 7 | Step 7 click paths + the seven greps with today/after values; `git diff $PBX` recorded for U9; user-run | covered (user-run) |
| AC-20 | user; Step 12 optional | device: icon, `bg` launch, no rotation, Settings lists Live Activities/Notifications, VoiceOver skips tile | plan §User-run ACs | listed verbatim; never a merge gate | out-of-scope — plan line 34: "Excluded ACs (user-run, never merge gates): AC-20 and AC-22" |
| AC-21 | Step 2 | "Done by this slice": artwork ships through the script | grep `AC-21` | Step 2 end: "AC-21 (closed by this step)"; `design/icon/` verified: three SVGs, `HomeGymLog-icon-1024.png` (RGB, not an input), `NOTE.md`; no root duplicates (`ls *.svg *.png` → none) | covered |
| AC-22 | user | public Pages repo, fill URLs, §2.6 steps 3–7 | plan §User-run ACs | listed; user-run | out-of-scope — plan line 34 (quoted above) |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|--------|
| `Engine/RestartPrefill.swift:31–32` read `OnboardingDraft.bodyWeightRangeLb` from a `nonisolated` context | read | `:31 bodyWeightLb: min(max(bodyWeightLb, OnboardingDraft.bodyWeightRangeLb.lowerBound),` `:32 OnboardingDraft.bodyWeightRangeLb.upperBound),` in `nonisolated enum RestartPrefill`; these are the only Engine code lines naming `OnboardingDraft` | true |
| `OnboardingDraft.swift:32` `static let bodyWeightRangeLb = 50.0...500.0` on a `@Observable final class`; `:95` uses `Self.bodyWeightRangeLb`; no other caller | grep `bodyWeightRangeLb` in app, tests, shared, widgets | exactly four hits: `OnboardingDraft.swift:32`, `:95`, `RestartPrefill.swift:31`, `:32`; `@Observable` at `:6`, `final class OnboardingDraft` at `:7`; no test reads it | true |
| `ProgramGenerator.swift:60–62` the three `static let` sets on `nonisolated enum ProgramGenerator` | read | `:59 nonisolated enum ProgramGenerator {` `:60 static let allowedMonths` `:61 allowedFrequencies` `:62 allowedSessionLengths` | true |
| `WorkoutView.swift:91` `.map(RestText.nextLine)` | read | `:91 nextText: RestTimer.next(exercises: exercises, state: state).map(RestText.nextLine),` | true |
| `WorkoutLogStore.swift:220`, `:291` `.map(SetSnapshot.init)`; `:288` `contains(where: awaitsRating)`; `:324` closure precedent with comment | read | `:220 let snapshots = ([set] + carried).map(SetSnapshot.init)`; `:288 guard !sets.contains(where: awaitsRating)`; `:291 let snapshots = pending.map(SetSnapshot.init)`; `:324 let setSnapshots = sets.map { SetSnapshot($0) }   // a closure, not \`SetSnapshot.init\`: the unapplied reference warns on Xcode 27`; `private struct SetSnapshot` `:20`, `private static func awaitsRating(_ set: LoggedSet)` `:252`, `enum WorkoutLogStore` `:18` | true |
| `RestText.next` calls `WorkoutText.exerciseName` (so `RestText` must not go `nonisolated`) | read `Shared/RestText.swift` | `:34 static func next(_ next: RestNext) -> String {` `:36 … WorkoutText.exerciseName(key: exerciseKey) …`; `:42 static func nextLine(_ next: RestNext) -> String` | true |
| App target: Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency | grep pbxproj | `:476–477, :521–522` `SWIFT_APPROACHABLE_CONCURRENCY = YES; SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;` (app configs only), `SWIFT_VERSION = 5.0;` ×6 | true |
| `GENERATE_INFOPLIST_FILE = YES;` ×6 at `:452,497,538,565,593,629` | grep -n | exactly those six lines | true |
| `INFOPLIST_FILE` lines excluding `GENERATE_INFOPLIST_FILE` = 2 today (the widget's) | `grep -v GENERATE_INFOPLIST_FILE \| grep -c INFOPLIST_FILE` | `2` — `:594`, `:630` `INFOPLIST_FILE = HomeGymLogWidgets/Info.plist;` | true |
| `MARKETING_VERSION = 1.0;` ×6, `CURRENT_PROJECT_VERSION = 1;` ×6, `INFOPLIST_KEY_NSSupportsLiveActivities = YES` ×2 | grep -c | 6, 6, 2 (`:453`, `:498`) | true |
| Orientation `_iPhone` lines ×2 with Landscape (today 2), Portrait 2; encryption key 0 today | grep | `:463`, `:508` `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";`; Landscape/UpsideDown count 2; Portrait 2; `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` 0 | true |
| `.gitignore:2` is `build/` | read | `:2 build/` | true |
| `FeedbackSourceTests.appSourceRoot` internal `static var` at `Static/FeedbackSourceTests.swift:8`; `codeLines`, `appFiles` exist | read | `:8 static var appSourceRoot: URL {`; `:15 static func codeLines(_ file: URL)`; `:27 static func appFiles()`; suite is `@Suite struct` with no access modifier (internal) | true |
| `LiveActivityProjectTests.lines()` internal `static func` at `:16`; no pin counts `INFOPLIST_FILE` or orientation | read whole file | `:16 static func lines() throws -> [String]`; pins: `IPHONEOS_DEPLOYMENT_TARGET` ×6, `TARGETED_DEVICE_FAMILY = 1;` ×6, `NSSupportsLiveActivities` ×2, `SWIFT_DEFAULT_ACTOR_ISOLATION` ×2, app-extension productType ×1, widgets bundle id ×2, `membershipExceptions` block has `Info.plist,`, `HomeGymLogShared` ≥ 3 / `path = HomeGymLogShared;` ×1 — none touched by the three GUI settings | true |
| `ColorsetContrastTests` filters `*.colorset`; `hardCodedColorSites` at `:247–257` without a `Color.white` token; `Color("` scan | read | `:53 .filter { $0.pathExtension == "colorset" }`; `:247 let hardCodedColorSites` … `:257 ]` tokens `.shadow(`, `Color.black`, `.black`, `preferredColorScheme`, `UIColor(`, `.primary`, `.secondary`, `Material`; `:179 matches { $0.contains("Color(\"") }` expects 11, all in `Shared/Theme.swift` | true |
| Non-Swift files under `HomeGymLog/` outside `Assets.xcassets` = `rest-over.caf` only; no `.svg` under `HomeGymLog/` | find | `HomeGymLog/rest-over.caf`; `find HomeGymLog -name "*.svg"` empty | true |
| `AppIcon.appiconset/Contents.json`: three `universal`/`ios`/`1024x1024` entries, ten `mac`, no PNGs | read, grep -c, ls | as claimed; folder holds only `Contents.json` | true |
| `AccentColor.colorset` single entry `0xE1 0x1D 0x48`, no dark variant; `bg.colorset` `F4F2F3` / dark `0F0E10` | read | as claimed | true |
| `WelcomeStep.swift:9–13` is the `Text("H")` block with `Color.white`; `AboutYouStep.swift:9` the subtitle | read | `:9 Text("H")` … `:13 .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))`; `:11 .foregroundStyle(Color.white)`; `AboutYouStep.swift:9 StepTitle(title: "About you", subtitle: "Used to size sessions and starting loads.")` | true |
| No `Image("` / `Image(decorative:` literal in the app today; no test pins `Text("H")` or the old subtitle | grep app + tests | zero hits in `HomeGymLog`, `HomeGymLogShared`, `HomeGymLogWidgets`; tests: zero hits for `Text("H")`, `Used to size` | true |
| `design/icon/`: three SVGs `0 0 1024 1024`, `xmlns:c2pa`, one `<metadata>` each, no `<text>`, `-dark.svg` exactly one `#0F0E10` rect as `<rect …></rect>`; 1024 PNG RGB; `NOTE.md` | read, grep, python regex | five files; `viewBox="0 0 1024 1024"` ×3; `<metadata>` 1 ×3; `<text` 0 ×3; `0F0E10` 1 in dark, 0 elsewhere; `</rect>` 4/4/3; dark SVG bytes: `<rect width="1024" height="1024" fill="#0F0E10"></rect>`; the plan's `re.findall` pattern returns exactly 1 match (that rect); `file` → `1024 x 1024, 8-bit/color RGB`, `hasAlpha: no` | true |
| Mark geometry pins (`x="160" y="464"`, `x="220" y="232"`, `x="628" y="232"`, `width="704" height="96"`) one hit each in all three SVGs | grep -o \| wc | 1/1/1/1 in each file | true |
| `/opt/homebrew/bin/rsvg-convert` 2.60.0 | ls, --version | symlink to `librsvg/2.60.0/bin/rsvg-convert`; `rsvg-convert version 2.60.0` | true |
| udid `5236ED20-CDE1-441F-9F48-54E856A3FB90` = iPhone 17 Pro Max, available | `xcrun simctl list devices available` | `iPhone 17 Pro Max (5236ED20-CDE1-441F-9F48-54E856A3FB90) (Booted)` | true |
| Seeds `onboarding`, `ob1`–`ob5`, `midProgram`, `missed`, `wo-start`, `wo-swipe`, `wo-rest`, `summary`, `progress-history`; `-tab program/progress/settings` | read `DebugSeed.swift`, `AppTab.swift`, `DebugProgramSelection.swift` | all cases present (`:19`, `:25–35`, `:57`); `AppTab: case home, program, progress, settings`; `-tab` parser `:29` | true |
| `DebugSeed.allCases` iterations in `HomeGymLogTests/Seed/` = eight (DebugSeedTests ×4, Restart, LiveActivity, Backup, Reminder) | grep -rn allCases | `DebugSeedTests.swift:10,87,94,96`, `RestartSeedTests:21`, `BackupSeedTests:41`, `LiveActivitySeedTests:35`, `ReminderSeedTests:41` = 8 (`DebugProgramSelectionEdgeTests:36` is `AppTab.allCases`, not a seed) | true |
| Every suite named in Step 1 / "breaks: none" exists; clamp pins exist | grep `struct <Name>` | all 22 names found; `RestartPrefillTests.swift:75 "body weight is clamped into 50…500 lb"`, `RestartPrefillEdgeTests.swift:69,72,73` (500.1, ±infinity), `OnboardingDraftTests.swift:45 "… clamped to 50…500 lb"` | true |
| `build/haptics-env.sh` supplies `DEST DEST26 UDID UDID26 BID APP BUILD TEST ONLY WONLY CNT LAUNCH SHOT APPEAR BOOT SEEDCLR` | read the source chain | `haptics-env.sh:1 source build/reminder-env.sh` → `reminder-env.sh:1 source build/settings-env.sh`; `settings-env.sh:1` `DEST`, `DEST26`, `BID`; `:2–4` `UDID`, `UDID26`, `APP`; `:5–7` `BUILD`, `TEST`, `ONLY`; `:10–13` `BOOT`, `LAUNCH`, `SHOT`, `APPEAR`; `SEEDCLR` in `reminder-env.sh`; `WONLY`, `CNT` in `haptics-env.sh` | true |
| `build/light-env.sh` `CROPS` ob0 `640 720 @ 200 45`, ob3 `640 340 @ 200 1620`; `build/light-cmpx.py`; `design/Benchmark Flows (standalone).html` | read, ls | `light-env.sh:23–24` as claimed; both files exist | true |
| Researcher Q1 XML is the first `<?xml` block in the report, 23 lines | read | lines 45–67 of `docs/reviews/m5-release-researcher.md`; the Q3 snippet (line 196) starts `<plist`, not `<?xml` | true |
| `RestChimeAssetTests` reads the app bundle through `Bundle.main` (hosted precedent) | read | `HomeGymLogTests/App/RestChimeAssetTests.swift:11 Bundle.main.url(forResource: "rest-over", withExtension: "caf")` | true |

### Findings

1. **should-fix** — Step 6's screenshot script aborts on its success path. Evidence: plan Step 6 declares `set -euo pipefail`
   and, per row, "(1) `terminate`, `install "$APP"`, `spawn … defaults delete seed` (tolerated), `launch`"; only `boot` and
   `defaults delete` are marked tolerated. Verified today on the booted iPhone 15: `xcrun simctl terminate <udid>
   <not-running bundle>` prints "found nothing to terminate" and exits `3`. After `simctl boot` the app is not running, so
   the first row's `terminate` kills the script before any screenshot, and the failure-path probe (`/nonexistent.app`)
   would "pass" for the wrong reason. The existing `LAUNCH` helper (`build/settings-env.sh:11`) only silences stderr
   (`2>/dev/null`), which is enough interactively but not under `set -e`. Fix: write the row's first command as
   `xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true` (and likewise mark `boot` with `|| true`), and add "terminate
   tolerated" to the Step 6 bullet so the implementer does not have to discover it. React analogy: `set -e` is a promise
   chain with no `.catch`; a rejected `terminate` short-circuits everything after it.
2. **should-fix** — AC-13 is `partial`: the planned `StoreMetadataTests` omit one predicate. Evidence: spec AC-13 (line 356–357)
   requires `privacy-policy.md` to contain `<effective date>` (or a `20` year); plan Step 5's AC-13 bullet checks only
   "each ≥ 400 bytes and contain `<contact email>` or `@`" plus the two checklist strings (`grep effective` in the plan hits
   the F5 prose and the file-content line 235, never the test). Fix: add `#expect(privacy.contains("<effective date>") ||
   privacy.range(of: #"\b20\d\d\b"#, options: .regularExpression) != nil)` to Step 5's AC-13 list.
3. **note** — AC-9, the only runtime probe of U14 (`UIImage(named: "WelcomeTile")`), is created in Step 8, after the user's
   GUI checkpoint, because spec §8 puts all of AC-8–10 in one post-checkpoint `ReleaseBundleTests` file. B-3 only requires
   the GUI-dependent pins (AC-10, AC-14) to wait. If `assetutil` in Step 2(a) shows a Vector entry but `UIImage(named:)`
   still returns nil on device-like runtime, the implementer reworks Step 2 after the checkpoint. Spec-conformant, so not a
   defect of the plan; recommended default: in Step 2(a) add a one-off hosted `#expect(UIImage(named: "WelcomeTile") != nil)`
   in a scratch test deleted before Step 3, or amend the spec to place AC-8/AC-9 in a hosted suite created in Step 3.
4. **note** — The plan's "Still open" S1/S2 lines (plan lines 18–20) are stale: spec §4.2 (lines 126–127) already says each
   `Contents.json` "is written by hand once (not a script output)", and INSIGHTS' icon bullet already reads "(superseded the
   same evening by the artwork bullet below)". Step 11's "Align … (S2)" becomes a confirm, not an edit. Cosmetic.
5. **note** — Step 5's checker control ("a 31-character subtitle and keywords `home gym,PR,iPhone` yields exactly three
   violations") depends on whether `violations(_:)` also reports a missing `name` / `description` / `promotional-text` as
   violations. Say the control markdown carries valid blocks for the other three ids, or assert the three expected
   violation ids rather than a count of three, so the control cannot fail for an unrelated reason.
6. **note** — Step 12 (optional scratch-copy XCUITest for the AC-20 rotation half) serves a user-run AC and is not scope
   creep; it stays optional and touches nothing in the repo. No action.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | plan §4 Data model changes, Steps 1–10 for any store write | "None: no `@Model`, field, relationship, delete rule, `#Predicate`, preference key, backup key or migration"; the six warning fixes are isolation-only, values unchanged (verified at each site) | addressed (n/a) |
| Delete rules | plan §4 | no new relationship | addressed (n/a) |
| Units | plan Steps 1–10 for `kg` | the only new numeric constant is `bodyWeightRangeLb = 50.0...500.0` (pounds, named `Lb`), copied from `OnboardingDraft.swift:32` | addressed |
| Date determinism | Step 6 seeds; Step 1 Engine change | screenshot seeds run on frozen clocks (`DebugSeed.swift:95–100` Tue 2026-09-15 12:00); the Engine change adds a constant only; `ClockUsageTests` stays the guard | addressed |
| Concurrency | §5.7 rule in Step 1 | closure form at four sites, constant moved into `nonisolated` Engine, no `nonisolated` on `RestText`/`SetSnapshot`/`awaitsRating`, no `@preconcurrency`/`nonisolated(unsafe)`; precedent `WorkoutLogStore.swift:324` compiles warning-free under the same settings (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Swift 5.0) | addressed; U11 probed by `RELEASEW` |
| Availability (iOS 17) | Steps 2–4, 7 | `Image(decorative:)` (iOS 13), SVG imageset with `preserves-vector-representation` (Xcode 12 / iOS 13, researcher Q2), `UILaunchScreen.UIColorName` (iOS 14, Q3), `INFOPLIST_KEY_*` settings exist in Xcode 27 (Q4); dark/tinted icons ignored on iOS 17 (not errors, Q2) | addressed |
| Privacy label | Step 3 manifest; §2.4 | `NSPrivacyTracking false`, empty `NSPrivacyTrackingDomains` and `NSPrivacyCollectedDataTypes`, one `UserDefaults` / `CA92.1` entry; no network, analytics or new usage string; label stays "Data Not Collected" (Q7) | addressed |
| Resume and empty states | plan §1, Step 4/9 | "this slice writes no state"; the 13-screen AC-3 regression covers home, program, progress, settings, missed, workout, summary | addressed |
| Bundle-resource surface (NB-2) | Step 2(b), Step 3 | `.svg` set and non-Swift set pinned; `mkdtemp` intermediates; `git status --short HomeGymLog/` listed in Steps 2 and 9 | addressed |
| GUI-dependent tests (B-3) | Step 7 → 8 → 9 → 10 ordering | `ReleaseBundleTests`, `ReleaseProjectTests`, the `plutil` lines and the archive all follow Step 7; plain `#expect` stated twice | addressed |
| Hand edits of `project.pbxproj`, CLI `INFOPLIST_FILE=`, plist in a synchronized folder | grep the plan for `INFOPLIST_FILE=`, `pbxproj`, `Info.plist` paths | pbxproj changes only by the user in Step 7 and read by `grep`/`git diff`; `INFOPLIST_FILE=` appears only inside "Never pass … on the command line"; the plist lives at `HomeGymLogSupport/Info.plist` (repo root, outside `HomeGymLog/`, `HomeGymLogTests/`, `HomeGymLogShared/`, `HomeGymLogWidgets/`) | addressed |

### Summary

- Covered: 19 of 22 acceptance criteria (AC-1–12, AC-14–19, AC-21; AC-19 user-run at the Step 7 checkpoint)
- Partial: AC-13
- Missing: none
- Ambiguous: none
- Out of scope (per plan): AC-20, AC-22 (user-run, "never merge gates", plan line 34)
- False claims about existing code: 0
- Traceability: plan carries AC numbers on every step and a step table; intact

## Round 2 — 2026-10-03, scoped to round-1 findings 1–5

VERDICT: PASS

Re-read the edited passages of `docs/plans/m5-release.md` only (lines quoted below). Nothing else in the plan or the codebase changed for this round.

| finding | plan spot re-read | evidence | status |
|---------|-------------------|----------|--------|
| 1 (should-fix) `simctl terminate` under `set -e` | Step 6, lines 260 and 265 | line 260: "`simctl boot … 2>/dev/null \|\| true` (tolerate "already booted")"; line 265: "(1) `terminate … 2>/dev/null \|\| true` (**terminate tolerated**: `simctl terminate` exits 3 with "found nothing to terminate" when the app is not running, and under `set -euo pipefail` an untolerated call aborts the first row; `boot` likewise `\|\| true`)" — matches the verified exit code | closed |
| 2 (should-fix) AC-13 `<effective date>` predicate | Step 5, lines 249–250 | "`privacy-policy.md` also contains `<effective date>` or a `20` year (one more `#expect`, spec AC-13)" — spec AC-13 (line 356–357) now fully covered; AC-13 moves from `partial` to `covered` | closed |
| 3 (note) U14 runtime probe after the checkpoint | Step 2(a), lines 130–132 | "Also run a one-off hosted probe now (scratch test, deleted after it passes …): `UIImage(named: "WelcomeTile")` non-nil with size 1024 × 1024 on 17.5"; the fallback trigger now reads "or the hosted probe is nil" | closed |
| 4 (note) stale S1/S2 "Still open" | lines 18–20, 49 | "**Resolved (verifier round 1, note 4):** S1 … S2 … Step 11's item is a confirm, not an edit."; line 49 "Open questions: none (S1 and S2 resolved, see above)." Residual, cosmetic: Step 11 line 373–374 still says "Align the icon bullet's "placeholder" / "derived from it" wording … (S2)" as an edit; the doc-writer will find INSIGHTS already aligned and should treat it as the confirm line 20 describes | closed (cosmetic residual, no action required) |
| 5 (note) checker-control count | Step 5, lines 246–248 | "an inline markdown with valid `name`, `promotional-text` and `description` blocks, a 31-character subtitle and keywords `home gym,PR,iPhone` yields exactly three violations, asserted by id (subtitle length, keyword term `PR` < 3 chars, banned word `iPhone` in keywords), so a missing-block rule cannot inflate the count" | closed |

Round-1 finding 6 was a no-action note and is unchanged.

### Summary (after round 2)

- Covered: 20 of 22 acceptance criteria (AC-1–19, AC-21)
- Partial: none
- Missing: none
- Ambiguous: none
- Out of scope (per plan line 34): AC-20, AC-22 (user-run, never merge gates)
- False claims about existing code: 0
- Traceability: plan carries AC numbers; intact

## Round 3 — 2026-10-03, scoped to the ABOUT card (spec §2.7/§5.9) and the pre-implementation GUI gate

VERDICT: PASS WITH FIXES

Re-read: spec §2.7, §4.3 "Ordering", §5.9, AC-3, AC-10, AC-11, AC-13, AC-19–22 and the "existing tests" list (424 lines); plan "Spec alignment", Steps 0, 2, 3, 5, 6, 11, the traceability table and the user-run section (448 lines). Code read: `Features/Settings/*.swift`, `Shared/SettingsText.swift`, `Shared/ProgressText.swift`, `Shared/WorkoutText.swift`, `HomeGymLogTests/Static/SettingsScreenSourceTests.swift`, `SettingsSourceTests.swift`, `FeedbackSourceTests.swift`, `HomeGymLogSupport/Info.plist`, `design/icon/` after commit `43b262e`, the live `ZhabskyiO/homegymlog-site` contents via `gh api`, and `project.pbxproj` as of this round.

### (a) Traceability of the ABOUT ACs

| AC | plan step | requirement (≤ 15 words) | evidence | status |
|----|-----------|--------------------------|----------|--------|
| AC-3 `settings` | Step 5 | non-scrolled `settings` shot pixel-identical; `/design-compare settings` with the ABOUT deviation | plan Step 5 verify: `RSHOTS s5; RCMP s5 # all 15 same`, then `/design-compare settings` against `build/rel/proto-settings.png` (Step 0 `PROTOOB` adds the `800 290 @ 2555 4148` crop, matching `light-env.sh` / gotcha 2026-09-22); the max-scroll view is Step 11 (optional) and AC-20 | covered |
| AC-10 version line | Step 5(c) | `SettingsText.versionText(short:build:)` from `infoDictionary` == "1.0 (1)" | plan line 270: `ReleaseBundleTests`, appended: `SettingsText.versionText(short: info["CFBundleShortVersionString"] as? String, build: info["CFBundleVersion"] as? String) == "1.0 (1)"`; the Info half stays in Step 3 (`1.0` / `1` pinned there) | covered |
| AC-11 ABOUT half | Step 5(a)(b) | two URL literals once each in `Shared/SettingsText.swift`, nowhere in Shared/Widgets; four strings; `versionText` four cases; `Link(` only in `AboutRows.swift` without `UIApplication`/`openURL`; `bottomPadding` tokens | plan Step 5(a) lists every predicate; raw-line scan justified (see (b)); `Link(` predicate has a collision — finding 1 | partial (finding 1) |
| AC-13 | Step 6 | pages ≥ 400 bytes with `poltavagaz@gmail.com`; privacy has `2026-10-03`; metadata has both URLs; checklist strings | plan line 300–301 names all five predicates; the fetched files satisfy them (see (d)) | covered |
| AC-20 | user; Step 11 optional | max-scroll ABOUT above the pill, links open Safari, VoiceOver order | plan §User-run ACs quotes the spec's wording; Step 11 (a)–(c) probes scroll, `.runningBackground` after the tap, and portrait in a scratch copy only | out-of-scope (user-run, plan line 443 "never block the merge") |

### (b) Claims about the Settings code and tests

| plan claim | found | verdict |
|------------|-------|---------|
| `SettingsContent.swift`: `SettingsSectionHeader(title:)` before each card, `SettingsCard { … }` with `SettingsDivider()` between rows, cards `preferencesCard`/`programCard`/`equipmentCard`/`backupCard`, `private static let bottomPadding = FloatingTabBar.height + 16`, `.padding(.bottom, Self.bottomPadding)` | all present (`SettingsContent.swift:36`, `:40–48`, `:52`, `:57–127`); `SettingsSectionHeader` `:121`, `SettingsCard<Content>` `:133`, `SettingsDivider` `:144` | true |
| `SettingsValueRow` (read-only label/value, one combined accessibility element) in `SettingsRows.swift` | `SettingsRows.swift:5–24`: `HStack` label 15 pt `tx`, value 14 pt `mu`, 16/13 padding, `.accessibilityElement(children: .combine)`, `.accessibilityLabel(label)`, `.accessibilityValue(value)` — the §2.7 row-3 shape | true |
| `ReminderActionRow` text shape (15 pt semibold, `Theme.accent`, full-width leading, 16/13 padding, `.contentShape(Rectangle())`, `.buttonStyle(.plain)`) | `ReminderRows.swift:50–66`, exactly those modifiers | true |
| `SettingsScreenSourceTests.filesScanned` 9 files today; `sectionHeaders` filters `hasSuffix("Section")` == `["programSection", "equipmentSection"]` and three header tokens; `dividerCount` == 10 | `:48–53` nine names (`AboutRows.swift` would sort first, as the plan says); `:107–117` filter and `Set(headers).count == 3`; `:120–124` `dividers == 10` — counted in `SettingsContent.swift`: 5 + 2 + 1 + 2 = 10 | true |
| `.noLiteralCopy`, `.preferencesRowOrder`, `.feedbackToggleRows`, `.rowAccessibilityShape` not broken by `AboutRows` / `aboutCard` | `noLiteralCopy` scans `Text("`/`Button("`/`Label("` (`Text(title)` is none); row-order tokens unchanged; toggle rows count stays 2; `SettingsValueRow` reused | true |
| `SettingsSourceTests.uiApplicationStaysInApp` tolerates `Link` | `:85` `hits("UIApplication.", in: all)` → exactly `[App/ReminderPermission.swift, App/RestActivityCenter.swift, App/RootView.swift]`; `Link(destination:)` contains no `UIApplication.`; today's `openURL` use is `SettingsView.swift:32,53,57` (unchanged) | true |
| Dash convention `ProgressText.none` / `WorkoutText.recordPrevious` | `ProgressText.swift:10 static let none = "\u{2014}"`; `WorkoutText.swift:91–94 recordPrevious … guard let lb else { return "—" }` | true |
| `FeedbackSourceTests.codeLines` cuts at the first `//` (so `https://` vanishes; raw-line scan needed) | `FeedbackSourceTests.swift:15–20`: `if let comment = line.range(of: "//") { return String(line[..<comment.lowerBound]) }` | true |
| `SettingsTextTests` suite exists (named in Step 5's `WONLY`) | `HomeGymLogTests/Shared/SettingsTextTests.swift` | true |
| `RestActivityCenter.settingsURL` precedent for `URL(string:)!` | `App/RestActivityCenter.swift:24 static let settingsURL = URL(string: UIApplication.openSettingsURLString)!` | true |
| `design/icon/` after `43b262e`: no `<metadata>`, rect-only; every round-1 pin still holds | `<metadata` 0 ×3, `xmlns:c2pa` 0 ×3, `#0F0E10` 1 in dark only, `</rect>` 4/4/3, the four attribute pins 1 hit each ×3, dark SVG bytes `<rect width="1024" height="1024" fill="#0F0E10"></rect>`; spec §4.2 (line 136), §4.4 U14 row (line 200) and AC-6 (line 342) updated to "no `<metadata>`" | true |

### (c) The Step 0 gate

Plan Step 0 lines 80–92: the seven greps are token-and-count greps (`grep -c Portrait`, `grep -cE "Landscape|UpsideDown"`, `grep -c "NO"`, `grep -c "HomeGymLogSupport/Info.plist"`, the `GENERATE_INFOPLIST_FILE` exclusion, the two version counts, the LiveActivities count); none pins an exact line, so a quoted or `$(SRCROOT)/`-prefixed value passes (B-2). The gate says "Stop and report on any mismatch; do not build". It also lints `HomeGymLogSupport/Info.plist` (on disk now: 11 lines, `plutil -lint` OK, `UILaunchScreen` → `UIColorName` = `bg`, outside every synchronized folder, untracked), checks `ls HomeGymLog/Info.plist` is empty, confirms `git status --short HomeGymLog.xcodeproj` shows only `project.pbxproj`, and reads the `HEAD` values (`git show HEAD:$PBX`) so Steps 3's predicates are shown false-before. U9 is recorded from `git diff $PBX`. Ordering is sound against the tree as it stands this round: `project.pbxproj` is unmodified (`git status` clean for it; Landscape count 2, encryption 0, `INFOPLIST_FILE` 2), so Step 0's first grep returns 2, not 0, and the implementer stops until the user's steps land; after them, `ReleaseBundleTests` (Steps 2, 3, 5) and `ReleaseProjectTests` (Step 3) are created with plain `#expect` at their natural steps, which is what spec §4.3 "Ordering (revised)" asks. The gate adds `git show HEAD:$PBX | grep _iPhone | grep -cE "Landscape"` → 2 and `grep -c ITSAppUses` → 0, both verified true at `HEAD` now.

### (d) The `gh api` fetch and the committed copies

`gh api repos/ZhabskyiO/homegymlog-site/contents/privacy.md --jq .content | base64 -d` run this round: the repo is public (`private: false`, `has_pages: true`, default `main`), the content field is base64 with embedded newlines and macOS `base64 -d` decodes it (973 bytes, starts `---\ntitle: Privacy policy\npermalink: /privacy/\n---`); `gh auth status` shows a logged-in account, and a public repo's contents endpoint needs none. Predicates: `privacy.md` 973 bytes ≥ 400, `poltavagaz@gmail.com` ×1, `2026-10-03` ×1; `support.md` 1166 bytes, `poltavagaz@gmail.com` ×1. Both live URLs answer `200 text/html`. The plan says the copies carry Jekyll front matter; they do, and spec §2.5 now calls the files "the committed copies of what `ZhabskyiO/homegymlog-site` serves" with the literal email and date, so AC-13 and §2.5 agree.

### Findings (round 3)

1. **should-fix** — The AC-11 predicate "`Link(` only in `Features/Settings/AboutRows.swift`" (spec line 367; plan Step 5(a) line 251) collides with `ShareLink(`. Evidence: `grep -rn "Link(" HomeGymLog` today returns exactly one line, `Features/Settings/BackupRows.swift:16 ShareLink(item: file, preview: …`, whose text contains the substring `Link(`. A `contains("Link(")` scan — the shape every other predicate in `ReleaseCopyTests` uses — would report two files and fail on a correct implementation, inviting a "fix" that weakens the pin. Fix: in Step 5(a) say the scan matches `Link(` as a whole token (regex `(?<![A-Za-z])Link\(`, or a line whose trimmed text starts with `Link(`), and name `BackupRows.swift:16`'s `ShareLink(` as the known non-hit; mirror the wording in spec AC-11. React analogy: `grep "Link("` also matching `ShareLink(` is the same as a selector `[class*="Link"]` catching `ShareLink`.

No other finding. The rest of (a)–(d) is closed as evidenced above.

### Summary (after round 3)

- Covered: 19 of 22 acceptance criteria (AC-1–10, AC-12–19, AC-21)
- Partial: AC-11 (finding 1, one predicate's token shape)
- Missing: none
- Ambiguous: none
- Out of scope (per plan): AC-20, AC-22 (user-run)
- False claims about existing code: 0
- Traceability: plan carries AC numbers and a step table; intact after renumbering (Steps 0–11)

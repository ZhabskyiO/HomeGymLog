# M5 slice 5 — release: app icon from `design/icon/`, copy fix, Settings ABOUT card, privacy manifest, Info keys, 0 warnings, store metadata, screenshots, archive
**Status: planned 2026-10-03.** Branch `m5-release`, baseline `43b262e` (1301 tests on iOS 17.5 and 26.5; `design/icon/` and the spec committed in `6a54b20`/`43b262e`).

For `docs/specs/m5-release.md` (architecture review `docs/reviews/m5-release-architecture.md` applied: B-1–B-3, NB-1–NB-6, U9–U13; U14 retired).
Spec §2–§6 and §8 are the contract (`AC-1`…`AC-22`). `implementer`: one step per build, nothing committed. **The user's three Xcode GUI settings
(spec §4.3, AC-19) are done before implementation; Step 0 gates on them** and no step stops for the user. Undo is always "restore by hand"; never
`git checkout`, `git stash` or `git clean` (most files in this slice have no commit yet).

## Spec alignment (spec revised 2026-10-03; the plan follows the revision)
- **F1** `INFOPLIST_FILE` counts exclude `GENERATE_INFOPLIST_FILE` lines (×6, `project.pbxproj:452,497,538,565,593,629`): 2 before the GUI steps, 4 after.
  **F2** AC-18's determinism check is `shasum` before and after a rerun. **F4** the wrapper SVG carries both namespaces, and every output image is read.
  **F6** AC-11 pins `Image(decorative:` on the one `"WelcomeTile"` line. **F7** the archive is the implementer's last step; re-run it if review changes Swift.
  **F8** the gate's tell is the Landscape/UpsideDown count (0 now, 2 at `HEAD`).
- **F3** `design/icon/` is the real artwork and ships now; AC-21 is closed. **U14 is retired**: the `<metadata>` block was stripped (`43b262e`).
  `make-app-icon.py` reads `design/icon/` directly. Both catalog `Contents.json` files are written by hand once; the script writes only its four outputs.
- **F5 / pages.** The site is live (`https://zhabskyio.github.io/homegymlog-site/privacy/`, `/support/`). `docs/release/privacy-policy.md` and `support.md`
  are **fetched** from `ZhabskyiO/homegymlog-site` (`privacy.md`, `support.md`) with `gh api`, so they are byte copies of what the site serves, Jekyll
  front matter included. I chose this over retyping §2.5. Probed while planning (repo head `dea6a29`): 973 bytes and a support page that both carry
  `poltavagaz@gmail.com`; the privacy page reads `Effective: 2026-10-03`.
- **ABOUT card (§2.7, §5.9)** is in scope (§9 Q1 resolved): new Step 5.
- **GUI gate (§4.3 "Ordering", AC-19)**: the old mid-plan checkpoint is gone. `ReleaseBundleTests` / `ReleaseProjectTests` are created at their natural
  steps (2, 3, 5) with plain `#expect`. `HomeGymLogSupport/Info.plist` already exists on disk (written by the main session).

## 1. Goal and scope
Make the app submittable, Engine and pure helpers before views:
Step 0 gates on the user's GUI settings and records their pbxproj lines; Step 1 zeroes the six Release warnings (every later Release build is a clean
probe); then the icon, the manifest, the A1 tile and A4 subtitle, the Settings ABOUT card, the App Store text and pages, the 6.9" screenshots; finally
both runtimes, the Release plist read-back, and the signed archive.

Every step ends green on iPhone 15 / iOS 17.5.
**Out of scope (spec §7):** upload, `-exportArchive`, the App Store Connect record, CloudKit, localization, a widget manifest or display name, iPad, `.icon` files.
**Excluded ACs:** AC-20 and AC-22 are user-run after the merge; AC-19 was done before implementation (Step 0 verifies it); AC-21 is closed by Step 2.

No dependency, entitlement, capability, model, preference or seed is added. `rsvg-convert` is a dev-machine tool, like `afconvert` (NB-5).

## 2. Decisions this plan relies on
- **INSIGHTS** 2026-10-03 "M5 release decisions" (icon slots with fixed names, artwork in `design/icon/`; manifest CA92.1; Info keys through the GUI;
  `HomeGymLogSupport/`; copy audit; 0 warnings; `docs/release/`; one 6.9" set; the archive as done) and its architecture bullets: B-1, NB-1, B-3, B-2, NB-2.
- **Spec §2.7 / §5.9** (ABOUT card geometry, URL and `versionText` contracts); m4-settings §2 geometry; m5-export's bottom-padding rule (`SettingsContent.swift:35`).
- **Researcher** (binding): Q1 manifest, Q2 rsvg RGB / imageset / mac entries inert, Q3 merged plist outside synchronized folders, Q4 hosted shapes,
  Q5 archive, Q6 6.9" screenshots, Q9 `HasAlpha != true`.
- **gotchas** Xcode/build 2026-10-03 (the release entries; the 26.5 hang after `simctl` shots), 2026-09-25 (26.5 first-shot island), 2026-09-24
  (non-Swift files under `HomeGymLog/` ship; hosted `Bundle.main` is the app), 2026-09-23 (`WONLY`), 2026-09-22 (`sips -c h w --cropOffset y x`).
- **Open questions:** none. Minor findings are in the hand-back (the plist is 11 lines, not "11-line"; `design/icon` is already committed).

## 3. Steps
Every command block starts with `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/release-env.sh`. Run one foreground `xcodebuild` at a time
(timeout 600000). "Green" means `BUILD SUCCEEDED`, a passing `WONLY` summary, `TEST SUCCEEDED`, and `CNT` with `failedTests: 0` and `totalTestCount` =
the previous count + the step's new tests. "RELEASEW 0" means `BUILD SUCCEEDED` then `0`.

### Step 0 — GUI gate, shorthands, baselines (AC-19 check; one gotchas entry, no code)
Write `build/release-env.sh` (gitignored, `.gitignore:2`). It first does `source build/haptics-env.sh`, which supplies `DEST DEST26 UDID UDID26 BID APP BUILD TEST ONLY WONLY CNT
LAUNCH SHOT APPEAR BOOT SEEDCLR`, then defines:
```
PBX=HomeGymLog.xcodeproj/project.pbxproj; REL=build/DerivedData/Build/Products/Release-iphonesimulator/HomeGymLog.app; mkdir -p build/rel
PROMAX=5236ED20-CDE1-441F-9F48-54E856A3FB90
CMPX() { python3 build/light-cmpx.py "$@"; }            # a.png b.png [topRowsToSkip]; bottom 60 rows ignored
RELEASEW() { xcodebuild -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build > build/last-release.log 2>&1; grep -E "BUILD (SUCCEEDED|FAILED)" build/last-release.log; grep -c "warning:" build/last-release.log; }
TEST26S() { xcrun simctl boot $UDID26 2>/dev/null; xcrun simctl bootstatus $UDID26 -b >/dev/null; rm -rf build/tests26.xcresult
  xcodebuild -scheme HomeGymLog -destination "$DEST26" -derivedDataPath build/DerivedData -resultBundlePath build/tests26.xcresult \
  -parallel-testing-enabled NO test 2>&1 | tee build/last-test26.log | grep -E "✘|TEST (SUCCEEDED|FAILED)"; }
CNT26() { xcrun xcresulttool get test-results summary --path build/tests26.xcresult | jq -c "{result,totalTestCount,passedTests,failedTests}"; }
RLIST=("ob0|-seed onboarding" "ob1|-seed ob1" "ob2|-seed ob2" "ob3|-seed ob3" "ob4|-seed ob4" "ob5|-seed ob5" "home|-seed midProgram"
  "program|-seed midProgram -tab program" "progress|-seed midProgram -tab progress" "settings|-seed midProgram -tab settings"
  "missed|-seed missed" "wo-start|-seed wo-start" "wo-swipe|-seed wo-swipe" "wo-rest|-seed wo-rest" "summary|-seed summary")
RSHOTS() { for e in "${RLIST[@]}"; do SEEDCLR $UDID; LAUNCH $UDID ${=e#*|} >/dev/null; SHOT $UDID "rel-$1-${e%%|*}"; done; }
RCMP() { for e in "${RLIST[@]}"; do local n=${e%%|*}; print -n "$n: "; CMPX build/shot-rel-base-$n.png build/shot-rel-$1-$n.png 150; done; }
PROTOOB() { (cd design && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &); until curl -sf -o /dev/null http://127.0.0.1:8765/; do sleep 0.2; done
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=3000,5600 \
    --virtual-time-budget=20000 --screenshot=build/rel/proto-all.png "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
  sips -c 640 720 --cropOffset 200 45 build/rel/proto-all.png --out build/rel/proto-ob0.png >/dev/null
  sips -c 640 340 --cropOffset 200 1620 build/rel/proto-all.png --out build/rel/proto-ob3.png >/dev/null
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=5600,5600 \
    --virtual-time-budget=20000 --screenshot=build/rel/proto-all-5600.png "http://127.0.0.1:8765/Benchmark%20Flows%20(standalone).html"
  sips -c 800 290 --cropOffset 2555 4148 build/rel/proto-all-5600.png --out build/rel/proto-settings.png >/dev/null; pkill -f "http.server 8765"; }
```
The crops are copied from `build/light-env.sh` `CROPS` (`ob0|3000x5600|640 720|200 45`, `ob3|3000x5600|640 340|200 1620`, `settings|5600x5600|800 290|2555 4148`;
`sips` takes h w, then y x).
**Gate first** (read-only, spec §4.3 semantic greps). Stop and report on any mismatch; do not build:
```
grep INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone $PBX | grep -cE "Landscape|UpsideDown"  # 0 (the tell, F8)
grep INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone $PBX | grep -c Portrait                 # 2
grep INFOPLIST_KEY_ITSAppUsesNonExemptEncryption $PBX | grep -c "NO"                               # 2
grep -v GENERATE_INFOPLIST_FILE $PBX | grep INFOPLIST_FILE | grep -c "HomeGymLogSupport/Info.plist" # 2
grep -v GENERATE_INFOPLIST_FILE $PBX | grep -c INFOPLIST_FILE                                      # 4 (F1)
grep -c "MARKETING_VERSION = 1.0;" $PBX; grep -c "CURRENT_PROJECT_VERSION = 1;" $PBX               # 6 and 6
grep -c "INFOPLIST_KEY_NSSupportsLiveActivities = YES" $PBX                                        # 2
plutil -lint HomeGymLogSupport/Info.plist; ls HomeGymLog/Info.plist 2>/dev/null                    # OK; nothing
git diff --stat $PBX; git status --short HomeGymLog.xcodeproj                                      # only project.pbxproj, only the three settings
git show HEAD:$PBX | grep _iPhone | grep -cE "Landscape"; git show HEAD:$PBX | grep -c ITSAppUses  # 2 and 0: the predicates of Steps 3/8 were false at HEAD
```
**Record U9.** `git diff $PBX > build/rel/pbxproj-gui.diff`. Append one dated entry to `insights/gotchas.md` "Xcode / build" quoting the exact lines the
GUI wrote: whether they are quoted, and whether they carry a `$(SRCROOT)/` prefix. This is the only non-code write in this step.

Then, on the gated tree, before any Swift change:
- `BUILD && TEST; CNT`: expect 1301.
- `RELEASEW`: expect `BUILD SUCCEEDED` and `12`. Run `grep "warning:" build/last-release.log | sort -u` and confirm the six sites of §5.7.
- `BOOT $UDID; APPEAR $UDID dark; RSHOTS base`: the baselines are `build/shot-rel-base-<name>.png`, 15 files.
- `PROTOOB`, then **read** `build/rel/proto-ob0.png`, `proto-ob3.png` and `proto-settings.png` (a blank band means a transposed crop).

### Step 1 — the six Release warnings (§5.7, B-1, NB-1)
- `Engine/ProgramGenerator.swift`: add `static let bodyWeightRangeLb = 50.0...500.0` after `allowedSessionLengths` (`:62`). The value is copied from
  `Features/Onboarding/OnboardingDraft.swift:32`.
- `Engine/RestartPrefill.swift:31–32`: read `ProgramGenerator.bodyWeightRangeLb` (both bounds).
- `Features/Onboarding/OnboardingDraft.swift:32` becomes `static var bodyWeightRangeLb: ClosedRange<Double> { ProgramGenerator.bodyWeightRangeLb }`.
  Line `:95` (`Self.bodyWeightRangeLb`) is untouched.
- `Features/Workout/WorkoutView.swift:91`: `.map { RestText.nextLine($0) }`.
- `Models/WorkoutLogStore.swift:220` and `:291`: `.map { SetSnapshot($0) }`. `:288`: `!sets.contains { awaitsRating($0) }`. No `nonisolated`, no `@preconcurrency`.

Tests (write them first; the scan fails on today's `RestartPrefill.swift`):
- `Engine/ProgramGeneratorTests.swift` (append):
  - `ProgramGenerator.bodyWeightRangeLb == 50.0...500.0`
  - "no Engine file names a Features type": every `FeedbackSourceTests.appFiles()` entry whose path starts with `Engine/` has no code line containing `OnboardingDraft`.
- `Onboarding/OnboardingDraftTests.swift` (append, `@MainActor`): `OnboardingDraft.bodyWeightRangeLb == 50.0...500.0`, a typed literal rather than the Engine constant.
- Existing behavioral pins stay unchanged (spec §5.7).

Verify:
```
BUILD && WONLY ProgramGeneratorTests OnboardingDraftTests RestartPrefillTests RestartPrefillEdgeTests RestartFlowTests RestTextTests \
  RestActivitySeedFlowTests WorkoutSetWriterTests WorkoutSetWriterEdgeTests WorkoutCommitRollbackTests RestWriterRollbackTests; TEST; CNT
RELEASEW                      # BUILD SUCCEEDED, 0  (AC-15 first half; U11 probe)
```
The persistence suites run on 17.5 (gotchas "SwiftData"); no relationship, delete or `#Predicate` changes. If `RELEASEW` is not 0: read the
remaining diagnostic and report it. Do not reach for `@preconcurrency` or `nonisolated(unsafe)` (the §5.7 rule). **AC-15** (warnings half).

### Step 2 — `make-app-icon.py` over `design/icon/`, the two catalogs (AC-4, AC-5, AC-6, AC-9)
Probed while planning (scratchpad): all three sources render with `/opt/homebrew/bin/rsvg-convert` (light RGB; dark and tinted RGBA); two light renders are byte-identical; `-dark.svg` holds exactly one `<rect width="1024" height="1024" fill="#0F0E10"></rect>`
(the sources use `<rect …></rect>` pairs). The light render is **not** byte-equal to `design/icon/HomeGymLog-icon-1024.png`, which is not an input.

Order: (a) the actool smoke check, (b) the tests, red, (c) the script.
- **(a) actool smoke check first** (cheap; the sources are now plain SVGs like the one researcher Q2 compiled, so this is a confirmation, not a probe).
  - Create `HomeGymLog/Assets.xcassets/WelcomeTile.imageset/Contents.json` with researcher Q2's JSON verbatim (one `universal` image `WelcomeTile.svg`,
    `info` xcode/1, `preserves-vector-representation: true`).
  - `cp design/icon/HomeGymLog-icon.svg HomeGymLog/Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg`. The script recreates this file in (c).
  - `BUILD && RELEASEW`. Expect `BUILD SUCCEEDED` and `0`.
  - Then run: `xcrun --sdk iphonesimulator assetutil --info $REL/Assets.car | grep -B2 -A8 '"WelcomeTile"'`. Expect the
    `WelcomeTile` entry with `AssetType` `Vector` and a rasterised fallback (the Q2 shape).
  - **If the build fails, a warning names the imageset, or there is no Vector entry: stop and report** (the sources are
    rect-only SVGs matching researcher Q2's verified shape, so a failure here is new information, not the retired U14).
- **(b) Tests first, red.** New `HomeGymLogTests/Static/ReleaseAssetTests.swift` (`@Suite struct ReleaseAssetTests`, `import Foundation, ImageIO, Testing`):
  - Roots: `FeedbackSourceTests.appSourceRoot` (internal `static var`, `Static/FeedbackSourceTests.swift:8`), and `repoRoot = appSourceRoot.deletingLastPathComponent()`.
  - Decoders `IconSet` / `IconImage` (the Q9 shape plus `size`). The `pixelInfo(_ url:)` helper uses `CGImageSourceCopyPropertiesAtIndex`.
  - **AC-4:** exactly three images, all `universal`/`ios`/`1024x1024`, zero `mac` entries; `filename` → `appearances`: `AppIcon-Light.png` → nil,
    `AppIcon-Dark.png` → `[["appearance": "luminosity", "value": "dark"]]`, `AppIcon-Tinted.png` → `…"tinted"`.
  - **AC-5:** each PNG is 1024 × 1024. The light image's `kCGImagePropertyHasAlpha as? Bool != true` (never `== false`, Q9). No alpha check on dark or tinted.
  - **AC-6:**
    - `WelcomeTile.svg` `Data` == `repoRoot/design/icon/HomeGymLog-icon.svg` `Data`.
    - The imageset's `Contents.json` has one image: `filename == "WelcomeTile.svg"`, `idiom == "universal"`, and `properties["preserves-vector-representation"] as? Bool == true`.
    - Build the hex from `AccentColor.colorset/Contents.json` as `"#" + red + green + blue`, with `0x` stripped. The tile SVG must contain it.
    - The tile SVG has no `<text` and no `<metadata` element. Each of the three `design/icon/*.svg` contains the four strings `x="160" y="464"`, `x="220" y="232"`, `x="628" y="232"`, `width="704" height="96"`.
      (copied from the files, 1 hit each, matching spec §5.1).
  - **NB-2 half:** the `.svg` files under `HomeGymLog/` (enumerator `.skipsHiddenFiles`) are exactly `["Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg"]`.
- New `HomeGymLogTests/App/ReleaseBundleTests.swift` (`@MainActor @Suite struct ReleaseBundleTests`, `import Foundation, Testing, UIKit`; plain `#expect`,
    no `withKnownIssue`, `.disabled` or guard, B-3). **AC-9:** `UIImage(named: "WelcomeTile")?.size == CGSize(width: 1024, height: 1024)`.
  - `WONLY ReleaseAssetTests`: AC-4 and AC-5 fail (no PNGs, mac entries present), which shows the predicates can fail. AC-9 passes after (a).
- **(c) Implementation.**
  - `HomeGymLog/Assets.xcassets/AppIcon.appiconset/Contents.json`, hand-written once (S1): keep the three `universal`/`ios`/`1024x1024` entries, add the
    `filename`s `AppIcon-Light.png` / `AppIcon-Dark.png` / `AppIcon-Tinted.png` in that order, and delete the ten `"idiom" : "mac"` objects
    (`grep -c '"mac"'` is 10 today).
  - New `docs/tools/make-app-icon.py`, in the `make-rest-chime.py` shape:
    - The docstring says provenance only, not a build step, and that the outputs are never hand-edited. Paths come from `__file__` (`ROOT/design/icon`).
    - `RSVG = "/opt/homebrew/bin/rsvg-convert"`; exit with a message if it is missing. `tmp = tempfile.mkdtemp()`, removed in `finally`.
    - `without_dark_field(svg) -> str`: `re.findall(r'<rect[^>]*fill="#0F0E10"[^>]*>\s*</rect>|<rect[^>]*fill="#0F0E10"[^>]*/>', svg)` must
      find exactly 1. Otherwise `sys.exit("expected exactly one #0F0E10 field rect in HomeGymLog-icon-dark.svg, found N")`. The match is removed,
      and the result is written to `tmp/dark.svg`.
    - Renders, all `-w 1024 -h 1024`: light `HomeGymLog-icon.svg` with `-b '#E11D48'` → `AppIcon-Light.png`; dark `tmp/dark.svg`, no `-b` →
      `AppIcon-Dark.png`; tinted `HomeGymLog-icon-tinted.svg` as drawn, no `-b` → `AppIcon-Tinted.png`.
    - `shutil.copyfile(HomeGymLog-icon.svg, …/WelcomeTile.imageset/WelcomeTile.svg)`. It writes nothing else (NB-5).
  - Run `python3 docs/tools/make-app-icon.py`.
  - Negative probe of the guard: run the function on a string holding two field rects; it exits non-zero with the message. Done in a scratchpad
    `python3 -c`, not under `HomeGymLog/`.

Verify:
```
file HomeGymLog/Assets.xcassets/AppIcon.appiconset/*.png       # Light "8-bit/color RGB"; Dark, Tinted RGBA
sips -g pixelWidth -g pixelHeight -g hasAlpha HomeGymLog/Assets.xcassets/AppIcon.appiconset/*.png   # 1024 each; hasAlpha no / yes / yes
git status --short HomeGymLog/ design/   # M AppIcon Contents.json, ?? the three PNGs, ?? WelcomeTile.imageset/; design/ clean
BUILD && WONLY ReleaseAssetTests ReleaseBundleTests ColorsetContrastTests WidgetSourceTests; TEST; CNT; RELEASEW   # 0
```
Read the three PNGs: a white dumbbell-"H" on accent; an accent mark on transparent; a white mark on transparent. The light `hasAlpha: no` next to the
dark `yes` shows that AC-5's predicate tells the two apart. **AC-4, AC-5, AC-6, AC-9**, and AC-21 (closed by this step).

### Step 3 — privacy manifest, the merged plist's pins, project pins (AC-7, AC-8, AC-10 Info half, AC-14)
- `HomeGymLog/PrivacyInfo.xcprivacy` (new): the researcher's Q1 XML byte for byte, extracted by content rather than line number:
  `awk '/^<\?xml/{f=1} f{print} f&&/^<\/plist>/{exit}' docs/reviews/m5-release-researcher.md > HomeGymLog/PrivacyInfo.xcprivacy`
  (probed: 23 lines, `plutil -lint` OK).
- `HomeGymLogSupport/Info.plist` already exists (the main session wrote it before the gate). Only `plutil -lint` it; do not rewrite it.

Tests, written before the manifest; the manifest and bundle checks fail first:
- `ReleaseAssetTests`, appended. **AC-7:** the manifest parses to exactly four keys (`NSPrivacyTracking as? Bool == false`; tracking domains and collected
  data types empty; one accessed-API dict, `NSPrivacyAccessedAPICategoryUserDefaults` / `["CA92.1"]`); none under `HomeGymLogWidgets/` or `HomeGymLogShared/`;
  `HomeGymLogSupport/Info.plist` has exactly one key `UILaunchScreen` (`[String: Any]`, U10) whose only entry is `UIColorName == "bg"`; no `Info.plist`
  under `HomeGymLog/`; NB-2: the non-`.swift` files under `HomeGymLog/` outside `Assets.xcassets/` (`.skipsHiddenFiles`) are exactly `{"rest-over.caf", "PrivacyInfo.xcprivacy"}`.
- `ReleaseBundleTests`, appended:
  - **AC-8:** `Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")` is non-nil. Its `deletingLastPathComponent().resolvingSymlinksInPath().path`
    equals `Bundle.main.bundleURL.resolvingSymlinksInPath().path`, and its `Data` equals `appSourceRoot/PrivacyInfo.xcprivacy`'s.
  - **AC-10, Info half** (`info = Bundle.main.infoDictionary`): `["UISupportedInterfaceOrientations"] as? [String] == ["UIInterfaceOrientationPortrait"]`;
    `["ITSAppUsesNonExemptEncryption"] as? Bool == false`; `(info["UILaunchScreen"] as? [String: Any])?["UIColorName"] as? String == "bg"`;
    `CFBundleShortVersionString == "1.0"`, `CFBundleVersion == "1"`, `NSSupportsLiveActivities as? Bool == true`.
- New `HomeGymLogTests/Static/ReleaseProjectTests.swift`, using `LiveActivityProjectTests.lines()` (internal `static func`, `Static/LiveActivityProjectTests.swift:16`).
  **AC-14**, semantic (B-2):
  2 `…UISupportedInterfaceOrientations_iPhone` lines, each with `UIInterfaceOrientationPortrait`, none with `Landscape`/`UpsideDown`; 2 `…ITSAppUsesNonExemptEncryption`
  lines whose value (after `=`, trimmed of spaces, `;`, `"`) is `NO`; 4 `INFOPLIST_FILE` lines that are not `GENERATE_INFOPLIST_FILE`, 2 with `HomeGymLogSupport/Info.plist`
  and 2 with `HomeGymLogWidgets/Info.plist`; `MARKETING_VERSION = 1.0;` ×6, `CURRENT_PROJECT_VERSION = 1;` ×6, `INFOPLIST_KEY_NSSupportsLiveActivities = YES` ×2.
  Step 0's `git show HEAD:` lines show these predicates were false before the GUI steps.

If a U10 cast fails: read the value once with `#expect(String(describing: info["UILaunchScreen"]) == "")`, report it, delete that line, and fix only the cast.

Verify:
```
plutil -lint HomeGymLog/PrivacyInfo.xcprivacy HomeGymLogSupport/Info.plist
BUILD && WONLY ReleaseAssetTests ReleaseBundleTests ReleaseProjectTests LiveActivityProjectTests RestChimeAssetTests; TEST; CNT; RELEASEW   # 0
ls -a $REL | grep -E "PrivacyInfo.xcprivacy|rest-over.caf|DS_Store"; cmp $REL/PrivacyInfo.xcprivacy HomeGymLog/PrivacyInfo.xcprivacy
```
Expect both resources, no `.DS_Store`, and `cmp` silent. **AC-7, AC-8, AC-10** (Info half), **AC-14**, AC-15 (manifest listed).

### Step 4 — A1 tile and A4 subtitle (AC-1, AC-2, AC-11)
- `Features/Onboarding/WelcomeStep.swift:9–13`: replace the `Text("H")` block with
  `Image(decorative: "WelcomeTile").resizable().scaledToFit().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12))`.
  `Image(decorative:)` keeps it out of VoiceOver (≈ `alt=""` with `aria-hidden`). `Color.white` leaves the file.
- `Features/Onboarding/AboutYouStep.swift:9`: subtitle `"Session length sets how many exercises you do."`

Tests: new `HomeGymLogTests/Static/ReleaseCopyTests.swift` (AC-11, NB-4; uses `FeedbackSourceTests.codeLines` / `appFiles`). Write it first and run it once:
`WONLY ReleaseCopyTests` must fail on today's sources. Then make the edits. It checks: `AboutYouStep.swift` has the new literal on exactly one line;
no app file contains `"Used to size"`; `WelcomeStep.swift` has no `Text("H")` and exactly one `"WelcomeTile"` line, which contains `Image(decorative:` (F6);
no other app file has `Image("` or `Image(decorative: "` (`Image(systemName:` does not match).

Verify:
```
BUILD && WONLY ReleaseCopyTests ColorsetContrastTests OnboardingDraftTests; TEST; CNT; RELEASEW      # 0
BOOT $UDID; APPEAR $UDID dark; RSHOTS s4; RCMP s4
```
Expected: `RCMP s4` `same` for the 12 AC-3 names and `settings`; `ob0` `DIFF rows` spanning ≤ 132 (44 pt × 3, the tile only); `ob3` `DIFF rows`
confined to the subtitle band.
- `/design-compare ob0` (`SEEDCLR` then `-seed onboarding`, against `build/rel/proto-ob0.png`): matches. Allowed deviations: m2-onboarding AC-1's
  two (body copy "HomeGymLog", "up to 52.5 lb") and the tile is the icon artwork, a white dumbbell-"H" on `#E11D48` at radius 12 (same slot and size).
- `/design-compare ob3` (`-seed ob3`, against `build/rel/proto-ob3.png`): matches m2-onboarding AC-4 (180 / lb, Intermediate, 45m, "5 exercises per
  session"). The one allowed deviation is the new subtitle.
- Read `build/shot-rel-s4-ob0.png` at full size: a white dumbbell-"H" on accent with rounded corners. **AC-1, AC-2, AC-3** (first pass), **AC-11**.

### Step 5 — Settings ABOUT card (§2.7, §5.9; AC-3 `settings`, AC-10 version line, AC-11 ABOUT half)
Order: (a) scans red, (b) `SettingsText`, (c) views.
- **(a) Tests first, red.**
  - `Static/ReleaseCopyTests.swift`, appended. Each of the two URL literals sits on exactly one line of the app target, in `Shared/SettingsText.swift`, and
    appears nowhere under `HomeGymLogShared/` or `HomeGymLogWidgets/`. Scan **raw** lines and skip lines whose trimmed text starts with `//`.
    `FeedbackSourceTests.codeLines` cuts every line at its first `//`, so `"https://…"` would vanish and the count could never be 1.
  - Also: `Link(` as a whole token (regex `(?<![A-Za-z])Link\(`, so `ShareLink(` at `BackupRows.swift:16` is not a hit) only in `Features/Settings/AboutRows.swift`, which has no `UIApplication` / `openURL`; `SettingsContent.swift` keeps a
    `static let bottomPadding = FloatingTabBar.height + 16` line and a `.padding(.bottom, Self.bottomPadding)` line (tokens, any access modifier).
  - `Static/SettingsScreenSourceTests.swift` (spec §8's three breaks): `filesScanned` 10 files, `"AboutRows.swift"` first; `sectionHeaders` filter
    `["programSection", "equipmentSection", "aboutSection"]` and token `"SettingsText.aboutSection"` (4 headers, sorted); `dividerCount` 10 → 12.
  - `WONLY ReleaseCopyTests SettingsScreenSourceTests` fails on today's sources.
- **(b) `Shared/SettingsText.swift`:**
  - `aboutSection = "ABOUT"`, `privacyPolicy = "Privacy policy"`, `support = "Support"`, `version = "Version"`
  - `privacyPolicyURL = URL(string: "https://zhabskyio.github.io/homegymlog-site/privacy/")!`, `supportURL = URL(string: "https://zhabskyio.github.io/homegymlog-site/support/")!`.
    The literals are copied from spec §5.9, and the `!` follows the `RestActivityCenter.settingsURL` precedent.
  - `static func versionText(short: String?, build: String?) -> String`: `guard let short, !short.isEmpty, let build, !build.isEmpty else { return "—" }`;
    `return "\(short) (\(build))"`.

  Value tests in `ReleaseCopyTests` (AC-11): the four strings and both `absoluteString`s against typed literals; `versionText(short: "1.0", build: "1")
  == "1.0 (1)"`; `(nil, nil)`, `("1.0", nil)`, `("", "1")` each `== "—"`.
- **(c) Views.**
  - New `Features/Settings/AboutRows.swift` holds `struct AboutLinkRow: View { let title: String; let url: URL }`. Its body is a `Link(destination: url) { Text(title) … }`,
    in the `ReminderActionRow` text shape: 15 pt semibold, `Theme.accent`, full-width leading, 16/13 padding, `.contentShape(Rectangle())`, `.buttonStyle(.plain)`.
    `Link` ≈ an `<a href>` that hands the URL to Safari. No literal string, no `UIApplication`, no `openURL`.
  - `Features/Settings/SettingsContent.swift`: after `backupCard` add `SettingsSectionHeader(title: SettingsText.aboutSection)` and `aboutCard`.
    `private var aboutCard: some View` = `SettingsCard { AboutLinkRow(title: SettingsText.privacyPolicy, url: SettingsText.privacyPolicyURL); SettingsDivider();
    AboutLinkRow(… support …); SettingsDivider(); SettingsValueRow(label: SettingsText.version, value: SettingsText.versionText(short: info?["CFBundleShortVersionString"]
    as? String, build: info?["CFBundleVersion"] as? String)) }`, with `private var info: [String: Any]? { Bundle.main.infoDictionary }`. Padding unchanged.
  - `ReleaseBundleTests`, appended (**AC-10, version line**): `SettingsText.versionText(short: info["CFBundleShortVersionString"] as? String, build: info["CFBundleVersion"] as? String) == "1.0 (1)"`.

Verify:
```
BUILD && WONLY ReleaseCopyTests SettingsScreenSourceTests SettingsSourceTests SettingsTextTests ReleaseBundleTests; TEST; CNT; RELEASEW   # 0
BOOT $UDID; APPEAR $UDID dark; RSHOTS s5; RCMP s5        # all 15 same (the card is below the fold on 6.1")
```
Then run `/design-compare settings` with `SEEDCLR` and `-seed midProgram -tab settings`, against `build/rel/proto-settings.png`. It matches with the m5-haptics,
m5-export and m5-live-activity AC-1 deviations; the **deliberate new deviation** is the ABOUT card below BACKUP. The non-scrolled shot is pixel-identical
to the baseline, because the card is below the fold. The max-scroll view is Step 11 (optional) and AC-20. **AC-3** (`settings`), **AC-10** (version line), **AC-11** (ABOUT half).

### Step 6 — App Store text and the two pages (AC-12, AC-13)
New `docs/release/`:
- `app-store-metadata.md`: the §2.4 table rows (category, App Privacy, age rating, export compliance, the two live URLs, Marketing/What's New,
  version/build, copyright) and five fenced blocks `name`, `subtitle`, `promotional-text`, `keywords`, `description`, text copied from §2.4 (description
  headings on their own line, blank line between paragraphs; recounted: 1518 scalars, subtitle 30, promotional text 165, keywords 98 bytes).
- `privacy-policy.md` and `support.md`, fetched (byte copies of what the site serves):
  `gh api repos/ZhabskyiO/homegymlog-site/contents/privacy.md --jq .content | base64 -d > docs/release/privacy-policy.md`, and the same for `support.md`.
  Read both and check them against §2.5's points. Record the fetched commit (`gh api repos/ZhabskyiO/homegymlog-site/commits --jq '.[0].sha'`) in `release-checklist.md`.
- `release-checklist.md`: §2.6 steps 1–7 verbatim (step 2 struck through as done), with §5.8's command in a code block.

Tests: new `HomeGymLogTests/Static/StoreMetadataTests.swift` (`docs/release` under `repoRoot`):
- Helpers: `static func blocks(in markdown: String) -> [String: [String]]` (a line `` ```<id> `` opens a block, a line `` ``` `` closes it, and the
  content is joined with `\n`), and `static func violations(_ f: [String: String]) -> [String]` (the AC-12 rules).
- **AC-12**: exactly one block per id; `violations` empty; `name == "HomeGymLog"`. Rules: Unicode-scalar counts name 2…30, subtitle ≤ 30, promotional
  ≤ 170, description ≤ 4000; keywords `utf8.count` ≤ 100, every trimmed term ≥ 3 chars, none empty; none of `iPhone`, `Live Activit`, `Dynamic Island`,
  `TestFlight`, `App Store`, `Marcy`, `HomeGymLog` (case-insensitive) in subtitle or keywords.
- **Checker control**: an inline markdown with valid `name`, `promotional-text` and `description` blocks, a 31-character subtitle and keywords
  `home gym,PR,iPhone` yields exactly three violations, asserted by id (subtitle length, keyword term `PR` < 3 chars, banned word `iPhone` in
  keywords), so a missing-block rule cannot inflate the count. This proves the rules can fail.
- **AC-13**: both pages ≥ 400 bytes and contain `poltavagaz@gmail.com`; `privacy-policy.md` contains `2026-10-03`; `app-store-metadata.md` contains
  both §2.4 URLs (typed literals); `release-checklist.md` contains `xcodebuild archive` and `Validate App`.

Verify: `BUILD && WONLY StoreMetadataTests; TEST; CNT`. **AC-12, AC-13.**

### Step 7 — `make-store-screenshots.sh` and the five PNGs (AC-16)
`docs/tools/make-store-screenshots.sh` (new, `bash`, `set -euo pipefail`, header comment: provenance, Debug build, §5.6):
- Variables: `UDID=5236ED20-CDE1-441F-9F48-54E856A3FB90`, `BID`. `ROOT` comes from `$0`. `APP=${1:-$ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app}`.
  `OUT=$ROOT/docs/release/screenshots`; `mkdir -p "$OUT"`.
- `TMP=$(mktemp -d)`, then `trap 'rm -rf "$TMP"; xcrun simctl status_bar "$UDID" clear' EXIT` (the status-bar clear runs last).
- Set up the device: `simctl boot … 2>/dev/null || true` (tolerate "already booted"), `bootstatus -b`, `simctl ui "$UDID" appearance dark`, then
  `status_bar … override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`.
- One throwaway `simctl io … screenshot "$TMP/throwaway.png"` (gotcha 2026-09-25).
- Rows, copied from §5.6: `01-home|-seed midProgram`, `02-workout|-seed wo-swipe`, `03-rest|-seed wo-rest`, `04-progress|-seed progress-history -tab progress`,
  `05-program|-seed midProgram -tab program`.
- For each row: (1) `terminate … 2>/dev/null || true` (**terminate tolerated**: `simctl terminate` exits 3 with "found nothing to terminate" when the app is not running, and under `set -euo pipefail` an untolerated call aborts the first row; `boot` likewise `|| true`), `install "$APP"`, `spawn … defaults delete seed` (tolerated), `launch` with the arguments, `sleep 3`;
  (2) screenshot to `"$TMP/shot.png"`; (3) write `"$TMP/wrap.svg"` (both namespaces, F4; `width="1320" height="2868"`, one `<image width="1320" height="2868" xlink:href="shot.png"/>`).
  (4) `/opt/homebrew/bin/rsvg-convert -w 1320 -h 2868 -b '#000000' -o "$OUT/NN-name.png" "$TMP/wrap.svg"`.
- It writes nothing else.

Verify:
```
BUILD && bash docs/tools/make-store-screenshots.sh
ls docs/release/screenshots          # exactly 01-home.png 02-workout.png 03-rest.png 04-progress.png 05-program.png
for f in docs/release/screenshots/*.png; do sips -g pixelWidth -g pixelHeight -g hasAlpha "$f"; file "$f"; done   # 1320 2868 no; 8-bit/color RGB
xcrun simctl status_bar $PROMAX list                     # no override
bash docs/tools/make-store-screenshots.sh /nonexistent.app; echo $?; xcrun simctl status_bar $PROMAX list; ls docs/release/screenshots | wc -l
```
The last line is the failure path: it exits non-zero, the status bar is cleared, and there are still 5 files.
Read all five images against §5.6 "Shows" (01 "Good afternoon" + Pull card; 02 the row mid-swipe; 03 "1:02", "Next: set 2 of 3"; 04 chart and
calendar; 05 the current week). All must be Dark with 9:41 and not black. Then `BUILD && TEST; CNT` (unchanged). **AC-16.**

### Step 8 — Release read-back, both runtimes, icon determinism, final regression (AC-3, AC-15, AC-18)
```
RELEASEW                                                    # BUILD SUCCEEDED, 0
ls $REL | grep PrivacyInfo.xcprivacy
plutil -p $REL/Info.plist | grep -E "UILaunchScreen|UIColorName|ITSAppUses|UISupportedInterfaceOrientations" -A1
  # UILaunchScreen => { UIColorName => "bg" }, ITSAppUsesNonExemptEncryption => 0, [ "UIInterfaceOrientationPortrait" ]
plutil -p $REL/PlugIns/HomeGymLogWidgetsExtension.appex/Info.plist | grep NSExtensionPointIdentifier   # still widgetkit
BUILD && TEST; CNT                                          # 17.5, record totalTestCount
TEST26S; CNT26                                              # 26.5 (iPhone 17), same count, ReleaseBundleTests included (U12)
ICON=(HomeGymLog/Assets.xcassets/AppIcon.appiconset/*.png HomeGymLog/Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg)
shasum $ICON > build/rel/icon-sha.1; python3 docs/tools/make-app-icon.py; shasum $ICON > build/rel/icon-sha.2
diff build/rel/icon-sha.1 build/rel/icon-sha.2 && echo identical; git status --short HomeGymLog/   # F2: identical; same list as Step 2
BOOT $UDID; APPEAR $UDID dark; RSHOTS s9; RCMP s9           # 12 AC-3 names + settings same; ob0/ob3 as Step 4
```
**AC-3** (final), **AC-15**, **AC-18.**

### Step 9 — definition of done: the signed archive (AC-17; no `-exportArchive`, no upload)
Spec §5.8, with a stale archive removed first:
```
rm -rf build/HomeGymLog.xcarchive
xcodebuild archive -scheme HomeGymLog -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -archivePath build/HomeGymLog.xcarchive 2>&1 | tail -3
A=build/HomeGymLog.xcarchive; APPX=$A/Products/Applications/HomeGymLog.app
ls $A/dSYMs; ls $APPX/PlugIns            # HomeGymLog.app.dSYM HomeGymLogWidgetsExtension.appex.dSYM; HomeGymLogWidgetsExtension.appex
codesign -dvvv $APPX 2>&1 | grep -E "Identifier=|TeamIdentifier="       # com.zhabskyi.homegymlog.ios, 4GKZ96A6QR
codesign -dvvv $APPX/PlugIns/HomeGymLogWidgetsExtension.appex 2>&1 | grep Identifier=   # com.zhabskyi.homegymlog.ios.widgets
ls $APPX/PrivacyInfo.xcprivacy; plutil -p $APPX/Info.plist | grep -E "UILaunchScreen|UIColorName|ITSAppUses|UISupportedInterfaceOrientations" -A1
```
The implementer's last step (F7): re-run it after review if any Swift changed. Green means `** ARCHIVE SUCCEEDED **` and every line as commented. On a signing failure: re-run once with `-allowProvisioningUpdates` (§5.8 optional), then report.
The local variable is `APPX` because `APP` is the Debug path in the env. **AC-17.**

### Step 10 — docs (doc-writer, after test-writer and swift review)
- `docs/layout.md` rows: `HomeGymLogSupport/` (path-referenced by `INFOPLIST_FILE`, never synchronized), `HomeGymLog/PrivacyInfo.xcprivacy`, the catalogs'
  new files (PNGs/SVG script outputs, `Contents.json` hand-written), `design/icon/` (edit there, rerun), `docs/release/` (pages = copies of
  `ZhabskyiO/homegymlog-site`, `screenshots/`), `Features/Settings/AboutRows.swift`, the two tools, the five new test files.
- `CLAUDE.md`: layout-block rows for `HomeGymLogSupport/` and `docs/release/`, with `docs/tools/` named. The M5 milestone line for `m5-release`.
- `insights/INSIGHTS.md`: an "Implemented" bullet under the 2026-10-03 release decisions (counts, the gate, the ABOUT card).
- `insights/gotchas.md`: anything that bit. Step 0 already recorded U9; add the `codeLines`-vs-`https://` trap if it cost time.

### Step 11 (optional) — scratch-copy XCUITest: Settings max scroll, the links, portrait lock
INSIGHTS "Real-touch probes". Copy the repo (working changes included) to the scratchpad. **In the copy only**, add a UI-test target and set the
bundle ids to `….probe` / `.probe.widgets`. The repo's `project.pbxproj` is never touched. Skip path: delete the copy. Require `BUILD SUCCEEDED`
before `test-without-building`.
- (a) `-seed midProgram -tab settings`: "Restore from backup…" exists (positive); swipe up 10× (no sheet or dialog opens on a swipe); "Version" exists with
  `frame.maxY ≤ window height − 64` (`FloatingTabBar.height`, `Shared/FloatingTabBar.swift:7`) **and the max-scroll screenshot shows it above the pill** (`isHittable` is no proof).
- (b) Same launch, at max scroll: tap "Privacy policy". `app.wait(for: .runningBackground, timeout: 5)` is true (Safari came forward); relaunch.
- (c) `-seed wo-rest` and `-seed summary`, one launch each: width < height and "Skip rest" (resp. the summary title) exists; `XCUIDevice.shared.orientation
  = .landscapeLeft`, wait 1 s; still width < height with the element hittable. Report pass or fail for each.

### Traceability (AC → step)
| AC | Step | AC | Step | AC | Step |
|---|---|---|---|---|---|
| 1 | 4 | 9 | 2 | 17 | 9 |
| 2 | 4 | 10 | 3 (Info), 5 (version) | 18 | 8 (26.5, determinism) |
| 3 | 4, 5 (`settings`), 8 | 11 | 4, 5 (ABOUT) | 19 | 0 (gate; done before implementation) |
| 4 | 2 | 12 | 6 | 20 | user (Step 11 optional) |
| 5 | 2 | 13 | 6 | 21 | 2 (closed: artwork ships) |
| 6 | 2 | 14 | 3 | 22 | user |
| 7 | 3 | 15 | 1 (0 warnings), 3, 8 (plist lines) | | |
| 8 | 3 | 16 | 7 | | |

Tooling: `make-app-icon.py` runs in Step 2 (AC-4–6) and Step 8 (AC-18). `make-store-screenshots.sh` runs in Step 7 (AC-16).

### Existing tests this slice changes (spec §8)
- **Updated in Step 5, part of the slice:** `SettingsScreenSourceTests.filesScanned` (9 → 10, `AboutRows.swift`), `.sectionHeaders` (`aboutSection` last of
  four), `.dividerCount` (10 → 12).
- **Checked, not broken:** `.noLiteralCopy` (no `Text("` in `AboutRows`), `.preferencesRowOrder`, `.feedbackToggleRows`, `.rowAccessibilityShape`
  (`SettingsValueRow` reused); `SettingsSourceTests.uiApplicationStaysInApp` (`Link`); every `DebugSeed.allCases` iteration; `ColorsetContrastTests`
  (`Color.white` not a token, `:247–257`); `FeedbackSourceTests.appFiles` / `ClockUsageTests`; `LiveActivityProjectTests` (no `INFOPLIST_FILE`/orientation
  pin, `:24–40`); `WidgetSourceTests`, `LiveActivitySourceTests`; `RestTextTests`, the restart/onboarding suites, the `WorkoutLogStore` persistence suites.

## 4. Data model changes
None: no `@Model`, field, relationship, delete rule, `#Predicate`, preference key, backup key or migration. The ABOUT card reads only `Bundle.main.infoDictionary`.

## 5. Risks and gotchas
| Risk | Mitigation |
|---|---|
| The GUI settings are missing or wrong when implementation starts | Step 0 gate; stop and report, never patch `project.pbxproj` (the hook forbids it) |
| U9 pbxproj line shape | **Observed at the gate; the lines are recorded in gotchas at Step 0**; pins are token-and-value (B-2) |
| A CLI `INFOPLIST_FILE=` breaks the appex; dragging `HomeGymLogSupport/` into the navigator → "Multiple commands produce" (gotchas 2026-10-03) | No `INFOPLIST_*` on any command line; Step 8 checks the appex's `NSExtensionPointIdentifier` |
| F1: `GENERATE_INFOPLIST_FILE` carries the token | Excluded in the gate grep and in `ReleaseProjectTests` |
| `codeLines` truncates `https://…` at `//` | The URL scans read raw lines (Step 5) |
| The ABOUT card pushes BACKUP's last row under the pill | Padding stays under the last card (pinned in `ReleaseCopyTests`); Step 11 (a) checks frames and a screenshot; AC-20 |
| U11 (a closure form warns), U10/U12 (hosted casts, 26.5) | `RELEASEW` in Step 1; cast-only fallback; `TEST26S` runs `ReleaseBundleTests` |
| 26.5 run hangs after `simctl` shots | `TEST26S` boots first, `-parallel-testing-enabled NO` |
| Light PNG alpha passes actool silently (ITMS-90717) | AC-5; `file` / `sips` in Step 2 |
| `.DS_Store` under `HomeGymLog/` | `.skipsHiddenFiles`; Step 3 `ls -a $REL` is the probe |
| Store shots: RGBA, 26.5 island, status bar left overridden, a black flatten | rsvg flatten, throwaway shot, `trap` plus failure probe, every image read |
| The site pages change after the fetch | The fetched commit is recorded in the checklist; AC-13 pins the email and date, not the whole text |
| A changed artwork without exactly one `#0F0E10` field rect | The script exits (Step 2 negative probe) |
| Archive signing for the second bundle id (Q5) | One retry with `-allowProvisioningUpdates`; report |

## 6. Definition of done
- [ ] Step 0 gate greps as listed; U9 lines in gotchas.
- [ ] `RELEASEW` prints 0 from Step 1 on.
- [ ] `ob0`, `ob3` and `settings` match by `/design-compare` with the listed deviations; the AC-3 names and `settings` are `same` against `build/shot-rel-base-*`.
- [ ] Full suite green on 17.5 and 26.5 with equal `totalTestCount`; the five new suites are present and the three `SettingsScreenSourceTests` updates are in.
- [ ] Release `.app`: the manifest, `UILaunchScreen => { UIColorName => "bg" }`, encryption `0`, portrait only; the appex keeps widgetkit.
- [ ] `docs/release/`: four `.md` files (the pages equal the fetched site sources) and five 1320 × 2868 RGB screenshots; the status bar is cleared; the icon rerun is byte-identical.
- [ ] `** ARCHIVE SUCCEEDED **` with both dSYMs, the appex, both identifiers, `4GKZ96A6QR`, the manifest and the three plist values.
- [ ] Docs (Step 10); swift review in `docs/reviews/m5-release-swift-review.md`.

## Files to commit (the user commits; the implementer never does)
- `git add design/icon` (already committed in `6a54b20`/`43b262e`; a no-op unless the artwork changes); `git add HomeGymLogSupport/Info.plist HomeGymLog.xcodeproj/project.pbxproj`. The plist was written by the main session, and the pbxproj was modified by
  the user's GUI steps before implementation.
- `git add HomeGymLog/PrivacyInfo.xcprivacy HomeGymLog/Assets.xcassets/AppIcon.appiconset HomeGymLog/Assets.xcassets/WelcomeTile.imageset`
- `git add HomeGymLog/Features/Settings/AboutRows.swift`, the Step 1, Step 4 and Step 5 Swift edits, the five new test files, and the three appended suites
  (`ProgramGeneratorTests`, `OnboardingDraftTests`, `SettingsScreenSourceTests`)
- `git add docs/tools/make-app-icon.py docs/tools/make-store-screenshots.sh docs/release`, plus the plan, spec, reviews, and the `insights/` edits. Never `build/`.

After the commit, one more `make-app-icon.py` rerun must leave `git status --short HomeGymLog/` empty (the post-commit form of AC-18).

## User-run ACs (never block the merge)
- **AC-19**: done before implementation (spec §4.3); Step 0 verifies it.
- **AC-20** (iPhone 14 Pro Max): the white dumbbell-"H" on the Home Screen; a `bg` cold launch; rotation changes nothing in the workout or summary; iOS
  Settings → HomeGymLog lists Live Activities and Notifications; VoiceOver on A1 starts at the headline and skips the tile; Settings at max scroll shows
  ABOUT above the pill, both links open the live pages, and VoiceOver after "Restore from backup…" reads "ABOUT" → "Privacy policy, link" → "Support, link" → "Version, 1.0 (1)".
- **AC-21**: closed by Step 2. **AC-22**: the site is done; what remains is the App Store Connect record (§2.6 steps 3–7).

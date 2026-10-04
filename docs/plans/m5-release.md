# M5 slice 5 — release: app icon from `design/icon/`, copy fix, privacy manifest, Info keys, 0 warnings, store metadata, screenshots, archive
**Status: planned 2026-10-03.** Branch `m5-release`, baseline `d8d8619` (1301 tests on iOS 17.5 and 26.5).

For `docs/specs/m5-release.md` (architecture review `docs/reviews/m5-release-architecture.md` applied: B-1–B-3, NB-1–NB-6, U9–U13).
Spec §2–§6 and §8 are the contract (`AC-1`…`AC-22`). `implementer`: one step per build, nothing committed. **Step 7 is the user's
Xcode GUI checkpoint**: the implementer stops there and hands it over in one message. Undo is always "restore by hand"; never
`git checkout`, `git stash` or `git clean` (most files in this slice have no commit yet).

## Spec alignment (spec revised 2026-10-03 for F1–F8; the plan follows the revision)
- **F1** `INFOPLIST_FILE` counts exclude `GENERATE_INFOPLIST_FILE` lines (×6 at `project.pbxproj:452,497,538,565,593,629`): 2 today, 4 after (§4.3, AC-14).
- **F2** AC-18's determinism check is `shasum` of the four outputs before and after a rerun (a `git status` is never empty before the commit).
- **F3** `design/icon/` is the real artwork, user-confirmed, and ships now. It is the only copy and is committed. There is no placeholder and no
  `docs/tools/app-icon.svg`; `make-app-icon.py` reads `design/icon/` directly. AC-21 is closed and §9 Q3 is moot. New **U14** (an SVG with a
  foreign-namespace `<metadata><c2pa:manifest>` block): Step 2 probes it before anything else.
- **F4** the wrapper SVG carries both namespaces, and every output image is read. **F5** the pages are prose with `<contact email>` / `<effective date>`.
  **F6** AC-11 pins `Image(decorative:` on the one `"WelcomeTile"` line; VoiceOver is in AC-20. **F7** the archive is the implementer's last step,
  the doc-writer runs after swift review, and the archive is re-run if review changes Swift. **F8** the checkpoint tell is the Landscape/UpsideDown count, 2 → 0.
- **Resolved (verifier round 1, note 4):** **S1**, the spec §4.2 now says both catalog `Contents.json` files are written by hand once and only the
  four named files (three PNGs and `WelcomeTile.svg`) are script outputs, which is what Step 2 does. **S2**, the INSIGHTS placeholder bullet is marked
  superseded by the artwork bullet; Step 11's item is a confirm, not an edit.

## 1. Goal and scope
Make the app submittable in dependency order:
- Zero the six Release warnings first (the body-weight constant moves into Engine, plus four closure forms), so every later step's Release build is a clean 0-warning probe.
- Then the icon renders from `design/icon/` (U14 probed first), the privacy manifest and the merged `Info.plist` file, the A1 tile and the A4 subtitle, the
  App Store text, and the 6.9" screenshots.
- Then the user's GUI checkpoint, the hosted and project pins it unblocks, both runtimes, the Release plist read-back, and the signed archive.

Every step ends green on iPhone 15 / iOS 17.5.

**Out of scope (spec §7):** upload, `-exportArchive`, the App Store Connect record, the Pages repo, an in-app privacy link (§9 Q1),
CloudKit, localization, widget manifest or display name, iPad, `.icon` files.

**Excluded ACs (user-run, never merge gates):** AC-20 and AC-22 (closing section); AC-21 is closed by Step 2. AC-19 is the Step 7 checkpoint itself.

No dependency, entitlement, capability, model or seed is added. `rsvg-convert` is a dev-machine tool, like `afconvert` for the chime (NB-5).

## 2. Decisions this plan relies on
- **INSIGHTS** 2026-10-03 "M5 release decisions": icon slots with fixed file names (artwork now `design/icon/`, F3); manifest at the synchronized root (CA92.1); three Info
  keys through the GUI; `HomeGymLogSupport/` holds path-referenced inputs; copy audit; 0 warnings; `docs/release/`; one 6.9" set; the archive as
  definition of done; §9 defaults. Architecture bullets: B-1 (bounds on `ProgramGenerator`), NB-1 (closure form, no `nonisolated` on `RestText`),
  B-3 (GUI-dependent tests after the checkpoint, plain `#expect`), B-2 (semantic pbxproj pins), NB-2 (bundle-resource surface).
- **Researcher** (binding): Q1 (manifest XML, bundle-root copy, hosted read), Q2 (rsvg RGB, imageset `Contents.json`, 1024 pt, mac entries
  inert, no actool warning with filled dark/tinted slots), Q3 (merged plist outside synchronized folders; CLI `INFOPLIST_FILE=` breaks
  the appex), Q4 (setting names, hosted shapes), Q5 (archive commands), Q6 (iPhone 17 Pro Max 1320 × 2868, status-bar override), Q9 (`HasAlpha != true`).
- **gotchas** Xcode/build 2026-10-03 (all five release entries; the Info tab follows the run destination), 2026-10-03 (26.5 test hang after
  `simctl` shots → boot first, `-parallel-testing-enabled NO`), 2026-09-25 (26.5 first shot island), 2026-09-24 (non-Swift files under
  `HomeGymLog/` ship; hosted `Bundle.main` is the app), 2026-09-23 (`WONLY` watchdog), 2026-09-22 (`sips -c h w --cropOffset y x`).
- **Open questions:** none (S1 and S2 resolved, see above).

## 3. Steps
Every command block starts with `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/release-env.sh`. Run one foreground
`xcodebuild` at a time (timeout 600000). "Green" means `BUILD SUCCEEDED`, `WONLY` prints a passing Swift Testing summary, `TEST` prints
`TEST SUCCEEDED`, and `CNT` shows `failedTests: 0` with `totalTestCount` = the previous count + the tests the step adds. "RELEASEW 0"
means `BUILD SUCCEEDED` then `0`.

### Step 0 — shorthands, baselines (no repo file changes)
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
  sips -c 640 340 --cropOffset 200 1620 build/rel/proto-all.png --out build/rel/proto-ob3.png >/dev/null; pkill -f "http.server 8765"; }
```
The crops are copied from `build/light-env.sh` `CROPS` (`ob0|3000x5600|640 720|200 45`, `ob3|3000x5600|640 340|200 1620`; `sips` takes h w, then y x).
On HEAD, before any Swift change:
- `BUILD && TEST; CNT`: expect 1301.
- `RELEASEW`: expect `BUILD SUCCEEDED` and `12` (spec §4.4). Run `grep "warning:" build/last-release.log | sort -u` and confirm the six sites of §5.7.
- `BOOT $UDID; APPEAR $UDID dark; RSHOTS base`: the baselines are `build/shot-rel-base-<name>.png`, 15 files.
- `PROTOOB`, then **read** `build/rel/proto-ob0.png` and `proto-ob3.png` (a blank band means a transposed crop).
- Record the pbxproj "today" values that the Step 8 predicates must flip:
  - `grep INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone $PBX | grep -cE "Landscape|UpsideDown"` → 2
  - `grep -c INFOPLIST_KEY_ITSAppUsesNonExemptEncryption $PBX` → 0
  - `grep -v GENERATE_INFOPLIST_FILE $PBX | grep -c INFOPLIST_FILE` → 2

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

### Step 2 — `make-app-icon.py` over `design/icon/`, the two catalogs (AC-4, AC-5, AC-6; U14 first)
Probed while planning, rsvg half of U14 (scratchpad): all three sources render with `/opt/homebrew/bin/rsvg-convert` despite the `<metadata>` block
(light RGB; dark and tinted RGBA); two light renders are byte-identical; `-dark.svg` holds exactly one `<rect width="1024" height="1024" fill="#0F0E10"></rect>`
(the sources use `<rect …></rect>` pairs). The light render is **not** byte-equal to `design/icon/HomeGymLog-icon-1024.png`, which is not an input.

Order: (a) the actool probe, (b) the tests, red, (c) the script.
- **(a) U14 actool probe first.**
  - Create `HomeGymLog/Assets.xcassets/WelcomeTile.imageset/Contents.json` with researcher Q2's JSON verbatim (one `universal` image `WelcomeTile.svg`,
    `info` xcode/1, `preserves-vector-representation: true`).
  - `cp design/icon/HomeGymLog-icon.svg HomeGymLog/Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg`. The script recreates this file in (c).
  - `BUILD && RELEASEW`. Expect `BUILD SUCCEEDED` and `0`.
  - Then run: `xcrun --sdk iphonesimulator assetutil --info $REL/Assets.car | grep -B2 -A8 '"WelcomeTile"'`. Expect the
    `WelcomeTile` entry with `AssetType` `Vector` and a rasterised fallback (the Q2 shape).
  - Also run a one-off hosted probe now (scratch test, deleted after it passes, since AC-9 proper lands in Step 8 after the checkpoint):
    `UIImage(named: "WelcomeTile")` non-nil with size 1024 × 1024 on 17.5, so U14's runtime half is known before the tile is wired in Step 4.
  - **If the build fails, a warning names the imageset, there is no Vector entry, or the hosted probe is nil, take the U14 fallback:** the script strips the
    `<metadata>…</metadata>` element (one `re.subn` with `re.S`, asserted to remove exactly 1) from every render input and from the `WelcomeTile.svg`
    copy. `ReleaseAssetTests` then compares `WelcomeTile.svg` to the source with the same strip applied (a test helper `strippedMetadata(_:)`).
    Rerun (a), and report the fallback as a spec deviation for §5.2 and AC-6. AC-9 (Step 8) and AC-18 (Step 9) are the later probes.
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
    - The tile SVG has no `<text` (a `<metadata` element is allowed). Each of the three `design/icon/*.svg` contains the four strings `x="160" y="464"`, `x="220" y="232"`, `x="628" y="232"`, `width="704" height="96"`.
      (copied from the files, 1 hit each, matching spec §5.1).
  - **NB-2 half:** the `.svg` files under `HomeGymLog/` (enumerator `.skipsHiddenFiles`) are exactly `["Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg"]`.
  - `WONLY ReleaseAssetTests`: AC-4 and AC-5 fail (no PNGs, mac entries present). This shows the predicates can fail.
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
git status --short HomeGymLog/ design/   # M AppIcon Contents.json, ?? the three PNGs, ?? WelcomeTile.imageset/, ?? design/icon/
BUILD && WONLY ReleaseAssetTests ColorsetContrastTests WidgetSourceTests; TEST; CNT; RELEASEW   # 0
```
Read the three PNGs: a white dumbbell-"H" on accent; an accent mark on transparent; a white mark on transparent. The light `hasAlpha: no` next to the
dark `yes` shows that AC-5's predicate tells the two apart. **AC-4, AC-5, AC-6**, and AC-21 (closed by this step).

### Step 3 — privacy manifest and the merged plist file (AC-7)
- `HomeGymLog/PrivacyInfo.xcprivacy` (new): the researcher's Q1 XML byte for byte, extracted by content rather than line number:
  `awk '/^<\?xml/{f=1} f{print} f&&/^<\/plist>/{exit}' docs/reviews/m5-release-researcher.md > HomeGymLog/PrivacyInfo.xcprivacy`
  (probed: 23 lines, `plutil -lint` OK).
- `HomeGymLogSupport/Info.plist` (new, repo root, outside every synchronized folder): the standard plist header and the §5.4 dict
  `UILaunchScreen` → `UIColorName` = `bg`. It is not referenced yet, so the build is unaffected until Step 7.

Tests (append to `ReleaseAssetTests`). **AC-7**:
- The manifest parses through `PropertyListSerialization` to exactly the four keys: `NSPrivacyTracking as? Bool == false`; `NSPrivacyTrackingDomains`
  and `NSPrivacyCollectedDataTypes` empty; `NSPrivacyAccessedAPITypes` one dict, type `NSPrivacyAccessedAPICategoryUserDefaults`, reasons `["CA92.1"]`.
- No `PrivacyInfo.xcprivacy` under `repoRoot/HomeGymLogWidgets` or `repoRoot/HomeGymLogShared`.
- `HomeGymLogSupport/Info.plist` parses to exactly one key, `UILaunchScreen`. Read it as `[String: Any]` (U10); its only entry is `UIColorName as? String == "bg"`.
- No file named `Info.plist` under `HomeGymLog/`.
- NB-2: the non-`.swift` files under `HomeGymLog/` outside `Assets.xcassets/` (`.skipsHiddenFiles`) are exactly `{"rest-over.caf", "PrivacyInfo.xcprivacy"}`.

Verify:
```
plutil -lint HomeGymLog/PrivacyInfo.xcprivacy HomeGymLogSupport/Info.plist
BUILD && WONLY ReleaseAssetTests RestChimeAssetTests; TEST; CNT; RELEASEW                 # 0
ls -a $REL | grep -E "PrivacyInfo.xcprivacy|rest-over.caf|DS_Store"; cmp $REL/PrivacyInfo.xcprivacy HomeGymLog/PrivacyInfo.xcprivacy
```
Expect both resources, no `.DS_Store`, and `cmp` silent. **AC-7**, AC-15 (manifest listed).

### Step 4 — A1 tile and A4 subtitle (AC-1, AC-2, AC-11)
- `Features/Onboarding/WelcomeStep.swift:9–13`: replace the `Text("H")` block with
  `Image(decorative: "WelcomeTile").resizable().scaledToFit().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12))`.
  `Image(decorative:)` keeps it out of VoiceOver (≈ `alt=""` with `aria-hidden`). `Color.white` leaves the file.
- `Features/Onboarding/AboutYouStep.swift:9`: subtitle `"Session length sets how many exercises you do."`

Tests: new `HomeGymLogTests/Static/ReleaseCopyTests.swift` (AC-11, NB-4; uses `FeedbackSourceTests.codeLines` / `appFiles`). Write it first and run it once:
`WONLY ReleaseCopyTests` must fail on today's sources. Then make the edits. It checks:
- `AboutYouStep.swift` has the new literal on exactly one line.
- No app file contains `"Used to size"`.
- `WelcomeStep.swift` has no `Text("H")` and exactly one line containing `"WelcomeTile"`. That line contains `Image(decorative:` (F6).
- No other app file has a line matching `Image("` or `Image(decorative: "`. `Image(systemName:` does not match.

Verify:
```
BUILD && WONLY ReleaseCopyTests ColorsetContrastTests OnboardingDraftTests; TEST; CNT; RELEASEW      # 0
BOOT $UDID; APPEAR $UDID dark; RSHOTS s4; RCMP s4
```
Expected results:
- `RCMP s4`: `same` for all 13 names in AC-3.
- `ob0`: `DIFF rows` with a span ≤ 132 (44 pt × 3, the tile only).
- `ob3`: `DIFF rows` confined to the subtitle band.
- `/design-compare ob0` (`SEEDCLR` then `-seed onboarding`, against `build/rel/proto-ob0.png`): matches. Allowed deviations: m2-onboarding AC-1's
  two (body copy "HomeGymLog", "up to 52.5 lb") and the tile is the icon artwork, a white dumbbell-"H" on `#E11D48` at radius 12 (same slot and size).
- `/design-compare ob3` (`-seed ob3`, against `build/rel/proto-ob3.png`): matches m2-onboarding AC-4 (180 / lb, Intermediate, 45m, "5 exercises per
  session"). The one allowed deviation is the new subtitle.
- Read `build/shot-rel-s4-ob0.png` at full size: a white dumbbell-"H" on accent with rounded corners.

**AC-1, AC-2, AC-3** (first pass), **AC-11**.

### Step 5 — App Store text and pages (AC-12, AC-13)
New `docs/release/`:
- `app-store-metadata.md`:
  - The §2.4 table rows: category, App Privacy, age rating, export compliance, the two URL placeholders, Marketing/What's New, version/build, copyright.
  - Five fenced blocks whose info strings are `name`, `subtitle`, `promotional-text`, `keywords`, `description`. Each block's text is copied from §2.4.
  - The description has headings on their own line, followed by their sentences, with a blank line between paragraphs.
    Recounted while planning: 1518 scalars; subtitle 30, promotional text 165, keywords 98 bytes.
- `privacy-policy.md` (§2.5 points 1–7 as prose, one paragraph each, in order, with the literal placeholders `<contact email>` and `<effective date>`, F5), `support.md` (§2.5 support list), and `release-checklist.md` (§2.6 steps 1–7 verbatim, with §5.8's command in a code block).

Tests: new `HomeGymLogTests/Static/StoreMetadataTests.swift` (`docs/release` under `repoRoot`):
- Helpers: `static func blocks(in markdown: String) -> [String: [String]]` (a line `` ```<id> `` opens a block, a line `` ``` `` closes it, and the
  content is joined with `\n`), and `static func violations(_ f: [String: String]) -> [String]` (the AC-12 rules).
- **AC-12**: exactly one block per id; `violations` empty; `name == "HomeGymLog"`. The rules:
  - limits: Unicode-scalar counts for name 2…30, subtitle ≤ 30, promotional text ≤ 170, description ≤ 4000; keywords `utf8.count` ≤ 100
  - every trimmed keyword term is ≥ 3 characters and none is empty
  - the banned words (case-insensitive) appear in neither subtitle nor keywords: `iPhone`, `Live Activit`, `Dynamic Island`, `TestFlight`, `App Store`, `Marcy`, `HomeGymLog`
- **Checker control**: an inline markdown with valid `name`, `promotional-text` and `description` blocks, a 31-character subtitle and keywords
  `home gym,PR,iPhone` yields exactly three violations, asserted by id (subtitle length, keyword term `PR` < 3 chars, banned word `iPhone` in
  keywords), so a missing-block rule cannot inflate the count. This proves the rules can fail.
- **AC-13**: `privacy-policy.md` and `support.md` are each ≥ 400 bytes and contain `<contact email>` or `@`; `privacy-policy.md` also contains
  `<effective date>` or a `20` year (one more `#expect`, spec AC-13). `release-checklist.md` contains
  `xcodebuild archive` and `Validate App`.

Verify: `BUILD && WONLY StoreMetadataTests; TEST; CNT`. **AC-12, AC-13.**

### Step 6 — `make-store-screenshots.sh` and the five PNGs (AC-16)
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

### Step 7 — CHECKPOINT: the user's Xcode GUI steps (implementer STOPS and hands these over in one message; AC-19)
No dated gotchas recipe exists for these three controls. The click paths are spec §4.3 / researcher Q4 wording, **unverified in Xcode 27**,
so each step is paired with a grep. Ask for a screenshot whenever the user cannot find a control. Agents only grep `project.pbxproj`.
- (0) Open `HomeGymLog.xcodeproj`. Set the toolbar run destination to an **iPhone 15** simulator (the target tabs follow the destination's platform,
  gotchas 2026-10-03). In the Project navigator, select the blue **HomeGymLog** project row → TARGETS → **HomeGymLog** (not HomeGymLogTests,
  not HomeGymLogWidgetsExtension).
- (1) **General** tab → **Deployment Info** → **iPhone Orientation**: untick **Landscape Left** and **Landscape Right**. **Portrait** stays ticked,
  **Upside Down** stays unticked.
- (2) **Build Settings** tab → filter **All** (and **Combined**) → type `Non-Exempt` in the search field → row **App Uses Non-Exempt
  Encryption** → set the value to **No** on the row itself, not on an expanded Debug/Release sub-row.
- (3) Still in Build Settings, search `Info.plist File` → **Packaging** → **Info.plist File** → double-click the value → type exactly
  `HomeGymLogSupport/Info.plist` → Return. **Never** drag `HomeGymLogSupport/` or the file into the navigator, and never use Add Files (Xcode 27
  would make it a synchronized folder, and the build would fail with "Multiple commands produce", gotchas 2026-10-03).

Verify read-only (F1, F8: semantic, never exact lines; quotes or a `$(SRCROOT)/` prefix still pass):
```
grep INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone $PBX | grep -c Portrait                 # 2
grep INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone $PBX | grep -cE "Landscape|UpsideDown"  # 0 (Step 0: 2)
grep INFOPLIST_KEY_ITSAppUsesNonExemptEncryption $PBX | grep -c "NO"                               # 2 (Step 0: 0)
grep -v GENERATE_INFOPLIST_FILE $PBX | grep INFOPLIST_FILE | grep -c "HomeGymLogSupport/Info.plist" # 2
grep -v GENERATE_INFOPLIST_FILE $PBX | grep -c INFOPLIST_FILE                                      # 4 (Step 0: 2)
grep -c "MARKETING_VERSION = 1.0;" $PBX; grep -c "CURRENT_PROJECT_VERSION = 1;" $PBX               # 6 and 6
grep -c "INFOPLIST_KEY_NSSupportsLiveActivities = YES" $PBX                                        # 2
git diff --stat $PBX; git diff $PBX     # one file; only the three settings; record the exact new lines for gotchas (U9)
git status --short | grep -v "^??" ; ls HomeGymLog.xcodeproj/xcshareddata/xcschemes                # no scheme or navigator change
```
On a wrong count, give the user the one corrective click and re-grep. Then run `BUILD && TEST; CNT` (green, unchanged).
Optional, if the user wants a visual check before the device pass: launch-screen probe (gotcha 2026-10-03 recipe). Run `xcrun simctl install $UDID $APP`, then
`xcrun simctl launch --wait-for-debugger $UDID $BID`, `sleep 3`, `xcrun simctl io $UDID screenshot build/rel/launch-dark.png`, `xcrun simctl terminate $UDID $BID`.
Read the image: a uniform near-black `0F0E10`, not `000000`. Sample one centre pixel with the `build/light-cmpx.py` `load` shape.

### Step 8 — hosted and project pins, created only now (AC-8, AC-9, AC-10, AC-14)
- New `HomeGymLogTests/App/ReleaseBundleTests.swift` (`@MainActor @Suite struct ReleaseBundleTests`, `import Foundation, Testing, UIKit`; plain
  `#expect`, no `withKnownIssue`, `.disabled` or guard, per B-3):
  - **AC-8**: `Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")` is non-nil. Its `deletingLastPathComponent().resolvingSymlinksInPath().path`
    equals `Bundle.main.bundleURL.resolvingSymlinksInPath().path`. Its `Data` equals `appSourceRoot/PrivacyInfo.xcprivacy`'s.
  - **AC-9**: `UIImage(named: "WelcomeTile")?.size == CGSize(width: 1024, height: 1024)`. This is U14's runtime probe. On failure, take the Step 2 U14 fallback and rerun Steps 2 and 8.
  - **AC-10**: `info = Bundle.main.infoDictionary`:
    - `["UISupportedInterfaceOrientations"] as? [String] == ["UIInterfaceOrientationPortrait"]`
    - `["ITSAppUsesNonExemptEncryption"] as? Bool == false`
    - `(info["UILaunchScreen"] as? [String: Any])?["UIColorName"] as? String == "bg"` (U10)
    - `CFBundleShortVersionString == "1.0"`, `CFBundleVersion == "1"`, `NSSupportsLiveActivities as? Bool == true`
- New `HomeGymLogTests/Static/ReleaseProjectTests.swift`, using `LiveActivityProjectTests.lines()` (internal `static func`, `Static/LiveActivityProjectTests.swift:16`). **AC-14**, semantic (B-2):
  - Orientation: the lines containing `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` number 2; each contains `UIInterfaceOrientationPortrait`, and none
    contains `Landscape` or `UpsideDown`.
  - Encryption: the lines containing `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` number 2. Each one's value (text after `=`, trimmed of spaces, `;` and `"`) is `NO`.
  - Plist path: the lines containing `INFOPLIST_FILE` and **not** `GENERATE_INFOPLIST_FILE` number 4 (F1); 2 contain `HomeGymLogSupport/Info.plist` and 2 contain
    `HomeGymLogWidgets/Info.plist`.
  - Versions: `MARKETING_VERSION = 1.0;` ×6, `CURRENT_PROJECT_VERSION = 1;` ×6, `INFOPLIST_KEY_NSSupportsLiveActivities = YES` ×2.

  Every predicate here was false on Step 0's recorded values, so each can fail.

Verify: `BUILD && WONLY ReleaseBundleTests ReleaseProjectTests LiveActivityProjectTests; TEST; CNT`. If U10's cast or another hosted read fails:
read the actual value with a one-off `#expect(String(describing: info["UILaunchScreen"]) == "")`, report it, delete the probe line, and fix only the cast (never weaken the value).
**AC-8, AC-9, AC-10, AC-14.**

### Step 9 — Release read-back, both runtimes, icon determinism, final regression (AC-3, AC-15, AC-18)
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
BOOT $UDID; APPEAR $UDID dark; RSHOTS s9; RCMP s9           # 13 AC-3 names same; ob0/ob3 as Step 4
```
**AC-3** (final), **AC-15**, **AC-18.**

### Step 10 — definition of done: the signed archive (AC-17; no `-exportArchive`, no upload)
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
Green means `** ARCHIVE SUCCEEDED **` and every line as commented. On a signing failure: re-run once with `-allowProvisioningUpdates` (§5.8 optional), then report.
The local variable is `APPX` because `APP` is the Debug path in the env. **AC-17.**

### Step 11 — docs (doc-writer, after test-writer and swift review)
- `docs/layout.md`: roster rows for `HomeGymLogSupport/` (`Info.plist`: path-referenced by `INFOPLIST_FILE`, never synchronized),
  `HomeGymLog/PrivacyInfo.xcprivacy`, the two catalogs' new files (script outputs), `design/icon/` (the artwork source, edit here and rerun),
  `docs/release/` (four `.md` and `screenshots/`), `docs/tools/make-app-icon.py`, `make-store-screenshots.sh`, and the five new test files.
- `CLAUDE.md`: in the layout block, rows for `HomeGymLogSupport/` and `docs/release/`, with `docs/tools/` named. The M5 milestone line for `m5-release`.
- `insights/INSIGHTS.md`: an "Implemented" bullet under 2026-10-03 release decisions (counts, F1–F8 and U14 outcomes). Confirm the icon bullets
  already read `design/icon/` as the one source (S2 was fixed by the main session during planning; no edit expected).
- `insights/gotchas.md` (Xcode/build): the pbxproj lines the GUI actually wrote at Step 7 (U9), and anything else that bit.

### Step 12 (optional) — scratch-copy XCUITest: portrait lock (AC-20 rotation half on the simulator)
INSIGHTS "Real-touch probes":
- Copy the repo (working changes included) to the scratchpad; **in the copy only** add a UI-test target and bundle ids `….probe` / `.probe.widgets`; the
  repo's `project.pbxproj` is never touched. Skip path: delete the copy. Require `BUILD SUCCEEDED` before `test-without-building`.
- `-seed wo-rest`, then `-seed summary`, one launch each: assert width < height and that "Skip rest" (resp. the summary title) exists (positive control);
  set `XCUIDevice.shared.orientation = .landscapeLeft`, wait 1 s, assert width < height again with the same element hittable. No scroll-end check (no tab grows).

### Traceability (AC → step)
| AC | Step | AC | Step | AC | Step |
|---|---|---|---|---|---|
| 1 | 4 | 9 | 8 (U14 runtime probe) | 17 | 10 |
| 2 | 4 | 10 | 8 | 18 | 9 (26.5, determinism) |
| 3 | 4, 9 | 11 | 4 | 19 | 7 (user) |
| 4 | 2 | 12 | 5 | 20 | user (Step 12 optional) |
| 5 | 2 | 13 | 5 | 21 | 2 (closed: artwork ships) |
| 6 | 2 | 14 | 8 | 22 | user |
| 7 | 3 | 15 | 1 (0 warnings), 3, 9 (plist lines) | | |
| 8 | 8 | 16 | 6 | | |

Tooling: `make-app-icon.py` runs in Step 2 (AC-4–6) and again in Step 9 (AC-18). `make-store-screenshots.sh` runs in Step 6 (AC-16).

### Existing tests this slice breaks: none
These were checked against spec §8 while planning:
- every `DebugSeed.allCases` iteration (no seed added)
- `ColorsetContrastTests.elevenColorsets` (filters `*.colorset`) and `hardCodedColorPaths`: `Color.white` is not one of its tokens (`ColorsetContrastTests.swift:247–257`), and leaving `WelcomeStep.swift` changes no row. Its `Color("` scan is untouched (the tile uses `Image`).
- `FeedbackSourceTests.appFiles` / `ClockUsageTests` (`.swift` only)
- `LiveActivityProjectTests`: none of its pins counts `INFOPLIST_FILE` or orientation (`:24–40`), so the six pins survive Step 7
- `WidgetSourceTests` (the widget catalog is untouched)
- `SettingsScreenSourceTests`, `LiveActivitySourceTests`
- `RestTextTests`, `RestartPrefillTests`, `RestartPrefillEdgeTests`, `OnboardingDraftTests`, `RestartFlowTests`, and the `WorkoutLogStore` persistence suites (Step 1 changes isolation and the constant's home only)

No test pins `Text("H")` or the old subtitle (grepped).

## 4. Data model changes
None: no `@Model`, field, relationship, delete rule, `#Predicate`, preference key, backup key or migration. `AppSchemaV1` is untouched.

## 5. Risks and gotchas
| Risk | Mitigation |
|---|---|
| F1: the spec's `INFOPLIST_FILE` ×4 count fails on a correct project | Exclude `GENERATE_INFOPLIST_FILE` lines in the grep and in `ReleaseProjectTests`; report to the spec owner |
| U9: GUI line shape unknown (quotes, `$(SRCROOT)/`) | Token-and-value pins (B-2); Step 7 records the observed lines for gotchas |
| GUI click paths unverified in Xcode 27; the Info/General tabs follow the run destination (gotchas 2026-10-03) | Destination set first; each click paired with a grep; screenshot on doubt |
| Dragging `HomeGymLogSupport/` into the navigator → "Multiple commands produce"; a CLI `INFOPLIST_FILE=` breaks the appex (gotchas 2026-10-03) | Typed path only (Step 7 (3)); no `INFOPLIST_*` on any command line in this plan; Step 9 checks the appex's `NSExtensionPointIdentifier` |
| U11: a closure form still warns | `RELEASEW` in Step 1 is the probe; report rather than annotate |
| U10/U12: hosted casts or 26.5 behaviour differ | U10 cast as `[String: Any]`; Step 8 fallback fixes only the cast; Step 9 `TEST26S` runs `ReleaseBundleTests` |
| 26.5 test run hangs after `simctl` shots (gotchas 2026-10-03) | `TEST26S` boots first and runs with `-parallel-testing-enabled NO` |
| A light PNG with alpha passes actool silently (Q2, ITMS-90717) | AC-5 test; `file` / `sips -g hasAlpha` in Step 2 |
| Finder `.DS_Store` under `HomeGymLog/` would ship and break NB-2 | Enumerators skip hidden files; Step 3 `ls -a $REL` shows no `.DS_Store` (whether Xcode copies dotfiles is unverified; that listing is the probe) |
| Store shots: RGBA from `simctl`, first 26.5 shot island, status bar left overridden, all-black flatten (F4) | rsvg flatten; throwaway shot; `trap` with failure-path probe; read every image |
| Icon script output stray under `HomeGymLog/` ships (gotcha 2026-09-24) | `mkdtemp` intermediates; Step 2 `git status --short HomeGymLog/` lists only the expected files; NB-2 test |
| U14: the `<metadata><c2pa:manifest>` block breaks actool's SVG compile | Step 2 (a) probes with `assetutil` before the tests; AC-9 and AC-18 probe again; the fallback strips `<metadata>` in the script and in AC-6's comparison |
| A changed artwork without exactly one `#0F0E10` field rect in `-dark.svg` | The script exits with a message (guarded by Step 2's negative probe); never hand-edit the outputs |
| Archive signing (second bundle id on the wildcard dev profile, Q5) | One retry with `-allowProvisioningUpdates`; report on failure |

## 6. Definition of done
- [ ] `RELEASEW` prints 0 warnings (Steps 1–9), and `build/last-release.log` has no `warning:` line.
- [ ] `ob0` and `ob3` match by `/design-compare` with the listed deviations; the 13 AC-3 names are `same` against `build/shot-rel-base-*`.
- [ ] Step 7 greps read as listed; `git diff --stat` touches only `project.pbxproj`'s three settings.
- [ ] Full suite green on iPhone 15 / 17.5 and iPhone 17 / 26.5 with equal `totalTestCount`; the five new suites are present.
- [ ] Release `.app`: `PrivacyInfo.xcprivacy`, `UILaunchScreen => { UIColorName => "bg" }`, encryption `0`, portrait only; the appex keeps widgetkit.
- [ ] `docs/release/` holds the four `.md` files and five 1320 × 2868 RGB screenshots; the screenshot device's status bar is cleared; the icon rerun is byte-identical.
- [ ] `** ARCHIVE SUCCEEDED **` with both dSYMs, the embedded appex, both identifiers, team `4GKZ96A6QR`, the manifest and the three plist values.
- [ ] Docs updated (Step 11); swift review saved to `docs/reviews/m5-release-swift-review.md`.

## Files to commit (the user commits; the implementer never does)
`git add design/icon` (the artwork source: three SVGs, `HomeGymLog-icon-1024.png`, `NOTE.md`); `git add docs/tools/make-app-icon.py
docs/tools/make-store-screenshots.sh docs/release HomeGymLogSupport HomeGymLog/PrivacyInfo.xcprivacy HomeGymLog/Assets.xcassets/AppIcon.appiconset
HomeGymLog/Assets.xcassets/WelcomeTile.imageset`; the six Step 1 Swift files and the two onboarding files; the five new test files and the two appended
suites; `HomeGymLog.xcodeproj/project.pbxproj` (Step 7, the user's GUI edit); `docs/plans/m5-release.md`, the spec and the reviews. Never `build/`.
After the commit, `git status --short HomeGymLog/` must be empty after one more `make-app-icon.py` rerun (the post-commit form of AC-18).

## User-run ACs (never block the merge)
- **AC-19**: Step 7 (mid-slice; it unblocks Steps 8–10).
- **AC-20** (iPhone 14 Pro Max): the Home Screen shows the white dumbbell-"H" on `#E11D48`; a cold launch shows `bg`, not white or black; rotating in
  the workout and the summary changes nothing; iOS Settings → HomeGymLog still lists Live Activities and Notifications; VoiceOver on A1 (F6) starts at "Your gym. Your program." and never stops on the tile.
- **AC-21**: closed by this slice. `design/icon/` ships through the script (Step 2); a future artwork change is an edit there plus a rerun.
- **AC-22**: create the public `homegymlog-site` repo with both pages, fill in the two URLs in `app-store-metadata.md`, then §2.6 steps 3–7.

# M5 slice 2 — Light theme audit (three colorset edits, contrast suite, every screen in Light on both runtimes): implementation plan
**Status: draft 2026-09-25, for plan-verifier.** For `docs/specs/m5-light-theme.md` (approved draft; architecture review
`docs/reviews/m5-light-theme-architecture.md` B1, B2 (b), NB1–NB8 folded in). Spec §2–§6 and §8 are the contract (`AC-1`…`AC-17`)
and are not restated. Format follows `docs/plans/m5-haptics.md`. `implementer`: one step per build, nothing committed.
Baseline: HEAD `0a64b13` (branch `m5-light-theme`), 1080 tests.

## Spec issues (found while planning; the plan takes the stated default, none blocks)
1. *(Folded into spec AC-11, 2026-09-25.)* **AC-11 "total, no throws" vs a hex-string call shape** (`ratio("FFFFFF","17161A")`). A function that parses a `String`
   cannot be total without a silent fallback, which NB1 forbids. Default: `RGB` is `ExpressibleByStringLiteral` and
   **traps** (`preconditionFailure`) on a malformed *literal* (test source only); `ratio` / `blend` / `luminance` take `RGB` and are
   total. Colorset data never goes through the literal init: it goes through the Static suite's `#require` parser (NB1).
2. *(Folded into spec AC-11, 2026-09-25.)* **`15803D` on light `bg` is 4.50011** (planner recompute, Python, same §5.1 formula): AC-12's "≥ 4.5" holds by 1.1 × 10⁻⁴.
   Not a contradiction, but the test must compare the **unrounded** `Double`; rounding to two decimals first would still
   pass, rounding the luminances first could not be trusted. `B45309` on `bg` is 4.5055.
3. **`/design-compare` has no input for a substitute reference image.** Default: the light reference path is passed in the
   skill's free-form second argument ("reference: `build/light-ref/<snapshot>.png`, app shot: `<path>`, skip step 1"). If the skill re-renders from `design/` anyway, fall back to a manual side-by-side: Read
   `build/light-ref/<snapshot>.png` and the app shot, and list differences by the skill's step-3 checklist.
4. **"`cmp` outside the home-indicator band"** (AC-2, AC-9): `cmp` cannot exclude a region. Default: `CMPX` (Step 1), a
   row-wise compare of the two PNGs converted to BMP by `sips`, bottom 60 px rows excluded (planner probe 2026-09-25: two
   `build/shot-*-home.png` files compared `same`, a dark vs light pair `DIFF rows 0..2499`).
5. **Rows with no prototype frame** (`restDay`, `freshProgram`, the banner, the Program Missed / Skipped cards, the three
   reminder states, `wo-swap-rdl`, `wo-notes`): the reference is the nearest snapshot's light render for layout plus the
   (a)–(f) checklist; the mapping is Step 6's `LIGHTLIST` second column.
6. **AC-15 "back to System and Dark reverts them, including an open sheet"**: with a sheet up, Settings is covered, so the
   only way to change appearance under an open sheet is the device switch; the optional Step 8 cannot tap that, it stays
   user-run.

## 1. Goal and scope
Confirm the eleven tokens against the prototype, fix the three light entries the audit found (`success`, `warning` gain a
dark entry and a darker light base; light `mu` darkens), pin tokens, entry shapes, hard-coded color sites and the WCAG ratios
in a Static suite, prove Dark is byte-identical before/after, and screenshot every screen in Light on iOS 17.5 and 26.5
against a light-patched render of the prototype. Order: env and Dark baselines (before any asset edit, B1) → light reference
render → test helper and invariant suite → the three `Contents.json` edits with their After-state tests → Dark regression →
Light screens 17.5 → 26.5, Release, review gate.
**Out of scope (spec §7):** any `.swift` change under `HomeGymLog/`, `accent` in either theme, Dark's own ratios, Dynamic
Type / Increase Contrast / Reduce Motion, sheet dim, `foregroundColor` spellings, new seeds, icon, Live Activity, export.
**User-run ACs (MVP pass, not a merge gate):** AC-15, AC-16, AC-17 (device taps, keyboard, outdoor legibility). Optional
Step 8 machine-checks AC-15 (minus the open-sheet half, issue 6) and AC-16 in a scratch copy.
**No dependency, entitlement, capability, plist key, schema, seed or `project.pbxproj` change.**

## 2. Decisions this plan relies on
- INSIGHTS 2026-09-25 "M5 light-theme decisions" (fix the fills themselves; light `mu` `68646A`; accepted brand shortfalls;
  `ColorsetContrastTests` with a test-only helper; JSON read via `#filePath`, never `Bundle.main`; Dark baselines first;
  patched scratch prototype as the light reference; rest-card shadow kept; no new seed). INSIGHTS 2026-09-22 Appearance via
  `overrideUserInterfaceStyle` from `RootView` (unchanged). Patterns "Real-touch probes" (Step 8).
- Spec §2.2 "After" column (the only owner of the new hex values), §5.1–5.4 formulas, §8 rows 1–10, AC-11–AC-14 literals.
- gotchas: SwiftUI 2026-09-22 (`UIColor(named:)`, `simctl ui appearance` System-only, `.preferredColorScheme`); Xcode / build
  2026-09-22 (stale `seed` suite → `defaults delete seed`; home-indicator fade; `xcodebuild test` clones the simulator;
  `sips -c h w --cropOffset y x`, read every crop); 2026-09-23 (`-only-testing` hang → watchdog); 2026-09-16
  (`-only-testing:…/function()` runs 0 tests → select suites; quote `totalTestCount`); 2026-09-13 (poll the http server);
  2026-09-15 (sheet dim 0.12 / 0.20 in Light); Design export 2026-09-09 (standalone HTML is a gzip+base64 bundle).
- Verified by the planner's probe (2026-09-25, scratchpad only): the flows file's `__bundler/manifest` holds six
  compressed entries; `const s={...base};` occurs exactly once, in entry `10ae844f-5d65-4168-98c9-d7426b1c7044` (text/html,
  the `benchmarkApp` resource); the Step 2 script patches it, the page renders every frame light, every recorded crop
  below lands on its frame in the patched render (read: ob0, home-light, wo-start, program, progress, settings, missed),
  and the patched `home-light` crop is byte-identical (`cmp`) to the unpatched one.
- **Open questions:** none; spec issues above carry their defaults.

## 3. Steps
Every command starts with `cd /Users/zhabskyi/AppleApps/HomeGymLog && source build/light-env.sh` (zsh). One foreground
`xcodebuild` at a time, timeout 600000. Undo = restore by hand; never `git checkout`, `git stash` or `git clean` (the
spec, review and plan files have no commit yet). `build/` is gitignored; nothing in `design/` is written.

### Step 1 — shorthands and Dark baselines (before any asset edit) — AC-9, AC-10 (baseline half)
Create `build/light-env.sh` (commands copied from CLAUDE.md "Commands"; `SEEDCLR`/`WONLY` from gotchas 2026-09-22/-23):
```sh
DEST='platform=iOS Simulator,name=iPhone 15,OS=17.5'; DEST26='platform=iOS Simulator,name=iPhone 17,OS=26.5'; BID=com.zhabskyi.homegymlog.ios
UDID=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-5"][] | select(.name=="iPhone 15") | .udid')
UDID26=$(xcrun simctl list devices available -j | jq -r '.devices["com.apple.CoreSimulator.SimRuntime.iOS-26-5"][] | select(.name=="iPhone 17") | .udid')
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/HomeGymLog.app; mkdir -p build/lt build/light-ref build/proto-light
BUILD() { xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData build 2>&1 | tee build/last-build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; }
TEST() { rm -rf build/tests.xcresult; xcodebuild -scheme HomeGymLog -destination "$DEST" -derivedDataPath build/DerivedData -resultBundlePath build/tests.xcresult "$@" test 2>&1 | tee build/last-test.log | grep -E "✘|TEST (SUCCEEDED|FAILED)"; }
ONLY() { local a=(); for s in "$@"; do a+=("-only-testing:HomeGymLogTests/$s"); done; TEST -parallel-testing-enabled NO "${a[@]}"; }
WONLY() { (ONLY "$@") & local P=$!; (sleep 500; kill $P 2>/dev/null) & local W=$!; wait $P; kill $W 2>/dev/null; tail -3 build/last-test.log | grep -E "Test run|TEST"; }
CNT() { xcrun xcresulttool get test-results summary --path build/tests.xcresult | jq -c "{result,totalTestCount,passedTests,failedTests}"; }
RELEASE() { xcodebuild -scheme HomeGymLog -configuration Release -destination "$DEST" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; }
TEST26() { xcodebuild -scheme HomeGymLog -destination "$DEST26" -derivedDataPath build/DerivedData test 2>&1 | tee build/last-test26.log | grep -E "✘|TEST (SUCCEEDED|FAILED)"; }
BOOT() { xcrun simctl boot "$1" 2>/dev/null; xcrun simctl bootstatus "$1" -b >/dev/null; xcrun simctl status_bar "$1" override --time 9:41; }
SEEDCLR() { xcrun simctl spawn "$1" defaults delete seed 2>/dev/null; }
APPEAR() { xcrun simctl ui "$1" appearance "$2"; }
LAUNCH() { local u=$1; shift; xcrun simctl terminate "$u" $BID 2>/dev/null; xcrun simctl install "$u" "$APP" && xcrun simctl launch "$u" $BID "$@" >/dev/null; }
SHOT() { sleep 3; xcrun simctl io "$1" screenshot "build/lt/$2.png" >/dev/null; }
CMPX() { python3 build/light-cmpx.py "$@"; }   # CMPX a.png b.png [topRowsToSkip]
DARKLIST=("home|-seed midProgram" "program|-seed midProgram -tab program" "progress|-seed midProgram -tab progress"
  "settings|-seed midProgram -tab settings" "wo-rest|-seed wo-rest" "summary|-seed summary" "missed|-seed missed")
DARKSHOTS() { local u=$1 tag=$2; APPEAR $u dark; for e in "${DARKLIST[@]}"; do local n=${e%%|*} a=${e#*|}; SEEDCLR $u; LAUNCH $u ${=a}; SHOT $u "$tag-dark-$n"; done; }
DARKCMP() { local rt=$1; for e in "${DARKLIST[@]}"; do local n=${e%%|*}; print -n "$rt $n: "; CMPX build/lt/$rt-base-dark-$n.png build/lt/$rt-after-dark-$n.png; done; }
```
`LIGHTLIST`, `LIGHTSHOTS`, `CROPS`, `PROTOL` are appended in Steps 2 and 6. Create `build/light-cmpx.py` (Python 3 stdlib
+ `sips`; the probe of spec issue 4): convert each PNG with `sips -s format bmp`, read the BMP header (offset at byte 10,
width/height at 18, bpp at 28, 4-byte-aligned stride, bottom-up unless height < 0), compare rows `top ..< height − 60`; print
`same`, `DIFF size`, or `DIFF rows <first>..<last> (<n>)`; exit 1 on a difference.
Verify: `git diff --quiet -- HomeGymLog/Assets.xcassets && echo clean` (**must print `clean`; if not, stop — the baseline would
be vacuous, B1**); `BUILD && TEST; CNT` (expect `totalTestCount` 1080; record if different); `BOOT $UDID; DARKSHOTS $UDID 17-base`;
`BOOT $UDID26; DARKSHOTS $UDID26 26-base` (the Debug simulator build installs on both runtimes); sanity:
`CMPX build/lt/17-base-dark-home.png build/lt/17-base-dark-home.png` prints `same` and
`CMPX build/lt/17-base-dark-home.png build/lt/17-base-dark-missed.png` prints `DIFF rows …` (the compare can fail). Read
`build/lt/17-base-dark-home.png` and `build/lt/26-base-dark-missed.png` (dark, clock 9:41). 14 baseline PNGs in `build/lt/`.

### Step 2 — light reference render (scratch, `build/proto-light/`) — enables AC-1, AC-3–AC-8
Create `build/proto-light/patch_light.py` (verbatim; probed 2026-09-25):
```python
import base64, gzip, json, re, sys
src, dst = sys.argv[1], sys.argv[2]
page = open(src, encoding="utf-8").read()
m = re.search(r'<script type="__bundler/manifest">(.*?)</script>', page, re.S)
manifest = json.loads(m.group(1))
OLD, NEW = "const s={...base};", "const s={...base,theme:'light'};"
patched = []
for uuid, entry in manifest.items():
    raw = base64.b64decode(entry["data"])
    body = gzip.decompress(raw) if entry.get("compressed") else raw
    try:
        text = body.decode("utf-8")
    except UnicodeDecodeError:
        continue
    if text.count(OLD) == 0:
        continue
    patched += [uuid] * text.count(OLD)
    out = text.replace(OLD, NEW).encode("utf-8")
    entry["data"] = base64.b64encode(gzip.compress(out, mtime=0) if entry.get("compressed") else out).decode("ascii")
assert len(patched) == 1, f"expected one patch site, found {patched}"
open(dst, "w", encoding="utf-8").write(page[:m.start(1)] + json.dumps(manifest, separators=(",", ":")) + page[m.end(1):])
print("patched", patched[0])
```
Append to `build/light-env.sh`. Crops are copied from `.claude/skills/design-compare/SKILL.md` ("h×w @ (y, x)" =
`sips -c h w --cropOffset y x`), with the render each was recorded on:
```sh
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CROPS=("ob0|3000x5600|640 720|200 45" "ob1|3000x5600|640 370|200 790" "ob2|3000x5600|640 430|200 1180"
  "ob3|3000x5600|640 340|200 1620" "ob4|3000x5600|640 455|200 1960" "ob5|3000x5600|640 575|200 2425"
  "home|3000x5600|900 700|930 40" "wo-start|3000x5600|600 300|930 740" "wo-swipe|3000x5600|600 300|930 1045"
  "wo-rpe|3000x5600|700 310|930 1345" "wo-rest|3000x5600|600 300|930 1665" "summary|3000x5600|640 330|930 1975"
  "wo-adjust|3000x5600|570 300|1890 40" "wo-detail|3000x5600|570 300|1890 350" "wo-swap|3000x5600|570 300|1890 640"
  "program|3000x5600|720 1620|2530 30" "progress|4400x5600|2340 2520|2540 1620" "missed|3000x6600|850 680|4970 44"
  "settings|5600x5600|800 290|2555 4148" "home-light|5600x5600|850 680|2555 4456")
SERVE() { (cd "$1" && python3 -m http.server $2 --bind 127.0.0.1 >/dev/null 2>&1 &); until curl -sf -o /dev/null http://127.0.0.1:$2/; do sleep 0.2; done; }
RENDER() { "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=${2/x/,} --virtual-time-budget=20000 \
  --screenshot=$3 "http://127.0.0.1:$1/Benchmark%20Flows%20(standalone).html" >/dev/null 2>&1; }
PROTOL() { python3 build/proto-light/patch_light.py "design/Benchmark Flows (standalone).html" "build/proto-light/Benchmark Flows (standalone).html"
  SERVE build/proto-light 8766; for r in 3000x5600 4400x5600 5600x5600 3000x6600; do RENDER 8766 $r build/proto-light/r-$r.png; done
  SERVE design 8765; RENDER 8765 5600x5600 build/proto-light/orig-5600x5600.png; pkill -f "http.server 876"
  for c in "${CROPS[@]}"; do IFS='|' read -r s r hw yx <<< "$c"; sips -c ${=hw} --cropOffset ${=yx} build/proto-light/r-$r.png --out build/light-ref/$s.png >/dev/null; done
  sips -c 850 680 --cropOffset 2555 4456 build/proto-light/orig-5600x5600.png --out build/light-ref/home-light-orig.png >/dev/null; }
```
Verify: `PROTOL` prints `patched 10ae844f-5d65-4168-98c9-d7426b1c7044`; `cmp build/light-ref/home-light.png
build/light-ref/home-light-orig.png && echo same` prints `same` (the patch changes no layout; AC-1's reference is the real
crop either way); `git status --porcelain design/` prints nothing; **read every one of the 20 `build/light-ref/*.png`** (a blank
band = a transposed or off-page crop; stop and re-measure from `sips -Z 1500 build/proto-light/r-<size>.png`, never guess).

### Step 3 — `ContrastRatio` helper and the invariant half of `ColorsetContrastTests` — AC-11, AC-13, AC-14, AC-12 (parser, shape, unchanged hex)
Create `HomeGymLogTests/Support/ContrastRatio.swift` (internal; `import Foundation`; no file paths, NB2):
```swift
/// Test-only WCAG 2.1 math (spec 5.1, 5.2, 5.4). ≈ a small pure util module used only by Jest tests.
struct RGB: Equatable, CustomStringConvertible, ExpressibleByStringLiteral {
    let r: Int, g: Int, b: Int                          // 0…255
    init(r: Int, g: Int, b: Int)
    init(stringLiteral hex: String)                    // "15803D"; preconditionFailure unless 6 hex digits (spec issue 1)
    var hex: String { get }                            // uppercase "15803D"; also `description`
}
enum ContrastRatio {
    static func luminance(_ c: RGB) -> Double           // 5.1: c/255, ≤ 0.03928 → /12.92, else ((c+0.055)/1.055)^2.4
    static func ratio(_ a: RGB, _ b: RGB) -> Double     // 5.2: (lighter + 0.05) / (darker + 0.05), order-free
    static func blend(_ fg: RGB, _ alpha: Double, _ bg: RGB) -> RGB   // 5.4: per channel (α·fg + (1−α)·bg).rounded()
}
```
Create `HomeGymLogTests/Static/ColorsetContrastTests.swift`, `@Suite struct ColorsetContrastTests`. Doc comment: the JSON is
read from the source tree because the hosted target's `Bundle.main` holds the compiled `Assets.car`, never the colorset JSON.
```swift
struct Entry: Equatable { let isDark: Bool; let color: RGB; let alpha: String }
static var assetsRoot: URL                              // FeedbackSourceTests.appSourceRoot + "Assets.xcassets" (NB3 walk)
static func colorsets() throws -> [String: [Entry]]     // key = directory name minus ".colorset"
static func color(_ set: String, dark: Bool) throws -> RGB   // #require exactly one matching entry, message names set
```
Private `Decodable` mirrors: `ColorsetJSON { colors: [ColorJSON] }`, `ColorJSON { idiom; appearances: [AppearanceJSON]?; color:
ColorBodyJSON }`, `ColorBodyJSON { colorSpace ("color-space"); components: [String: String] }`, `AppearanceJSON: Equatable
{ appearance; value }`. **Loud parser (NB1):** each file's `Data` and decode go through `try #require(…, "<set>")`; component
keys must be exactly `red green blue alpha`; `red`/`green`/`blue` must match `0x` + 2 hex digits, else `#require` fails naming
the file and key (a decimal `"0.082"` or a number fails, never `?? 0`). Tests:
- `ratioAnchors` (AC-11, literals from the spec, recomputed by the planner): `ratio("FFFFFF","17161A")` within 0.01 of 18.01;
  `ratio("22C55E","FFFFFF")` of 2.28; `ratio("15803D","FFFFFF")` of 5.02; `ratio("FFFFFF","000000")` within 0.001 of 21;
  `blend("000000", 0.55, "F4F2F3") == "6E6D6D"`; `blend("15803D", 0.14, "FFFFFF") == "DEEDE4"`.
- `elevenColorsets`: the key set == `["AccentColor","bd","bg","mu","phaseDeload","phaseFoundation","sf","sf2","success","tx","warning"]`.
- `entryShape`: every entry `idiom == "universal"`, `colorSpace == "srgb"`; alpha `"0.080"` for both `bd` entries, `"1.000"` elsewhere.
- `appearanceShape`: every set has exactly one base entry (`appearances == nil`) and at most one other, whose `appearances`
  `== [AppearanceJSON(appearance: "luminosity", value: "dark")]`.
- `singleEntrySets` (args `AccentColor phaseFoundation phaseDeload`): exactly one entry, the base.
- `themedSetsHaveDark` (typed file-scope argument array `themedSets`, this step `["bg","sf","sf2","tx","mu","bd"]`): one base + one dark.
- `unchangedHex` (typed file-scope table `(set, dark, RGB)`, values copied from the `Contents.json` files read 2026-09-25 =
  spec §2.2): bg `F4F2F3`/`0F0E10`, sf `FFFFFF`/`1A191C`, sf2 `EBE8EA`/`242226`, tx `17161A`/`F5F3F4`, mu dark `8F8B91`,
  bd `000000`/`FFFFFF`, AccentColor `E11D48`, phaseFoundation `5B8DEF`, phaseDeload `8F8B91`.
- `themeNamesMatchColorsets` (AC-13): the names between `Color("` and `")` on `FeedbackSourceTests.codeLines("Shared/Theme.swift")`
  form a set equal to the colorset key set; `FeedbackSourceTests.matches { $0.contains("Color(\"") }` has 11 hits, every path
  `"Shared/Theme.swift"`.
- `hardCodedColorPaths` (AC-14, NB5; typed table token → sorted paths, via `FeedbackSourceTests.matches`, asserted as `found.map(\.path).sorted() == expected` (an array, not a Set, so each path appears exactly once), message names the
  token and says a new `.fontWeight(.black)` is a hit to review): `.shadow(` → `["Features/Home/MissedActionBanner.swift",
  "Features/Workout/RestOverlay.swift", "Shared/FloatingTabBar.swift"]`; `Color.black` → `["Features/Home/MissedPromptHost.swift"]`;
  `.black` → `["Features/Home/MissedActionBanner.swift", "Features/Home/MissedPromptHost.swift", "Features/Workout/RestOverlay.swift",
  "Shared/FloatingTabBar.swift"]`; `preferredColorScheme`, `UIColor(`, `.primary`, `.secondary`, `Material` → `[]` (planner grep
  2026-09-25 matches, one line per path).
Can fail: each literal is independent of the code under test; `hardCodedColorPaths` lists paths, not counts.
Verify: `BUILD && WONLY ColorsetContrastTests` green; then `TEST; CNT` (1080 + the new `@Test` functions; record).

### Step 4 — the three `Contents.json` edits and the After-state tests — AC-12 (remainder), F1, F2
**Red first.** In `ColorsetContrastTests.swift`: `themedSets` gains `"success","warning"`; add
- `afterHex` (table): mu light `68646A`; success light `15803D`, dark `22C55E`; warning light `B45309`, dark `F59E0B`.
- `contrastFloors` (typed file-scope table `(label, fg: (set, dark), bg: (set, dark), floor)`, colors read through `color(_:dark:)`,
  compared unrounded, spec issue 2): Light and Dark `tx`, `mu` on `bg`/`sf`/`sf2` ≥ 4.5 (12 rows); Light `success`, `warning` on
  `bg`/`sf` ≥ 4.5 and on `sf2` ≥ 4.0 (6); Dark `success`, `warning` on `bg`/`sf`/`sf2` ≥ 4.5 (6).
- `whiteOnFills`: `ratio("FFFFFF", AccentColor)` ≥ 4.5; `ratio("FFFFFF", success light)` and `(…, warning light)` ≥ 4.5.
- `pillOnTint`: `ratio(success light, blend(success light, 0.14, sf light))` ≥ 4.0.
Not asserted (Q3 = A): white on dark `success`/`warning`, accent on any surface.
`BUILD && WONLY ColorsetContrastTests` → **must fail** on: `themedSetsHaveDark` success/warning, every `afterHex` row, the
Light `mu`-on-`sf2` row (4.36) and every `success`/`warning` row, both white-on-light-fill checks, `pillOnTint` (2.02). If any of
these passes, the test is wrong; fix it before editing JSON.
**Then** replace the three files (Xcode's own layout; write with the editor, not the Xcode inspector):
`HomeGymLog/Assets.xcassets/success.colorset/Contents.json`
```json
{
  "colors": [
    {
      "idiom": "universal",
      "color": {
        "color-space": "srgb",
        "components": { "red": "0x15", "green": "0x80", "blue": "0x3D", "alpha": "1.000" }
      }
    },
    {
      "idiom": "universal",
      "appearances": [ { "appearance": "luminosity", "value": "dark" } ],
      "color": {
        "color-space": "srgb",
        "components": { "red": "0x22", "green": "0xC5", "blue": "0x5E", "alpha": "1.000" }
      }
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```
`HomeGymLog/Assets.xcassets/warning.colorset/Contents.json`
```json
{
  "colors": [
    {
      "idiom": "universal",
      "color": {
        "color-space": "srgb",
        "components": { "red": "0xB4", "green": "0x53", "blue": "0x09", "alpha": "1.000" }
      }
    },
    {
      "idiom": "universal",
      "appearances": [ { "appearance": "luminosity", "value": "dark" } ],
      "color": {
        "color-space": "srgb",
        "components": { "red": "0xF5", "green": "0x9E", "blue": "0x0B", "alpha": "1.000" }
      }
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```
`HomeGymLog/Assets.xcassets/mu.colorset/Contents.json` (only the base components change, `0x6E 0x6A 0x70` → `0x68 0x64 0x6A`)
```json
{
  "colors": [
    {
      "idiom": "universal",
      "color": {
        "color-space": "srgb",
        "components": { "red": "0x68", "green": "0x64", "blue": "0x6A", "alpha": "1.000" }
      }
    },
    {
      "idiom": "universal",
      "appearances": [ { "appearance": "luminosity", "value": "dark" } ],
      "color": {
        "color-space": "srgb",
        "components": { "red": "0x8F", "green": "0x8B", "blue": "0x91", "alpha": "1.000" }
      }
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```
(Expanded, one-key-per-line formatting as in `bg.colorset` is equally valid; the suite decodes JSON, not text.)
Verify: `python3 -m json.tool` on each of the three files succeeds; `BUILD && WONLY ColorsetContrastTests` green; `TEST; CNT`;
`git diff --stat` lists exactly the three `Contents.json` files (the new test files and `docs/reviews/m5-light-theme-*.md` are untracked).

### Step 5 — Dark regression after-shots — AC-9, AC-10 (dark half)
Verify: `BOOT $UDID; DARKSHOTS $UDID 17-after; BOOT $UDID26; DARKSHOTS $UDID26 26-after; DARKCMP 17; DARKCMP 26` (`DARKCMP`
reads Step 1's `<rt>-base-dark-*` and this step's `<rt>-after-dark-*`). Every line must print `same`. A 26.5 diff confined to
rows < 150 is the status-bar artifact (gotchas 2026-09-14): re-run that pair as `CMPX <base> <after> 150` and record it. Any
other diff: **stop and report** with both images; never re-baseline and never edit the JSON to chase it (this is the slice's
one runtime probe: an "Any + Dark" set must resolve the dark entry to today's components).

### Step 6 — Light screens on iOS 17.5 — AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8
Append to `build/light-env.sh` (`name|reference|launch`, spec §8 rows 1 and 3–8; reference = a Step 2 crop, spec issue 5):
```sh
LIGHTLIST=("home-light|home-light|-seed midProgram" "ob0|ob0|-seed onboarding" "ob1|ob1|-seed ob1" "ob2|ob2|-seed ob2"
  "ob3|ob3|-seed ob3" "ob4|ob4|-seed ob4" "ob5|ob5|-seed ob5" "restDay|home|-seed restDay" "freshProgram|home|-seed freshProgram"
  "missed|missed|-seed missed" "banner|home|-seed missed -missedDayPolicy shift -holdBanner"
  "program|program|-seed midProgram -tab program" "program-missed|program|-seed missed -tab program -programWeek 2 -programDay 2"
  "program-skipped|program|-seed missed-skipped -tab program -programWeek 2 -programDay 2"
  "progress|progress|-seed midProgram -tab progress" "progress-empty|progress|-seed freshProgram -tab progress"
  "progress-history|progress|-seed progress-history -tab progress" "progress-missed|progress|-seed missed -tab progress"
  "settings|settings|-seed midProgram -tab settings" "settings-restart|settings|-seed settings-restart -tab settings"
  "reminder-on|settings|-seed reminder-on -tab settings" "reminder-denied|settings|-seed reminder-denied -tab settings"
  "reminder-unasked|settings|-seed reminder-unasked -tab settings" "haptics-off|settings|-seed midProgram -tab settings -haptics off"
  "wo-start|wo-start|-seed wo-start" "wo-swipe|wo-swipe|-seed wo-swipe" "wo-rpe|wo-rpe|-seed wo-rpe" "wo-adjust|wo-adjust|-seed wo-adjust"
  "wo-rest|wo-rest|-seed wo-rest" "summary|summary|-seed summary" "wo-detail|wo-detail|-seed wo-detail" "wo-swap|wo-swap|-seed wo-swap"
  "wo-swap-rdl|wo-swap|-seed wo-swap-rdl" "wo-notes|wo-detail|-seed wo-notes")
LIGHTSHOTS() { local u=$1 rt=$2; APPEAR $u dark; for e in "${LIGHTLIST[@]}"; do local n=${e%%|*} rest=${e#*|}; local a=${rest#*|}
  SEEDCLR $u; LAUNCH $u ${=a} -appearance light; SHOT $u "$rt-light-$n"; done; }
SYSPATH() { local u=$1 rt=$2; SEEDCLR $u; APPEAR $u light; LAUNCH $u -seed midProgram; SHOT $u "$rt-system-home"; APPEAR $u dark
  CMPX build/lt/$rt-light-home-light.png build/lt/$rt-system-home.png; }
```
Verify: `BOOT $UDID; LIGHTSHOTS $UDID 17; SYSPATH $UDID 17` (AC-2: `same`; `SEEDCLR` runs first, NB8; a DIFF confined to rows < 150 is the status bar, so re-run as `CMPX build/lt/<rt>-light-home-light.png build/lt/<rt>-system-home.png 150` and record it, as in Step 5). For each `LIGHTLIST`
entry run `/design-compare <reference> "reference: build/light-ref/<reference>.png (light-patched render, Step 2; skip the
skill's step 1); app: build/lt/17-light-<name>.png"` (spec issue 3). Deviations to skip = the row's existing spec deviations
(m2-home AC-1, m2-onboarding, m4-missed-day, m4-progress, m4-settings, m4-reminder, m5-haptics, m3 ACs) plus F1 (green / amber
`15803D` / `B45309` where the render has `22c55e` / `f59e0b`) and F2 (`mu` `68646A` vs `6e6a70`). Every shot also passes the
§8 (a)–(f) checklist and the row's "Extra" column (e.g. `wo-start` pill `15803D` on `DEEDE4`, `missed` scrim `6E6D6D`,
`ob1`/`ob5` Peak legend square `B45309`, `settings-restart` dialog light, `haptics-off` off track system gray). Record per
row: matches / differences, in the implementer's report.

### Step 7 — iOS 26.5, Release, full suite, review gate — AC-10, AC-14 (gate), all unit ACs re-run
Verify: `BUILD && TEST; CNT` (17.5, full); `TEST26` → `TEST SUCCEEDED`; `RELEASE` → `BUILD SUCCEEDED`; then (tests clone and
shut the simulator down) `BOOT $UDID26; LIGHTSHOTS $UDID26 26; SYSPATH $UDID26 26` (`same`) and the Step 6 `/design-compare`
pass on `build/lt/26-light-*.png`, noting the 0.20 dim and floating sheets as runtime facts; `DARKCMP 26` once more (still
`same`). Review gate (NB4): `git diff --stat main` names only the three `Contents.json` files; `git status --porcelain`
additionally shows only `HomeGymLogTests/Support/ContrastRatio.swift`, `HomeGymLogTests/Static/ColorsetContrastTests.swift`,
this plan, the spec, `docs/reviews/m5-light-theme-*.md`, `insights/INSIGHTS.md`; `git diff --quiet -- '*.pbxproj' && git status --porcelain -- HomeGymLog | grep -v Contents.json`
prints nothing. `xcrun simctl status_bar $UDID clear; xcrun simctl status_bar $UDID26 clear`.

### Step 8 (optional) — scratch-copy XCUITest for AC-15 and AC-16
Only if the user wants them machine-checked before the MVP pass; skipped cleanly by not doing it. Copy the repo (without
`build/`, `.git`) to the session scratchpad, generate a `HomeGymLogUITests` target into **the copy's** project and give the copy
the bundle id `com.zhabskyi.homegymlog.probe` (as `docs/reviews/m4-settings-researcher.md` Addendum 2026-09-22 did; INSIGHTS
"Real-touch probes"); the repo's `project.pbxproj` is never touched. Test-local helper (declared in the UI-test file):
`func luma(_ app: XCUIApplication, at p: CGVector) -> Double` from `XCUIScreen.main.screenshot().image`'s pixel at the
normalized point. Simulator dark (`APPEAR <udid> dark`), traces:
1. **AC-15** from `-seed midProgram -tab settings` (System stored): assert `luma` of the Settings background < 0.2 (positive dark
   first), tap `app.buttons["Light"]`, assert > 0.8; tap the pills `app.buttons["Home"]`, `"Program"`, `"Progress"` (FloatingTabBar
   labels), sampling each > 0.8; on Home tap `app.buttons["About Lat Pulldown"]` (TodayCard label), assert "Form cues" exists, sample
   the sheet > 0.8, swipe it down; on Settings tap `app.buttons["Missed a day"]` (by type, gotchas 2026-09-22), assert the menu item
   "Always shift" exists, sample, dismiss; tap "Build a new program…", assert the dialog's "Cancel" exists, sample, tap Cancel; tap
   `"System"`, assert the Settings sample < 0.2 again. Discard alert: relaunch `-seed wo-rpe -appearance light` (a set is logged and
   the RPE card replaces only the bottom bar, so the header's Exit is visible and `exitTapped` raises the alert; `wo-start` has no
   logged set and would discard at once), tap `app.buttons["Exit"]`, assert `app.alerts.firstMatch` exists, sample it > 0.8, tap Cancel.
2. **AC-16** from `-seed wo-detail -appearance light`: assert "Notes" exists, tap `app.textViews.firstMatch`; if
   `app.keyboards.firstMatch.waitForExistence(timeout: 3)` is false, report `DATA no software keyboard (hardware keyboard
   connected)` and skip; else sample the keyboard area and report its `luma` as `DATA` (light > 0.6 passes; dark is a follow-up,
   not this slice).
Report pass / DATA per AC; uninstall the probe bundle and runner from both simulators; repo `git status` unchanged.

## 4. Data model changes
**None.** No `@Model`, field, relationship, delete rule, `#Predicate` or store writer; no preference or seed. The three
`Contents.json` files are design constants resolved at draw time. No migration impact, so no persistence test is required.

## 5. Risks and gotchas
| Risk | Mitigation |
|---|---|
| Baselines taken after the edit make AC-9 vacuous (B1) | Step 1 refuses to shoot unless `git diff --quiet -- HomeGymLog/Assets.xcassets`; Step 5 compares, never re-baselines |
| An "Any + Dark" set compiled by actool resolves Dark differently from today's single entry (unverified; the only runtime claim) | AC-9 `DARKCMP` on 17.5 and 26.5 over shots that draw green and amber (`home`, `program`, `progress`, `missed`, `summary`); stop on any diff |
| Stale `seed` suite after an `-appearance light` launch (gotchas 2026-09-22) | `SEEDCLR` before every launch in `DARKSHOTS`, `LIGHTSHOTS`, `SYSPATH` (NB8) |
| Home-indicator fade / status-bar clock break byte compares | `BOOT` pins 9:41; `SHOT` waits a fixed 3 s; `CMPX` skips the bottom 60 rows; a status-bar-only 26.5 diff → `CMPX … 150`, recorded |
| Transposed or off-page `sips` crops (m4-settings, m4-progress) | Crops copied verbatim from the skill in h w / y x order, probed on the patched render; Step 2 reads all 20 |
| Headless Chrome renders a blank page before the server answers (gotchas 2026-09-13) | `SERVE` polls with `curl`; `pkill -f "http.server 876"` after |
| The patch site moves in a re-exported design | `patch_light.py` asserts exactly one site and prints its entry id |
| `success` on light `bg` 4.5001 sits on the threshold (spec issue 2) | Compare unrounded `Double`s; the planner's recompute matches the review's |
| Xcode's color inspector rewrites components as decimals | Loud parser (NB1) fails naming the file; edit the JSON by hand, not in the inspector |
| `xcodebuild test` clones and shuts down the simulator; `-only-testing` hang; `…/function()` runs 0 tests | `BOOT` again after every test run; `WONLY` watchdog; select the suite only |
| Hosted `Bundle.main` has `Assets.car`, not JSON | Suite reads the source tree via `FeedbackSourceTests.appSourceRoot` (doc comment says why) |
| `UIColor(named:)` / `.preferredColorScheme` sneaking in later | `hardCodedColorPaths` asserts both `[]` |

## 6. Definition of done
- [ ] `ColorsetContrastTests` green; full suite green on iPhone 15 / iOS 17.5 and iPhone 17 / iOS 26.5; Release build green.
- [ ] `git diff --stat main`: only `success`, `warning`, `mu` `Contents.json`; no `.swift` under `HomeGymLog/`; `project.pbxproj` untouched.
- [ ] Dark: `DARKCMP 17` and `DARKCMP 26` print `same` for all seven shots.
- [ ] Simulator dark, `-seed midProgram -appearance light` matches `home-light` except F1 (week-strip ✓ `15803D`) and F2;
      simulator light with plain `-seed midProgram` is identical (System path), on both runtimes.
- [ ] Every `LIGHTLIST` shot on both runtimes matches its light reference with only listed deviations and passes (a)–(f):
      greens `15803D`, ambers `B45309`, cards white, scrim over the light shell, tab bar white with its shadow, dark status bar.
- [ ] By hand (MVP pass): AC-15 (Settings → Light on a dark phone: every tab, ⓘ sheets, menu, dialog, alert light; System and
      Dark revert, an open sheet too), AC-16 (note-editor keyboard light), AC-17 (outdoor legibility of the darker greens/ambers).

# Swift review — m5-light-theme (2026-09-27)

**Verdict: ship.** No significant finding. Three low, optional observations below.

Scope reviewed: `git diff main...HEAD` (docs only), uncommitted `git diff` (three `Contents.json` under
`HomeGymLog/Assets.xcassets/`, spec, INSIGHTS, gotchas), untracked `HomeGymLogTests/Static/ColorsetContrastTests.swift`
and `HomeGymLogTests/Support/ContrastRatio.swift`. No app Swift changed. `xcodebuild` was not run (test-writer building in
parallel); the two result bundles `build/tests.xcresult` (iPhone 15 / 17.5) and `build/tests26.xcresult` (iPhone 17 / 26.5)
were read instead: 1093 passed, 0 failed on each, and all 13 `ColorsetContrastTests` nodes are present and `Passed`.
Release-only risk: none — the slice adds no Swift to the app target, so there is nothing a `#if DEBUG` guard could hide.

## Colorset JSON

`success`, `warning`: base entry (`idiom: universal`, no `appearances`, `color-space: srgb`, `0xRR` components,
`alpha: "1.000"`) followed by an entry with `appearances: [{"appearance": "luminosity", "value": "dark"}]`. `mu`: base
entry's three channels changed only. This is byte-for-byte the shape the existing `bg`, `sf`, `sf2`, `tx`, `bd`
colorsets already use (Any + Dark), so Xcode's `actool` resolves them the same way; the implementer's 14 byte-identical
Dark baselines confirm the dark entry still wins under the dark trait. Values match spec §2.2 "After": `15803D`, `B45309`,
`68646A`, dark `22C55E` / `F59E0B` / `8F8B91`.

## Tests: loud, correct, non-vacuous

- **Can they fail?** Yes. Recomputed independently (Python, WCAG 2.1 formulas): with the pre-slice values, light `mu` on
  `sf2` is 4.36 (< 4.5) and light `success` on `bg` is 2.04, so `contrastFloors` fails on the old catalog; `afterHex` and
  `themedSetsHaveDark` fail on a single-entry `success`. The plan's Step 4 recorded that red run.
- **Unrounded comparison.** `contrastFloors` compares the raw `Double` (`ratio >= floor`); light `success` on `bg` is
  4.5001 and passes; the tolerance-based `ratioAnchors` (±0.01) checks only the helper against the spec's worked values,
  never a floor. Recomputed: 18.0086, 2.2786, 5.0156, 21.0; blends `6E6D6D`, `DEEDE4`; pill over `bg` `D5E2DA`, 3.7546.
- **Parser is loud.** Every component must be a 4-character `"0xRR"` string; a decimal (Xcode's inspector rewrite), a
  missing key, an extra key, or a non-`"1.000"` / `"0.080"` alpha fails through `#require` naming the set and key. No
  `?? 0` anywhere. `Decodable` mirrors fail on a missing `idiom` / `color` / `color-space`.
- **`#filePath` resolution.** Reuses `FeedbackSourceTests.appSourceRoot` (three `deletingLastPathComponent()` from
  `Static/`), the same walk four existing static suites use. Robust wherever the checkout is, since `#filePath` is baked
  at compile time; the only way it breaks is moving the repo between build and run, which also breaks the existing suites.
  The Support helper computes no path (NB2), as the plan required.
- **Shape checks are independent.** `appearanceShape` asserts a non-base entry's `appearances` is exactly the
  luminosity-dark pair, so `Entry.isDark = appearances != nil` (which would also be true for a `contrast: high` entry)
  cannot silently misclassify: that entry would fail `appearanceShape` first.

## Observations (low, optional; none applied)

1. `HomeGymLogTests/Static/ColorsetContrastTests.swift:58-59` — `try #require(try? …)` converts the thrown error to
   `nil`, so a decode failure reports `"<set>: JSON shape"` and drops the `DecodingError`'s key path (which key, which
   index). Still loud and names the set; only the diagnosis detail is lost. Fix, if wanted:
   ```swift
   let data = try Data(contentsOf: file)                       // the thrown error names the path
   let decoded: ColorsetJSON
   do { decoded = try JSONDecoder().decode(ColorsetJSON.self, from: data) }
   catch { Issue.record("\(name): \(error)"); throw error }
   ```
   (React mapping: `try?` is `.catch(() => null)`; `#require` on the `nil` is then `expect(x).not.toBeNull()` with the
   original error gone.) The `Issue.record` + rethrow path is **unverified** on this project; the proof is a one-off run
   with a deliberately broken `Contents.json` on both 17.5 and 26.5, reading the failure message in the result bundle.
2. `ColorsetContrastTests.swift:255-256` — the AC-14 tokens `.primary` and `.secondary` also match SwiftUI's toolbar
   placements `.primaryAction` / `.secondaryAction`, which are not colors. A future `ToolbarItem(placement:
   .primaryAction)` would fail the test with a message that does not explain why. The `.black` row already carries such a
   note (`.fontWeight(.black)`); add the same for these two, or tighten the tokens to `.primary)` / `.secondary)` and
   `foregroundStyle(.primary`. Not a bug today (both lists are `[]` and the scan agrees).
3. `ColorsetContrastTests.swift:200-206` — light `success` on `bg` is 4.5001 against a 4.5 floor, so a one-unit darkening
   of `bg` (`F4F2F3` → `F3F2F3`) or any re-rounding of `15803D` flips it. That is the guard the test exists for, and the
   failure message prints the ratio; a future editor should know the margin is 0.0001 rather than treat the failure as a
   helper bug. Recording it here is enough; no code change proposed.

## Not findings (checked and fine)

- `RGB: ExpressibleByStringLiteral` trapping on a malformed literal: spec AC-11 asked for it; literals exist only in test
  source, and colorset data never reaches this init. Acceptable in a test helper.
- `themeNamesMatchColorsets` asserts `found.count == 11` (a bare count): AC-13 specifies the 11 explicitly and the path
  check beside it is the real gate.
- `RGB` is a generic name in the test module, but `ColorsetContrastTests.swift` does not `@testable import HomeGymLog`
  and the app target declares no `RGB`, so no ambiguity exists.
- WCAG linearisation threshold 0.03928 (vs the 0.04045 errata): no channel in any of the 19 entries lies between
  10 and 10.3/255, so both give identical results here.
- `contentsOfDirectory` + `pathExtension == "colorset"` skips `AppIcon.appiconset` and the root `Contents.json`.

## Machine-checked facts I relied on (from the caller and the result bundles)

1093/1093 on iOS 17.5 and 26.5 (`build/tests.xcresult`, `build/tests26.xcresult`, both `"result": "Passed"`); Debug and
Release green today per the implementer; 14 Dark baselines byte-identical (26.5 first-shot Dynamic Island skip recorded in
gotchas 2026-09-25); 34 Light screens per runtime compared by hand. User-run remaining: AC-15 open-sheet half, AC-17
VoiceOver.

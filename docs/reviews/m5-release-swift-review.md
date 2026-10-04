# m5-release — Swift review (2026-10-04)

**Verdict: ship.** No data-loss, crash, logic or SwiftUI-state finding. Five low notes, none blocking; two are optional
code tidy-ups, two are tooling hardening, one is a test that could pin more than it does. The implementer's deviation D4
(a 1 px shift in the Settings regression shot) is sub-pixel text snapping, not a layout change — confirmed below.

Reviewed: `git diff HEAD` plus the untracked files under `HomeGymLog/`, `HomeGymLogTests/`, `docs/tools/`, `docs/release/`,
against `docs/specs/m5-release.md` (§2.1, §2.2, §2.7, §4.2, §5.1–§5.9, AC-4–AC-16), `docs/plans/m5-release.md` (Steps 1–8),
`docs/reviews/m5-release-architecture.md` (B-1–B-3, NB-1–NB-6), CLAUDE.md, `.claude/skills/swift-best-practices/SKILL.md`,
`insights/INSIGHTS.md` (2026-10-03 release decisions) and `insights/gotchas.md`.

## What was verified (commands run by the reviewer)

| Check | Result |
|---|---|
| Release build, shared DerivedData (the CLAUDE.md command) | `BUILD SUCCEEDED`, 0 `warning:` — but **0 Swift compiles** (incremental; the gotcha of 2026-10-03 says this count is meaningless) |
| Release build, **clean** scratch DerivedData (`/private/tmp/…/scratchpad/DerivedData`, deleted afterwards) | full recompile (app, shared, widgets, intents metadata), `BUILD SUCCEEDED`, **0 `warning:`** → AC-15 / U11 hold |
| Clean Release product | `PrivacyInfo.xcprivacy` at the bundle root, byte-equal to source; `UILaunchScreen → UIColorName = bg`; `ITSAppUsesNonExemptEncryption = false`; `UISupportedInterfaceOrientations = [Portrait]`; `CFBundleShortVersionString 1.0` / `CFBundleVersion 1`; appex keeps `com.apple.widgetkit-extension` |
| Targeted tests on iPhone 15 / 17.5 (scratch DerivedData): `ReleaseBundleTests`, `ReleaseAssetTests`, `ReleaseCopyTests`, `ReleaseProjectTests`, `StoreMetadataTests`, `SettingsScreenSourceTests`, `SettingsSourceTests`, `ProgramGeneratorTests`, `OnboardingDraftTests`, `ColorsetContrastTests`, `RestartPrefillTests`, `RestartPrefillEdgeTests`, `WorkoutSetWriterEdgeTests` | `TEST SUCCEEDED` |
| `PrivacyInfo.xcprivacy` | the four keys of spec §5.3 exactly: tracking `false`, two empty arrays, one `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` |
| `AppIcon.appiconset/Contents.json` | three `universal`/`ios`/`1024x1024` entries with filenames; dark and tinted carry `luminosity` appearances; the ten `mac` entries gone |
| The three PNGs (IHDR) | 1024 × 1024; Light colour type 2 (RGB, no alpha), Dark and Tinted type 6 (RGBA) — matches §5.1 |
| `WelcomeTile.imageset` | `Contents.json` one `universal` image, `preserves-vector-representation: true`; `WelcomeTile.svg` byte-equal to `design/icon/HomeGymLog-icon.svg` (`cmp` silent), rect-only, `#E11D48` field |
| `docs/release/app-store-metadata.md` fenced blocks | one each; name 10, subtitle 30, promotional-text 165, keywords 98 bytes, description 1 518 scalars (spec §5.5) |
| `docs/release/screenshots/` | exactly 5 files, each 1320 × 2868, colour type 2 (RGB); `01-home` shows "Good afternoon", the Pull card and 9:41; `03-rest` shows "1:02" and "Next: set 2 of 3" |
| `Link(` whole-token grep over `HomeGymLog/` | one hit, `Features/Settings/AboutRows.swift:11`; `Image("` / `Image(decorative:` one hit, `WelcomeStep.swift:10` |
| `HomeGymLogSupport/Info.plist` | two keys, as spec §5.4 |

## Focus items from the brief

1. **The six concurrency-warning fixes.** `ProgramGenerator.swift:63–64` adds `static let bodyWeightRangeLb = 50.0...500.0`
   beside the three other input bounds (nonisolated enum, `ClosedRange<Double>` is Sendable). `RestartPrefill.swift:31–32`
   reads it; `grep OnboardingDraft HomeGymLog/Engine/` is empty, so Engine no longer names a Features type (B-1).
   `OnboardingDraft.swift:33` forwards through a computed `static var`, so `OnboardingDraft.swift:96` (`Self.bodyWeightRangeLb`)
   and every test caller compile unchanged; the value is pinned twice (`ProgramGeneratorTests`, `OnboardingDraftTests`,
   the latter in a `@MainActor` suite as the main-actor class requires). `WorkoutView.swift:91`, `WorkoutLogStore.swift:220`,
   `:288`, `:291` take the closure form `{ f($0) }` — the exact shape of the `WorkoutLogStore.swift:324` precedent; no
   `nonisolated`, `nonisolated(unsafe)` or `@preconcurrency` anywhere in the diff; `guard !sets.contains(where: { awaitsRating($0) })`
   is the same predicate as before, only no longer an unapplied main-actor reference. Behaviour unchanged by construction.
   React mapping: passing `SetSnapshot.init` to `map` is like handing a method reference that closes over a store to a worker
   thread; wrapping it in `{ SetSnapshot($0) }` keeps the call on the thread the compiler can see.
2. **ABOUT card.** `AboutRows.swift:11–20`: `Link(destination:)` with the visible text as its only label, so the accessibility
   label is the visible text; the link trait is the control's own. `.buttonStyle(.plain)`, 15 pt semibold accent, 16/13 padding,
   `.contentShape(Rectangle())`, no trailing glyph — identical to `ReminderActionRow` and the restart row. `SettingsContent.swift:49–50`
   appends header + card after `backupCard`; `:112–124` three rows, two `SettingsDivider()`s (12 total, pinned); the Version row reuses
   `SettingsValueRow` (one combined element with label and value). `bottomPadding` and its `.padding(.bottom, …)` unchanged and
   now pinned by `ReleaseCopyTests.bottomPaddingKept`. `SettingsText.swift:45–46`: `URL(string:)!` on literals only, the
   `RestActivityCenter.settingsURL` / `ReminderPermission.settingsURL` precedent, both `absoluteString`s pinned. `versionText`
   (`:49–52`) is total: `guard let … !isEmpty` on both inputs, else U+2014.
3. **`WelcomeStep.swift:10`.** `Image(decorative: "WelcomeTile").resizable().scaledToFit().frame(width: 44, height: 44)
   .clipShape(RoundedRectangle(cornerRadius: 12))` — modifier order is right (`resizable` before the frame), the slot and radius
   are today's, `Color.white` has left the file and no test pinned it (`hardCodedColorSites` has no `Color.white` token).
4. **Tests.** The URL scans read raw lines (`ReleaseCopyTests.rawFiles`, skipping only whole-line `//` comments), so `https://`
   survives — correct, and the one-line-per-literal pin would be impossible through `codeLines`. The `Link(` scan uses ICU via
   `range(of:options: .regularExpression)` with `(?<![A-Za-z])Link\(`; `ShareLink(` and `NavigationLink(` are not hits, the
   gotcha for Swift `Regex`'s missing lookbehind is recorded. No `try` inside `#expect` in the five new files. Isolation: the only
   main-actor reads are `SettingsText` (test marked `@MainActor`) and `UIImage`/`Bundle` (suite marked `@MainActor`); everything
   else is file I/O. No tautologies: `iconSlots`, `iconPixels`, `tileIsByteCopy`, `urlLiteralHome`, `portraitOnly`, `infoPlistFiles`
   all fail on the pre-slice tree (the plan's red-first runs), and the metadata checker has a control that produces exactly three
   named violations. The two smoke floors the implementer flagged — `engine.count > 10` (Engine has 30 files) and `all.count > 500`
   (`project.pbxproj` has 702 lines) — are "the walk found the folder" guards, not pins; acceptable as written (see L-3 for the
   stronger scan that test could carry).
5. **Tooling.** `make-app-icon.py` writes exactly the four named outputs, intermediates in `tempfile.mkdtemp()` removed in
   `finally`, exits with a message when `rsvg-convert` is missing or the dark field rect count is not 1, and `check=True` turns a
   render failure into a non-zero exit. `make-store-screenshots.sh`: `set -euo pipefail`, `mktemp -d`, one `trap … EXIT` that removes
   the temp dir and clears the status bar, writes only `docs/release/screenshots/NN-name.png`. Nothing new under `HomeGymLog/`
   beyond the manifest, the three PNGs and the one SVG (`nonSwiftResources` / `onlyTileSVG` pin that). See L-1 / L-2 for hardening.
6. **Manifest and catalogs.** Exact (table above).
7. **Data loss / crash.** None. The slice writes no state, touches no model, relationship or preference. The only new force
   unwraps are the two URL literals (static, pinned by `absoluteString`); `info?["…"] as? String` is nil-safe and feeds a total
   function.

## D4 — the 1 px shift in the `settings` regression shot

**Plausible, and acceptable; not a layout change.** I re-ran the project's `build/light-cmpx.py` on the implementer's
`build/shot-rel-base-settings.png` vs `shot-rel-s5-settings.png` (and `s9`): 82 differing rows in five bands, columns
114–119 at rows 419–452 (the "A" of Appearance), 134–165 at 458–459, 582–1008 at rows 1613–1652 (the "6-month program · 5 days"
value), and 956–1080 at rows 2282–2291 (text under the translucent pill). Then a column-restricted shift test: inside the first
two bands **every row of the new shot equals the baseline one row higher (65/65 and 70/70 rows)**; the third band matches only
partly because the pill's blur mixes neighbouring pixels. No divider, card edge or other text run differs anywhere.

Why that is snapping and not layout: 1 px on a 3× display is 1/3 pt. Every layout constant in `SettingsContent` and its rows
is a whole point (8, 13, 16, 18, 22, `FloatingTabBar.height + 16`), so no padding or spacing change can move anything by 1/3 pt,
and a real layout change would move the card backgrounds and hairlines (which are pixel-aligned rects) by ≥ 3 px as well. What
changed is the scroll content's total height; SwiftUI resolves each `Text`'s fractional frame origin against the content's
rounded size, and three runs whose origins sat near a rounding boundary flipped. The shot is deterministic (reshoot and `s9`
identical), so the only consequence is that the `settings` baseline for future `/design-compare` runs is the new file. Nothing in
the view needs attention; AC-20's max-scroll device check covers the card itself.

## Findings (none blocking)

### L-1 — `docs/tools/make-store-screenshots.sh:32,50` — the screenshot's error text is swallowed

`xcrun simctl io "$UDID" screenshot "$TMP/shot.png" >/dev/null 2>&1`: under `set -e` a failed shot still aborts the run
(non-zero), but the only thing printed is the trap's `status_bar clear`, so a user sees a silent exit. "Fail loudly" wants the
reason. Fix: keep stdout quiet, let stderr through, and tolerate only the throwaway shot:

```bash
xcrun simctl io "$UDID" screenshot "$TMP/throwaway.png" >/dev/null 2>&1 || true   # line 32: warm-up only
xcrun simctl io "$UDID" screenshot "$TMP/shot.png" >/dev/null                      # line 50: stderr stays visible
```

### L-2 — `docs/tools/make-app-icon.py:62–65` — outputs are written in place, not atomically

Each `rsvg-convert` writes straight into `AppIcon.appiconset/`; if the second or third render fails, the catalog holds one new
PNG and two old ones (or a 0-byte file), and `git status` is the only tell. actool would fail a broken PNG loudly, so nothing
ships wrong, but the four-file set is no longer consistent. Fix: render into `tmp`, then move all four at the end:

```python
out = {name: os.path.join(tmp, name) for name in ("AppIcon-Light.png", "AppIcon-Dark.png", "AppIcon-Tinted.png")}
render(..., out["AppIcon-Light.png"], ACCENT); render(dark_path, out["AppIcon-Dark.png"]); render(..., out["AppIcon-Tinted.png"])
for name, path in out.items():
    shutil.move(path, os.path.join(ICON_SET, name))
shutil.copyfile(os.path.join(ICON, "HomeGymLog-icon.svg"), TILE)
```
Byte-determinism (AC-18's `shasum` rerun) is unaffected.

### L-3 — `HomeGymLogTests/Engine/ProgramGeneratorTests.swift:243–249` — the B-1 scan pins one name, not the rule

`engineNamesNoFeaturesType` greps Engine for the literal `OnboardingDraft`. The decision recorded in INSIGHTS is "Engine never
references a `Features/` type"; a future `Engine/Foo.swift` that reaches for `SettingsContent` or `WorkoutView` passes this test.
A stronger version collects the type names declared under `Features/` and checks none appears in an Engine code line:

```swift
let features = try FeedbackSourceTests.appFiles().filter { $0.path.hasPrefix("Features/") }
let declared = Set(features.flatMap { file in file.lines.compactMap { line -> String? in
    let words = line.split(separator: " ")
    guard let i = words.firstIndex(where: { ["struct", "class", "enum", "actor"].contains($0) }), i + 1 < words.count else { return nil }
    return String(words[i + 1].prefix { $0.isLetter || $0.isNumber })
} })
let hits = engine.filter { file in file.lines.contains { line in declared.contains { line.contains($0) } } }.map(\.path)
#expect(hits == [])
```
**Unverified** on this tree (a Features type name that is also an English word in an Engine comment would be a false hit;
`codeLines` strips `//` comments, so only string literals could collide). The proving run is `-only-testing:HomeGymLogTests/ProgramGeneratorTests`
on both 17.5 and 26.5. Optional; the current test already proves the one regression the slice fixed cannot return.

### L-4 — `Features/Settings/AboutRows.swift:12–18` — third copy of the accent action-label chain

The six-modifier label (15 pt semibold, `Theme.accent`, leading full width, 16/13 padding, `contentShape`) now lives in
`ReminderActionRow` (`ReminderRows.swift:56–62`), the restart `Button` (`SettingsContent.swift:91–97`) and here. A newcomer
reading the three has to diff them to learn they are the same row. Optional extraction, no behaviour change:

```swift
/// The accent action label every Settings action row shares (restart, Allow notifications, the ABOUT links).
struct SettingsActionLabel: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
    }
}
// AboutLinkRow: Link(destination: url) { SettingsActionLabel(title: title) }.buttonStyle(.plain)
```
React analogy: three JSX call sites repeating the same `className` string instead of one `<ActionLabel>` component. If taken,
`SettingsScreenSourceTests.noLiteralCopy` and `.rowAccessibilityShape` stay green (no literal, same element tree) but
`/design-compare settings` should be re-run for the two rows above the fold. Not needed for this slice.

### L-5 — `AboutRows.swift:4–5` — the "link" trait claim rests on the user's AC-20 device check

The doc comment states VoiceOver reads "Privacy policy, link" because `Link` carries the trait. That is SwiftUI's documented
behaviour (XCUITest finds a SwiftUI `Link` under `app.links`), and no probe in `docs/reviews/m5-release-*.md` recorded it on
either runtime, so it is **unverified** here. It is already the user's AC-20; if a device ever reads "button", the one-line
fallback is `.accessibilityAddTraits(.isLink)` on the `Link`. The scratch-copy XCUITest that would settle it on both runtimes:
`-seed midProgram -tab settings`, swipe up to the end, `#expect(app.links["Privacy policy"].exists)`. No change requested.

## Checks requested by the brief with no finding

- No `#if DEBUG`-only type is referenced outside its guard (the clean Release build compiled every target with 0 warnings).
- No `@State` holding a model, no timer, no `.task`, no sheet boolean was added; the ABOUT card has no state.
- `SettingsContent.swift:124` `private var info` reads `Bundle.main.infoDictionary` on each body evaluation — a cached
  dictionary, not I/O; fine.
- `insights/gotchas.md` gains two accurate entries (Swift `Regex` lookbehind; the 1 px snapping tell). Neither contradicts an
  earlier entry.
- `docs/release/privacy-policy.md` / `support.md` carry Jekyll front matter (byte copies of the site, as the plan chose) and the
  contact email; `release-checklist.md` records the fetched commit.
- The implementer-noted D4 is recorded in gotchas with the right recognition rule ("match the baseline when shifted by one row").

## Note for the ship-check

The CLAUDE.md Release command against the shared `build/DerivedData` compiled nothing on this tree and printed 0 warnings for
that reason alone. The 0 reported above came from a clean scratch DerivedData with every Swift module recompiled. Any future
"0 warnings" gate should either clean first or confirm `SwiftCompile normal` lines are present in the log (the gotcha of
2026-10-03 already says so).

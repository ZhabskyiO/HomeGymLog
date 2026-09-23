# m4-settings researcher: Appearance override (System / Dark / Light)

**Direct answer:** Do not drive the Appearance setting with `.preferredColorScheme(_:)`; set `overrideUserInterfaceStyle` on
the scene's `UIWindow`s from `RootView` (`onAppear` + `onChange(of:)` of the `@AppStorage("appearance")` value, ~12 lines).
The SwiftUI modifier reverts the root correctly on 17.5 and 26.5, but on 17.5 `.alert` and `.confirmationDialog` ignore it
entirely (the workout's Exit alert would render light while the app is dark), and on both runtimes an already-presented
sheet keeps the scheme it was presented with. The window override follows and reverts everywhere probed, with no light
frame at cold launch.

Verified 2026-09-22 with Xcode 27.0 (27A266a), iOS 17.5 iPhone 15 and iOS 26.5 iPhone 17 simulators, a scratch copy of the
app (bundle id changed, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), the probe living in the **app
target** (a DEBUG `AppearanceProbeHost` wrapped around `RootView` in the copy's `HomeGymLogApp`, driven by a timed
`-appearanceScript` so no taps). Simulator system appearance was **light** for every run, so "nil = System" is visible as a
revert to light. Nothing under the real repo was modified; probe bundles were uninstalled afterwards.

## Q1 — Does `.preferredColorScheme(nil)` revert at runtime? Alternative and its cost

**Verdict:** The root reverts on both runtimes; presentations do not. Use the UIKit window override.

Evidence (SwiftUI modifier on the WindowGroup content, i.e. around `RootView`):

| Case | 17.5 | 26.5 |
|---|---|---|
| Root dark → nil → light → nil (`midProgram`) | reverts each step, status bar follows | same |
| Sheet already open when root goes dark → nil (`wo-detail`, the real detail sheet) | sheet **stays dark** (screen behind goes light) | **stays dark** |
| Sheet open, root dark → light | sheet **stays dark** | **stays dark** |
| Sheet presented while dark, then nil, with `.preferredColorScheme(scheme)` repeated inside the sheet content | still **stays dark** | still **stays dark** |
| `.confirmationDialog` presented while root is dark | **light** (ignores the override) | dark, and reverts to light after nil |
| `.alert` presented while root is dark | **light** (ignores the override) | dark, and reverts after nil |
| Missed-day overlay (`missed` seed, `.overlay` on `ShellView`) | follows both ways | follows both ways |

Mechanism seen in the logs: SwiftUI implements the modifier by setting `overrideUserInterfaceStyle` on the root
`UIHostingController` (the `UIWindow` stays `unspecified` on 17.5; on 26.5 the window's trait follows too). A
`PresentationHostingController` gets its own override copied at presentation time and is never updated afterwards, which is
the stuck-sheet behaviour. On 17.5 the `PlatformAlertController` gets nothing (trait stays system).

Same steps with `window.overrideUserInterfaceStyle` on every window of the connected `UIWindowScene`s:

| Case | 17.5 | 26.5 |
|---|---|---|
| Root dark → nil → dark → nil | follows, reverts | follows, reverts |
| `.confirmationDialog` open across dark → nil | dark, then light | dark, then light (screenshot at +1.5 s; the VC's `traitCollection` read at +0.6 s still said dark, so read screenshots, not traits, for dialogs) |
| `.alert` open across dark → nil | dark, then light | dark, then light |
| Sheet presented while dark, then nil | dark, then light | dark, then light |
| `@Environment(\.colorScheme)` in SwiftUI views | changes (logged `env changed -> dark/light`) | changes |
| Cold launch, system light, stored Dark, override applied synchronously in the root's `onAppear` | first content frame is already dark; the only light frames are the white launch screen cross-fading into the dark Home (frames at 2.367–2.5 s inspected at full resolution) | luminance timeline has the same shape (white launch screen → 0.15 s fade → dark, no light plateau); frames not inspected individually |

Cost of the alternative: one `import UIKit`, one enum, one `applyAppearance()` of ~6 lines called from `onAppear` and
`onChange`. No delegate, no representable, no capability. `UIApplication.shared.connectedScenes` is main-actor; the project's
`MainActor` default isolation makes the call legal from a view without annotation.

Historical bug, for the record: Apple's iOS 18.1 release notes, SwiftUI Resolved Issues: "On iOS 18.0, there is a known issue
where passing `nil` to the `.preferredColorScheme` modifier, after the preferred color scheme is set by a different view in
the hierarchy, does not trigger the system color scheme to change. Starting in iOS 18.1 … uses the system color scheme.
(133689390) (FB14768320)". So the root-level nil bug is 18.0 only (not 17.x, fixed in 18.1); the user's iPhone 14 Pro Max is
not on 18.0 as far as this project knows (unverified). The presentation behaviour above is separate from that bug.

Availability: `preferredColorScheme(_:)` iOS 13.0; `UIView.overrideUserInterfaceStyle` iOS 13.0; `onChange(of:) { }`
(zero-parameter) iOS 17.0. Nothing needs `#available`. No entitlement, capability, or privacy-label impact; UserDefaults
storage is not "data collected".

Sources:
- https://developer.apple.com/documentation/swiftui/view/preferredcolorscheme(_:) — "nearest enclosing presentation, like
  a popover, a sheet, or a window"; "Pass nil to indicate that there is no preferred color scheme".
- https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18_1-release-notes — quoted above.
- https://developer.apple.com/forums/thread/765029 and https://developer.apple.com/forums/thread/763251 — iOS 18.0 reports
  (DTS confirmed the 18.1 fix in the first).
- https://www.hackingwithswift.com/forums/swiftui/preferredcolorscheme-not-affecting-datepicker-and-confirmationdialog/11796
  — blog-tier; the only prior description of UIKit-backed presentations ignoring the modifier. Apple's docs are silent on it;
  the probe above is the primary evidence.

### Code (compiles against iOS 17; the key name `"appearance"` is the brief's placeholder, keep whatever the spec fixes)

```swift
// Shared/Appearance.swift
import UIKit

enum Appearance: String, CaseIterable {
    case system, dark, light

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// RootView.swift — below `.defaultAppStorage(defaults)`, so the seed suite and a `-appearance` launch argument are honoured
@AppStorage("appearance") private var appearanceRaw = Appearance.system.rawValue

var body: some View {
    Group { /* existing routes */ }
        .onAppear(perform: applyAppearance)              // first frame is already styled (verified, cold launch)
        .onChange(of: appearanceRaw) { applyAppearance() } // ≈ useEffect(..., [appearance])
}

private func applyAppearance() {
    let style = (Appearance(rawValue: appearanceRaw) ?? .system).interfaceStyle
    for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
        for window in scene.windows { window.overrideUserInterfaceStyle = style }
    }
}
```

React analogy: `.preferredColorScheme` is a `data-theme` attribute on one subtree that portals (sheets, alerts) do not
re-read; `overrideUserInterfaceStyle` on the window is setting it on `<html>`.

Unverified: keyboard appearance under the window override (no seed focuses a text field; the keyboard window appeared in the
logs only when an alert showed). The 26.5 cold-launch frames were classified by luminance only.

## Q2 — Where the modifier sits; do sheets need it repeated?

**Verdict:** With the window override, placement is irrelevant to inheritance: sheets, alerts, confirmation dialogs and the
missed-day overlay all live in the same `UIWindow` and follow, nothing is repeated. `applyAppearance` must run where the
`@AppStorage` reader sees the right suite: `RootView` (below `.defaultAppStorage`) like `units`, not `HomeGymLogApp`.
If the SwiftUI modifier were used anyway: once, on the WindowGroup's content (the preference climbs to the window from any of
`RootView`'s branches); repeating it inside sheet content does **not** fix the stuck sheet (probed, both runtimes), and
nothing fixes 17.5 alerts and dialogs.

## Q3 — Do the asset-catalog colors follow?

**Verdict:** Yes. `Theme.swift` resolves every color as `Color("name")` and the app target has no `UIColor` /
`Color(uiColor:)` anywhere (grep); `Color("bg")` swatches followed every switch under both mechanisms on both runtimes, as
did the phase/accent colors on Home, Progress and the detail sheet. Gotcha for future code: a `UIColor(named:)` resolved
**outside a view body** (`.cgColor`, `resolvedColor(with: .current)`) stayed at the system value (`F4F2F3`) under every
override on 17.5 and under the window override on 26.5; only `resolvedColor(with: window.traitCollection)` followed the
window override. `Color(uiColor: UIColor(named:))` written inside a body followed. Keep colors as SwiftUI `Color`.

## Q4 — Swift Charts and the status bar

**Verdict:** Both follow. `progress-history -tab progress` under a dark override on a light system: chart line, axis labels
and grid rendered dark-mode on 17.5 and 26.5, reverted with nil. Status bar text went white under dark (SwiftUI modifier:
`statusBarStyle` reads `lightContent`; window override: reads `default` but renders white, screenshot-verified on both) and
black again on revert. The project's `UIStatusBarStyle = Default` needs no change.

## Q5 — `xcrun simctl ui <udid> appearance` vs the in-app override

**Verdict:** `simctl ui appearance` sets the *system* appearance. The app follows it live only while its stored value is
System (both mechanisms, both runtimes: `env changed` logged on each toggle); with Dark or Light stored, toggling the
simulator changes nothing in the app. Consequences for `/design-compare`:
- `settings` and every dark snapshot: unchanged recipe (seed suite is throwaway → System, `simctl ui appearance dark`).
- A light snapshot: `simctl ui appearance light` with System, or `-appearance light` after the seed argument (same
  NSArgumentDomain mechanism as `-units kg`; the specific key is unverified until it exists).
- The status-bar clock override and the appearance persist per simulator across launches; `status_bar clear` and
  `ui appearance dark` before a byte-compare.
- A stored Dark on a light simulator shows no light frame at launch (Q1), so no "wait for the flip" delay is needed.

## Suggested `insights/gotchas.md` lines

- 2026-09-22 — **`.preferredColorScheme` does not reach UIKit-backed presentations the way the doc implies**: on iOS 17.5
  `.alert` and `.confirmationDialog` render in the system scheme while the app is overridden, and on 17.5 and 26.5 an open
  sheet keeps the scheme it was presented with (repeating the modifier inside the sheet does not help). Appearance is set with
  `overrideUserInterfaceStyle` on the scene's windows from `RootView` instead, which follows and reverts everywhere. Source:
  `docs/reviews/m4-settings-researcher.md` Q1.
- 2026-09-22 — **`UIColor(named:)` resolved outside a view body ignores the app's appearance override** (`.cgColor`,
  `resolvedColor(with: .current)` stayed at the system value on 17.5 and 26.5). Use `Color("name")`; if a `UIColor` is ever
  needed, resolve it against `window.traitCollection`.
- 2026-09-22 — **`xcrun simctl ui appearance` is the system appearance, not the app's**: with Dark or Light stored the app
  ignores it; only System follows it live. Screenshot recipes that toggle it assume the throwaway seed suite (System).
- 2026-09-22 — **A `.task` closure reads `@Environment` values captured at task start**: an env value logged after an `await`
  was stale for the whole run (probe). Read it in `body` or via `onChange`, never after an `await` (≈ a stale closure in
  `useEffect`).

## Suggested `insights/INSIGHTS.md` line

- **Appearance (m4-settings):** `@AppStorage("appearance")` read in `RootView`, applied as `overrideUserInterfaceStyle` on
  every window of the connected scenes in `onAppear` and `onChange`; `.preferredColorScheme` is not used (17.5 alerts and
  dialogs ignore it, open sheets stick). Verified on 17.5 and 26.5, app target, MainActor default isolation.

---

## Addendum 2026-09-22 — follow-up probes for the architecture review (B3 and the four unverified claims)

Same scratch copy and toolchain (Xcode 27.0 27A266a; iPhone 15 / iOS 17.5 `3CAE4D76…`, iPhone 17 / iOS 26.5 `834F0313…`;
app target Debug, Swift 5, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, deployment 17.0). A UI-test target
(`HomeGymLogUITests`, Swift 5, no default isolation, product id `0A20DBBF…` that the shared scheme already references) was
generated into the copy's project file; the repo's `project.pbxproj` is untouched. Taps are XCUITest `tap()` on labelled
elements with an outcome check; `.task` / `onAppear` results come from the app's own log file. Every result below was
identical on both runtimes unless split. Probe bundles and the runner were uninstalled afterwards.

**P1 (B3) — a full-size transparent host root does not intercept touches; nothing needs fixing.** Verdict: pick the
full-size root; no `allowsHitTesting` or `contentShape` work. The copy's `MissedPromptHost` root ran in five shapes on
`-seed midProgram` (host empty): `zstack` (today's zero-sized root), `full` (`.frame(maxWidth: .infinity, maxHeight:
.infinity)`), `banner` (full-size plus a "Probe banner" `Button` in `.overlay(alignment: .top)`, 18 pt side padding, 8 pt
top), `clear` (a `Color.clear` child filling the root, plus the banner) and `nohit` (`.allowsHitTesting(false)` on the
root, banner as the overlay). In all five, on both runtimes: tapping Home's "About Lat Pulldown" opened the info sheet
("Form cues" present), tapping the "Program" pill selected it (`isSelected` true, 24 week-chip buttons listed), and where
the banner existed a tap on it fired its action and removed it. So a transparent `.frame` and even a full-size
`Color.clear` are not hit-testable in SwiftUI without drawn content or a `contentShape`; the banner inside the same host
is, because it draws. Geometry-dependent: banner frame (18, 67, 357 × 44.3) pt on 17.5 / (18, 70, 366 × 44.3) on 26.5,
i.e. top safe area + 8 pt; re-check if the padding or the device changes. React: the container behaves like
`pointer-events: none` for free, and drawn children like `pointer-events: auto`.

**P2 — `.task(id:)` on the host runs at mount while it draws nothing, and re-runs when the id changes.** Verdict: yes.
`.task(id: selected)` on the empty root (`full`, `clear` and `zstack` shapes) logged `host task id=home` on every launch;
with `-tab program` (RootView flips the tab in `onAppear`) it logged `id=home` then `id=program`. Ordering gotcha:
on 17.5 `onAppear` ran before the task, on 26.5 the task ran **before** `onAppear`, so a task keyed on or reading state that
`onAppear` sets (the host's `now`) sees the pre-appear value on 26.5; derive the key from the clock / rows directly (the
host's `now ?? clock.now()` pattern), never from `onAppear`-written state.

**P3 — an `.alert` presented from a `.confirmationDialog` button's action is not dropped.** Verdict: works, same view and
sibling. Dialog on the host with buttons "Alert same" (sets the host's own alert flag) and "Alert sibling" (sets a flag
bound to `.alert` on a sibling view inside the overlay). Both runtimes: the dialog was up, the tap dismissed it, the alert
appeared within 3 s (`app.alerts[title]` existed), OK dismissed it. No `.task` deferral needed.

**P4 — `-appearance` and `-missedDayPolicy` launch arguments override `@AppStorage` under the app's
`.defaultAppStorage(defaults)` for both suites.** Verdict: yes, with the reader below `.defaultAppStorage` (the probe host
is). Read through `@AppStorage("appearance")` / `@AppStorage("missedDayPolicy")` at the root's `.task`:
- seed suite (`-seed midProgram`): no args → `system` / `ask`; `-appearance dark -missedDayPolicy shift` → `dark` / `shift`;
  a stale value written into the `seed` suite beforehand plus the args → `dark` / `shift`.
- standard suite (no seed; `defaults write` stored `light` / `skip` first): no args → `light` / `skip`; with the args →
  `dark` / `shift`; next launch without args → `light` / `skip` again (arguments do not persist).
Same on 17.5 and 26.5. This is the NSArgumentDomain rule: every `UserDefaults` instance consults it first.

Unverified: the spec's real keys will be read in `RootView` / the Settings screen / `MissedPromptHost`; those views are
below `.defaultAppStorage` today, so the result transfers only if that stays true (a reader placed on `HomeGymLogApp`'s
own body, above the modifier, would read `UserDefaults.standard`, not the seed suite).

### Suggested `insights/gotchas.md` lines (addendum)

- 2026-09-22 — **A transparent full-size SwiftUI frame, and even a full-size `Color.clear`, intercept no touch** (17.5,
  26.5): the overlay host's root can be `.frame(maxWidth: .infinity, maxHeight: .infinity)` with a drawn banner in
  `.overlay(alignment: .top)` and Home plus the tab pill stay tappable; only drawn content or a `contentShape` hit-tests.
- 2026-09-22 — **`.task` vs `onAppear` order differs by runtime**: on 17.5 `onAppear` ran first, on 26.5 `.task(id:)` ran
  first on the same view. A task must not depend on state that `onAppear` writes.
- 2026-09-22 — **`xcodebuild test` on a simulator clones the device by default** ("Clone 1 of iPhone 15"): files the app
  writes during the run vanish with the clone and the original simulator is shut down afterwards; pass
  `-parallel-testing-enabled NO` when a probe reads the app's container, and re-`boot` before any `simctl launch`.

# m4-missed-day: platform research (auto-presented prompt, look and coverage, dismissal, sheet interplay)

**Direct answer.** Only a custom scrim + card placed on `ShellView` *above* the `.safeAreaInset` tab bar matches the prototype (0.55 black over everything including the bar, card 44 pt from the bottom edge, present in the very first app frame on both runtimes); it needs no gesture to block touches, and it must own or be handed the "missed" state because Home's `onAppear` does not fire when the app opens on another tab. A system sheet from `HomeView` presents and re-presents reliably too (1.05–1.10 s after launch, again 1.03–1.10 s after every foreground) but dims only 0.29 / 0.48 (17.5 / 26.5 dark), floats inset on 26.5, stacks its 34 pt safe area under the card's 44 pt padding, and slides in over a visible Home for about 0.4 s.

No API here needs a capability, entitlement, Info.plist key, or has App Privacy / review impact. Everything used is iOS 16.4 or earlier; `presentationSizing(.fitted)` (iOS 18.0) is the one tempting alternative and is flagged below.

## Configuration every claim was verified under

- Xcode 27.0 (27A266a), SDK iphonesimulator27.0. Runtimes: iPhone 15 / iOS 17.5 (`3CAE4D76-A126-455D-9F6B-61A82E8108B4`) and iPhone 17 / iOS 26.5 (`834F0313-6E07-453C-925D-4C8B7F7389FE`). Dark appearance unless stated.
- Probe: a scratch copy of the repo at `a37d268` in `/private/tmp/claude-501/-Users-zhabskyi-AppleApps-HomeGymLog/69045cf4-6248-4922-8ccd-b835a977b739/scratchpad/probe/`, bundle id `com.zhabskyi.homegymlog.probe`, a generated UI-test target (`HomeGymLogUITests`, Swift 5, no default isolation) added with the earlier `patch_pbxproj.py`. App target unchanged: Debug, `SWIFT_VERSION 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY YES`, deployment 17.0. All prompt views live in the **app target**; they are not verified in any other target.
- Launch: `-seed missed -probe <mode>` (frozen clock Tue 2026-09-15, in-memory store). Modes: `sheet-home` (`.sheet(isPresented:)` on HomeView next to the existing `exerciseInfoSheet(item:)`), `sheet-home-locked` (+ `.interactiveDismissDisabled()`), `sheet-enum` (one `.sheet(item:)` with `.info(Exercise)` / `.missed`), `overlay-shell` (scrim with `.onTapGesture {}` + `.accessibilityAddTraits(.isModal)`, `.overlay` after the shell's `.safeAreaInset`), `overlay-shell-plain` (bare `Color`, no gesture, no trait), `overlay-home` (`.overlay` on `HomeContent`). Presentation is driven by `.onAppear` and `.onChange(of: scenePhase) { … == .active }`; the sheet content is `MissedPromptCard.fixedSize(horizontal: false, vertical: true).onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }.presentationDetents([.height(sheetHeight)]).presentationCornerRadius(28).presentationDragIndicator(.hidden).presentationBackground(Theme.sf)`.
- Evidence: `xcrun simctl io screenshot` read with a small CoreGraphics pixel tool (`scratchpad/pix`), `simctl io recordVideo` sampled every 1/60 s with an AVAssetImageGenerator tool (`scratchpad/frames`), and XCUITest runs whose data lines are in `scratchpad/ui-out/17.txt`, `17b.txt`, `17c.txt`, `26.txt`, `26c.txt` (plus hierarchy dumps and PNGs per state). Console: `log stream --predicate 'process == "HomeGymLog"'` at default level during the two-sheet scenario captured no app message on either runtime; the same stream at debug level captured 908 / 1,459 lines per launch, so the capture works.
- Clean-up: probe app uninstalled from both simulators (`listapps` shows none), repo `git status` shows only the main session's untracked `docs/specs/m4-missed-day.md`; `project.pbxproj` untouched.

## Q1 — Auto-presentation on cold launch and on foreground

**Verdict.** Every variant presented on every cold launch on both runtimes with no failure or console warning, and re-presented after being dismissed once the scene became active again. The overlay is in the first app frame; the sheet animates in over a visible Home for ~0.4 s. A Home-owned prompt does not appear when the app opens on another tab.

Evidence (XCUITest, times from `XCUIApplication.launch()` returning, both runtimes unless split):
- Present on launch: 1.05–1.10 s for all six modes (17.5: 1.07–1.10; 26.5: 1.05–1.06). Exactly one prompt instance (`shiftCount=1`).
- Background (home button, 1 s) then `activate()` while presented: still presented, still one instance; `activeCount` incremented, so `.onChange(of: scenePhase)` fires for a view inside `TabView → NavigationStack`.
- Skip → dismissed (`missed.exists=false`, Start workout hittable again) → background/foreground → re-presented in 1.03–1.10 s (all modes, both runtimes).
- Launch with `-tab program`: `sheet-home` and `overlay-home` did **not** present (Home's `onAppear` has not fired); tapping the Home tab presented it 1.04–1.10 s later. `overlay-shell` presented at once. `onAppear` inside a `TabView` runs for the selected tab only.
- Cold-launch frames (video, 1/60 s): overlay variants — the button-strip pixel rises straight to its dimmed value (17.5: 4→110 over the launch fade, 26.5: 4→110) and the card is at its final place in the first sampled app frame on both runtimes; no undimmed frame of Home. Sheet — 17.5: first app frame at 2.233 s of video, the card's body passes the sample point at 2.517 s, settled by 2.65 s (≈ 420 ms after the first frame); 26.5: first frame 2.113 s, card at 2.217 s, settled ≈ 2.50 s (≈ 390 ms). The dim ramps with the launch fade (no full-brightness Home frame), but Home is visible under the sliding sheet for that ~0.4 s.
- Screenshot stability after `simctl launch` returns (the screen is black for ≈ 1 s): overlay — final at the first non-black shot (17.5: 1.45 s; 26.5: 0.97 s was still mid-fade at 78/101, 1.46 s final); sheet — 17.5: the 1.45 s shot caught the sheet mid-slide (fully dimmed, card not yet in place), final from 1.92 s; 26.5: 0.93 s mid-fade, final from 1.41 s. Use ≥ 2 s; the existing `sleep 3` is safe.

Availability: `.sheet(isPresented:)`, `.sheet(item:)` iOS 13.0; `scenePhase` iOS 14.0; `.onAppear` iOS 13.0; `.overlay { }` iOS 15.0. All fine at the 17.0 floor, no `#available`.

Recommendation: drive the flag from `onAppear` + `scenePhase == .active` exactly as probed. If the overlay lives in `ShellView`, it appears regardless of the selected tab (matches "on cold launch"); if the prompt lives in `HomeView`, it shows only once Home is on screen — say so in the spec.

## Q2 — Look and coverage

**Verdict.** Custom overlay = prototype (0.55 black, card flush with the screen bottom, tab bar covered when the overlay is on the shell). System sheet = 0.29 / 0.48 dim, safe-area gap under the card on 17.5, floating inset sheet on 26.5.

Measured (dark; accent button 225,29,72 and bg 15,14,16 as references):
| | 17.5 dark | 17.5 light | 26.5 dark | 26.5 light |
|---|---|---|---|---|
| System sheet dim (black α) | 0.29 (225→160; bg 15→11) | 0.12 (bg 244→215) | 0.48 (225→117) | 0.20 (225→180; 244→195) |
| Custom overlay dim | 0.55 (225→101) | 0.55 (244→110) | 0.55 | 0.55 |
Prototype: 0.55.

Geometry:
- Content height measured 281 pt on both (`h=281` in the probe's state label; 320 was the pre-measure default).
- 17.5 sheet: edge-to-edge (sf at x = 0), reaches the screen bottom, top at 536.7 pt → 315 pt tall = 281 + 34 pt bottom safe area. The card's 44 pt bottom padding stacks on that inset: Skip's bottom edge is 78 pt above the screen bottom vs 44 in the prototype. Fix if a sheet is chosen: `.padding(.bottom, 10)` inside the sheet, or `.ignoresSafeArea(edges: .bottom)` on the card.
- 26.5 sheet: **inset, not scaled** — sf starts at x = 24 px (8 pt side insets, 386 of 402 pt wide), bottom gap 8–9 pt (sf ends at 865.7 of 874 pt), all four corners rounded, top at 563 pt → ≈ 303 pt tall. Text sizes are identical to 17.5. Never assert sheet frames across runtimes (agrees with the existing gotcha).
- Custom overlay on the shell: covers the floating bar (not visible); card bottom exactly 44 pt above the screen edge on both runtimes (17.5 Skip bottom at 808 of 852 pt); card top at 1338 px (17.5) / 1780 px (26.5) with the top of "Start workout" still visible above it.
- Custom overlay inside `HomeView`: the bar draws **over** the card and the scrim (the `.safeAreaInset` of the `TabView` is above Home's overlay), and the bar stays tappable (tapping "Program" switched tabs; `programSelected=true` on both runtimes). Confirmed: it cannot cover the bar.
- Neither overlay covers a UIKit sheet: with the info sheet open and the shell overlay shown, the sheet floats above the scrim and card (`ui-out/26-ProbeUITeststestInfoThenMissed-overlay-shell-info-and-missed.png`).

Accessibility (XCUITest hierarchy):
- Sheet: the content behind is still in the tree (`Start workout` `.exists=true`, tab buttons exist, 103 / 110 elements) but `Start workout.isHittable=false`.
- Overlay: `Start workout.isHittable=true` even though a tap there does nothing (XCUITest's hit-test ignores a SwiftUI scrim) and the tree is identical with and without `.accessibilityAddTraits(.isModal)` (95 / 101 elements). So XCUITest cannot verify `.isModal`; **VoiceOver behaviour of the overlay is unverified** (needs the device: with VoiceOver on, swipe right from the card's last button and check the focus does not reach Home or the bar).

Availability: `presentationDetents` / `PresentationDetent.height` / `presentationDragIndicator` iOS 16.0; `presentationCornerRadius` / `presentationBackground` / `presentationBackgroundInteraction` iOS 16.4; `onGeometryChange(for:of:action:)` iOS 16.0 (the two-value overload is 18.0); `UnevenRoundedRectangle` iOS 16.0; `.background(_:in:)` iOS 15.0; `AccessibilityTraits.isModal` iOS 13.0; `presentationSizing(.fitted)` **iOS 18.0 — do not use** (compile error without `#available`; the measured `.height` detent replaces it). Read from the SDK's `SwiftUI` / `SwiftUICore` swiftinterfaces.

Recommendation: overlay on `ShellView` for the prototype's look; if the spec prefers the system sheet, accept 0.29/0.48 dim and the floating 26.5 sheet, add the bottom-padding fix, and keep `.fixedSize(horizontal: false, vertical: true)` on the content (see gotcha below).

## Q3 — Dismissal

**Verdict.** Sheet: drag-down and a tap on the dimmed area both dismiss on both runtimes; `.interactiveDismissDisabled()` blocks both on both runtimes. Overlay: a bare `Color` scrim already blocks every touch beneath; nothing else is required, but the overlay must sit above the `.safeAreaInset` to block the bar.

Evidence (XCUITest, both runtimes):
- `press(forDuration: 0.1, thenDragTo:)` 500 pt down from the card: dismissed (`sheet-home`, `sheet-enum`); the binding flipped (`missed=false` / `sheet=nil`). XCUITest's fast `swipeDown()` flick did **not** dismiss on either runtime (short travel); a real finger drag is the press-and-drag case.
- Tap at (50 %, 12 %) of the screen (dimmed area): dismissed; nothing behind received the tap (no workout started).
- `sheet-home-locked`: drag, dim tap and flick all left the sheet presented.
- Overlay (`overlay-shell`, `overlay-shell-plain`, `overlay-home`): coordinate tap on "Start workout" → no workout (`Exit` never appeared); coordinate tap on "About Lat Pulldown" → no info sheet; press-and-drag on the scrim → Home did not scroll (`Start workout` frame y unchanged: 554 on 17.5, 557 on 26.5). Identical for the plain `Color` without `.onTapGesture`. Tab bar: unreachable under the shell overlay (its Skip button frame (20, 758, 353, 50) overlaps the bar (109, 768, …); the tap landed on Skip and dismissed the prompt), reachable under the Home overlay (tab switched).

Availability: `interactiveDismissDisabled` iOS 15.0; `onTapGesture` iOS 13.0. Recommendation: for the sheet, decide explicitly whether the prompt may be swiped away (the prototype has no dismiss without choosing; `.interactiveDismissDisabled()` gives that). For the overlay, `Color.black.opacity(0.55).ignoresSafeArea()` in a `ZStack` with the card, applied with `.overlay` **after** `.safeAreaInset(edge: .bottom)` on the `TabView`; add `.onTapGesture {}` only if you want to document intent, it changes nothing.

## Q4 — Interplay with the info sheet and the route flip

**Verdict.** Two `.sheet` modifiers on `HomeView` do not conflict: the missed sheet waits and presents itself when the info sheet is dismissed, with no console warning. One enum `.sheet(item:)` swaps the info sheet for the missed one immediately. A root route flip with the prompt presented tears the sheet down cleanly, and the fresh `HomeView` re-presents it on return.

Evidence (both runtimes unless split):
- Two modifiers (`sheet-home`): Skip, open "About Lat Pulldown", background/foreground → `showMissed = true` while the info sheet is up: missed sheet not presented (`missed.exists=false`, Form cues visible, state `missed=true`); tap Done → missed sheet present within 1.5 s, and still there after 3 s. No "already presenting" line at default log level (stream verified).
- Enum (`sheet-enum`): same steps; setting `.missed` while `.info(latPull)` is shown replaced the info sheet within 1.5 s (`formCues.exists=false`, prompt present). Whether the swap animates as dismiss-then-present or as a content change is unverified (no video of that moment).
- Overlay (`overlay-shell`, `overlay-home`): the overlay appears under the open info sheet; after Done it is fully visible.
- Route flip (`-probeFlip`: the primary button calls `WorkoutLogStore.start(sessionIndex: 7, …)` and leaves the flag/item untouched): `RootView` switched to the workout (`Exit` present in ~1 s); the prompt's elements were gone (`missed.exists=false`, `shift.exists=false`; the workout screenshot is clean, `ui-out/26-ProbeUITeststestRouteFlip-sheet-home-flipped.png`). Exit (no confirmation since nothing was logged) → shell back → prompt re-presented by the new `HomeView` instance (`appear=1 active=0`), for `sheet-home`, `sheet-enum` and `overlay-home`. No warning logged.
- Consequence for the real feature: because the shell is replaced, prompt state held in `HomeView`/`ShellView` `@State` is lost on the flip and rebuilt from `onAppear`; derive "show it" from data (a missed session exists) plus a per-foreground "dismissed" flag, not from a one-shot boolean.

Recommendation: follow INSIGHTS ("one optional Identifiable sheet item per screen") only if the prompt is a sheet on Home — then `enum HomeSheet { case info(Exercise), missed }`. With the shell overlay the info sheet keeps its own `.sheet(item:)` on Home and nothing changes there.

## Minimal example (compiles against iOS 17; the shape verified in the probe)

```swift
// ShellView.swift — the overlay goes after .safeAreaInset so it covers the floating bar.
TabView(selection: $selected) { … }
    .safeAreaInset(edge: .bottom, spacing: 0) { FloatingTabBar(selected: $selected) }
    .overlay {
        if showMissed {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.55).ignoresSafeArea()          // blocks every touch beneath on 17.5 and 26.5
                MissedPromptCard(onShift: …, onSkip: { showMissed = false })
                    .background(Theme.sf, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                    .ignoresSafeArea(edges: .bottom)                 // card's 44 pt padding reaches the screen edge
            }
            .accessibilityAddTraits(.isModal)                        // VoiceOver effect unverified on the simulator
        }
    }
    .onAppear { showMissed = shouldPrompt }                          // cold launch
    .onChange(of: scenePhase) { _, phase in if phase == .active { showMissed = shouldPrompt } }   // foreground
```
Card: `VStack(alignment: .leading, spacing: 0)` with kicker (12 bold, `Theme.warning`, `.textCase(.uppercase)`, tracking 0.5), title (22 bold, tracking −0.4, top 6), body (14, `Theme.mu`, lineSpacing 3, top 6), two 50 pt buttons radius 13 in a `VStack(spacing: 8)` top 18; `.padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 44)`. Sheet alternative: the modifier chain in the configuration section, with `.fixedSize(horizontal: false, vertical: true)` before `onGeometryChange`.

React analogy: `.overlay { if show { … } }` on the shell is a conditional modal rendered at the app root (no portal, so a UIKit sheet is still above it); `.sheet(isPresented:)` is a `<Dialog open>` the framework mounts in a portal over everything, including your own overlays.

## Unverified (and the probe that would settle it)
- VoiceOver focus containment of the overlay with `.isModal`: device, VoiceOver on, swipe through the card.
- Whether the enum-sheet swap (`.info` → `.missed`) plays two animations: record video during that step.
- Home-level overlay after switching tabs and back: the `@State` stayed true; re-showing on return not observed (tap Home tab in the `overlay-home` blocking test).
- Timings and frame counts come from the simulator on a Mac; nothing was measured on a phone.

## Suggested entries

`insights/gotchas.md` (SwiftUI):
- 2026-09-15 — **A `.height(h)` detent measured with `onGeometryChange` needs `.fixedSize(horizontal: false, vertical: true)` on the content**: otherwise the content is compressed to the initial detent, the body text truncates to one line ("…") and the measured height is the truncated one (17.5, missed-day probe). Also the sheet's bottom safe area (34 pt) stacks under the content's own bottom padding.
- 2026-09-15 — **XCUITest `isHittable` is true for elements under a SwiftUI overlay scrim** and the tree is identical with or without `.accessibilityAddTraits(.isModal)`; a system sheet keeps the content behind in the tree with `isHittable=false`. Verify blocking with a coordinate tap and an outcome check, never with `isHittable`. XCUITest's `swipeDown()` flick does not dismiss a 315 pt sheet; use `press(forDuration:thenDragTo:)`.
- 2026-09-15 — **System sheet dim differs by runtime and appearance**: black 0.29 / 0.12 (17.5 dark / light), 0.48 / 0.20 (26.5); 26.5 partial sheets float with 8 pt side insets and an 8 pt bottom gap (insets, not scaling). The prototype's 0.55 only comes from a custom scrim.

`insights/INSIGHTS.md` (Patterns):
- 2026-09-15 — **Missed-day prompt mechanics.** An overlay must be applied after the shell's `.safeAreaInset` to cover the floating bar; an overlay inside a tab leaves the bar tappable. A bare `Color` scrim blocks taps and scrolls beneath on 17.5 and 26.5. Any `.sheet` floats above a custom overlay. Two `.sheet` modifiers on one view queue (the second presents after the first is dismissed, no warning); one enum `.sheet(item:)` swaps. `onAppear` inside `TabView` fires for the selected tab only, so a Home-owned prompt is not shown when the app opens on another tab. A root route flip drops the prompt with the shell; the remounted Home re-presents it from `onAppear`, so derive the prompt from data plus a per-foreground dismissed flag.

Probe artifacts (not in the repo): code `…/scratchpad/probe/HomeGymLog/App/DebugSeed/ProbeMode.swift`, `…/probe/HomeGymLog/Features/Home/MissedPrompt.swift`, `…/probe/HomeGymLog/Features/Home/HomeView.swift`, `…/probe/HomeGymLog/App/ShellView.swift`, `…/probe/HomeGymLogUITests/ProbeUITests.swift`; screenshots `…/scratchpad/shots/` (`17-*.png`, `26-*.png`, `*-light-*.png`, `stab/`, `*-launch-*.mp4`); UI-test data and per-state dumps `…/scratchpad/ui-out/` (scratchpad root: `/private/tmp/claude-501/-Users-zhabskyi-AppleApps-HomeGymLog/69045cf4-6248-4922-8ccd-b835a977b739/scratchpad`).

---

# Addendum: scoped probes for B5 (host handlers while it draws nothing) and B6 (drag starting on a card button)

**Direct answer.** P1: give the host a concrete `ZStack(alignment: .bottom) { if shows { … } }` root; with it `.onAppear`, `.onChange(of: scenePhase)` and `.onChange(of: selected)` all fire while the host draws nothing, on both runtimes, and the hidden host intercepts no touch on Home, the tab bar or the Program tab. With a bare `Group { if shows { … } }` root only `onAppear` misbehaves (it does not run at mount while hidden and re-runs every time the content appears); the two `onChange` handlers fire either way. The fallback (ShellView-owned `now`) works but is unnecessary.
P2: attach the `DragGesture(minimumDistance: 20)` to the card with **`.highPriorityGesture`**, outside the `.offset`. That is the only variant where a drag beginning on a button never activates the button (40, 90 and 120 pt, both buttons, both runtimes), ≥ 80 pt dismisses, < 80 pt springs back, and a plain tap on each button still fires exactly once. `.gesture`, `.simultaneousGesture` and "gesture on the text block only" all let a button fire when the finger is released within roughly 70 pt of the button, which a drag starting on the bottom button always is.

## Configuration

Same scratch copy and toolchain as the main report (Xcode 27.0 27A266a, SDK iphonesimulator27.0; iPhone 15 / iOS 17.5 `3CAE4D76…`, iPhone 17 / iOS 26.5 `834F0313…`; app target Debug, Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, deployment 17.0; UI-test target Swift 5, no default isolation). The copy still held the earlier probe modes; the new code sits beside them and is selected by new `-probe` values, so the earlier results are unaffected. Every claim below was verified on **both** runtimes unless a runtime is named; results were identical across runtimes in every case.

- Host: `MissedPromptHost` placed in `ShellView`'s `.overlay` **after** `.safeAreaInset` (the position the main report measured). It takes `selected: AppTab`, owns `@State now`, `@State silenced`, reads `scenePhase` and `appClock`; rule `shows = !hidden && !silenced && selected == .home`. Handlers (one `ViewModifier` on the root): `.onAppear`, `.onChange(of: scenePhase) { … == .active }`, `.onChange(of: selected) { … == .home }`; each writes `now` and bumps a counter. Shapes: **(a)** `Group { if shows { scrim; card } }` + handlers; **(b)** `ZStack(alignment: .bottom) { if shows { scrim; card } }` + handlers; **(c)** = (b) + `.allowsHitTesting(shows).accessibilityHidden(!shows)`; **(fb)** = ShellView owns `now` and the three handlers on the `TabView` chain, the host has none and receives `now`.
- Counters live in an `@Observable` object created by `ShellView` and rendered into a 1 pt clear `Text` (`probe.counters`) on the shell, so XCUITest reads them even while the host draws nothing. `-probeHidden` forces the rule false from the first frame (needed because `RootView` applies `-tab program` in `onAppear`, so the shell's first frame is on Home, NB6).
- Card for P2: the `VStack` of kicker/title/body plus two 50 pt `Button`s, `.offset(y: max(0, translation))` while dragging, dismiss on release at ≥ 80 pt else `withAnimation(.spring())` back; variants `gesture` (`.gesture` on the card, outside the offset), `simultaneous` (`.simultaneousGesture`), `high` (`.highPriorityGesture`), `highg` (same, `coordinateSpace: .global`), `textblock` (gesture on the text block only, local space) and `textblockg` (text block, global space). Each button and the scrim tap bump their own counter; `-probeReshow` clears the silence on scene-active so one launch can run every case.
- Drives: XCUITest `press(forDuration: 0.1, thenDragTo:)` from the element centre; plain `tap()`; `swipeDown()` for a flick; `XCUIDevice.press(.home)` + `activate()` for a foreground cycle. Data lines: `scratchpad/ui-out/17d.txt`, `26d.txt` (P1 and P2), `17e.txt`, `26e.txt` (Program controls), `17f.txt`, `26f.txt` (extra drag variants).
- Clean-up: probe app uninstalled from both simulators (0 left), no `log stream` left running, repo `project.pbxproj` has no diff; the repo's modified `insights/*` and untracked `docs/*` files are the main session's, this agent wrote nothing into the repo.

## P1 (B5) — handlers on a host that draws nothing

| Scenario (host hidden) | (a) `Group { if }` | (b) `ZStack` root | (c) (b)+hitTesting/a11y | (fb) shell-owned |
|---|---|---|---|---|
| `-probeHidden`, launch on Home: `onAppear` at mount | **0** | 1 | 1 | 1 (shell) |
| background 1 s → `activate()`: scene handler | fires (1→2) | fires | fires | fires |
| Program → Home tab round-trip: selected handler | fires (1) | fires | fires | fires |
| `-tab program` launch: `onAppear` | 1 (only because the first frame is on Home, NB6; 0 after a route-flip remount on Program) | 1 | 1 | 1 |
| cycle while hidden on Program: scene | fires | fires | fires | fires |
| tap Home tab: selected handler, prompt shows | fires; prompt 1.03–1.05 s | fires; 1.03–1.04 s | fires; 1.03–1.07 s | fires; 1.04 s |
| Skip, then cycle while silenced on Home: scene | fires | fires | fires | fires |
| `onAppear` count after the prompt has shown once | **2** (re-runs each time the content appears) | 1 | 1 | 1 |

Also observed: the scene handler fires **once during launch** on both runtimes (`scene=1` about 2.5 s after launch with no cycle), so even shape (a) had `now` set before any interaction; the Group-root's missing `onAppear` is therefore masked in practice, but not by contract.

Touches with the host hidden (coordinate tap + outcome), identical for (a), (b), (c), (fb): "About Lat Pulldown" on Home opened the info sheet (Form cues visible); the "Program" bar button switched tabs (`isSelected` true); on the Program tab, its card's "Start workout" started the workout (`Exit` appeared; the route flipped and came back) and "Week 2" changed the day row (buttons containing "18": 2→1, containing "11": 1→2). The empty `ZStack` in an `.overlay` has zero size, so (c)'s `.allowsHitTesting(false)` is not needed for touch. Whether the hidden host is invisible to VoiceOver is **unverified** (XCUITest's tree looked the same for (b) and (c); no VoiceOver on the simulator).

Recommendation: shape **(b)**, host-owned handlers, `now ?? clock.now()` as the pre-appear fallback. Keep `.accessibilityHidden(!shows)` only if the VoiceOver pass on the device shows an empty focus stop; it costs nothing. The fallback is not required.

## P2 (B6) — drag that starts on a button

Button geometry on 17.5: shift (20, 690, 353, 50), Skip (20, 758, 353, 50), screen 852 pt, so a drag from Skip's centre can travel at most ≈ 69 pt before the screen edge (XCUITest clamps the end point; a finger stops there too). Counters: `skip`/`shift` = button actions fired, `drag` = dismiss-by-drag.

| Case | `.gesture` | `.simultaneousGesture` | **`.highPriorityGesture`** (local and `.global` identical) | text block only (local) | text block only (`.global`) |
|---|---|---|---|---|---|
| (i) 120 pt from Skip (clamped ≈ 69) | prompt gone, **Skip fired** | gone, **Skip fired** | stays, nothing fired | gone, **Skip fired** | gone, **Skip fired** |
| (ii) 120 pt from shift | gone by drag, shift not fired | gone, **shift fired and drag** | gone by drag, shift not fired | stays, nothing (gesture stuck, see note) | stays, nothing fired |
| 90 pt from shift | – | – | gone by drag, not fired | – | gone, **shift fired** |
| (iii) 120 pt from title | gone by drag | gone by drag | gone by drag | **stays** (stuck) | gone by drag |
| (iv) 40 pt from title | stays, no action | stays | stays, no action | stays | stays |
| 40 pt from Skip | gone, **Skip fired** | gone, **Skip fired** | stays, nothing fired | gone, **Skip fired** | gone, **Skip fired** |
| 40 pt from shift | – | – | stays, nothing fired | – | gone, **shift fired** |
| (v) plain tap on Skip / shift | fires once each | fires once each | fires once each | fires once each | fires once each |
| flick (`swipeDown()` on title) | stays | stays | stays | stays | stays |
| scrim tap | dismisses | dismisses | dismisses | dismisses | dismisses |
| drag on scrim (200 pt up) | prompt stays, Home not scrolled (Start y 554 / 557 unchanged) | same | same | same | same |

Reading: a SwiftUI `Button` keeps tracking a touch that has moved off it and fires on release while the finger is still within roughly 70 pt of its bounds (Skip at 40 and ≈ 69 pt: fired; shift at 40 and 90 pt: fired; shift at 120 pt: not fired). A card-level `.gesture` or a text-block gesture does not cancel that; `.simultaneousGesture` makes both happen (shift fired **and** the drag dismissed at 120 pt). `.highPriorityGesture` cancels the button once the drag recognises (20 pt), so no button-origin drag fires a button, while taps (no movement) still reach the buttons. The "gesture on the text block only" fallback does **not** protect the buttons (they still fire from their own drags) and, when placed inside the card's `.offset`, its local-space translation feeds back and it never reaches 80 pt (the "stuck" cells); `coordinateSpace: .global` fixes the stuck part only.

Recommendation: `.highPriorityGesture(DragGesture(minimumDistance: 20))` on the card, applied after `.offset(y:)`, dismiss at ≥ 80 pt, spring back below; semantics for the spec: "a drag beginning on a button never activates the button; ≥ 80 pt dismisses; less springs back; a tap on a button fires once". Add the 80 pt threshold to the card's copy of the rule; a real drag from Skip cannot reach 80 pt on a 852 pt screen (max ≈ 69 pt), so from Skip it always springs back, which is acceptable. XCUITest's `swipeDown()` flick never dismissed (too short); use press-and-drag in any future UI probe.

Availability: `DragGesture(minimumDistance:coordinateSpace:)`, `.highPriorityGesture`, `.simultaneousGesture`, `.offset` iOS 13.0; `withAnimation(.spring())` iOS 13.0/15.0. No capability, entitlement or review impact.

Unverified: VoiceOver's treatment of the hidden host and of `.highPriorityGesture` (VoiceOver activates buttons by double-tap, which is a tap, so it should be unaffected; device check); the `onAppear`-at-launch behaviour on a phone (simulator only).

Suggested gotcha entries:
- 2026-09-15 — **A view whose body is `Group { if cond { … } }` gets no `onAppear` at mount while `cond` is false, and re-runs it each time the content appears**; `.onChange(of:)` handlers on it fire regardless. Use a concrete root (`ZStack { if … }`) when a handler must run at mount. (17.5 and 26.5)
- 2026-09-15 — **A SwiftUI `Button` fires on release up to ~70 pt outside its bounds**, so a container `.gesture`/`.simultaneousGesture` drag that starts on a button can end with the button firing (and with `.simultaneousGesture`, both). `.highPriorityGesture(DragGesture(minimumDistance: 20))` cancels the button once the drag recognises and still lets taps through. A `DragGesture` placed inside the view's own `.offset` feeds back its translation and never reaches the threshold; attach it outside the offset or use `coordinateSpace: .global`.
- 2026-09-15 — `.onChange(of: scenePhase)` to `.active` fires once during a cold launch (both runtimes); do not count on it as "only on return from background".

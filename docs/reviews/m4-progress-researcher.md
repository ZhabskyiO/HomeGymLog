# m4-progress: platform research (Swift Charts line, chart accessibility, re-render cost, chip row, month grid)

**Direct answer.** Build the chart as `Chart { LineMark… + PointMark.symbol { hollow Circle } + three RuleMark }` with both axes hidden and explicit, padded `chartXScale`/`chartYScale` domains computed in the Engine; that reproduces the prototype's SVG to the point (baseline at 110/120, dashed rules at 10 and 60, first marker centre 10 pt in, r = 4, markers overflow the plot unclipped) identically on iOS 17.5 and 26.5. Hide the line and rule marks from accessibility and label each point (`accessibilityHidden` on `LineMark`/`RuleMark`, `accessibilityLabel/Value` on `PointMark`); without that, VoiceOver gets "0 to 0.5, 40 to 40, 2 values". A 200-point chart re-renders in ≈ 3 ms; nothing animates unless the data change is inside `withAnimation`. Reuse `WeekChipRow`'s `ScrollViewReader` + deferred `scrollTo(anchor: nil)` for the chips (`scrollPosition(id:)` scrolls an already-visible chip to the leading edge on 17.5 and writes back while the user scrolls). Use `LazyVGrid` with seven `.flexible()` columns and `.aspectRatio(1, contentMode: .fit)` cells; leading blanks = `CalendarRules.appWeekday(of: monthStart)`.

No API here needs a capability, entitlement, Info.plist key, paid-tier feature, or has App Privacy / review impact. Every API used is iOS 17.0 or earlier (most 16.0); the one tempting iOS 18-only item, the vectorized `Chart(data) { … }` key-path modifiers (`.accessibilityLabel(\.keyPath)`, `MarkDimensions`, `lineStyle(\.keyPath)`), is flagged in Q1. No `#available` is needed anywhere.

## Configuration every claim was verified under

- Xcode 27.0 (27A266a), SDK iphonesimulator27.0. Runtimes: iPhone 15 / iOS 17.5 (`3CAE4D76-A126-455D-9F6B-61A82E8108B4`, 393 × 852 pt) and iPhone 17 / iOS 26.5 (`834F0313-6E07-453C-925D-4C8B7F7389FE`, 402 × 874 pt). Dark appearance.
- Probe: a scratch copy of the repo at `dd5fcc4` in `…/25a4eb31-9206-404b-9471-adb94a6d9a38/scratchpad/probe/`, bundle id `com.zhabskyi.homegymlog.probe`, plus a generated UI-test target (`HomeGymLogUITests`, Swift 5, no default isolation) added with the earlier `patch_pbxproj.py`. App target unchanged: Debug, `SWIFT_VERSION 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY YES`, deployment 17.0. All probe views live in the **app target** (`App/DebugSeed/ProbeView.swift`, `#if DEBUG`) behind `-probe <mode>`; nothing is verified in any other target.
- Evidence: XCUITest data lines (`scratchpad/ui-out/17.txt`, `26.txt`, per-mode hierarchy dumps and PNGs), `pix` pixel reads of the screenshots, `simctl io recordVideo` sampled every 1/60 s with a column-scanning tool (`scratchpad/col`) for the animation question, and a macOS `swift cal.swift` run for the calendar math (Foundation calendar, `America/New_York`, `en_US_POSIX`, `firstWeekday = 1` like `TestCalendar`).
- Availability lines are read from the SDK's `Charts`, `SwiftUI` and `SwiftUICore` `.swiftinterface` files, not from memory.
- Clean-up: probe bundles uninstalled from both simulators (`listapps` shows none), iPhone 17 shut down again, repo `git status` shows only the main session's untracked `docs/specs/m4-progress.md`; `project.pbxproj` untouched.

## Q1 — Reproducing the prototype chart with Swift Charts

**Verdict.** `LineMark` + `PointMark` with a custom `symbol { }` view + three `RuleMark`s, axes hidden, explicit padded domains. Measured geometry on both runtimes matches the SVG exactly; no 17.5 vs 26.5 difference; a hidden-axes chart has no inset or background on either runtime (plot area = frame, rules span the full 325 / 334 pt width).

Measured (chart frame 120 pt tall at y = 146.7 / 149.7):
- Rules at 109.5, 59.5, 9.5 pt from the chart top (element frames `y=256.2 / 206.2 / 156.2`, 1 pt tall) = the SVG's 110 / 60 / 10 of 120.
- First marker: accent stroke pixels at x = 120 and 144 px on row 685 → centre 132 px = 44.0 pt = **10.0 pt from the chart's left edge** (SVG: 10 of 320), outer diameter ≈ 8 pt + 2.5 pt stroke = r 4 with a 2.5 stroke. The centre pixel is `sf` (hollow). Marker y for the minimum weight (40 lb) = 81.7 pt from the top; the SVG formula gives 81.4 (the min point sits 5 lb above the baseline, as in the prototype).
- Single point (`chart-one`): centred at x = 196.5 + 16 ≈ 212 pt (screen centre 196.5 of the 393 screen; the chart element is 34…359, centre 196.5) and on the middle dashed rule, as the SVG's `X = 160, Y(mn+5) = 60`.
- Empty (`chart-empty`): the three rules render with an explicit domain; the "No sessions logged yet…" text below. **Always pass explicit domains**; an empty chart with `RuleMark`s and no data has no inferred domain (not probed without domains; the recipe never leaves them out).
- **Marks are not clipped to the plot area** (`chart-edge`, domain exactly min…max and 0…n−1, plot tinted blue): the corner markers overflow the plot on both runtimes, as the prototype's `overflow:visible`. The flip side: a `RuleMark` outside the y domain is drawn **outside the chart frame** (measured at 66.2 and 346.2 pt, i.e. 80 pt above and 80 pt below a 120 pt chart, over the card title and under the card). Keep every rule inside the domain; there is no `chartOverflowResolution` view modifier in the SDK (the only overflow API is `annotation(…, overflowResolution:)`, iOS 17.0, for annotations). `clipShape` exists on `ChartContent` (16.0) and `.clipped()` on the chart view if clipping is ever wanted.
- 26.5 (Liquid Glass era): identical rendering with axes hidden; no default background, inset or material appears. Default axis styling on 26.5 was not probed because the design hides both axes.

Geometry recipe (pure, Engine-testable). With `weights` = top weight per completed session, `n = weights.count`:
- `lo = min − 5`, `hi = max + 5`, `ext = (hi − lo) / 10`; y domain `(lo − ext)…(hi + ext)`; rules at `lo` (solid), `(lo + hi) / 2` (dashed), `hi` (dashed). This maps `lo` to 110/120 and `hi` to 10/120 with no plot padding, so no clipping question arises for y.
- x: plot by session index. `n ≥ 2`: `pad = (n − 1) / 30`, domain `−pad…(n − 1) + pad` (= 10 pt insets of 320). `n == 1`: domain `−1…1`, point at 0 (centred). Even spacing falls out of the integer index; plotting by `Date` would space by elapsed days and break the "evenly by session index" rule.
- `lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))`, `interpolationMethod(.linear)` (the default; stated for clarity), fixed `.frame(height: 120)`.

Availability (all fine at the 17.0 floor, no `#available`): `Chart`, `LineMark`, `PointMark`, `RuleMark`, `symbol(_:)`, `symbol(symbol:)` (custom view), `symbolSize`, `lineStyle(_:)`, `interpolationMethod`, `chartXAxis(_:)`/`chartYAxis(_:)` `.hidden`, `chartXScale(domain:)`/`chartYScale(domain:)`, `chartPlotStyle`, `chartLegend`, `AxisMarks`/`AxisGridLine(stroke:)`, `ChartContent.clipShape` — all **iOS 16.0**. `BasicChartSymbolShape.circle.strokeBorder(lineWidth:)` (16.0) gives a stroke-only circle whose interior is transparent, so the line shows through; the custom `symbol { }` view with an `sf` fill is what matches the prototype. `chartXSelection`, `chartScrollableAxes`, `chartXVisibleDomain`, `annotation(overflowResolution:)` — 17.0, not needed. **iOS 18.0 — do not use:** the vectorized `Chart(data) { … }` family (`VectorizedChartContent`, `MarkDimensions`, key-path overloads of `accessibilityLabel`, `lineStyle`, `symbolSize`, `position(by:)`). `RuleMark` vs `chartYAxis { AxisMarks(values:) { AxisGridLine(stroke:) } }`: both are 16.0; `RuleMark` was chosen because a grid line is an axis mark (it needs the axis visible, and the axis reserves label space unless every mark is stripped), whereas rules are marks inside the plot and their y is exact.

Apple's guidance (WWDC22 "Swift Charts: Raise the bar", transcript): "You can pass in .hidden to the chart axis modifiers to hide an axis"; "use the .chartYScale modifier, and set the domain of the scale"; "You can use the .chartPlotStyle modifier to configure the plot area of a chart." (https://developer.apple.com/videos/play/wwdc2022/10137/). Docs: `chartPlotStyle(content:)` "Configures the plot area of charts … the size or aspect ratio" (https://developer.apple.com/documentation/swiftui/view/chartplotstyle(content:)); `symbol(_:)` (https://developer.apple.com/documentation/charts/chartcontent/symbol(_:)).

React analogy: `Chart { marks }` is a declarative `<svg>` builder like Recharts' `<LineChart><Line/><Scatter/><ReferenceLine/></LineChart>`; `chartYScale(domain:)` is d3's `scaleLinear().domain(...)`.

## Q2 — Accessibility of the chart

**Verdict.** By default Charts exposes one element per x bucket that merges the line and the point ("0 to 0.5" / "40 to 40, 2 values") plus one element per rule (label empty, value "35"). Per-mark `accessibilityLabel/Value` on `PointMark` is **ignored while an unhidden `LineMark` shares the bucket**; add `.accessibilityHidden(true)` to the `LineMark`s and the three `RuleMark`s and every point reads "Aug 31, 40 lb". Same on 17.5 and 26.5. That is the simplest sound approach for ≤ 60 points.

Evidence (XCUITest tree of the `chart` element, identical on both runtimes):
- `chart` (no modifiers): 9 descendants — rules `value='35' / '43.8' / '52.5'`, points `label='0 to 0.5' value='40 to 40, 2 values'` … `label='5 to 5.5' value='45 to 45, 2 values'`. The x bucket "0 to 0.5" comes from the integer index scale; the "2 values" is the line + point pair.
- `chart-marks` (labels on `PointMark` only): **unchanged**, labels swallowed.
- `chart-marks-hidden` (`LineMark.accessibilityHidden(true)` + labelled points): points read `label='Aug 31' value='40 lb'` … `'Sep 11' / '45 lb'`; rules still present as unlabeled elements → hide them too.
- `chart-points-only` (no `LineMark`): same as above, so the fix is the hidden line, not the mark order.
- `chart-summary` (`.accessibilityElement(children: .ignore)` + label + value on the chart): a wrapper element `label: 'Dumbbell bench top weight per session', value: 6 sessions, from 4…` appears **above** the `chart` element, and XCUITest still lists the 9 children beneath it. XCUITest's tree does not honour `.ignore` (the missed-day probe saw the same with `.isModal`), so whether VoiceOver stops at the wrapper is **unverified**; per-point labels are the verified route.
- `chart-descriptor` (`accessibilityChartDescriptor(AXChartDescriptorRepresentable)`): compiles and runs at the 17.0 floor; nothing changes in the XCUITest tree (it feeds VoiceOver's Audio Graph rotor only) — **unverified with VoiceOver**; optional extra, not needed for a sound baseline.

Availability: `ChartContent.accessibilityLabel/Value/Hidden/Identifier` iOS 16.0 (the key-path overloads are 18.0); `accessibilityChartDescriptor(_:)` and `AXChartDescriptorRepresentable` iOS 15.0 (docs: "Adds a descriptor to a View that represents a chart to make the chart's contents accessible to all users", https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor(_:)); Apple, WWDC22 10137: "By default, the chart will be exposed to VoiceOver users with automatically generated accessibility elements. You can customize these with the .accessibilityLabel and .accessibilityValue modifiers." WWDC22 10136: "the chart supports the Audio Graphs feature Apple presented in 2021, including the sonifications" (https://developer.apple.com/videos/play/wwdc2022/10136/).

Recommendation: label points as "<date>, <weight> lb" through a `*Text` helper in `Shared/` (formatting never in Engine), hide line and rules, and give the whole card a heading; the device VoiceOver pass stays with the user's MVP checks.

## Q3 — Re-render cost and Charts gotchas

**Verdict.** Cheap: replacing one point 20×/s for 5 s took 5.36 s with 6 points, 5.38 s with 60 and 5.64 s with 200 on both runtimes (`Task.sleep` overhead is the 0.36 s baseline), i.e. ≈ 0.2 ms extra per update at 60 points and ≈ 2.8 ms at 200. Re-rendering on every SwiftData save is fine; a `@Query`-driven view that rebuilds the ≤ 200-point array per body is nowhere near a frame.

Gotchas verified:
- **No implicit animation.** Replacing the data outside `withAnimation` jumps in one frame (17.5: marker at row 669 in one frame, 540 in the next; 26.5 same). Inside `withAnimation(.easeInOut(duration: 0.6))` the marker interpolates over 0.57 s / 0.60 s (17.5 / 26.5). The prototype has no animation, so plain assignment is right. A chip change swaps to a different point count; how Charts animates a count change was **not probed** — do not wrap it in `withAnimation` without a look.
- **Markers overflow the plot** (Q1): matches the prototype; it also means nothing hides an out-of-domain mark, so keep domains explicit and rules inside them.
- `.id` is not needed on the chart: identity comes from `ForEach(points)` with the session index as id; keying the card on the selected exercise (`.id(exerciseId)`) would only reset local `@State`, of which the chart has none. Avoid it: an `.id` change re-creates the chart and would defeat any future animation.
- `chartPlotStyle` (16.0) can pin the plot's frame; not needed because with hidden axes the plot already equals the frame. `.clipped()` / `ChartContent.clipShape` (16.0) exist if overflow is ever unwanted. `scrollClipDisabled` is 17.0 and irrelevant here.
- Integer x with `PlottableValue<Int>`: the x scale is numeric and buckets ("0 to 0.5") appear in accessibility only; visually it is a plain linear scale.

## Q4 — Horizontal chip row that scrolls the selected chip into view

**Verdict.** Reuse `Features/Program/WeekChipRow.swift`'s shape (`ScrollViewReader` + `.id(chipId)` + `Task { @MainActor in proxy.scrollTo(id, anchor: nil) }` from `onAppear`). It behaves identically on both runtimes: a selected chip already on screen never moves (chip 0 stays at x = 18), an off-screen one is scrolled minimally so its trailing edge lands flush with the screen edge (chip 9: x = 257.3, w = 135.7 → right edge 393.0 on 17.5; 266.3 + 135.7 = 402.0 on 26.5). `scrollPosition(id:)` (iOS 17.0) is worse on 17.5 and wrong for this use.

`scrollPosition(id:anchor: nil)` + `scrollTargetLayout()` measured:
- 17.5, selected 1 (already visible): row moved anyway; chip 1 to x = −0.0 (leading edge of the screen, ignoring the HStack's 18 pt padding), chip 0 to −129.3.
- 17.5, selected 9: chip 9 to x = 45.3, i.e. leading-edge alignment clamped by the end of the content (chip 11 ends at 375 + 18 = 393).
- 26.5, both: identical to `scrollTo(anchor: nil)` (minimal scroll, chip 0 untouched at 18).
- The binding is written back as the user scrolls (`pos 9` label updates), so a selected-chip state bound to it would change while the user merely drags. Keep selection as its own `@State` and drive the scroll from `ScrollViewReader`.

Geometry-dependent: re-check if padding, chip widths or screen size change — 12 chips with these names total 375 pt of content past the 18 pt padding; the "flush with the edge" numbers above depend on that.

Availability: `ScrollViewReader`/`scrollTo` iOS 14.0; `scrollPosition(id:anchor:)`, `scrollTargetLayout`, `scrollTargetBehavior`, `defaultScrollAnchor` iOS 17.0; `scrollPosition(_: Binding<ScrollPosition>)` and `onScrollGeometryChange` **iOS 18.0 — do not use**. The existing gotcha (2026-09-11: `scrollTo` inside `onAppear` runs before layout on 17.5) applies; the deferred call is already in the probe and in `WeekChipRow`.

React analogy: `scrollTo(id, anchor: nil)` ≈ `el.scrollIntoView({ block: "nearest", inline: "nearest" })`; `scrollPosition(id:)` ≈ a controlled scroll-position prop whose `onChange` fires on every user scroll.

## Q5 — Month calendar grid

**Verdict.** `LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4)` with each cell `.aspectRatio(1, contentMode: .fit)`; `Grid`/`GridRow` (iOS 16) renders pixel-identically (cells 43 × 43 pt on 17.5, 44.3 on 26.5, 7 × 43 + 6 × 4 = 325 = card content width) but needs the cells chunked into rows and `Color.clear.gridCellUnsizedAxes` fillers, so it is only more code. Laziness is irrelevant at 35–42 cells; inside the tab's `ScrollView` a `LazyVGrid` is fine (it takes the full width, no `GeometryReader`).

Leading blanks and month length with the app's conventions (verified with the fixture calendar, Sunday-first on purpose, `America/New_York`):
- `monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!`
- `lead = CalendarRules.appWeekday(of: monthStart, calendar:)` — the existing 0 = Monday helper; equals the prototype's `(getDay() + 6) % 7`.
- `days = calendar.range(of: .day, in: .month, for: monthStart)!.count`.
- Checked: Sep 2026 → lead 1, 30 days, 5 rows; Nov 2026 → lead 6, 30 days, **6 rows (42 cells)**; Feb 2026 → 6, 28, 5; Feb 2024 → 3, 29, 5; Mar 2026 → 6, 31, 6; Dec 2026 → 1, 31, 5. Each day's column, walked with `calendar.date(byAdding: .day)`, equals `appWeekday(day)` in all six months. Independent of `firstWeekday`. Note the card is taller in 6-row months; the prototype's `hint-placeholder-count="35"` is a placeholder, not a rule.
- Blank cells: `Color.clear` with `.accessibilityHidden(true)` (on 26.5 `Grid` already dropped the blank from the tree; `LazyVGrid` exposed it as an empty StaticText — hide it explicitly on both).
- Cell accessibility: the identifier landed on the overlay `Text` (the shape and the text merge into one StaticText per day), so a per-day label like "16, today, scheduled" can go on the cell as a whole.

Availability: `LazyVGrid`/`GridItem` iOS 14.0; `Grid`/`GridRow`/`gridCellUnsizedAxes` iOS 16.0; `aspectRatio` 13.0; `containerRelativeFrame` 17.0 (not needed).

React analogy: `LazyVGrid` with seven `.flexible()` columns ≈ CSS `grid-template-columns: repeat(7, 1fr)`; `.aspectRatio(1, .fit)` ≈ `aspect-ratio: 1`.

## Code example (compiles against iOS 17.0 in the app target; verified shape from the probe)

```swift
import SwiftUI
import Charts

/// Engine (pure): the prototype's SVG geometry as scale domains. Test this, not the view.
struct TopWeightChartGeometry: Equatable {
    let xDomain: ClosedRange<Double>
    let yDomain: ClosedRange<Double>
    let baseline: Double, mid: Double, top: Double
    init(weights: [Double]) {
        let n = weights.count
        let pad = n <= 1 ? 1 : Double(n - 1) / 30           // 10 of 320 each side; a single point sits at 0 of −1…1
        xDomain = n <= 1 ? -1...1 : (-pad)...(Double(n - 1) + pad)
        let lo = (weights.min() ?? 0) - 5, hi = (weights.max() ?? 10) + 5
        let ext = (hi - lo) / 10                              // 10 of 120 pt above and below
        yDomain = (lo - ext)...(hi + ext)
        baseline = lo; mid = (lo + hi) / 2; top = hi
    }
}

struct TopWeightPoint: Identifiable { let index: Int; let date: Date; let weightLb: Double; var id: Int { index } }

struct TopWeightChart: View {
    let points: [TopWeightPoint]            // one per completed session, in date order
    let geometry: TopWeightChartGeometry
    let label: (TopWeightPoint) -> Text     // "Aug 31" / value "40 lb" come from a Shared *Text helper

    var body: some View {
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Session", p.index), y: .value("Top weight", p.weightLb))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)            // else VoiceOver reads "0 to 0.5, 40 to 40, 2 values"
            }
            ForEach(points) { p in
                PointMark(x: .value("Session", p.index), y: .value("Top weight", p.weightLb))
                    .symbol {                             // hollow r = 4, stroke 2.5, filled with the card colour
                        Circle().fill(Theme.sf)
                            .overlay(Circle().stroke(Theme.accent, lineWidth: 2.5))
                            .frame(width: 8, height: 8)
                    }
                    .accessibilityLabel(label(p))
                    .accessibilityValue(Text("\(p.weightLb, format: .number) lb"))
            }
            RuleMark(y: .value("Baseline", geometry.baseline))
                .lineStyle(StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.bd).accessibilityHidden(true)
            RuleMark(y: .value("Mid", geometry.mid))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4])).foregroundStyle(Theme.bd).accessibilityHidden(true)
            RuleMark(y: .value("Top", geometry.top))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4])).foregroundStyle(Theme.bd).accessibilityHidden(true)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: geometry.xDomain)
        .chartYScale(domain: geometry.yDomain)
        .frame(height: 120)
    }
}
```

Chip row: copy `WeekChipRow`'s body with `Capsule` chips and `ForEach(chips, id: \.exerciseId)`, keep the deferred `proxy.scrollTo(selectedId, anchor: nil)`.

Grid:
```swift
LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
    ForEach(0..<lead, id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fit).accessibilityHidden(true) }
    ForEach(1...days, id: \.self) { day in DayCell(day: day, …).aspectRatio(1, contentMode: .fit) }
}
```

## Unverified

- VoiceOver itself (device): whether `.accessibilityElement(children: .ignore)` on the chart collapses the marks, and the Audio Graph from `accessibilityChartDescriptor`. XCUITest shows neither.
- Charts' animation when the point *count* changes under `withAnimation` (only equal-count changes were recorded).
- Default axis look on iOS 26.5 (not needed; both axes are hidden).
- An empty `Chart` with `RuleMark`s and **no** explicit domain (the recipe always sets one).

## Suggested insights entries

INSIGHTS.md (architecture/pattern):
- 2026-09-16 — Swift Charts line with prototype geometry: plot by session index, hide both axes, three `RuleMark`s, and compute padded x/y domains in the Engine (`±5 lb → 10…110 of 120`, `10 of 320` x insets); the hidden-axes chart's plot equals its frame on 17.5 and 26.5, so domains alone reproduce the SVG. Hollow markers are a custom `symbol { Circle().fill(sf).overlay(stroke) }`; markers overflow the plot unclipped, like the prototype.
- 2026-09-16 — Chart accessibility recipe: `accessibilityHidden(true)` on every `LineMark`/`RuleMark`, `accessibilityLabel/Value` on each `PointMark` ("Aug 31", "40 lb"); a 200-point chart re-renders in ≈ 3 ms, no implicit animation, no `.id` on the chart.

gotchas.md:
- 2026-09-16 — **`PointMark.accessibilityLabel/Value` are ignored while an unhidden `LineMark` shares the x value** (17.5 and 26.5): Charts merges both into one "0 to 0.5, 40 to 40, 2 values" element. Hide the line (`.accessibilityHidden(true)`) and the labels apply. Recognize it: XCUITest/VoiceOver reads "N values" instead of your label.
- 2026-09-16 — **A `RuleMark` outside the scale domain is drawn outside the chart's frame** (80 pt above/below a 120 pt chart in the probe) because marks are not clipped to the plot. Keep rules inside the explicit domain, or `.clipped()`.
- 2026-09-16 — **`scrollPosition(id:)` on iOS 17.5 scrolls the id to the leading edge even when it is already visible** (chip 1 moved to x = 0; 26.5 scrolls minimally like `scrollTo(anchor: nil)`), and the binding is rewritten during user scrolls. Use `ScrollViewReader` + deferred `scrollTo(id, anchor: nil)` (`WeekChipRow`) for "scroll the selected chip into view".
- 2026-09-16 — zsh in this harness: `echo ====` fails ("=== not found", `=cmd` expansion) and an unmatched glob like `rm ui-out/*` aborts the whole command; quote or `setopt` before chaining probe runs.

## Addendum 2026-09-16 (architecture probes)

**Direct answer.** Every session-predicate shape the architecture review (B5, unverified claims 1–3) asked about compiles, fetches without crashing and returns exactly the right rows on 17.5 and 26.5: `$0.program?.archivedAt != nil`, its `flatMap` twin, and a one-query `||` of the current-program and archived-completed shapes all exclude orphans (`program == nil`) and exclude the current program where they should; only `program?.archivedAt == nil` admits orphans (re-confirmed). The per-key `LoggedExercise` predicate returns archived programs' rows once the Swift-side program filter is dropped (17 keys, fetched = ground truth on both runtimes). On 17.5 an upward `row.program?.…` hop in a fresh context costs 322–347 µs per row and is not cached between passes (150 rows ≈ 47–52 ms per `body`, three frames); on 26.5 it is 2–5 µs. `.task(id:)` restarts on every return to a `TabView` tab (the previous run is cancelled on disappear) and does not restart when the selected tab is re-tapped; identical on both runtimes.

Configuration: same scratch copy and toolchain as above (Xcode 27.0, app target Debug, `SWIFT_DEFAULT_ACTOR_ISOLATION MainActor`, deployment 17.0). Q1–Q3 are Swift Testing tests in the copy's **HomeGymLogTests** target (`Persistence/ArchProbeTests.swift`, `@MainActor`, `@testable import HomeGymLog`, real `@Model` classes, `AppSchema.makeContainer(inMemory: true)`, `TestCalendar`), one fresh in-memory store per test, each line appended to `scratchpad/ui-out/arch-Version_17.5_(Build_21F79).txt` / `arch-Version_26.5_(Build_23F77).txt` before the next fetch so a crash could not lose earlier results (none crashed: 9 tests, 20 data lines per runtime). Q4 is a `-probe tabtask` mode in the **app target** driven by XCUITest taps. Fixture per test: an archived program (`MidProgramSeed.populate`, 6 months × 5 days = 120 sessions, indexes 0–10 minus 7 completed through `WorkoutLogStore.start/finish`; `archivedAt` set by hand — probe only, the writer arrives with m4-settings), then a current program (same seed, sessions 0–2 completed), then two orphan `PlannedSession`s with `program == nil` (one completed, one pending); 242 session rows, 13 finished logs. Fetches run in a fresh `ModelContext(container)` unless stated. Probe bundles uninstalled, iPhone 17 shut down, repo untouched (`git status`: only the main session's untracked spec and this report).

### Q1 — `PlannedSession` predicates for archived programs' sessions

All compile on the iOS 27.0 SDK and fetch without throwing or crashing; results identical on 17.5 and 26.5 (expected: archived = 120, of which completed = 10; current = 120; orphans = 2):

| Predicate | total | current | archived (completed) | orphans |
|---|---|---|---|---|
| `$0.program.flatMap { $0.archivedAt != nil } == true` | 120 | 0 | 120 (10) | 0 |
| `$0.program?.archivedAt != nil` | 120 | 0 | 120 (10) | 0 |
| `$0.program?.archivedAt == nil` (reference) | 122 | 120 | 0 | **2** |
| `$0.program?.archivedAt != nil && $0.statusRaw == completedRaw` (B5(b) archived query) | 10 | 0 | 10 (10) | 0 |
| `$0.program.flatMap { $0.archivedAt != nil } == true && $0.statusRaw == completedRaw` | 10 | 0 | 10 (10) | 0 |
| `$0.program?.id == currentID \|\| ($0.program?.archivedAt != nil && $0.statusRaw == completedRaw)` | 130 | 120 | 10 (10) | 0 |
| `$0.program?.id == currentID \|\| ($0.program.flatMap { $0.archivedAt != nil } == true && …)` | 130 | 120 | 10 (10) | 0 |
| `$0.program.flatMap { $0.id == currentID \|\| ($0.archivedAt != nil && session.statusRaw == completedRaw) } == true` | 130 | 120 | 10 (10) | 0 |

So a one-hop `?.` chain with `!= nil` is safe (the existing gotcha's crash is the **two-hop** `?.` chain), a one-hop `||` disjunction is safe, and `!= nil` on the hop excludes orphans because a nil chain compares unequal to a non-nil. Recommendation stands with B5(b): two queries (current via the existing `sessionPredicate(programID:)`, archived-completed via `program?.archivedAt != nil && statusRaw == completedRaw`), with the one-query `||` verified as a fallback if a single `@Query` is ever preferred. `completedRaw` and `currentID` must be captured as locals (`SessionStatus.completed.rawValue` inline inside `#Predicate` was not tried; the existing `distantPast` gotcha suggests keeping every constant a local).

### Q2 — Per-key `LoggedExercise` fetch across programs

`exerciseKey == key && workout.flatMap { $0.finishedAt != nil } == true` (the `finishedTops` predicate, no program clause) returned, for every one of the 17 keys the current program plans, exactly the finished logs holding the key in **both** programs (fetched current/archived = traversal ground truth, e.g. `dbBench 1/1 + 3/3`, `pecDeck 1/1 + 5/5`, `rdl 2/2 + 3/3`), 0 rows whose log lacks a session or program (the fixture has none; the total rule "drop rows whose log has no session or program" in NB1(ii) is still needed for a log-only swap or a deleted session). Identical on 17.5 and 26.5. So `WorkoutSnapshotBuilder.finishedExercisePredicate(key:)` can be the one shared predicate: `finishedTops` keeps its Swift-side `log.session?.program?.id == programID`, and the Progress builder simply omits it and reads `log.session` for the program fields. The two-hop read per row (`workout?.session?.program`) is a traversal, priced under Q3; ≤ ~60 rows per key in v1.

### Q3 — Cost of `row.program?.createdAt / archivedAt` per row in `body`

`ContinuousClock` around a plain loop over the fetched rows (µs per row; 17.5 iPhone 15 simulator / 26.5 iPhone 17 simulator):

| Read | 17.5 | 26.5 |
|---|---|---|
| Scalar `statusRaw` (baseline), 242 rows, fresh context | 7.3–7.6 | 0.7 |
| `program?.createdAt` + `program?.archivedAt`, fresh context, pass 1 | **322–346** | 4.3–4.8 |
| same rows, pass 2 (cache check) | 321–353 | 2.0–2.1 |
| `program?.id` only, fresh context | 159–178 | 1.1 |
| 150 rows, fresh context, pass 1 (the question's size) | 314–347 → **47–52 ms per `body`** | 4.6–6.8 → 0.7–1.0 ms |
| `exercises` Codable decode, 150 rows (for scale) | 14.5–15.0 | 9.4–10.1 |
| the inserting context (objects registered since insert) | 33–35 | 3.1–3.3 |
| fresh context with **all** `Program` rows fetched first (`FetchDescriptor<Program>()`, RootView's `@Query` shape), pass 1 / pass 2 | 40.3 / 33.2 | 3.1 / 2.0 |
| fresh context with only the current `Program` fetched first (id predicate), hop on the 120 current rows | 326.5 | 1.9 |
| same context, hop on the 120 archived rows | 340.3 | 2.0 |

Reading: the gotcha's "~300 µs per upward to-one hop, uncached" (2026-09-11) holds on 17.5 and is now measured on `PlannedSession → Program` specifically; a second pass costs the same. On 26.5 the hop is a memory read. The one cheap 17.5 path — every `Program` fetched into the same context beforehand (33–40 µs/row) — did **not** reproduce when only the current `Program` was fetched by an id predicate (326–340 µs/row for current and archived rows alike); which of the two differences causes it (an unfiltered `FetchDescriptor<Program>()` vs an id predicate, or the extra filter pass that ran before the timing) is **unverified**, so do not design on the cheap path. Consequences for B5: (b) is right for the current rows (no hop); for the archived rows, ≤ 120 in v1 (one fully completed archived program) × 340 µs ≈ **41 ms per `body` on 17.5**, over a frame and paid on every save while the shell is mounted (NB10), so B5(c)'s escape hatch applies from day one. Cheapest shape that needs no hop at all: a `@Query` of archived programs (`archivedAt != nil`, ≤ 1 row in v1; scalar `id/createdAt/archivedAt` reads) and, in the fingerprint-keyed task, one `FetchDescriptor` per archived program with the existing `HomeSnapshotBuilder.sessionPredicate(programID:)` plus `statusRaw == completedRaw` — the program's fields come from the loop variable, the rows are scalar reads (7 µs/row), and `body` never touches `row.program`. If the archived rows must stay in `body`, read `row.program?.id` only (159–178 µs/row, ≈ 20 ms for 120 rows) and look the fields up in a dictionary built from the archived-programs query.

### Q4 — Does `.task(id:)` restart when a `TabView` tab is re-selected?

Yes, on both runtimes, with the previous run cancelled on disappear. Probe: a two-tab `TabView`; tab B's content has `.task(id: 1)` (constant id) that increments `taskRuns`, then sleeps an hour so cancellation can be counted, plus `onAppear`/`onDisappear` counters, all in tab B's `@State` and shown in a label. XCUITest taps (17.5 / 26.5 identical):

| Step | label |
|---|---|
| first tap on B | `task 1 appear 1 disappear 0 cancel 0` |
| A, then B | `task 2 appear 2 disappear 1 cancel 1` |
| A, then B again | `task 3 appear 3 disappear 2 cancel 2` |
| re-tap B while selected | `task 3 appear 3 disappear 2 cancel 2` (no change) |

The `@State` counters survived every switch, so `TabView` keeps the tab's view alive, yet each return runs `onDisappear` → `onAppear` and the task is cancelled and restarted. This settles NB6: the per-key fetch runs once per return to Progress (plus once per id change while showing); keep `held` across runs (B3) so a return never flashes the empty line, and guard the assignment with `Task.isCancelled` / the held key, since a fast tab flip cancels a run mid-fetch (a synchronous fetch still completes; only the assignment can be skipped). Availability: `.task(id:)` iOS 15.0.

### Suggested insights entries (addendum)

INSIGHTS.md:
- 2026-09-16 — Cross-program session reads: a one-hop `?.` predicate with `!= nil` (`$0.program?.archivedAt != nil`), its `flatMap` twin, and a one-query `||` over the current-program and archived-completed shapes all fetch correctly and exclude orphans on 17.5 and 26.5; only `== nil` admits orphans. Verified with the real models (`docs/reviews/m4-progress-researcher.md`, addendum Q1).
- 2026-09-16 — `.task(id:)` on a `TabView` tab restarts on every return to the tab (cancelled on disappear, `@State` kept), never on re-tapping the selected tab; verified 17.5 and 26.5 (addendum Q4).

gotchas.md:
- 2026-09-16 — **`PlannedSession → program` hop costs 322–347 µs per row on 17.5 in a fresh context, uncached across passes** (2–5 µs on 26.5); `program?.id` alone 159–178 µs. 150 rows in `body` = 47–52 ms. Fetching every `Program` into the context first dropped it to 33–40 µs, but fetching only the current one by id did not — unverified why; do not rely on it. Read program fields from a `Program` query and fetch sessions per program id instead (addendum Q3).
- 2026-09-16 — `xcodebuild -only-testing:Target/Suite/function` executes 0 tests for a Swift Testing function (no error, exit 0); select the suite (`Target/Suite`) or filter inside the suite.

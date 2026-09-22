# m4-progress — Swift concepts, for a React developer

What is new in this slice, in the order it helps to read it. Earlier notes cover `@State`, `@Binding`,
`@Query`, `.task(id:)`, `.onChange`, `FetchDescriptor`, closures, `throws` and caseless enums; those are
not repeated here.

## 1. Swift Charts: a chart is a view builder, not a config object

`Chart { }` takes marks (`LineMark`, `PointMark`, `RuleMark`) the same way a `VStack` takes views: you
write them, you do not pass a data/options dictionary.

```swift
Chart {
    ForEach(Array(points.enumerated()), id: \.offset) { i, p in
        LineMark(x: .value("Session", i), y: .value("Top weight", p.topWeightLb))
```
`Features/Progress/TopWeightChart.swift:17`. React analogy: Recharts, where `<LineChart>` takes `<Line>` and
`<ReferenceLine>` children, rather than Chart.js, where you pass one options object. **Surprise:** marks are
not clipped to the plot area. A `RuleMark` outside the scale's domain draws *outside the chart's frame*, over
whatever is next to it, so the domain must always contain every rule.

## 2. `.value("Label", x)` — plottable values carry their own name

Each mark axis takes a `PlottableValue`: a display name plus the number. The name is what a legend or
VoiceOver would use, not a data key.

```swift
PointMark(x: .value("Session", i), y: .value("Top weight", p.topWeightLb))
```
`Features/Progress/TopWeightChart.swift:27`. React analogy: `<Line dataKey="topWeight" name="Top weight" />`,
except the pair is built per point instead of being read off the row by key. **Surprise:** since the label is
per value, two marks can share an axis with different labels, and Charts will happily plot both.

## 3. `.symbol { }` — the marker is a view

A point's marker can be any SwiftUI view, which is how the prototype's hollow circle (card-coloured fill,
accent ring) is reproduced.

```swift
.symbol {
    Circle().fill(Theme.sf)
        .overlay(Circle().stroke(Theme.accent, lineWidth: 2.5))
```
`Features/Progress/TopWeightChart.swift:28`. React analogy: Recharts' `dot={<CustomDot />}`. **Surprise:**
`.frame(width: 8, height: 8)` inside the symbol sets the marker size; there is no `r` or `size` property, so
the geometry lives in the view, not in the chart's configuration.

## 4. Explicit scale domains: `chartYScale(domain:)` and `ClosedRange`

`10...110` is a `ClosedRange<Double>`, an ordinary value you can compute, store in a struct and return from
a pure function. The Engine computes the domains; the view only applies them.

```swift
.chartXScale(domain: geometry.xDomain)
.chartYScale(domain: geometry.yDomain)
```
`Features/Progress/TopWeightChart.swift:46`, built by `Engine/ProgressStats.swift:147`. React analogy: d3's
`scaleLinear().domain([lo, hi])`, computed in a selector and passed down as a prop. **Surprise:** ranges are
first-class values, so `ChartGeometry` is unit-testable with no chart and no view in the test.

## 5. Plotting by position, and `Array.enumerated()`

`enumerated()` pairs each element with its offset, and `Array(...)` makes that pairing a real array so
`ForEach` can use it. The offset — not a stored session index — is each point's identity.

```swift
ForEach(Array(points.enumerated()), id: \.offset) { i, p in
```
`Features/Progress/TopWeightChart.swift:19`. React analogy: `points.map((p, i) => <Dot key={i} … />)`.
**Surprise:** `id: \.offset` looks like the "never use the array index as a key" anti-pattern, and here it is
the *correct* choice: session indexes restart at 0 in every program, so two programs' first sessions would
otherwise collide and one dot would vanish.

## 6. `LazyVGrid`, `GridItem(.flexible())` and `.aspectRatio`

A grid is declared by its columns; `.flexible()` means "share the width equally", and `.aspectRatio(1, .fit)`
keeps each cell square.

```swift
private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
```
`Features/Progress/MonthCalendar.swift:10`. React analogy: `grid-template-columns: repeat(7, 1fr)` with
`aspect-ratio: 1`. **Surprise:** "Lazy" means cells are built as they scroll into view, so code in a cell's
body may not run until it appears — fine for 42 squares, but it is the reason a `LazyVGrid` cannot be measured
as a whole before it is laid out.

## 7. `Set` and `insert(_:).inserted` — dedupe that tells you if it was new

`Set.insert` returns a tuple whose `inserted` flag says whether the value was actually added. That is how the
chip list keeps first-seen order while skipping duplicates.

```swift
if seen.insert(exercise.exerciseKey).inserted { keys.append(exercise.exerciseKey) }
```
`Engine/ProgressStats.swift:38`. React analogy: `if (!seen.has(k)) { seen.add(k); keys.push(k) }` — two calls
in JavaScript, one here. **Surprise:** the flag makes the check a side effect *and* a test in one expression.
Readable in an `if` body; the swift review rejected the same thing hidden in a `for … where` clause.

## 8. `Dictionary(_:uniquingKeysWith:)` — building a lookup without crashing

Building a dictionary from pairs must say what to do with duplicate keys; there is no silent last-wins.

```swift
Dictionary(([current] + archived).map { ($0.id, $0.createdAt) }, uniquingKeysWith: { first, _ in first })
```
`Models/ProgressSnapshotBuilder.swift:35`. React analogy: `Object.fromEntries(pairs)`, which silently keeps the
last duplicate. **Surprise:** the plain `Dictionary(uniqueKeysWithValues:)` initializer *traps* (crashes) on a
duplicate key, so the uniquing form is the safe default whenever the input is not provably unique.

## 9. `Task.isCancelled` — the async guard that replaces an "is this still current?" ref

`.task(id:)` cancels the previous run when its id changes, but cancellation is cooperative: the old run keeps
going until it checks. The check happens before the result is stored.

```swift
guard !Task.isCancelled else { return }   // a superseded run never overwrites a newer result
```
`Features/Progress/ProgressTabView.swift:79`. React analogy: the `let cancelled = false` flag returned from a
`useEffect` cleanup, so a slow fetch cannot set state after a newer one. **Surprise:** nothing throws or stops
the function for you; without that line, tapping two chips quickly could leave the first chip's data on screen.

## 10. `accessibilityElement(children:)` — `.contain` vs `.ignore`

`.contain` keeps the children as their own elements and adds a container label around them; `.ignore` replaces
the children with one element you label yourself.

```swift
.accessibilityElement(children: .contain)
.accessibilityLabel(summary)
```
`Features/Progress/TopWeightChart.swift:49`, against `.ignore` on a day cell at
`Features/Progress/MonthCalendar.swift:61`. React analogy: an ARIA group with a label, versus
`aria-hidden` children plus one `aria-label` on the wrapper. **Surprise:** a chart's point labels are ignored
entirely while the line mark is still visible to VoiceOver — Charts merges them into one "2 values" element,
so `.accessibilityHidden(true)` on the line is what makes the dots speak.

## What to read next

- [Swift Charts](https://developer.apple.com/documentation/charts) — marks, scales and chart modifiers.
- [Audio Graphs](https://developer.apple.com/documentation/accessibility/audio-graphs) — the chart descriptor
  VoiceOver can play, the next step after per-point labels.
- [`AppStorage`](https://developer.apple.com/documentation/swiftui/appstorage) — the preferences wrapper the
  Settings slice is built on.

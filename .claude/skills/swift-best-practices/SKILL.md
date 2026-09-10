---
name: swift-best-practices
description: Apply HomeGymLog's Swift, SwiftUI, and SwiftData conventions to given files or explain them with React analogies. Use when writing new Swift code, when unsure how to structure a view or model, or to check a file against the house style. Usage: /swift-best-practices [file or topic].
---

House rules for Swift in this project (iOS 17+, SwiftUI, SwiftData). The reader knows React and
TypeScript. When invoked with a file, check it against every rule below and list violations with the
fix. When invoked with a topic, explain that section with a short example and its React analogy.

## Language

- Value types by default: `struct` and `enum` for data, `final class` only when identity or SwiftData
  requires it. Analogy: structs behave like immutable objects you spread-copy; classes are references.
- Optionals are handled with `if let` / `guard let`; no force unwrap `!` outside tests and static
  library data that is validated at startup. Analogy: `?.` and explicit null checks, never `!` assertions.
- Enums with associated values over string flags. Model mutually exclusive UI (sheets, phases, set
  status) as one enum, not several booleans.
- `let` unless mutation is needed. Small pure functions in `Engine/`; no `Date()` or `Calendar.current`
  inside Engine functions, pass them in so tests can pin them.
- Errors: `throws` with a typed `enum ...Error: Error` per module; never swallow with `try?` on a write.
- Units in names when ambiguous: `weightLb`, `restSeconds`, `weekNumber` (1-based). Doc comment on any
  public Engine function stating units and ranges.

## SwiftUI

- One screen per file in `Features/<Screen>/`. Extract a subview once `body` passes about 80 lines.
- State ownership: `@State` for view-local UI state (≈ `useState`), `@Query` for persisted reads
  (≈ a live selector over the store), `@Bindable` to edit a SwiftData object (≈ controlled input bound to
  store), `@Environment` for injected services (≈ context), `@Observable` classes for shared mutable
  state (≈ a store). Never copy a `@Query` result into `@State`.
- Sheets and alerts driven by one optional enum with `.sheet(item:)`, not stacked booleans.
- Side effects in `.task {}` (cancelled on disappear, ≈ effect with cleanup) or `.onChange(of:)`.
  Timers must be cancelled; prefer `Date`-based computation over incrementing counters so backgrounding
  does not drift.
- Theme through a single `Theme` namespace (colors, spacing, radii) in `Shared/`; no raw hex in views.
  Support Dynamic Type and both color schemes; test both in previews.
- Every view file has a `#Preview` using an in-memory model container with sample data.
- Accessibility: buttons have labels when the visible content is an icon; custom gestures (swipe to log)
  have a button alternative.

## SwiftData

- Models are `final class` with `@Model`, in `Models/`. Relationships declare a delete rule explicitly.
- Store facts, derive stats. Streak, PRs, volume, chart points are computed by `Engine/Stats` from logs.
- Writes happen in the main-actor `ModelContext` from the environment; save explicitly after a user
  action that must survive (logging a set). Do not batch user-visible writes.
- Migrations: any change to a shipped model gets a `VersionedSchema` and a `SchemaMigrationPlan`. Before
  the first TestFlight build this is relaxed; note it in `insights/`.
- Keep Engine free of SwiftData imports. Views map models to Engine value types when computing.

## Concurrency

- `async/await`, no completion handlers. UI-facing types are `@MainActor`. Avoid `Task { }` in `body`;
  use `.task`. Mark Engine types `Sendable`.

## Testing

- Swift Testing (`@Test`, `#expect`). Engine tests need no simulator UI. Fixed dates and calendars.

## Report format when checking a file

`path:line` — rule — what to change. Group by section. End with "no violations" if clean.

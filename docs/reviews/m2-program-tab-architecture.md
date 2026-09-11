# architecture-reviewer — m2-program-tab, 2026-09-11

**Verdict: approve with changes.** Data flow mirrors Home exactly (own `@Query` in init, `Program` for immutable
fields, `now` on appear/scene-active, `.id(program.id)`), no writer, window rules 5.1–5.5 verified against
`ProgramGenerator`/`Reslot` for Monday, mid-week and weekend generation and unaffected by an M4 shift (anchor = earliest
actual date, count grows by at most one). Every recomputed number (Example E windows/phases, midProgram/freshProgram
counts, week 2/3/4 targets) is right.

## Blocking (folded into the spec 2026-09-11)

- **B1** Section 3 clamped an out-of-range week while 4.1/AC-10a said DEBUG week 99 falls back to the computed value.
  One rule everywhere: a `selectedWeek` outside 1…weekCount or `selectedDay` outside 0…6 is treated as nil (follow
  today); nothing is clamped. DEBUG values are written raw and validated by the same use-time rule.
- **B2** The Release fallback rendered a blank tab after a no-op `assertionFailure` (the class the swift-reviewer
  flagged last slice). The Program tab does not need `HomeStatsInput` (no uniqueness requirement in 5.1–5.6): feed
  `HomeSnapshotBuilder.sessionSummaries(from:)` straight into `ProgramTabStats`.
- **B3** Delivery shape of `-programWeek`/`-programDay` unspecified. Use the `seedDraft` pattern: production value
  type `ProgramTabPreselection { week: Int?; day: Int? }`, an `@Entry` environment value defaulting to nil, set at the
  root only inside the existing `#if DEBUG` block, parsed by a DEBUG-only sibling of `DebugSeed`. The view has no
  `#if`; "applied on every appear" and "reset on every appear" are one write: `selection = preselection ?? followToday`.
- **B4** "Center only when off-screen" is not implementable on iOS 17 without a layout read (`scrollTo(anchor: .center)`
  and `scrollPosition(id:)` both scroll when visible; `onScrollGeometryChange` is iOS 18). **User chose minimal scroll**
  (`scrollTo(id, anchor: nil)`: scrolls the minimum to make the chip wholly visible, never when already visible).

## Non-blocking (adopted unless noted)

1. Move `ExerciseInfoSheet` from `Features/Home/` to `Shared/` (features do not reach into each other); the four
   presentation modifiers become a small Shared `View` extension.
2. `SessionCardStatus` duplicates `WeekStripState` minus `.rest` and the switch inside `HomeStats.weekStrip`. Promote
   that switch to `HomeStats.sessionState(_:today:calendar:) -> WeekStripState`, used by the strip and the card.
3. Add `CalendarRules.days(from:to:)` (`dateComponents([.day])` on start-of-day values); test across 2027-03-14
   (spring forward), which a naive `/ 86400` would pass on every seed but fail there.
4. State shape: `enum Selection { followToday, week(Int), day(week:day:) }` over two optionals (adopted).
5. Probe that `.onAppear` fires on every tab return in this shell on 17.5 and 26.5; fallback `.onChange(of: selectedTab)`.
   Record in INSIGHTS.
6. AC-11 must run with WK 24 selected: "i" → Done leaves WK 24 selected (sheet dismissal must not reset).
7. `WeekChip.phase: Phase?` — keep the nil branch to one line; no separate visual.
8. Tighten the 5.1 prose about which generations spill (any non-Monday generation whose first training day precedes
   the generation weekday).

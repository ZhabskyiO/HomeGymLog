# swift-reviewer — m2-program-tab, 2026-09-11

Release build succeeded with zero warnings; the `-programWeek` / `-programDay` / `-tab` strings appear nowhere outside
`App/DebugSeed/`. No writer in the slice, so nothing in the data-loss category.

## Findings

1. **Logic error — `defaultDay` picks the wrong day for the six days before the program's first week.**
   `ProgramTabStats.window(of:anchor:calendar:)` computed `days / 7 + 1`; Swift's `/` truncates toward zero, so
   days −1…−6 gave window 1. `initialWeek` hid it through its `max(…, 1)`, but `defaultDay`'s "today lies in this
   window" test then returned `appWeekday(today)` instead of the first session's weekday. Scenario: onboard on
   Saturday 09-12 with Mon/Wed/Fri training → every week-1 session re-slots to the week of Mon 09-14 (the anchor); on
   Sat/Sun the tab opened WK 1 with Sat 19 selected and the rest card instead of Mon 14 · "Upper A · Sep 14" (spec §6).
   **Fix applied**: `window(of:)` returns 0 for any day before the anchor; regression test with Example A generated
   Sat 09-12, `defaultDay(week: 1, today: 09-12 and 09-13) == 0`.
2. **Comments wrong in Debug**: `DebugProgramSelection.parse` returns a non-optional value, so `preselection` is never
   nil in Debug (both fields nil instead); two `///` comments said nil. **Fix applied**: parser returns nil when both
   fields are nil, comments now true.
3. **Up to three deferred scroll tasks per tab return** (two resets + the row's own `onAppear`). Idempotent minimal
   scrolls; not a bug. Optional: one `.task(id: scrollToken)` in `WeekChipRow`, re-verified by screenshot. Not changed.
4. **Readability**: tuple `min(by:)` in `defaultDay` → `HomeStats.ordered(inWindow).first`. **Fix applied**.

Manual check flagged: AC-11 (sheet dismissal keeps WK 24 · Mon 8) relies on `.onAppear` not firing on sheet dismissal;
left to the user's tap-through.

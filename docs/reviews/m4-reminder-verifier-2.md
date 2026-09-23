VERDICT: PASS

## Plan Verifier result — docs/plans/m4-reminder.md against docs/specs/m4-reminder.md (round 2, 2026-09-23)

Scope: round-1 findings 1–8 (`docs/reviews/m4-reminder-verifier-1.md`). Notes 9–10 were kept by the coordinator as
recorded. Nothing outside those findings was re-verified; the round-1 matrix and claims table stand for every other row.

### Traceability matrix (rows touched by the fixes)

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-10 | Step 1 | A's first `dateComponents` = 2026-09-16 07:00, nil zone, robust equality | grep `field by field`, `isLeapMonth` | plan 78–80: "A's first `dateComponents` has year 2026, month 9, day 16, hour 7, minute 0 and a nil `timeZone`, compared field by field (never `DateComponents ==`: `isLeapMonth` can differ …)" | covered |
| AC-12 | Step 3 | en_US 420/1110/0/720 with U+202F and U+00A0 normalised; en_GB contains "07:00" | grep `00A0`, `07:00` | plan 116–118: "`.replacingOccurrences(of: "\u{202F}", with: " ")` and then of `"\u{00A0}"` with `" "`"; "en_GB 420 contains "07:00" and " on training days"" (spec §5.3 line 219, AC-12 line 311) | covered |
| AC-14 | Steps 4, 8 | `@unknown default → .denied` pinned; reminder rows in toggle → divider → second-row order | grep `@unknown`, `ascending` | plan 130 "`@unknown default → .denied (spec §4.1)`"; 157–158 `ReminderSourceTests`: "an `@unknown default` line whose next non-blank line returns `.denied`"; 268–269 "The first `Toggle(` line comes before the `SettingsDivider()` line, which comes before the first `ReminderText.timeLabel` / `ReminderText.openSettings` / `ReminderText.allow` line (ascending line indexes, spec AC-14)" | covered |
| AC-8 | Step 6, Step 11 | code half unit-tested; live banner + synthetic `rest-timer` only in optional Step 11 | round 1 | unchanged; deferred by plan 16–17 and permitted by spec AC header line 276 | out-of-scope (live half, per plan) |
| AC-9 | Step 8, Step 11 | structure scanned; spoken labels only in optional Step 11 / MVP | round 1 | unchanged; same deferral | out-of-scope (spoken half, per plan) |

### Fix verification (findings 1–8)

| # | round-1 finding | plan now | verdict |
|---|-----------------|----------|---------|
| 1 | `ReminderRowState` case `notDetermined` vs spec `unasked` | line 90 `case off, scheduled, denied, unasked`; 101–102 "not determined → `.unasked`"; 247 `.unasked → ReminderActionRow(title: ReminderText.allow …)`. The remaining `.notDetermined` at 258 is `permission.status == .notDetermined`, a `ReminderAuthorization` value (spec §4.3 line 127) | fixed |
| 2 | only U+202F normalised | line 117 normalises U+202F then U+00A0 | fixed |
| 3 | en_GB "07:00" not asserted | line 118 `contains "07:00" and " on training days"` | fixed |
| 4 | `@unknown default → .denied` unstated | line 130 comment; 157–158 source-scan pin in `ReminderSourceTests` | fixed |
| 5 | stale "Open question" and F1–F7 as live contradictions | line 35 "`enabled && status == nil` (before the first read) renders `.scheduled` (spec §2.1, F4)"; 370 "Spec gaps found while planning — all resolved in the spec (2026-09-23), kept here for the record" | fixed (see note 1) |
| 6 | `ReminderRows.swift` order not asserted | lines 268–269 ascending-index check Toggle → divider → action/picker line | fixed |
| 7 | `DateComponents ==` may trip on `isLeapMonth` | lines 78–80 field-by-field comparison | fixed |
| 8 | `ReminderRequest` extra fields | lines 57–58 `let identifier: String; let dateComponents: DateComponents` only, matching spec §4.3 line 129 | fixed |

### Findings

1. **note** — plan line 34 still reads "**Plan choices that fill spec gaps** are F1–F4 in §5" while §5's heading (370) now
   says every gap is resolved in the spec. Harmless wording; the doc-writer can drop the sentence or say "recorded in §5".

### Implicit requirements

Unchanged from round 1: no store write, no schema change, no `Date()` / `Calendar.current` outside `AppClock`, no new
dependency, entitlement or plist key, DEBUG-only code under `#if DEBUG`, Release build and the 26.5 suite in Step 10.

### Summary

- Covered: 12 of 19 acceptance criteria (AC-1, 2, 3, 4, 10, 11, 12, 13, 14, 15; AC-8 and AC-9 code halves)
- Partial: none
- Missing: none
- Ambiguous: none
- Out of scope (per plan): AC-5, AC-6, AC-7, AC-8 live half, AC-9 spoken half (optional Step 11, else the MVP pass);
  AC-16–AC-19 (device pass)
- False claims about existing code: 0
- Traceability: plan carries AC numbers

### Questions only the user can answer

- Run optional Step 11 before the merge, or defer AC-5–AC-9 to the MVP pass? Recommended default: defer, except AC-8's
  synthetic `rest-timer` coexistence, which only Step 11 can exercise.

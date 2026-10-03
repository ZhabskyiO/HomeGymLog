VERDICT: PASS

## Plan Verifier result — docs/plans/m5-export.md against docs/specs/m5-export.md (round 2)

Scoped to round-1 findings 1–9 (`docs/reviews/m5-export-verifier-1.md`). Re-read the edited plan passages, spec AC-19 and §9, and
re-grepped the four literal scans and the four reader scans. Working tree unchanged apart from the docs (`git status`).

Correction to round 1: the line numbers I quoted for the static scans other than `SettingsScreenSourceTests` were offsets inside a
concatenated read, not file lines. The real lines are given below; nothing else in round 1 depended on them.

### Fix-by-fix

| # | round-1 severity | plan evidence | spec evidence | verdict |
|---|------------------|---------------|---------------|---------|
| 1 | blocking | Step 7 Tests: "**changed existing test** `DebugSeedTests.parses(seed:)` (`Seed/DebugSeedTests.swift:10-27`) gains `case .backupConfirm, .backupFailed, .backupRestoring: expectedDay = TestCalendar.day(2026, 9, 15)`, else its `default:` (08-31) fails three times" (plan :322-323) | AC-19: "`DebugSeedTests.parses(seed:)` (`HomeGymLogTests/Seed/DebugSeedTests.swift:10-27`) gains a case for the three `backup-*` seeds with their 2026-09-15 clock" (spec :441) | landed, consistent (the test's `default:` at `DebugSeedTests.swift:24` is the one both name) |
| 2 | should-fix | Step 1a.1: copies into `URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Support/Fixtures", isDirectory: true)` … "after `#require`ing that the path ends in `HomeGymLogTests/Support/Fixtures`" (plan :64-66) | n/a (recipe detail) | landed; the walk from `<repo>/HomeGymLogTests/Persistence/FixtureStoreWriter.swift` resolves to `<repo>/HomeGymLogTests/Support/Fixtures` |
| 3 | should-fix | Step 2: "Its `CodingKeys` (and every DTO's) have **no raw values**: the JSON key is the case name, which equals the storage key (`case appearance`, never `case appearance = "appearance"`)" (plan :110-112); `BackupSourceTests`: "no file under `Engine/Backup/` contains `"appearance"`, `"missedDayPolicy"`, `"reminderEnabled"`, `"reminderMinutes"`, `"hapticsEnabled"` or `"soundEnabled"`" (plan :161-162) | AC-19: same rule and the same six literals, "so the four reader scans stay unchanged" (spec :441) | landed, consistent; scan check below |
| 4 | should-fix | Step 3: "`insert` … calls `context.insert(row)` for **every** row, orphans included, before linking" (plan :179-180); `insertRichGraph` gains "one orphan chain: a finished log with no session (no rest instants), holding one exercise with one done set, so the round trip proves orphans survive" (plan :192) | n/a (§5.1 already tolerates nil parents) | landed; the orphan passes rules 5–11 (no rest on a finished log, no session status to mismatch) and `BackupRoundTripTests` now exercises it |
| 5 | note | Step 3: "`Persistence/StoreCommitReplaceTests` (a new file, the home of AC-16's "`StoreCommitTests` gains `replaceInScratch` cases"; the existing `StoreCommitTests.swift` is untouched)" (plan :205-206) | AC-16 still reads "`StoreCommitTests` gains …" (spec :423) | recorded in the plan as asked; the spec wording is a residual mismatch, note only |
| 6 | note | Step 8: "For the doc-writer: `docs/layout.md` rosters the new `App/RestoringView.swift` (`RootRestoreState`, `RestoringView`), `Engine/AppearanceMode.swift` (moved from `Shared/`) with `Shared/AppearanceMode+Label.swift`, and the new Backup files and fixture" (plan :341-343) | n/a | deferred to the doc-writer as the coordinator said |
| 7 | note | Step 6 `BackupSourceTests`: "every string token in `BackupRows.swift` is a `BackupText.` or `SettingsText.` member, excluding lines containing `systemName:` (AC-10)" (plan :293-294) | n/a | landed |
| 8 | note | Step 3: "The per-row parent hops (~570 for `progress-history`, ≤ ~150 ms on 17.5, gotchas SwiftData 2026-09-16) run only in the lazy export closure, never in `body`: accepted (verifier note 8)" (plan :173-174) | n/a | recorded |
| 9 | note | Step 6: "`sectionHeaders` (a strengthening, not a repair: `textMembers` never sees `BackupText.`, so the old assertion would still pass) checks the line order …" (plan :291-292) | AC-19 still reads "`.sectionHeaders` → `["programSection", "equipmentSection", "backupSection"]` … (or the test's filter widened …)" (spec :443-444) | recorded in the plan; spec wording residual, note only |

### Does "no raw values" leave the scans green?

The four literal scans match a **quoted** string on a comment-stripped code line, reading `.swift` files only:

- `SettingsSourceTests.storageKeyLiterals` — `Self.hits("\"appearance\"", …)` and `Self.hits("\"missedDayPolicy\"", …)`, each expected on exactly one
  `storageKey` line (`HomeGymLogTests/Static/SettingsSourceTests.swift:36-41`).
- `ReminderSourceTests.keyLiterals` — `("\"reminderEnabled\"", "enabledKey"), ("\"reminderMinutes\"", "minutesKey")`, hits must all be in
  `Engine/ReminderPlan.swift` on a `static let` line (`ReminderSourceTests.swift:92-96`).
- `FeedbackSourceTests.keyLiteralsOnce` — `("\"hapticsEnabled\"", "static let hapticsKey"), ("\"soundEnabled\"", "static let soundKey")`, exactly one
  hit each in `Engine/FeedbackCues.swift` (`FeedbackSourceTests.swift:176-183`).

Current app-target hits are exactly the six declaration lines (`Shared/AppearanceMode.swift:11`, `Engine/MissedDay.swift:18`,
`Engine/FeedbackCues.swift:25-26`, `Engine/ReminderPlan.swift:36-37`; the asset-catalog `"appearance"` keys are JSON, outside the `.swift`
filter). A `CodingKeys` case with no raw value is an unquoted identifier: `printf 'enum CodingKeys: CodingKey { case units, bodyWeightUnits,
appearance, missedDayPolicy, reminderEnabled, reminderMinutes, hapticsEnabled, soundEnabled }' | grep -c '"appearance"\|"reminderEnabled"\|
"hapticsEnabled"\|"missedDayPolicy"'` → `0`. So the three literal scans keep one hit each, on the same lines; Step 4's move of the `"appearance"`
line to `Engine/AppearanceMode.swift` is already in the plan and AC-19.

The four **reader** scans key on `@AppStorage(<Constant>)` tokens, not literals: `@AppStorage(FeedbackCues.hapticsKey)` /
`@AppStorage(FeedbackCues.soundKey)` (`FeedbackSourceTests.swift:187,193`), `@AppStorage(ReminderPlan.enabledKey)` /
`@AppStorage(ReminderPlan.minutesKey)` (`ReminderSourceTests.swift:102`), `@AppStorage(MissedDayPolicy.storageKey)`
(`MissedPromptSourceTests.swift:69`), `@AppStorage(AppearanceMode.storageKey)` (`SettingsSourceTests.swift:48`). `Engine/Backup/` never
declares an `@AppStorage`, so those scans change only by the `App/RootView.swift` additions Step 5 and AC-19 already list. Green.

The JSON keys still equal the storage keys because the eight property names (`units`, `bodyWeightUnits`, `appearance`, `missedDayPolicy`,
`reminderEnabled`, `reminderMinutes`, `hapticsEnabled`, `soundEnabled`, spec §5.7) are spelled identically to the `UserDefaults` keys; a
`CodingKeys: CodingKey` enum without raw values yields `stringValue` = case name, and a `: String, CodingKey` one synthesizes the same.
React analogy: a `const KEYS = { appearance: 'appearance' } as const` written once, with every consumer using `KEYS.appearance`.

### Findings

1. **note** — Spec AC-16 (:423) still says "`StoreCommitTests` gains `replaceInScratch` success and throw cases" while the plan (:205-206)
   puts them in a new `Persistence/StoreCommitReplaceTests.swift` and leaves `StoreCommitTests.swift` untouched. Same coverage; the
   doc-writer can align the spec sentence when it dates the status.
2. **note** — Spec AC-19 (:443-444) still describes `.sectionHeaders` as changing to a three-member list; the plan (:291-292) records that the
   existing assertion would pass unchanged and rewrites it as a line-order check. Cosmetic.

### Summary

- Round-1 findings resolved: 1 (blocking), 2, 3, 4 (should-fix), 7, 8, 9 (notes) in the plan; 1 and 3 also in spec AC-19; 6 deferred to the
  doc-writer in Step 8 as agreed; 5 recorded in the plan.
- Remaining: two cosmetic spec-wording notes, no should-fix, no blocking.
- False claims about existing code: 0.
- Traceability: plan carries AC numbers.

### Questions only the user can answer

- None.

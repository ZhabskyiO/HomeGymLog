VERDICT: FAIL

## Plan Verifier result — docs/plans/m5-export.md against docs/specs/m5-export.md

Round 1, 2026-09-29. Read in order: `CLAUDE.md`, `insights/INSIGHTS.md` (2026-09-29 decisions and the three 2026-09-29 Patterns
entries), `insights/gotchas.md` (all sections), the spec, the plan, `docs/reviews/m5-export-researcher.md` (Q1–Q8 and the B3
addendum), `docs/reviews/m5-export-architecture.md`; then every file the plan touches or says exists (listed under "Claims").
Working tree at `36ef597` (`git status`: only INSIGHTS, gotchas and the four untracked docs changed), so "HEAD's unversioned
schema" for Step 1a is true: `HomeGymLog/Models/AppSchema.swift:6` still reads `static let schema = Schema([`.

The plan carries AC numbers on every step. One blocking finding: an existing parameterized seed test breaks for the three new
seeds and neither AC-19 nor the plan lists it. Everything else the brief asked to check in particular holds (see the
"Particular checks" list after the findings).

### Traceability matrix

| AC | plan step | requirement (≤ 15 words) | how sought | evidence | status |
|----|-----------|--------------------------|------------|----------|--------|
| AC-1 | Step 6, 7, 9 | `settings` matches; BACKUP card below EQUIPMENT; second shot after a scroll | grep `AC-1`, `design-compare`, `2555, 4148` | Step 6 Verify names the recorded crop (`.claude/skills/design-compare/SKILL.md` "crop settings 800×290 @ (2555, 4148)" confirmed); Step 7 table row AC-1; Step 9.1 scroll or user list | covered |
| AC-2 | Step 7, 9 | `backup-confirm` dialog: title, §5.2 row 1 verbatim, destructive button, Cancel; light variant | grep `backup-confirm`, `Sep 15, 2026, 12:00 PM` | Step 7 table row AC-2 plus the 26.5 popover caveat (gotchas SwiftUI 2026-09-25); `BackupSeedTests` asserts the message equals §5.2 row 1 | covered |
| AC-3 | Step 7 | `backup-failed` shows the newer-version alert text | grep `backup-failed`, `newerFormat(2)` | Step 7 `openPreview()` sets `readError = .newerFormat(2)`; table row AC-3 | covered |
| AC-4 | Step 5, 7 | `backup-restoring`: `bg` screen, "Restoring…" centred `mu`, no pill | grep `RestoringView`, `backup-restoring` | Step 5 `RestoringView` (`Theme.bg`, `Text(BackupText.restoring)` 15 pt `Theme.mu`); Step 7 route `restore.isRestoring \|\| backupPreview == .restoring`; table row AC-4 | covered |
| AC-5 | Step 1, 4, 5, 6, 7 | every other seed unchanged | grep `baseline`, `cmp` | Step 1 baselines list (17.5 and 26.5, `defaults delete seed`, throwaway 26.5 shot per gotchas 2026-09-25); Steps 4–7 `cmp` | covered |
| AC-6 | Step 6, DoD | share sheet, file `HomeGymLog-backup-2026-09-15.json`, decodes, counts | grep `2026-09-15.json`, `BackupFileTests` | Step 6 `BackupFileTests`: pre-existing `…-09-14.json` removed, `other.json` kept, new file passes `BackupCodec.read`, `midProgram` counts (1, L, 0); sheet half in the DoD user-run list (spec: "user-run or a scratch-copy XCUITest") | covered |
| AC-7 | Step 6, DoD | picker cancel; `{"a":1}`, Benchmark, dangling, cancel dialog | grep `{"a":1}`, `Benchmark`, `danglingReference` | Step 6 `BackupImportActionTests` names all four files and the exact errors/texts; taps user-run | covered |
| AC-8 | Step 3, 5, 9, DoD | confirm lands on Home; prefs applied; archived-only → A2; in-progress → workout | grep `inProgressPredicate`, `Step 9`, `A2` | Step 3 `BackupReplaceTests` "after the sample replace, `inProgressPredicate` fetches the file's log"; Step 5 routes unchanged below the Restoring branch; Step 9.2 traced tap; the rest user-run | covered |
| AC-9 | DoD | reminders reconcile to the restored rows (device) | grep `AC-9`, `reminder` | Plan §6 "AC-9 reminders, on device"; spec marks it device-only; `ReminderHost` keyed `.id(currentPrograms.first?.id)` confirmed at `App/RootView.swift:78` | covered (user-run per spec) |
| AC-10 | Step 6, DoD | VoiceOver order; every spoken string in `BackupText`/`SettingsText` | grep `AC-10` | Step 6 `BackupSourceTests`: every string token in `BackupRows.swift` is a `BackupText.`/`SettingsText.` member (see finding 7); VoiceOver order user-run | covered |
| AC-11 | Step 1 | V1 version 1.0.0; plan one schema, no stages; fixture written once on 26.5 by HEAD, opens under V1 | grep `unversioned-1.0.0.store`, `withExtendedLifetime` | Step 1a recipe (26.5, `-parallel-testing-enabled NO`, `-wal` 0 bytes, `sqlite3` row check); Step 1b V1 verbatim from researcher Q1; `SchemaMigrationTests.fixtureOpensUnderV1` reads P 1 · S 3 · L 1 · E 2 · T 6 · N 1, note, `rpeSkipped == false`, holds the container | covered (path wording: finding 2) |
| AC-12 | Step 2 | codec round trips, sorted keys, no-fraction date, `152.49999999999997`, prefs | grep `152.49999999999997`, `bitPattern`, `distantPast` | Step 2 `BackupCodecTests` lists every AC-12 item with the spec's literals | covered |
| AC-13 | Step 2 | rules 1–11 each an exact error; tolerated → nil; rule order; §5.7 hand cases | grep `otherApp`, `"preferences": 7`, `1440` | Step 2 `BackupValidationTests` ("every §5.1 worked mutation", tolerated list, rules 2 vs 3 → `otherApp`), `BackupPreferencesTests` ("every §5.7 hand case, both seed rows, wrong-typed, `"preferences": 7`") | covered |
| AC-14 | Step 3 | store round trip byte-identical; named fields equal | grep `byte-identical`, `insertRichGraph` | Step 3 `BackupRoundTripTests` over `insertRichGraph` (sets `swappedFromKey`, RPE, `rpeSkipped`, rest instants, archived program); two encodes equal; fields listed | covered |
| AC-15 | Step 3 | replace over `midProgram`; reverse; `progress-history`; chains resolve | grep `PhaseSplit.weeks(months: 6) * 5`, `progress-history` | Step 3 `BackupReplaceTests` derives S/L/E/T from their owners; both directions; `session.program?.id` and `set.exercise?.workout?.session?.id` chains. Worked numbers re-derived below: 120/10/50/150 and 132/22/110/330 are right | covered |
| AC-16 | Step 3 | failed replace throws; old graph intact; main context clean; no `rollback()` | grep `allowsSave: false`, `replaceInScratch` | Step 3 `BackupReplaceRollbackTests` (the `ProgramArchiveRollbackTests` technique, `HomeGymLogTests/Persistence/ProgramArchiveRollbackTests.swift:23-27` confirmed) plus `StoreCommitReplaceTests`; scan pins no `rollback(` / `await` in the two bodies | covered (file name: finding 5) |
| AC-17 | Step 2, 3 | counts rows 1–3; messages; file names incl. 23:30/00:30 NY; twelve error texts | grep `23:30`, `00:30`, `twelve` | Step 2 `BackupTextTests` (fileName for 09-15, 2026-01-05, the NY pair, both DST days; rows 1–3 with U+202F/U+00A0 normalised; twelve `readFailedMessage` cases); Step 3 counts for rows 1–2 from seed rows | covered |
| AC-18 | Step 7 | seeds equal `midProgram`; preview mapping; confirm document | grep `BackupSeedTests`, `settingsBackupPreview` | Step 7 `BackupSeedTests` covers rows, `forcesMissedDayPrompt`, mapping nil for every other `allCases` entry, document at 09-15 12:00 with §5.7 prefs, `SeedNameScanTests.names` | covered (but see finding 1) |
| AC-19 | Steps 2–7 | every listed scan edit; no other existing test changes | grep each suite name; read every scan under `HomeGymLogTests/Static/` | Every AC-19 edit has a step (table under "Particular checks"). **"No other existing test changes" is false**: `DebugSeedTests.parses(seed:)` breaks (finding 1). CodingKeys literals unaddressed (finding 3) | partial |
| AC-20 | Step 8 | Release build; both suites green; `project.pbxproj` untouched; no plist/entitlement | read Step 8 | Step 8 runs the CLAUDE.md Release line and `git status --porcelain HomeGymLog.xcodeproj`; no step names `project.pbxproj`, `Info.plist` or an entitlement (`GENERATE_INFOPLIST_FILE = YES`, no plist or `.entitlements` file exists under `HomeGymLog/`) | covered |

### Claims about existing code

| plan claim | sought | found | verdict |
|------------|--------|-------|---------|
| `AppSchema.schema = Schema([six])`, `makeContainer` two lines change | read | `HomeGymLog/Models/AppSchema.swift:6-13` — `static let schema = Schema([ Program.self, … ExerciseNote.self, ])`; `try ModelContainer(for: schema, configurations: [configuration])` | true |
| `StoreCommit` has `commit`, `commitInsert`, `rehearseInsert`; `ModelContext(` only there in `Models/` | grep | `Models/StoreCommit.swift:14,27,42`; `grep "ModelContext(" Models/` → only `StoreCommit.swift:43` | true |
| `rollback()` on 2 code lines, both in `StoreCommit.swift` | grep | code lines `StoreCommit.swift:18,32`; every other hit is a `//` comment (stripped by the scan) | true |
| `delete(model:` appears nowhere under `HomeGymLog/` | grep | 0 lines | true |
| `ProgramStore.delete(_:in:)` deletes sessions, logs, exercises, sets explicitly; `current`, `currentPredicate`, `archive` exist | read | `Models/ProgramStore.swift` — `static func delete(_ program: Program, in context: ModelContext)` iterating `program.sessions` → `WorkoutLogStore.delete`; `current(in:)` with the DEBUG `assert(currentCount <= 1)`; `archive(_:at:in:)` | true |
| `WorkoutLogStore.delete(_:in:)` explicit; `finish` sets `finishedAt` + status; `setRPE` guards 6…10 | read | `Models/WorkoutLogStore.swift:370-377`, `:133-143`, `:259-260` `guard (6...10).contains(rpe)` | true |
| `ExerciseNoteStore.note` uses `fetchLimit = 1` (NB4) | grep | `Models/ExerciseNoteStore.swift:9` | true |
| `WorkoutSnapshotBuilder.inProgressPredicate` (nested `flatMap`) | read | `Models/WorkoutSnapshotBuilder.swift:20-22` | true |
| `RootView` has `@AppStorage("units")`, `AppearanceMode.storageKey`, `"bodyWeightUnits"`; routes on `activeLogs.first` / `currentPrograms.first`; `ReminderHost(...).id(currentPrograms.first?.id)`; no `FetchDescriptor` / `ModelContext(` | read | `App/RootView.swift:19-23,36-46,78`; grep count 0 | true |
| `ShellView(program:selected:)`; it calls `SettingsView(program:selectedTab:)`; both files have one `#Preview` | read | `App/ShellView.swift:10-13,44,49-59`; `Features/Settings/SettingsView.swift:118-128` | true |
| `SettingsView` reads seven `@AppStorage` keys; one `.confirmationDialog(` and one `.alert(` | read/grep | `SettingsView.swift:13-19`; `.confirmationDialog(` at 48, `.alert(` at 54 | true |
| `SettingsContent` has 8 `SettingsDivider()`, `SettingsSectionHeader`, `SettingsCard`, `equipmentCard` | grep | count 8 (4 + 2 + 2); types at `SettingsContent.swift:104-134` | true |
| `Shared/AppearanceMode.swift` is committed, holds cases, `storageKey`, `label`, `from(raw:)`, no UIKit | `git ls-files`, read | listed; `nonisolated enum AppearanceMode: String, CaseIterable, Sendable` with the three members, `import Foundation` only | true |
| `AppClock.swift` declares the nil-by-default `@Entry`s (`workoutSheetPreview`, `settingsRestartPreview` pattern) | read | `App/AppClock.swift:21-57` | true |
| `HomeGymLogApp` reads `seed.settingsRestartPreview` inside the `DebugSeed.parse(` branch, provides it once in `body` | read | `App/HomeGymLogApp.swift:62,78,131` | true |
| `DebugSeed.referenceDate` has `default:` 08-31; `initialDraft` exhaustive; `makeContainer` `default: break` (so the three seeds must be added to each) | read | `App/DebugSeed/DebugSeed.swift:83-95,104-116,119-146` | true (plan does add them) |
| `MidProgramSeed.populate`, `completedIndexes = [0…6, 8, 9, 10]`; `ProgressHistorySeed.populate` 1-month 3-day, 12 completed, archived | read | `App/DebugSeed/MidProgramSeed.swift:8,19`; `ProgressHistorySeed.swift:10-26` | true |
| `insertSampleGraph` values (09-07, months 1, freq 3, [0,2,4], 45, 180, "Intermediate", dbBench 40 / latPull 100; A/B/C 3×12 75 s; log at +3600 s, 2×3 sets; note "incline notch 2") | read | `HomeGymLogTests/Support/TestContainer.swift:24-49` | true |
| `TestCalendar` = America/New_York, `en_US_POSIX` | read | `Support/TestCalendar.swift:8-12` | true |
| 33 `ModelContainer(for: AppSchema.schema` call sites | grep | 33 | true |
| `ProgramGenerator.allowedMonths/.allowedFrequencies/.allowedSessionLengths` | grep | `Engine/ProgramGenerator.swift:60-62` (`Set<Int>`) | true |
| `ReminderPlan.validMinutes(_:) -> Int?`, `defaultMinutes = 420`, `enabledKey`, `minutesKey` | grep | `Engine/ReminderPlan.swift:35-37,72` | true |
| `FeedbackCues.hapticsKey/soundKey/defaultEnabled` | grep | `Engine/FeedbackCues.swift:25-27` | true |
| `MissedDayPolicy.storageKey`, `from(raw:)` in Engine | grep | `Engine/MissedDay.swift:14-24` | true |
| `SettingsText.cancel/ok/programSection/equipmentSection` | grep | `Shared/SettingsText.swift:16,24,27,29` | true |
| `SplitPlans.exerciseCount(sessionLengthMinutes:) -> Int?` (45 → 5); `PhaseSplit.weeks(months:)` = 4/month; `Phase.foundation.sets` = 3 | read | `Engine/SplitPlans.swift:85-92`; `PhaseSplit.swift:13-15`; `EngineTypes.swift:15-22` | true |
| `WorkoutSheetPreview` is a production enum (pattern for `BackupPreview`) | grep | `Features/Workout/WorkoutSheet.swift:27` | true |
| `PlannedExercise` is `Codable` (reused in the DTO) | grep | `Engine/EngineTypes.swift:84` `Codable, Hashable, Sendable` | true |
| `SettingsScreenSourceTests.filesScanned` (five files), `.dividerCount == 8`, `.sectionHeaders`, `.noLiteralCopy` (`Text("`, `Button("`, `Label("`) | read | `HomeGymLogTests/Static/SettingsScreenSourceTests.swift:48-53,99-119` | true |
| `SettingsSourceTests.storageKeyLiterals` pins `"appearance"` to `Shared/AppearanceMode.swift`; `.appearanceMechanism` filter names that path; `.appearanceReaders` two files; `.rootViewHasNoFetch` | read | `SettingsSourceTests.swift:259-306` | true |
| `ReminderSourceTests.preferenceReaders` = host + Settings | read | `ReminderSourceTests.swift:100-107` | true |
| `FeedbackSourceTests.hapticsReaders`, `.soundReaders`, `functionBody(_:in:)` | read | `FeedbackSourceTests.swift:255-259,332-343` | true |
| `MissedPromptSourceTests.policyReaders` "exactly two files"; `automaticPassIsSynchronous` | read | `MissedPromptSourceTests.swift:439-465` | true |
| `StoreCommitSourceTests.scratchContextsOnlyInStoreCommit`; `FailedSavePolicySourceTests.rollbackOnlyInStoreCommit == 2` | read | `StoreCommitSourceTests.swift:386-396`; `FailedSavePolicySourceTests.swift:449-453` | true |
| `SeedNameScanTests.names` list; `settingsEnvironmentWiring` shape | read | `SeedNameScanTests.swift:475-481,546-561` | true |
| `-probeLog` precedent (INSIGHTS 2026-09-14) | grep | `insights/INSIGHTS.md:1014` | true |
| "No other existing test changes" (spec AC-19; plan lists no other) | read every `Seed/`, `App/`, `Static/` test that enumerates `DebugSeed.allCases` | `HomeGymLogTests/Seed/DebugSeedTests.swift:10-27` — `@Test(…, arguments: DebugSeed.allCases) func parses(seed:)` with `default: expectedDay = TestCalendar.day(2026, 8, 31)` | **false** (finding 1) |

### Findings

1. **blocking** — `DebugSeedTests.parses(seed:)` fails for the three new seeds and no step edits it. Evidence:
   `HomeGymLogTests/Seed/DebugSeedTests.swift:10-27` is parameterized over `DebugSeed.allCases` and its `switch` ends in
   `default: expectedDay = TestCalendar.day(2026, 8, 31)`, then `#expect(seed.referenceDate(calendar: cal) == expectedDay + 12 h)`.
   Plan Step 7: "Each has reference date 09-15 12:00" (required: the confirm message reads "Sep 15, 2026, 12:00 PM"). So
   `backup-confirm`, `backup-failed`, `backup-restoring` hit `default` and the test fails three times; Step 7's `T17 test`
   cannot be green, and spec AC-19's "No other existing test changes" is false. Fix: Step 7 adds
   `case .backupConfirm, .backupFailed, .backupRestoring: expectedDay = TestCalendar.day(2026, 9, 15)` to that switch and AC-19
   lists `DebugSeedTests.parses`. (Checked the other `allCases` filters: `ReminderSeedTests:41`, `RestartSeedTests:21`,
   `DebugSeedTests:86-101` all expect nil/false for unlisted seeds, which the new seeds satisfy.)
   React analogy: a table-driven test with a catch-all row; a new enum case lands in the wrong row.

2. **should-fix** — Step 1a's fixture destination is ambiguous where the brief wants it exact. Evidence: plan Step 1a.1 "copies
   `.store`, `-wal` and `-shm` to `../../Support/Fixtures/` relative to `#filePath`". Relative to the file's directory
   (`<repo>/HomeGymLogTests/Persistence/`) that is `<repo>/Support/Fixtures/`, outside the test target; relative to the file path
   itself it is the intended `<repo>/HomeGymLogTests/Support/Fixtures/`. Fix: spell it as the scans do
   (`URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Support/Fixtures", isDirectory: true)`,
   the same walk `SettingsScreenSourceTests.appSourceRoot` uses at `:11-15`) and `#require` the path ends in
   `HomeGymLogTests/Support/Fixtures`. The rest of the recipe is exact and correct: 26.5 runtime, `-parallel-testing-enabled NO`,
   suite-level `-only-testing`, `-wal` 0-byte check with a `wal_checkpoint(TRUNCATE)` fallback, `sqlite3 … ?immutable=1` row
   check with a `.tables` fallback, and the writer file deleted before 1b (`/usr/bin/sqlite3` present).

3. **should-fix** — Six preference-key literals are pinned to one line each by four scans, and Step 2's hand-written `Codable`
   needs a `CodingKeys` enum whose cases could carry them. Evidence: `SettingsSourceTests.storageKeyLiterals:263-268`
   (`"appearance"` → `Shared/AppearanceMode.swift` only, `"missedDayPolicy"` → `Engine/MissedDay.swift` only),
   `ReminderSourceTests.keyLiterals:93-96` (`"reminderEnabled"`, `"reminderMinutes"` → `Engine/ReminderPlan.swift` only),
   `FeedbackSourceTests.keyLiteralsOnce:322-329` (`"hapticsEnabled"`, `"soundEnabled"` → `Engine/FeedbackCues.swift` only).
   Plan Step 2: "A hand-written `init(from:)` … `BackupPreferences` holds eight optionals, each decoded with `try? decodeIfPresent`".
   A `case appearance = "appearance"` in `Engine/Backup/BackupDocument.swift` breaks all four scans. Fix: state "CodingKeys
   without raw values (JSON key = property name)" in Step 2 and add a `BackupSourceTests` check that no file under
   `Engine/Backup/` contains any of the six quoted literals.
   React analogy: a lint rule that a config key string may be spelled in exactly one module.

4. **should-fix** — Orphan rows are validated as legal but the insert path only names orphan sessions. Evidence: spec §5.1
   "Tolerated on purpose: … nil parent ids (orphans, as the schema allows)"; plan Step 3 `insert`: "a session is appended to its
   program, or inserted as an orphan; a log is linked with `session.workoutLog = log`; exercises are appended to their log, and
   sets to their exercise". A log, exercise or set with a nil parent id is never `context.insert`ed under that description, so it
   silently vanishes on import, and no planned test has an orphan (`insertRichGraph` has none; AC-13's orphan case is
   validation-only). Fix: `insert` calls `context.insert(row)` for every row before linking (idempotent for rows that a
   relationship append would also insert), and `insertRichGraph` gains one orphan log so `BackupRoundTripTests` proves it.

5. **note** — AC-16 says "`StoreCommitTests` gains `replaceInScratch` success and throw cases"; plan Step 3 puts them in a new
   `Persistence/StoreCommitReplaceTests.swift`. Same coverage; record the deviation or fold them in.

6. **note** — Spec §4.5 places the restore state and the "Restoring…" route in `App/RootView.swift`; plan Step 5 adds
   `App/RestoringView.swift` holding `RootRestoreState` and `RestoringView`. Right layer, harmless; `docs/layout.md` will need
   both it and the `Shared/AppearanceMode.swift` → `Engine/` move (doc-writer).

7. **note** — Step 6's AC-10 scan "every string token in `BackupRows.swift` is a `BackupText.` or `SettingsText.` member" will
   match `Image(systemName: "doc.text")` in the same file (Step 6 `SharePreview(…, image: Image(systemName: "doc.text"))`).
   Exclude `systemName:` lines or move the glyph name into `BackupText`.

8. **note** — `BackupSnapshotBuilder` hops `session.program?.id`, `exercise.workout?.id`, `set.exercise?.id` per row (gotchas
   SwiftData 2026-09-16: a session → program hop is ~330 µs on 17.5, not cached). For `progress-history` that is ~570 hops,
   tens to ~150 ms, inside the lazy export closure and never in `body`, so it is acceptable; walking each parent's to-many
   collection and carrying the parent id down avoids it if the export ever feels slow. No scan forbids the hop there
   (`ProgressSourceTests` scans only `ProgressSnapshotBuilder.swift` and `Features/Progress/`).

9. **note** — `SettingsScreenSourceTests.sectionHeaders` does not break as spec AC-19 implies: `textMembers` collects
   `SettingsText.` members only (`:34-46`), so `BackupText.section` is invisible to it and `["programSection", "equipmentSection"]`
   stays true. The plan's Step 6 rewrite to a line-order check is a strengthening, not a repair; fine either way.

### Particular checks the brief asked for

- **Step 1 fixture on HEAD's unversioned schema, WAL handled, recipe exact.** Yes, except the path wording (finding 2):
  1a runs before 1b, on 26.5, with the `-wal` size check and checkpoint fallback, three files copied, writer deleted.
- **`AppSchemaV1` matches the researcher's probed shape.** Yes: plan Step 1b quotes Q1 verbatim (`versionIdentifier =
  Schema.Version(1, 0, 0)`, `static var models` of the six top-level classes, `AppMigrationPlan.schemas = [AppSchemaV1.self]`,
  `stages = []`, `Schema(versionedSchema:)`, `migrationPlan:` passed).
- **`StoreCommit.replaceInScratch`**: signature matches spec §4.5 and B2; body "`let scratch = ModelContext(container); try
  write(scratch); try scratch.save()` — no catch, no rollback()"; `BackupStore.deleteAll` is §5.4 steps 1–3 through
  `ProgramStore.delete` / `WorkoutLogStore.delete` and per-row `context.delete`, never `delete(model:)`; "all synchronous, with no
  `await`"; Step 3 scans pin no `delete(model:` anywhere and no `await`/`rollback(` in `func replaceAll(` / `func replaceInScratch(`.
- **Handler never reads a `@Query` after the save.** Step 5 snippet reads only `document.preferences?.resolved()` between
  `replaceAll` and `restore = .idle`; the failure branch sets `.failed` and returns; a line-range scan pins no `currentPrograms`,
  `activeLogs`, `.first` in that range (the `FeedbackSourceTests.skipOrder` shape, `:284-294`).
- **Every existing test AC-19 lists is touched; no other breaks unlisted.** Listed edits all have a step: `filesScanned`,
  `dividerCount`, `sectionHeaders` (Step 6); `preferenceReaders`, `hapticsReaders`, `soundReaders`, `policyReaders` (Step 5);
  `storageKeyLiterals`, `appearanceMechanism` (Step 4); `SeedNameScanTests.names` (Step 7). Unlisted break: finding 1.
  Unlisted risk: finding 3.
- **Seeds build their documents in DEBUG `onAppear`, never `body`.** Yes: Step 7 "`.onAppear { openPreview() }` runs the
  preview, never `body` (NB6)"; the preview enum is nil-by-default `@Entry` set only inside `DebugSeed.parse(`. `SettingsContent`
  is a plain `VStack` in a `ScrollView` (`SettingsContent.swift:25`), so the off-screen row's `onAppear` does fire; the plan's
  `.task` fallback covers the unverified case.
- **Nothing edits `project.pbxproj`, Info.plist or entitlements.** No step names them; Step 8 checks `git status --porcelain
  HomeGymLog.xcodeproj` is empty; `GENERATE_INFOPLIST_FILE = YES` and no `.plist`/`.entitlements` file exists under `HomeGymLog/`.
  The only git action is `git mv` of a committed file (Step 4), which stages a rename and commits nothing.
- **Commands match `CLAUDE.md`.** `T17`/`T26` are the CLAUDE.md destinations with the OS given (two "iPhone 17" devices exist,
  so `OS=26.5` is required and present); Step 8's result-bundle, `xcresulttool … summary` and Release lines are verbatim.
- **Each step builds green on its own.** Step 2 compiles with `AppearanceMode` still in `Shared/` (same module); Step 3 uses
  Step 2 types; Step 5 adds `onRestore` to `ShellView`/`SettingsView` with both `#Preview`s updated and `SettingsView` merely
  storing it until Step 6; Step 6 depends on Steps 2–5; Step 7's `BackupPreview` enum, `@Entry`, `DebugSeed` cases
  (`referenceDate`, exhaustive `initialDraft`, `makeContainer`) and `HomeGymLogApp` wiring all land together. Step 7's test run
  is the one that fails without finding 1's edit.

### Worked numbers re-derived from code

- `midProgram`: S = `PhaseSplit.weeks(6)` 24 × 5 = 120; L = `completedIndexes.count` = 10; E = 10 × `exerciseCount(45)` 5 = 50;
  T: indexes 0–10 are weeks 1–3, Foundation weeks for 24 = (23 × 35 + 99) / 100 = 9, `Phase.foundation.sets` = 3 → 150; N 0.
- `progress-history`: + 12 sessions, 12 logs, 60 exercises; sets = 6·5·3 + 3·5·4 + 3·5·2 = 180 (Foundation (3·35+99)/100 = 2
  weeks, Peak (3·25+99)/100 = 1) → P 2 · S 132 · L 22 · E 110 · T 330. Spec §5.2 rows 1–2 and plan Step 3 agree.
- Sample graph: P 1 · S 3 · L 1 · E 2 · T 6 · N 1, log unfinished → counts (1, 0, 1). Agree.

### Implicit requirements

| concern | sought | finding | status |
|---------|--------|---------|--------|
| Persistence timing | plan Steps 3, 5 for "save" | Import is one `save()` in `replaceInScratch`; export writes no row; a kill before the save leaves everything (spec §3) | addressed |
| Delete rules | plan §4 Data model changes | No new relationship or field; `AppSchemaV1` freezes the six classes | addressed (n/a) |
| Units | grep `kg`, `Lb` in plan | Every DTO weight is `*Lb`; §4.3 "Weights are pounds everywhere"; `units: "kg"` is a display preference only | addressed |
| Date determinism | grep `Date()`, `Calendar.current`, `clock.now()` | Engine takes `calendar:`/`locale:`; `BackupFile` reads `clock.now()` once; `ClockUsageTests` stays green; ISO 8601 formatter is UTC by default | addressed |
| Concurrency | grep `MainActor.run`, `Task.detached`, `ModelContext` | Store reads inside `MainActor.run`; coordinated file read in `Task.detached`; the scratch context is created and saved on the main actor in one pass | addressed |
| Availability | plan Step 6 APIs vs researcher §5–6 | `ShareLink` 16, `FileRepresentation` 16, `.suggestedFileName { }` 17.0, `.fileImporter` 14, `VersionedSchema` 17.0, `nonisolated(unsafe)` Swift 5.10 | addressed |
| Privacy label | grep `plist`, `entitlement`, `contentModificationDateKey` | None added; NB5 name-match cleanup with `includingPropertiesForKeys: nil` and a scan forbidding the two timestamp keys | addressed |
| Resume and empty states | spec §3, §6; plan Step 5 routes | Empty backup → onboarding at A1; archived-only → A2 prefilled; in-progress log → workout; kill mid-restore → old rows | addressed |

### Scope creep

- `App/RestoringView.swift` as its own file (finding 6), `Persistence/StoreCommitReplaceTests.swift` (finding 5),
  `BackupText.isBackupFileName(_:)`, `BackupCodec.decodingDetail` and several `BackupSourceTests` assertions beyond AC-19's list
  (`beginRestore` order, no `UserDefaults` in `RootView`, `@Entry` line shape). All test-side or layer-neutral; no dependency,
  model, entitlement or capability is added. Step 9 is optional and spec-sanctioned (AC-1, planner 4).

### Summary

- Covered: 19 of 20 acceptance criteria (AC-9 is user-run by the spec's own wording)
- Partial: AC-19
- Missing: none
- Ambiguous: none
- Out of scope (per plan): none
- False claims about existing code: 1 ("no other existing test changes" — `DebugSeedTests.parses`)
- Traceability: plan carries AC numbers

### Questions only the user can answer

- None. (Findings 5 and 6 are file-placement deviations the planner may simply record.)

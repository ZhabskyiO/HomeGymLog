# Plan — m5-export (JSON backup, replace-import, frozen `AppSchemaV1`)

Spec `docs/specs/m5-export.md` (approved 2026-09-29), branch `m5-export`; reports `docs/reviews/m5-export-researcher.md` (Q1–Q8, B3 addendum),
`…-architecture.md` (folded in), `…-verifier-1.md` (round 1 fixed). Code read: every file each step touches, and every scan AC-19 names.

## Spec issues

1. **Who reads the preferences.** §4.5 has the export row read the eight `@AppStorage` values. That would add `BackupRows.swift` to four reader scans
   (`ReminderSourceTests.preferenceReaders`, `FeedbackSourceTests.hapticsReaders` / `.soundReaders`, `MissedPromptSourceTests.policyReaders`), but
   AC-19 lets those scans gain only `App/RootView.swift`. **Plan:** `SettingsView` already reads seven of the keys. It adds
   `@AppStorage("bodyWeightUnits")`, which no scan pins, builds `BackupPreferences`, and passes it down as a value.
2. **Dates without a fraction.** §5.6 names one `ISO8601DateFormatter` with `.withFractionalSeconds`. AC-12 wants `"2026-09-15T12:00:00Z"` to decode,
   and that formatter is believed to reject it (unverified: the researcher probed only `.iso8601`). **Plan:** decode with the fractional formatter,
   then fall back to a plain `[.withInternetDateTime]` one. The encoder always writes the fraction; AC-12's test decides.
3. **Where the card is drawn.** §4.5 puts "the card" in `BackupRows.swift`, but AC-19 makes `SettingsContent`'s `.dividerCount` go from 8 to
   9. **Plan:** `SettingsContent` draws the header, the card and its one divider. `BackupRows.swift` declares the two rows, and the restore row owns
      the importer, dialog and alert. `SettingsView` keeps one `.alert(` and one `.confirmationDialog(`.
4. **Two checks need a scroll.** AC-1's second shot "after scrolling" and AC-2's "BACKUP card behind it" both need one, and taps are refused on this
   machine. **Plan:** the optional Step 9 XCUITest covers them; otherwise they are user-run.
5. **AC-8's "`wo-start` rows exported" cannot be produced in the UI**, because Settings is not mounted during a workout. **Plan:** Step 3 tests the
   data half; the device check needs a hand-made file.
6. **AC-19's `.noLiteralCopy` widening is a no-op.** The scan only rejects `Text("`, `Button("` and `Label("`.
7. **§4.4's sort is not total for orphans**, for example two orphan sessions that share an index. **Plan:** every table sorts with `id.uuidString` as
   the last key, so AC-14's byte-identical re-export holds.

## 1. Goal and scope

Export everything the store holds, plus the eight preferences, as one sorted, pretty-printed JSON file through the share sheet. Import such a file
with `.fileImporter`: decode and validate it fully in Engine, confirm, then replace the whole store in one save on a scratch context. The root shows
"Restoring…" during the save, then lands on Home, A2 or the workout by the existing routes. The schema is frozen as `AppSchemaV1` with an empty
migration plan, and a committed fixture proves that an unversioned store opens under it.

**Out of scope** (spec §7): CSV; merge or selective import; CloudKit; a custom UTType or document types; restoring the notification permission; a
"Last backup" row; a read spinner; time-zone re-anchoring; encryption; automatic backups; V2 or any migration stage; deleting the temp file after a
share; localisation. No AC is excluded.

## 2. Decisions this plan relies on

- **INSIGHTS 2026-09-29 "M5 export decisions".** Product: the card goes under EQUIPMENT; the backup is complete, preferences included; import
  replaces and never merges; the app lands on Home. Review: B1 moves `AppearanceMode` to Engine and makes `label` a Shared extension. B2 has
  `StoreCommit.replaceInScratch` open the scratch context. B4 hands the document up through an `onRestore` closure; B3 (resolved): a plain flag
  cleared in one synchronous handler, with no `@Query` read after the save.
- **INSIGHTS Patterns 2026-09-29.** V1 retrofit (Q1), whole-store replace (Q3), and the DTO mirror with `ShareLink` / `.fileImporter` (Q2, Q5–Q7).
  Also used: explicit delete helpers (2026-09-10); `allowsSave: false` for failed saves (2026-09-13); nil-by-default `@Entry` (2026-09-11); real-touch
  probes (2026-09-13); non-Swift test inputs through `#filePath` (2026-09-27); spec §5.1–§5.7 and AC-19's scan list.
- **Fixture bundling.** Non-Swift files in the synchronized `HomeGymLogTests/` folder are copied into the test bundle. That is verified for `.json`
  only (researcher §8, both runtimes); for `.store`, `-wal` and `-shm` it is unverified. So the fixture is read through `#filePath` (NB3), and
  bundling does not matter. Step 1's build proves the files break nothing.
- **Open questions: none.** One default is taken: rule 11's rest check covers only logs that have a `sessionID`, so a finished orphan log is tolerated
  like any other orphan.

**Commands.** `T17` = `xcodebuild -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath
build/DerivedData`; `T26` = the same with `name=iPhone 17,OS=26.5`. Focused runs add `-only-testing:HomeGymLogTests/<Suite>` (suite level only,
gotchas Xcode 2026-09-16 / 2026-09-29) under the watchdog (gotchas 2026-09-23).

## 3. Steps

### Step 1 — Fixture store, `AppSchemaV1`, migration plan, schema tests (AC-11; AC-5 baselines)

**1a. Write the fixture once, from HEAD's unversioned schema, on 26.5, before any V1 code exists.**
1. Create the throwaway `HomeGymLogTests/Persistence/FixtureStoreWriter.swift`, containing `@MainActor @Suite struct FixtureStoreWriter` with `@Test
   func writeUnversionedFixture() throws`. The test: inside a `do {}` scope, opens `ModelContainer(for: AppSchema.schema, configurations:
   [ModelConfiguration(schema: AppSchema.schema, url: <tmp>/unversioned-1.0.0.store)])` and runs `try insertSampleGraph(in: ModelContext(container))`,
   the source of P 1 · S 3 · L 1 · E 2 · T 6 · N 1; after the scope ends, copies `.store`, `-wal` and `-shm` into `URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
   .appendingPathComponent("Support/Fixtures", isDirectory: true)` (the `SettingsScreenSourceTests.appSourceRoot` walk; created if absent), after
   `#require`ing that the path ends in `HomeGymLogTests/Support/Fixtures`; `#require`s each copied file, and records the `-wal` size in the `#expect` comment.
2. Run `T26 -parallel-testing-enabled NO -only-testing:HomeGymLogTests/FixtureStoreWriter test`. With parallel testing off, the run uses the real
   device rather than a clone.
3. `ls -l HomeGymLogTests/Support/Fixtures/` must list three files. The `-wal` should be 0 bytes on 26.5 (gotchas SwiftData 2026-09-29). If it is not,
   run `sqlite3 <store> "PRAGMA wal_checkpoint(TRUNCATE);"`.
4. Check the rows without modifying anything: `sqlite3 "file:HomeGymLogTests/Support/Fixtures/unversioned-1.0.0.store?immutable=1" "SELECT COUNT(*)
   FROM ZPROGRAM; SELECT COUNT(*) FROM ZLOGGEDSET; SELECT ZTEXT FROM ZEXERCISENOTE;"` must print `1`, `6` and `incline notch 2`. If the table names
   differ, list them with `.tables`.
5. Fallback if the test cannot write to the repo path (unverified; the precedent is `-probeLog`, INSIGHTS 2026-09-14): write to the app's `tmp/` and
   copy the files out through `xcrun simctl get_app_container <udid> com.zhabskyi.homegymlog.ios data`.
6. Delete `FixtureStoreWriter.swift` by hand (it was never committed). The fixture is committed with the slice and **never regenerated**.

**1b. Freeze the schema.** New `Models/AppSchemaV1.swift`, researcher Q1 verbatim: `enum AppSchemaV1: VersionedSchema` with `versionIdentifier =
Schema.Version(1, 0, 0)` and `static var models` listing the six top-level classes; `enum AppMigrationPlan: SchemaMigrationPlan` with `schemas =
[AppSchemaV1.self]` and `stages = []`; `Models/AppSchema.swift` changes two lines: `static let schema = Schema(versionedSchema: AppSchemaV1.self)`,
and `try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])`.

**Tests.** New `HomeGymLogTests/Persistence/SchemaMigrationTests.swift` (`@MainActor`): `AppSchema.schema.version == Schema.Version(1, 0, 0)`;
`AppMigrationPlan.schemas.count == 1` and `stages.isEmpty`; `String(describing:)` over `AppSchemaV1.models` equals six literal class names;
`fixtureOpensUnderV1`: copy the three `#filePath` files (never `Bundle.main`) to a temp directory; open the copy with `ModelContainer(for:
AppSchema.schema, migrationPlan: AppMigrationPlan.self, configurations: [ModelConfiguration(schema: AppSchema.schema, url:)])`; read through a fresh
context: P 1 · S 3 · L 1 · E 2 · T 6 · N 1, the note `"incline notch 2"`, and `rpeSkipped == false` on every set; hold the container with
`withExtendedLifetime`, leave nothing pending, then remove the directory.

**Verify.** `T17 build`, `T17 test` and `T26 test`. The 33 `ModelContainer(for: AppSchema.schema, …)` call sites stay untouched; the fixture test must
pass on both runtimes. A 26.5-written store opening on 17.5 is unverified; if it fails there, stop and report, because a per-runtime fixture is a spec
change.

**AC-5 baselines**, taken now, before anything visible changes: For each launch below, on iPhone 15 / 17.5: `simctl spawn <udid> defaults delete
seed`, launch, wait 3 s, then screenshot to `build/m5-export-baseline/17/<name>.png`; the launches: `midProgram`, alone and with each of `-tab
program`, `-tab progress`, `-tab settings`, `-units kg`, `-appearance light`; `missed`, `onboarding`, `ob1`…`ob5`; every workout seed; `reminder-*`
and `settings-restart`, each with `-tab settings`; `restarted`; repeat on iPhone 17 / 26.5 into `…/26/`, after one throwaway shot (gotchas Xcode
2026-09-25).

### Step 2 — Engine codec, validation, preferences, `BackupText` (AC-12, AC-13, AC-17, part of AC-19)

Every type here is `nonisolated` (the Engine convention) and every file imports only Foundation. `ResolvedPreferences` names `AppearanceMode`, which
stays in `Shared/` until Step 4; that still compiles because both are in the same module.

**`Engine/Backup/BackupDocument.swift`** `BackupDocument: Codable, Equatable, Sendable` has these fields: `app`, `formatVersion`, `exportedAt: Date`,
the six DTO arrays (`programs`, `sessions`, `workoutLogs`, `loggedExercises`, `loggedSets`, `exerciseNotes`), and `preferences: BackupPreferences?`;
It also has `currentFormatVersion = 1`, `appName = "HomeGymLog"`, and `counts: (programs:, workouts:, notes:)`, where workouts counts logs with
`finishedAt != nil`; A hand-written `init(from:)` decodes `preferences` as `(try? c.decodeIfPresent(…)) ?? nil`, so a non-object reads as absent.
`encode` is synthesized and omits nils; DTO property names are the §4.3 keys. `phase` and `status` are raw strings, parent ids are optional, and
`exercises` is `[PlannedExercise]`; `BackupPreferences` holds eight optionals, each decoded with `try? decodeIfPresent`. Its `CodingKeys` (and every DTO's) have **no raw
values**: the JSON key is the case name, which equals the storage key (`case appearance`, never `case appearance = "appearance"`), so the six quoted
key literals the four reader scans pin stay on their one `storageKey` line. `resolved() ->
ResolvedPreferences` falls back per key:

  | Key | Fallback |
  |---|---|
  | units | `WeightUnit(rawValue:) ?? .lb` |
  | appearance | `AppearanceMode.from(raw:)` |
  | missed-day policy | `MissedDayPolicy.from(raw:)` |
  | reminder minutes | `ReminderPlan.validMinutes(_:) ?? ReminderPlan.defaultMinutes` |
  | reminder enabled | `false` |
  | haptics, sound | `FeedbackCues.defaultEnabled` |

`ResolvedPreferences: Equatable` has `static let defaults`.

**`Engine/Backup/BackupValidation.swift`** `enum BackupReadError: Error, Equatable` has §4.5's twelve cases; `BackupValidation.validate(_:) ->
BackupReadError?` runs rules 5–11 in order, visiting tables in §4.3 order and rows in array order, so the first failure is deterministic; it reuses
`ProgramGenerator.allowedMonths`, `.allowedFrequencies` and `.allowedSessionLengths`, and `6...10` for RPE (the range `WorkoutLogStore.setRPE`
guards); duplicates are found with `Set`s, never `Dictionary(uniqueKeysWithValues:)` (gotchas Swift 2026-09-11); the `invalidValue` field is the DTO
property name. Repeated exercise orders report `"exercises"`; a duplicate note reports `invalidValue("exerciseNotes", <second id>, "exerciseKey")`.

**`Engine/Backup/BackupCodec.swift`** `encode(_:) throws -> Data` sets `outputFormatting = [.sortedKeys, .prettyPrinted]` on one line, with a
`.custom` fractional date strategy; the decoder's `.custom` strategy tries the fractional formatter, then the plain one, and otherwise throws
`dataCorrupted`; `read(_:) throws -> BackupDocument` goes in this order: Decode a private `Header { app; formatVersion }`; a failure is `.notABackup`;
Check `app`; A version above 1 is `.newerFormat`; below 1 is `.undecodable("formatVersion")`; decode the full body; a failure is
`.undecodable(decodingDetail(error))`; run `validate`; `decodingDetail` joins the coding path with "." (a key's `intValue` if it has one, else its
`stringValue`) plus the missing key, and never uses the runtime's text. So a missing table gives `"sessions"`, and a string `months` gives
`"programs.0.months"`.

**`Shared/BackupText.swift`** The §4.5 constants, including `fileNamePrefix = "HomeGymLog-backup-"`, the only place that literal appears;
`fileName(date:calendar:)`, from the calendar's year, month and day via `String(format: "%04d-%02d-%02d")`; `isBackupFileName(_:)` and
`readFailedMessage(_:)`; `confirmMessage(exportedAt:programs:workouts:notes:calendar:locale:)`: the abbreviated date and shortened time in the
calendar's zone, with singular or plural nouns.

**Fixture `HomeGymLogTests/Support/BackupFixtures.swift`**: `sampleDocument()` and `mutated(_:)`. The values are copied from `insertSampleGraph`
(`TestContainer.swift`):
- program: 09-07, months 1, frequency 3, weekdays [0,2,4], 45 min, 180 lb, "Intermediate", dbBench 40 / latPull 100;
- sessions 0–2 on 09-07/09/11: "Full Body A/B/C", 3 × 12, 75 s;
- one log at 09-07 + 3600 s on session 0, with 2 × 3 sets;
- the note "incline notch 2"; UUIDs are fixed literals, and `exportedAt` is 2026-09-29 09:05 in `TestCalendar`.

**Tests** (plain suites) `Engine/BackupCodecTests` (AC-12): sorted keys and the exact §4.4 key set; `read(encode(d))` re-encodes to the same bytes;
whole-second dates stay exact, and `distantPast` survives; `".123Z"` decodes within 0.001 of a UTC `DateComponents` date; the no-fraction date
decodes; `152.49999999999997` keeps its `bitPattern`; `preferences` with all eight keys, and nil; `Engine/BackupValidationTests` (AC-13): every §5.1
worked mutation gives its exact error; each tolerated case gives nil; a file failing rules 2 and 3 gives `otherApp`; both detail strings;
`Engine/BackupPreferencesTests`: every §5.7 hand case, both seed rows typed out, a wrong-typed field, and `"preferences": 7`;
`Engine/BackupCountsTests`: §5.2 row 3 gives (1, 0, 1); `Shared/BackupTextTests` (AC-17): every fixed string verbatim, with U+2026 in the labels;
`fileName` for 09-15 12:00, 2026-01-05, the pair 23:30 on 09-15 / 00:30 on 09-16 in New York, and both DST days; `confirmMessage` for rows 1–3, plus
"1 workout" and "1 note", with U+202F and U+00A0 normalised; all twelve `readFailedMessage` cases, the eight "damaged" ones sharing one string; new
`Static/BackupSourceTests`: `Engine/Backup` imports only Foundation; `.iso8601` appears nowhere under `HomeGymLog/`; there is exactly one
`outputFormatting` line, and it contains `.sortedKeys`; `"HomeGymLog-backup-"` appears on exactly one line, in `BackupText.swift`; no file under `Engine/Backup/` contains
`"appearance"`, `"missedDayPolicy"`, `"reminderEnabled"`, `"reminderMinutes"`, `"hapticsEnabled"` or `"soundEnabled"` (review finding 3). **Verify.** `T17 test`, then `T26 -only-testing:HomeGymLogTests/BackupCodecTests test`.

### Step 3 — Row mapping, `replaceInScratch`, `BackupStore`, round trips (AC-14–AC-16, AC-17 rows 1–2, AC-8 data half, part of AC-19)

```swift
// Models/StoreCommit.swift
static func replaceInScratch(in container: ModelContainer, _ write: (ModelContext) throws -> Void) throws
// let scratch = ModelContext(container); try write(scratch); try scratch.save()   — no catch, no rollback()
```

**`Models/BackupSnapshotBuilder.swift`**: `document(in:exportedAt:preferences:) throws -> BackupDocument`. Runs six `FetchDescriptor`s; copies stored
fields only (`phaseRaw`, `statusRaw`, the parent's `?.id`); sorts as in §4.4, with `uuidString` as the last key. The per-row parent hops (~570 for
`progress-history`, ≤ ~150 ms on 17.5, gotchas SwiftData 2026-09-16) run only in the lazy export closure, never in `body`: accepted (verifier note 8).

**`Models/BackupStore.swift`**: `replaceAll(with document: BackupDocument, in container: ModelContainer) throws` is `StoreCommit.replaceInScratch {
deleteAll(in: $0); try insert(document, in: $0) }`.
- `deleteAll` is §5.4 steps 1–3, via `ProgramStore.delete` and `WorkoutLogStore.delete`.
- `insert` builds rows with the model inits, sets `id` and the raw strings, and calls `context.insert(row)` for **every** row, orphans included,
  before linking: a session is appended to its program, or inserted as an orphan; a log
  is linked with `session.workoutLog = log`; exercises are appended to their log, and sets to their exercise.
- Parent maps use `uniquingKeysWith`.
- It is all synchronous, with no `await`.

**Fixture `HomeGymLogTests/Support/BackupStoreFixtures.swift`**: `@MainActor func insertRichGraph(in:) throws -> (current: Program, archived:
Program)`. It starts from `insertSampleGraph` and sets every optional at least once, still passing rules 5–11:
- exercise 0 gets `swappedFromKey = "latPull"`;
- its set 0 is done at RPE 8, with `loggedAt` = start + 90.1234 s;
- exercise 1's set 0 gets `rpeSkipped = true`;
- the log gets a rest start, and an end 75 s later;
- a second program, archived 2026-09-06, has one skipped session and no log;
- one orphan chain: a finished log with no session (no rest instants), holding one exercise with one done set, so the round trip proves orphans survive.

**Tests** (`@MainActor`, containers held) `Persistence/BackupRoundTripTests` (AC-14): the rich graph goes `document` → `encode` → `read` →
`replaceAll` into a second `makeTestStore()` → `document(exportedAt: decoded.exportedAt)`; the two encodes must be byte-identical; a fresh context
shows equal counts, ids, `swappedFromKey`, `rpeSkipped`, `restEndsAt` (within 1 ms), `archivedAt`, `startingWeightsLb` and note text;
`Persistence/BackupReplaceTests` (`#if DEBUG`; AC-15, AC-17, AC-8 data half): `MidProgramSeed` rows replaced by `sampleDocument()` read P 1 · S 3 · L
1 · E 2 · T 6 · N 1, and `ProgramStore.current` has the file's id; the reverse direction checks counts from their owners: S =
`PhaseSplit.weeks(months: 6) * 5`, L = `MidProgramSeed.completedIndexes.count`, E = L × `SplitPlans.exerciseCount(sessionLengthMinutes: 45)!`, T = E ×
`Phase.foundation.sets`; `progress-history` exported and re-imported keeps every count; the `session.program?.id` and
`set.exercise?.workout?.session?.id` chains resolve; `counts` is (1, L, 0), and (2, L + `PhaseSplit.weeks(months: 1) * 3`, 0) for `progress-history`;
after the sample replace, `inProgressPredicate` fetches the file's log; `Persistence/BackupReplaceRollbackTests` (AC-16), with the
`ProgramArchiveRollbackTests` technique: put the sample on disk and reopen it with `allowsSave: false`; `replaceAll` throws; `ModelContext(writer)`
still reads the old counts and note, and `readOnly.mainContext.hasChanges` is false; remove the temp directory. Fallback if 26.5 aborts later (gotchas
2026-09-14): keep it; `Persistence/StoreCommitReplaceTests` (a new file, the home of AC-16's "`StoreCommitTests` gains `replaceInScratch` cases"; the
existing `StoreCommitTests.swift` is untouched): on success, a fresh context reads the note and `mainContext.hasChanges ==
false`; if `write` throws, the error is rethrown and 0 notes are stored; a refused save throws and leaves the store unchanged; `BackupSourceTests`
gains: no `delete(model:` anywhere; no `await` and no `rollback(` inside `func replaceAll(` or `func replaceInScratch(` (NB2; the
`FeedbackSourceTests.functionBody` shape); `StoreCommitSourceTests` and `FailedSavePolicySourceTests` stay unchanged and green. **Verify.** `T17 test`, then run `BackupReplaceRollbackTests` and `BackupRoundTripTests` on `T26` with `-only-testing`.

### Step 4 — Move `AppearanceMode` to Engine (B1; part of AC-19)

1. `git mv HomeGymLog/Shared/AppearanceMode.swift HomeGymLog/Engine/AppearanceMode.swift` (the file is committed), then drop `label` from it.
2. New `Shared/AppearanceMode+Label.swift`: `extension AppearanceMode { nonisolated var label: String }`, with the same three strings (gotchas Swift
   2026-09-23).
3. Update the scans: `SettingsSourceTests.storageKeyLiterals` expects `["Engine/AppearanceMode.swift"]`; `.appearanceMechanism`'s last filter names
   the new path; `BackupSourceTests` checks that this file has no `import UIKit` and no `label`. **Verify.** `T17 test`, then `cmp` the `-seed midProgram -tab settings` screenshot against its Step 1 baseline.

### Step 5 — Root restore state and the `onRestore` hand-off (AC-8 routing, AC-4 screen, part of AC-19)

**New `App/RestoringView.swift`:** `enum RootRestoreState { case idle, restoring(BackupDocument), failed(String) }` with `var isRestoring: Bool`;
`struct RestoringView`: `Theme.bg.ignoresSafeArea()` and `Text(BackupText.restoring)` centred, 15 pt, `Theme.mu`.

**`App/RootView.swift`:** Adds `@AppStorage` bindings for `MissedDayPolicy.storageKey`, `ReminderPlan.enabledKey`, `ReminderPlan.minutesKey`,
`FeedbackCues.hapticsKey` and `FeedbackCues.soundKey`, spelled as the scans read them. They are never a direct `UserDefaults` write (NB7); adds
`@State private var restore: RootRestoreState = .idle`; the routes start with `if restore.isRestoring { RestoringView() } else if let log =
activeLogs.first …`, and the shell gets `onRestore: { beginRestore($0) }`; on the `ZStack`: `.task(id: restore.isRestoring) { if case .restoring(let
d) = restore { performRestore(d) } }`, plus an `.alert(BackupText.restoreFailedTitle, …)` bound to `.failed`, whose `Button(SettingsText.ok)` sets
`restore = .idle`.

```swift
private func beginRestore(_ document: BackupDocument) { selectedTab = .home; restore = .restoring(document) }
private func performRestore(_ document: BackupDocument) {
    do { try BackupStore.replaceAll(with: document, in: modelContext.container) }
    catch { restore = .failed(BackupText.restoreFailedMessage); assertionFailure("Restore failed: \(error)"); return }
    if let p = document.preferences?.resolved() { unitsRaw = p.units.rawValue; /* … all eight … */ }
    restore = .idle   // nothing between replaceAll and here reads a @Query (B3 handler rule)
}
```

**`App/ShellView.swift`** gains `let onRestore: (BackupDocument) -> Void` and passes it to `SettingsView(program:selectedTab:onRestore:)`.
`SettingsView` stores it (Step 6 uses it). Both `#Preview`s pass `{ _ in }`.

**Scan edits (AC-19):** `ReminderSourceTests.preferenceReaders` becomes `["App/ReminderHost.swift", "App/RootView.swift",
"Features/Settings/SettingsView.swift"]`; `FeedbackSourceTests.hapticsReaders` and `.soundReaders` each gain `"App/RootView.swift"`;
`MissedPromptSourceTests.policyReaders` gains it too, and is retitled "three files"; `BackupSourceTests` checks `RootView.swift`: the lines from
`BackupStore.replaceAll(` down to the next `restore = .idle` contain no `currentPrograms`, `activeLogs` or `.first`; no `ModelContext(` and no
`UserDefaults`; in `beginRestore(`, `selectedTab = .home` comes before `restore = .restoring`. `rootViewHasNoFetch` is unchanged.

**Verify.** `T17 test`; `cmp` the 17.5 shots of `midProgram`, `midProgram -tab settings` and `wo-start` against their baselines, allowing the status
bar and home indicator (gotchas Xcode 2026-09-14 and 2026-09-22); the Restoring screen's seed arrives in Step 7 (the agreed order keeps seeds there),
so AC-4 is checked in Step 7.

### Step 6 — Settings BACKUP card, `ShareLink`, `.fileImporter` (AC-1, AC-6/AC-7 file and text halves, AC-10 strings, part of AC-19)

**`Features/Settings/BackupFile.swift`**: `struct BackupFile: Transferable`, in the researcher §5 shape. Fields: `container: ModelContainer`, `clock:
AppClock`, `preferences: BackupPreferences`, and `suggestedName: String` (§5.3, computed in `body`); the representation:
`FileRepresentation(exportedContentType: .json) { file in SentTransferredFile(try await MainActor.run { try file.writeTemporaryFile() },
allowAccessingOriginalFile: false) }.suggestedFileName { $0.suggestedName }`; `writeTemporaryFile()` reads `clock.now()` once, builds the document,
`assert`s `BackupValidation.validate(doc) == nil` (NB1), and calls `Self.write(doc, now:calendar:directory: FileManager.default.temporaryDirectory)`;
`static func write(_:now:calendar:directory:) throws -> URL` lists the directory with `contentsOfDirectory(at:includingPropertiesForKeys: nil)`,
removes every file matching `BackupText.isBackupFileName` (NB5), then encodes and writes `.atomic` to `BackupText.fileName`; fallback if the
`AppClock` field warns (unverified): `nonisolated(unsafe) let clock`.

**`Features/Settings/BackupImportAction.swift`** `static func load(url:) async -> Result<BackupDocument, BackupReadError>` runs `await Task.detached {
Self.coordinatedRead(url) }.value`, then `BackupCodec.read`; any other error maps to `.unreadable`; `nonisolated static func coordinatedRead(_:) ->
Data?` starts the security scope (stopped in a `defer`) and reads through `NSFileCoordinator` (researcher §6); it uses `Task.detached`, not a
`nonisolated async` helper, because approachable concurrency may run such a helper on the caller's actor (unverified).

**`Features/Settings/BackupRows.swift`** `BackupExportRow { let file: BackupFile }` is a `ShareLink(item: file, preview:
SharePreview(BackupText.sharePreviewTitle, image: Image(systemName: "doc.text"))) { Text(BackupText.export)… }`, in the "Build a new program…" row
style with `.buttonStyle(.plain)`; `BackupRestoreRow { let onRestore: (BackupDocument) -> Void }` has `@State` for `showsImporter`, `pending` and
`readError`: a `Button` presents `.fileImporter(allowedContentTypes: [.json])`; the completion runs `Task { load }`, and `.failure` becomes
`.unreadable`; `.confirmationDialog(BackupText.confirmTitle, …, titleVisibility: .visible, presenting: pending)` offers a destructive
`BackupText.confirmButton` that calls `onRestore(doc)`, plus `SettingsText.cancel`, with the message `BackupText.confirmMessage(…)`;
`.alert(BackupText.readFailedTitle, …)` offers `SettingsText.ok`.

**`SettingsContent`** gains `backupFile` and `onRestore`. After `equipmentCard` it draws `SettingsSectionHeader(title: BackupText.section)` and
`SettingsCard { BackupExportRow(file:); SettingsDivider(); BackupRestoreRow(onRestore:) }`.

**`SettingsView`** Adds `@AppStorage("bodyWeightUnits") private var bodyWeightUnitsRaw = WeightUnit.lb.rawValue`, and a `backupPreferences` built from
its eight values; passes `BackupFile(container: modelContext.container, clock: clock, preferences: backupPreferences, suggestedName:
BackupText.fileName(date: clock.now(), calendar: clock.calendar))` and `onRestore`; adds no fetch and no new `.alert(` or `.confirmationDialog(`.

**Tests** `Persistence/BackupFileTests` (AC-6 file half): a temp directory starts with `HomeGymLog-backup-2026-09-14.json` and `other.json`;
`write(sample, now: 09-15 12:00)` leaves only `other.json` and `HomeGymLog-backup-2026-09-15.json`; the new file passes `BackupCodec.read` and
re-encodes to the same bytes; under `#if DEBUG`, `writeTemporaryFile` over `midProgram` gives counts (1, L, 0); `Persistence/BackupImportActionTests`
(AC-7 text half): `encode(sample)` gives `.success`, with an equal re-encode; `{"a":1}` gives `.notABackup` ("This file isn't a HomeGymLog backup.");
`"app":"Benchmark"` gives `.otherApp("Benchmark")`; a dangling `exerciseID` gives `.danglingReference`; a missing URL gives `.unreadable`;
`SettingsScreenSourceTests`: `filesScanned` expects `BackupFile, BackupImportAction, BackupRows, ReminderRows, RestartAction, SettingsContent,
SettingsRows, SettingsView` and is retitled "eight"; `dividerCount` expects 9; `sectionHeaders` (a strengthening, not a repair: `textMembers` never sees `BackupText.`, so the old assertion would still pass) checks the line order `SettingsText.programSection` <
`SettingsText.equipmentSection` < `BackupText.section`; `BackupSourceTests`: no `contentModificationDateKey` or `creationDateKey` anywhere;
`includingPropertiesForKeys: nil` in `BackupFile.swift`; no `BackupSnapshotBuilder` or `FetchDescriptor` in `SettingsView.swift`; every string token
in `BackupRows.swift` is a `BackupText.` or `SettingsText.` member, excluding lines containing `systemName:` (AC-10).

**Verify.** `T17 test`; on 17.5, `/design-compare settings` with `-seed midProgram -tab settings`. Crop the 5600 render with `sips -c 800 290
--cropOffset 2555 4148` (gotchas Xcode 2026-09-22; `design-compare/SKILL.md` line 40), and read the crop first; it must match within m5-haptics AC-1's
deviations. The card is below the fold, so the shot must also `cmp` equal to the baseline.

### Step 7 — Seeds and `/design-compare` on 17.5 and 26.5 (AC-1–AC-5, AC-18, part of AC-19)

**`BackupRows.swift`** Declares the production `enum BackupPreview: Equatable { case confirm, readFailed, restoring }` (the `WorkoutSheetPreview`
pattern); `BackupRestoreRow` reads `@Environment(\.settingsBackupPreview)`, `modelContext` and `appClock`, and gains `preferences` (passed from
`SettingsView` through `SettingsContent`); `.onAppear { openPreview() }` runs the preview, never `body` (NB6). `openPreview()` sets `pending = try?
BackupSnapshotBuilder.document(in: modelContext, exportedAt: clock.now(), preferences: preferences)` for `.confirm`, and `readError = .newerFormat(2)`
for `.readFailed`.

**Wiring.** `App/AppClock.swift` adds `@Entry var settingsBackupPreview: BackupPreview? = nil`; `HomeGymLogApp` adds `private let backupPreview:
BackupPreview?`, set from `seed.settingsBackupPreview` inside the `DebugSeed.parse(` branch, and applies `.environment(\.settingsBackupPreview,
backupPreview)` once, outside `#if DEBUG`; `RootView`'s first route becomes `restore.isRestoring || backupPreview == .restoring`, reading
`@Environment(\.settingsBackupPreview)`.

**Seeds.** `DebugSeed.swift` adds `backupConfirm = "backup-confirm"`, `backupFailed = "backup-failed"` and `backupRestoring = "backup-restoring"`.
Each has reference date 09-15 12:00 and a nil `initialDraft`, and `makeContainer` uses `MidProgramSeed.populate`; new `App/DebugSeed/BackupSeed.swift`
(`#if DEBUG`): `extension DebugSeed { var settingsBackupPreview: BackupPreview? }`, which is `.confirm`, `.readFailed` or `.restoring` for the three
new seeds and nil for every other seed.

**Tests** `Seed/BackupSeedTests` (`#if DEBUG`, AC-18): the three seeds' table counts and session (index, status) lists equal `midProgram`'s;
`forcesMissedDayPrompt` is false; the preview mapping holds, and it is nil for every other `allCases` entry; the `backup-confirm` document, built with
§5.7's typed `midProgram` preferences, has `exportedAt` = `TestCalendar` 2026-09-15 12:00 and counts (1, `MidProgramSeed.completedIndexes.count`, 0);
its `confirmMessage` equals §5.2 row 1 (normalised), and `BackupCodec.read(encode(doc))` passes; `SeedNameScanTests.names` gains the three quoted
names; **changed existing test** `DebugSeedTests.parses(seed:)` (`Seed/DebugSeedTests.swift:10-27`) gains
`case .backupConfirm, .backupFailed, .backupRestoring: expectedDay = TestCalendar.day(2026, 9, 15)`, else its `default:` (08-31) fails three times; `BackupSourceTests`: exactly one `@Entry` line in `AppClock.swift` with `BackupPreview?` and a nil or empty initializer;
`.environment(\.settingsBackupPreview` on one line of `HomeGymLogApp.swift`; `seed.settingsBackupPreview` read between `DebugSeed.parse(` and the next
`#endif`.

**Verify** on 17.5, then 26.5, in Dark, with `defaults delete seed` before each launch:

| AC | Launch | Check |
|---|---|---|
| AC-1 | `midProgram -tab settings` | `/design-compare settings` |
| AC-2 | `backup-confirm -tab settings` | §5.2 row 1 verbatim, a destructive "Replace and restore", and "Cancel"; `-appearance light` gives a light dialog. On 26.5 the dialog is a popover with no Cancel, anchored off screen (gotchas SwiftUI 2026-09-25), so that shot is informational |
| AC-3 | `backup-failed -tab settings` | the read-failed alert |
| AC-4 | `backup-restoring` | "Restoring…" centred, no pill |
| AC-5 | every Step 1 launch | `cmp` against its baseline, with the gotchas Xcode 2026-09-14, 09-22 and 09-25 allowances |

### Step 8 — Full suite on both runtimes, Release build (AC-20)

`rm -rf build/tests.xcresult && T17 -resultBundlePath build/tests.xcresult test`, then `xcrun xcresulttool get test-results summary --path
build/tests.xcresult` (quote `totalTestCount`); `T26 test`; the CLAUDE.md Release build (`-configuration Release … CODE_SIGNING_ALLOWED=NO build`);
`git status --porcelain HomeGymLog.xcodeproj` prints nothing and `git status` lists the three fixture files. For the doc-writer: `docs/layout.md`
rosters the new `App/RestoringView.swift` (`RootRestoreState`, `RestoringView`), `Engine/AppearanceMode.swift` (moved from `Shared/`) with
`Shared/AppearanceMode+Label.swift`, and the new Backup files and fixture.

### Step 9 (optional) — Real-touch checks in a scratch copy (AC-1 second shot, AC-2/AC-3 dismissals, AC-8 confirm)

Following INSIGHTS "Real-touch probes": copy the repo, working changes included, into the scratchpad, and give the copy a UI-test target and the
bundle id `com.zhabskyi.homegymlog.probe`. The repo's `project.pbxproj` is never touched. **Skip path:** if the target will not add or build, record
"Step 9 skipped" and move these checks to the user list. Each tap path is traced through the state machine before it is written:

1. **`-seed midProgram -tab settings`.** Swipe up until "Restore from backup…" is hittable, assert that "BACKUP" and both buttons exist, and attach
   `XCUIScreen.main.screenshot()`.
2. **`-seed backup-confirm -tab settings` (17.5).** Assert the dialog title exists, then tap "Replace and restore". Assert Home's greeting and the
   selected Home pill; only then assert the title is gone. Trace: `onRestore` sets the tab to Home; Restoring renders; `.task` replaces the in-memory
   seed store with its own rows; the shell returns on Home; `missedPromptEnabled` is false for this seed, so no prompt covers Home.
3. **The same seed, 17.5 only** (26.5 has no Cancel). Assert the title, tap "Cancel", then assert the title is gone and "Settings" still shows.
4. **`-seed backup-failed -tab settings`.** Assert the alert, tap "OK", then assert the alert is gone and "Settings" still shows. Uninstall the probe bundle afterwards.

## 4. Data model changes

No stored field changes. `AppSchemaV1` wraps the six existing top-level classes at `Version(1, 0, 0)`, what `Schema([...])` already wrote into
every store (researcher Q1); `AppMigrationPlan` has one schema and no stages. **Migration impact: none**: unversioned stores open with every row on
17.5 and 26.5, and Step 1's committed fixture test is the two-install proof for every future version. Pounds everywhere, the file included (§4.3–4.4).

## 5. Risks and gotchas

| Risk | Mitigation |
|---|---|
| On 17.5 the rows stay in `-wal` (gotchas SwiftData 2026-09-29) | Write on 26.5; check the `-wal` is 0 bytes (checkpoint if not); commit all three files |
| A 26.5-written fixture may not open on 17.5, or the test may not be able to write to the repo (both unverified) | The Step 1 test runs on both runtimes, stop and report on failure; Step 1a fallback via `tmp/` and `simctl get_app_container` |
| `delete(model:)` deletes immediately and throws 134050; `rollback()` with a pending delete crashes 17.5 (gotchas 2026-09-13) | Neither is used; Step 3 scans; `rollback()` count stays 2 |
| On 17.5 a `@Query` is stale inside the saving handler (B3) | Decide from the document only; Step 5 line-range scan |
| On 26.5, deleted rows fault and a released container crashes | Restoring unmounts every reader; the body reads only `.first?.id` and `!= nil`; tests hold their containers |
| Pending changes plus a deleted store file abort 26.5 (gotchas 2026-09-14) | AC-16 leaves nothing pending; fallback: keep the temp store |
| `.iso8601` on 17.5; unstable key order on 26.5; a no-fraction date may be rejected (unverified); `Dictionary(uniqueKeysWithValues:)` traps | `.custom` strategy with a plain fallback, `.sortedKeys`; Step 2 scans; AC-12 test; `Set`s and `uniquingKeysWith` |
| The read may land on main; `AppClock` in a `Transferable` may warn (both unverified) | `Task.detached`; `nonisolated(unsafe) let clock` |
| `suggestedName` (render time) and the file name (build time) differ only across midnight | Accepted; AC-6 user check |
| An off-screen row's `onAppear` (confirm seed); the 26.5 popover dialog has no Cancel | The Step 7 shot proves `onAppear`, fallback `.task`; AC-2 judged on 17.5, Step 9 Cancel on 17.5 only |
| Stale `seed` suite; `-only-testing` selecting nothing; U+202F in times; file timestamps are a required-reason API (NB5); transposed `sips` pairs | `defaults delete seed` per shot; suite-level selection and the watchdog; normalise in tests; name match only (Step 6 scan); use the recorded crop and read it first |

## 6. Definition of done

- [ ] `HomeGymLogTests/Support/Fixtures/unversioned-1.0.0.store` (+ `-wal`, `-shm`) is committed, and `SchemaMigrationTests` is green on 17.5 and
      26.5.
- [ ] The suite is green on both runtimes (`totalTestCount` quoted), the Release build is green, `project.pbxproj` is unchanged, and there is no
      new plist key, entitlement or capability.
- [ ] `/design-compare settings` matches on 17.5, and every AC-5 shot equals its Step 1 baseline.
- [ ] `backup-confirm` shows §5.2 row 1 verbatim, `backup-failed` shows the newer-version alert, and `backup-restoring` shows "Restoring…".
- [ ] Step 9 ran (card after a scroll, confirm lands on Home, Cancel and OK dismiss), or it is recorded as skipped.
- [ ] **User-run in the MVP pass (does not block the merge):** AC-6 share sheet: "Save to Files" gives `HomeGymLog-backup-<date>.json`, the preview
      reads "HomeGymLog backup", Cancel works, and an unseeded launch uses today's date; AC-7 picker: Cancel; `{"a":1}`; "Benchmark"; a damaged file;
      a valid file whose dialog is cancelled; AC-8 restores via the picker: a `midProgram` file over `progress-history`; kg / dark / reminder on,
      which shows "Allow notifications"; an archived-only file, which lands on A2; a hand-made in-progress file; AirDrop, Mail, and an iCloud file
      that is not downloaded yet; AC-9 reminders, on device; AC-10 VoiceOver; AC-1's second shot and the AC-2 / AC-3 dismissals, if Step 9 was
      skipped.



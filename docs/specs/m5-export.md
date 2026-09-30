# M5 slice 3 — Export (JSON backup, replace-import, frozen `AppSchemaV1`)

**Status: approved draft 2026-09-29** (the user's §9 answers folded in; architecture review `docs/reviews/m5-export-architecture.md` "approve with changes" applied: B1, B2, B4, NB1–NB8 marked inline; B3 resolved by the researcher's addendum of 2026-09-29: plain flag, §2.4). Branch `m5-export`. Depends on `m5-light-theme` (merged 2026-09-27). Milestone-wide
decisions live in `docs/specs/m5-haptics.md` (header) and INSIGHTS 2026-09-24 "M5 slicing" (a JSON backup **with import**, the frozen schema
lands here); neither is restated. The Settings screen is owned by `docs/specs/m4-settings.md` (§2 geometry, §2.3 restart, AC-1 deviations) and
its two later rows by `m4-reminder` / `m5-haptics`. Platform facts, binding: `docs/reviews/m5-export-researcher.md` (Q1–Q8) and its INSIGHTS
Patterns entries of 2026-09-29 (V1 retrofit, whole-store replace, DTO mirror); gotchas SwiftData 2026-09-29 (`delete(model:)`, the 17.5 `-wal`,
`@Query` refresh from a scratch save), Swift 2026-09-29 (`.iso8601` and `.sortedKeys`), SwiftData 2026-09-13 (never `rollback()` with a pending
insert or delete; the 26.5 fault trap), 2026-09-14 (pending changes and a deleted store file). Code read: the six `@Model`s, `AppSchema`,
`ProgramStore` (`delete`, `archive`, `current`), `WorkoutLogStore` (`delete`, `start`, `finish`), `ExerciseNoteStore`, `StoreCommit`, `RootView`,
`ShellView`, `HomeGymLogApp`, `AppClock`, `ReminderHost`, `WorkoutSnapshotBuilder.inProgressPredicate`, the Settings files, `SettingsText`,
`DebugSeed`, `MidProgramSeed`, `RestartSeed`, `TestContainer.insertSampleGraph`, `SplitPlans.exerciseCount`, `PhaseSplit`, `ProgramGenerator`
(allowed sets), `HomeStatsInput` (`duplicateLogIndex`), and the static scans under `HomeGymLogTests/Static/`. The prototype's `settings`
snapshot (markup 242–262) **has no export UI**; §2.1 says what is added and how it follows the row style. Flow label **D3 `settings`**.

---

## 1. Purpose

Let the user save everything the app stores as one JSON file (share sheet: Files, AirDrop, Mail) and put such a file back, replacing the whole
store, so a phone change or a mistake is recoverable without a backend. The stored schema is frozen as `AppSchemaV1` with a one-stage-less
migration plan so the file format has a stable target. Covers D3 `settings` (one new card), the system share sheet and file picker (no
snapshots), a replace confirmation, a failure alert, a brief "Restoring…" root state, and the landing screen after a restore (`home`, or `ob1` /
the workout by the existing routes).

---

## 2. User-facing behavior

### 2.1 Backup card (new; prototype has none)

A third section under the Equipment card, in the exact style of m4-settings §2: header **"BACKUP"** (12 pt `mu` semibold, tracking 0.4, 22 pt
above / 8 pt below), an `sf` card radius 16, rows padded 13 / 16, one 1 pt `bd` hairline between them, none under the last. Both rows are
full-width left-aligned accent 15 pt semibold action rows (the "Build a new program…" / "Allow notifications" shape), no trailing value, the
label ending in U+2026 like every "opens something" label.

| Row | Label | Tap | VoiceOver |
|---|---|---|---|
| 1 | **"Export backup…"** | Opens the system share sheet with one item, the backup file (2.2). No confirmation | "Export backup…, button" |
| 2 | **"Restore from backup…"** | Opens the system file picker filtered to JSON files (2.3) | "Restore from backup…, button" |

Nothing on the card shows a date or a count; there is no "Last backup" row (Q6). The card is below EQUIPMENT (Q5), so the `settings` crop of
the prototype is unchanged above it and the app's screen gains ≈ 150 pt below the fold.

### 2.2 Export

| Step | Behaviour |
|---|---|
| Tap | The share sheet appears (system UI). The file is built lazily when the sheet asks for it: every row of the store is read on the main actor, mapped to the document (4.3), encoded (5.6) and written to the app's temporary directory as **`HomeGymLog-backup-<yyyy-MM-dd>.json`** (5.3; the day of `clock.now()` in the local calendar). The previous files are deleted first: `contentsOfDirectory(includingPropertiesForKeys: nil)` and a **name match** on `HomeGymLog-backup-*.json` only, never a request for `.contentModificationDateKey` / `.creationDateKey` (NB5: required-reason API, researcher Q7). The built document is checked against `BackupValidation` first; a non-nil result is a Debug assertion (NB1: the app must never export a file it would call damaged; Release still exports) |
| Sheet preview | Title **"HomeGymLog backup"**, the system document glyph; the file name is what Files / Mail show (unverified on this machine: user check, AC-9) |
| Cancel | Nothing written to the store; the temp file may remain until the next export or a system purge |
| Build fails (encode or write throws) | The transfer fails and the system sheet reports it its own way (unverified); the app shows no alert and writes nothing. A failing read of the store is a programming error: Debug asserts |

### 2.3 Restore

| Step | Behaviour |
|---|---|
| Tap "Restore from backup…" | The system document picker in open mode, JSON files only, single selection. Cancel → nothing |
| File picked | Read with security-scoped access through a coordinated read, off the main actor (an iCloud file may download first). Then decode and validate fully (5.1) before anything else |
| Read or validation fails | An alert over unchanged Settings: title **"Couldn't read this backup"**, one message from 5.1's table, one **"OK"**. Nothing changed |
| Valid | A confirmation dialog (action sheet): title **"Replace everything with this backup?"**, message = 5.2's text, e.g. **"Backup from Sep 15, 2026, 12:00 PM: 1 program, 10 workouts, 0 notes. Everything on this phone is replaced: your program, its history and your notes. Your settings are replaced too."**, destructive **"Replace and restore"**, **"Cancel"** |
| Cancel | Nothing changed; the read document is dropped |
| "Replace and restore" | The selected tab is set to Home, the routes give way to the Restoring state (2.4), and the whole store is replaced in one save (5.4) |

### 2.4 Restoring and after

| State | What shows | Then |
|---|---|---|
| Restoring | A plain `bg` screen with **"Restoring…"** centred (15 pt `mu`); no shell, no workout, no onboarding is mounted, so no screen holds a row being deleted. Lasts one save (5–9 ms measured) plus one render | Success or failure |
| **B3 (resolved, researcher addendum 2026-09-29)** | The restoring flag is **cleared in the same synchronous handler** as the save and the preference writes; no saved pre-restore ids, no `onChange` release. Probed on 17.5 and 26.5 (hosted `UIWindow`, on-disk store): the first `body` pass after the flag clears already holds the new `Program` (`programs.first === old` false, new fields, new session count), so the shell never mounts on the deleted row and the 26.5 delete trap has no window. **Handler rule (the probe's one finding):** after the save, the handler must **never read or branch on a `@Query` value** — on 17.5 `programs.first` is still the deleted row there (26.5 already the new one); the query is refreshed for the next render, not for the handler. Everything the handler needs after the save (the preferences, the tab) comes from the document. **Body rule while restoring:** nothing in the root's body reads a row except `currentPrograms.first?.id` and `activeLogs.first != nil` (stored, loaded scalars); never a relationship hop | — |
| Success | The routes come back from the live queries over the new rows: the shell **on Home** for the restored current program (`home`-style); onboarding prefilled at A2 (m4-settings §2.3) when the backup holds no current program; the workout screen when the current program has an in-progress log (2.5). The file's eight preferences are written **only after the save succeeded** (5.7), before the routes come back, so the restored shell renders in the file's units and appearance. No alert (Q3) | — |
| Failure (the save threw) | The scratch context is dropped, the store still holds the old rows, the routes come back (the shell on Home) and an alert shows: **"Couldn't restore this backup"** / **"Nothing was changed. Please try again."** / **"OK"**. Debug asserts | OK → the shell |

### 2.5 Interplay with a workout, the rest notification and the reminders

Verified against `RootView`: the shell (and so Settings) mounts only while the current program has no in-progress log (`activeLogs.first` wins
the route). So at export or import time there is no live workout, no live rest and no pending `rest-timer` notification to tear down.

| Situation | Behaviour |
|---|---|
| The backup holds an in-progress log on its current program | Restored as is (Q7). The in-progress query matches it and the workout screen opens; its existing rest reconcile cancels a past `restEndsAt` or schedules a future one (a backup made moments earlier). No import-specific code |
| Reminders | `ReminderHost` stays mounted through the restore (it reads only the program id). A different program id remounts it (`.id`) and its reconcile runs; the same id refreshes its session query on the save, and an unchanged key means nothing to do; every pending `reminder-*` not in the desired set is removed, as today |
| Preferences (Q1 = B) | The eight `@AppStorage` keys ride in the file (4.4 `preferences`) and are written after the store save succeeds, each through its per-key fallback (5.7); a failed save writes none. Live re-application needs no new code: `appearance` → `RootView`'s existing `onChange` sets `overrideUserInterfaceStyle` on every window; `units` / `bodyWeightUnits` → every screen reads the preference in `body`, so the restored shell renders in the file's unit (weights in the file are pounds regardless); `missedDayPolicy` → the remounted prompt host's key; `reminderEnabled` / `reminderMinutes` / `soundEnabled` → `ReminderHost`'s reconcile key changes and one reconcile runs; `hapticsEnabled` / `soundEnabled` → read at the next cue. **Notification permission is never restored**: it is system state read live by `ReminderPermission`; a restored `reminderEnabled = true` on a phone that never allowed notifications shows the "Allow notifications" row, on a denied one "Open iOS Settings" (m4-reminder), with no prompt of its own |
| Missed-day prompt / automatic policy | The remounted shell's host re-derives from the restored rows: a restored missed session prompts or is acted on exactly as after a relaunch |

---

## 3. States and transitions

| State | Shown | Leaves by |
|---|---|---|
| Settings (`midProgram`) | 2.1 card under EQUIPMENT | "Export backup…" → Share sheet; "Restore from backup…" → File picker |
| Share sheet (system) | the sheet with "HomeGymLog backup" | any activity or Cancel → Settings, unchanged |
| File picker (system) | JSON files | Cancel → Settings; pick → Reading |
| Reading | Settings unchanged (a read is < 1 s locally; iCloud may take longer; no spinner in v1) | failure → Read-failed alert; success → Confirmation |
| Read-failed alert | alert over Settings, 5.1's text | OK → Settings |
| Confirmation | dialog over Settings, 5.2's text | Cancel → Settings; "Replace and restore" → Restoring |
| Restoring (root) | "Restoring…" | save ok → routes over the new rows (Home / A2 / workout); save threw → Restore-failed alert over the shell on Home |
| Restore-failed alert | alert, old rows behind it | OK → shell |
| Resume after kill | Export: nothing to resume. Import: the replace is one save, applied fully or not at all; a kill before the save leaves everything; after it, relaunch derives every route from the restored rows. The read document is never persisted |
| First run | No Settings until a program exists; nothing to export before one |

---

## 4. Data

### 4.1 Read

| Value | Source | Notes |
|---|---|---|
| Export rows | every `Program`, `PlannedSession`, `WorkoutLog`, `LoggedExercise`, `LoggedSet`, `ExerciseNote` row, fetched on the main actor when the sheet requests the file | archived programs and their history included (Q2); orphan rows included as they are |
| `exportedAt`, file-name day | `clock.now()` at the moment the file is built | an instant; the day is its local calendar day |
| Import bytes | the picked file, coordinated read | never persisted, no bookmark |
| Confirm counts and date | derived from the validated document (5.2) | — |

### 4.2 Written

| Action | Write | Notes |
|---|---|---|
| Export | one temp file in the app's `tmp/` | never the store; the previous `HomeGymLog-backup-*.json` files there are removed first |
| Confirm restore | `BackupStore.replaceAll(with:in:)` on a **scratch context opened by `StoreCommit.replaceInScratch`** (B2), one `save()` (5.4) | success: the root's `@Query`s re-fetch (verified 17.5 / 26.5); failure: the context is dropped, nothing else is touched; never `rollback()`, never `delete(model:)` |
| After a successful save | the eight preferences (5.7) through the root's `@AppStorage` bindings, the same storage every screen reads (the seed suite in a `-seed` launch) | after the save only, in the same handler; nothing on failure or cancel |
| Everything else | nothing | export never writes a row or a preference |

No schema change to any field. The schema is frozen as `AppSchemaV1` (5.5): every existing store opens with every row (researcher Q1, both runtimes).

### 4.3 Backup contents (every model, every stored field; nothing derived is written)

| Table (JSON key) | Row id | Stored fields, units | Parent reference |
|---|---|---|---|
| `programs` | `id` | `createdAt`, `archivedAt?`, `startDate`, `months`, `frequency`, `trainingWeekdays: [Int]` (0 = Mon), `sessionLengthMinutes`, `bodyWeightLb` (lb), `experience`, `startingWeightsLb: {key: lb}` | — |
| `sessions` | `id` | `index`, `week`, `phase` (raw: "Foundation" / "Build" / "Peak" / "Deload"), `name`, `scheduledDate`, `sets`, `reps`, `restSeconds`, `exercises: [{order, exerciseKey, targetWeightLb}]` (lb), `status` (raw: "pending" / "completed" / "skipped") | `programID?` |
| `workoutLogs` | `id` | `startedAt`, `finishedAt?`, `restStartedAt?`, `restEndsAt?` | `sessionID?` |
| `loggedExercises` | `id` | `order`, `exerciseKey`, `swappedFromKey?`, `targetWeightLb` (lb) | `workoutID?` |
| `loggedSets` | `id` | `order`, `weightLb` (lb), `reps`, `status` (raw: "pending" / "done" / "skipped"), `rpe?` (6…10), `rpeSkipped`, `loggedAt?` | `exerciseID?` |
| `exerciseNotes` | `id` | `exerciseKey`, `text`, `updatedAt` | — |

Included: the current program, **every archived program** with its sessions and logs (Q2), in-progress logs, skipped sessions, notes, and the
eight `@AppStorage` preferences (5.7; Q1 = B). Not included: anything derived (streaks, PRs, volume, week numbers), the exercise library (static
code), the notification permission (system state, never stored), the DEBUG argument-domain keys `haptics` / `sound` (m5-haptics NB4: launch
overrides no `@AppStorage` reads). Grepped 2026-09-29: the app target has exactly these eight `@AppStorage` keys. Weights are pounds everywhere.

### 4.4 JSON shape

| Key (sorted output) | Type | Value |
|---|---|---|
| `app` | string | `"HomeGymLog"` (the wrong-app check, 5.1) |
| `exportedAt` | string | ISO 8601 UTC with milliseconds, `2026-09-15T16:00:00.000Z` (5.6) |
| `exerciseNotes` | array | 4.3 rows |
| `formatVersion` | integer | `1` |
| `loggedExercises` | array | 4.3 rows |
| `loggedSets` | array | 4.3 rows |
| `preferences` | object | the eight keys of 5.7, each optional; the object itself optional |
| `programs` | array | 4.3 rows |
| `sessions` | array | 4.3 rows |
| `workoutLogs` | array | 4.3 rows |

Per row: keys sorted; `UUID` as its uppercase string; dates as above (`Date.distantPast` writes `0001-01-01T00:00:00.000Z`); `Double` as JSON
numbers (bit-exact round trip, researcher Q2); optionals **omitted when nil** (a decoder treats a missing optional as nil, so both spellings read
back); arrays in **stable, total order** with **`id.uuidString` as the last key of every table** (planner 7: two orphan sessions may share an
`index`): programs by (`createdAt`, id), sessions by (`programID?.uuidString ?? ""`, `index`, id), logs by (`startedAt`, id), exercises by
(`workoutID?.uuidString ?? ""`, `order`, id), sets by (`exerciseID?.uuidString ?? ""`, `order`, id), notes by (`exerciseKey`, id), so two exports of
the same store are byte-identical. Pretty
printed (a 6-month program is a few hundred KB). Unknown keys are ignored on read (forward-tolerant within version 1).

### 4.5 Seams and text (plain values; Engine total over its inputs, throws only for a caller-supplied file)

| Item | Shape |
|---|---|
| `BackupDocument` (Engine, `Codable`, `Equatable`) | `app`, `formatVersion`, `exportedAt`, the six DTO arrays of 4.3, `preferences: BackupPreferences?`; `static let currentFormatVersion = 1`, `static let appName = "HomeGymLog"` |
| `BackupPreferences` (Engine, `Codable`, `Equatable`) | eight optional raw fields (5.7: `units: String?`, `bodyWeightUnits: String?`, `appearance: String?`, `missedDayPolicy: String?`, `reminderEnabled: Bool?`, `reminderMinutes: Int?`, `hapticsEnabled: Bool?`, `soundEnabled: Bool?`), decoded leniently (a wrong-typed field reads as nil, never a decode failure); `resolved() -> ResolvedPreferences` applies the per-key fallbacks of 5.7 (total) |
| `ResolvedPreferences` (Engine value) | `units: WeightUnit`, `bodyWeightUnits: WeightUnit`, `appearance: AppearanceMode`, `missedDayPolicy: MissedDayPolicy`, `reminderEnabled: Bool`, `reminderMinutes: Int`, `hapticsEnabled: Bool`, `soundEnabled: Bool`; `static let defaults` = 5.7's fallback column |
| `BackupReadError` (Engine, `Error`, `Equatable`) | `notABackup`, `otherApp(String)`, `newerFormat(Int)`, `undecodable(String)`, `duplicateID(table: String, id: UUID)`, `danglingReference(table: String, id: UUID, parentTable: String, parentID: UUID)`, `duplicateSessionIndex(programID: UUID, index: Int)`, `duplicateSessionLog(sessionID: UUID)`, `invalidValue(table: String, id: UUID, field: String)`, `multipleCurrentPrograms(Int)`, `statusMismatch(sessionID: UUID)`, `unreadable` |
| `BackupCodec.encode(_ document: BackupDocument) throws -> Data` (Engine) | `.sortedKeys`, `.prettyPrinted`, the `.custom` ISO 8601 strategy (5.6); throws only an encoder error (programming error) |
| `BackupCodec.read(_ data: Data) throws -> BackupDocument` (Engine) | header check → full decode → `BackupValidation.validate`; every failure is a `BackupReadError` (5.1). Never traps on any bytes |
| `BackupValidation.validate(_ document: BackupDocument) -> BackupReadError?` (Engine) | the rules of 5.1 in order; nil = valid |
| `BackupDocument.counts -> (programs: Int, workouts: Int, notes: Int)` (Engine, in `BackupDocument.swift`; NB8) | workouts = logs with `finishedAt != nil` (5.2) |
| `BackupSnapshotBuilder.document(in context: ModelContext, exportedAt: Date, preferences: BackupPreferences) throws -> BackupDocument` (Models) | fetches the six tables, maps rows → DTOs, orders as 4.4; **`SettingsView` builds the preferences** from its seven existing `@AppStorage` bindings plus a new `@AppStorage("bodyWeightUnits")` (a literal key no scan pins) and passes the value down through `SettingsContent` to the export row (planner 1), so `BackupRows.swift` reads no `@AppStorage` and the four reader scans stay exactly as AC-19 says; stores nothing |
| `StoreCommit.replaceInScratch(in container: ModelContainer, _ write: (ModelContext) throws -> Void) throws` (Models; B2) | the failed-save policy's third shape beside `commit`, `commitInsert`, `rehearseInsert`: opens the scratch context, runs `write`, saves once; on a throw the context leaves scope with its pending changes never saved; no `rollback()` |
| `BackupStore.replaceAll(with document: BackupDocument, in container: ModelContainer) throws` (Models) | 5.4 inside `replaceInScratch`; `RootView` passes `modelContext.container` and never creates a context; no `delete(model:)` |
| `BackupImportAction.load(url: URL) async -> Result<BackupDocument, BackupReadError>` (Features/Settings) | security scope + coordinated read off the main actor (`.unreadable` on any read failure), then `BackupCodec.read` |
| Root restore state | root-owned enum: idle / restoring(document) / failed(message); the routes render "Restoring…" while restoring; a task keyed on it runs `replaceAll` synchronously, then on success writes `document.preferences?.resolved()` into the root's eight `@AppStorage` bindings (none when the object is absent; **NB7: five new bindings beside `units`, `appearance`, `bodyWeightUnits`, deliberate — a direct `UserDefaults` write would miss the seed suite behind `.defaultAppStorage`; do not "clean up"**), then clears the flag, all in one synchronous handler that reads no `@Query` after the save (B3, 2.4) |
| `onRestore: (BackupDocument) -> Void` (B4) | The Settings → root path: a closure prop `RootView → ShellView → SettingsView → BackupRows` (the `onDone` precedent of the workout screen), never an `@Observable` or a second copy of the state. The root's handler sets `selectedTab = .home` and flips the state in the same call. `ShellView.init` and `SettingsView.init` gain the parameter; the two `#Preview`s pass `{ _ in }`; no static scan pins `ShellView(`'s argument list (checked 2026-09-29) |
| `BackupFile` (Features/Settings, `Transferable`) | `FileRepresentation(exportedContentType: .json)`: builds the document on the main actor, Debug-asserts `BackupValidation.validate(document) == nil` (NB1), encodes, deletes previous `HomeGymLog-backup-*.json` in `tmp/` by name (NB5), writes atomically, `suggestedFileName` = 5.3 |
| `BackupText` (Shared; **every spoken string**, labels = visible text) | `section = "BACKUP"`; `export = "Export backup…"`; `restore = "Restore from backup…"`; `sharePreviewTitle = "HomeGymLog backup"`; `fileName(date:calendar:)` (5.3); `readFailedTitle = "Couldn't read this backup"`; `readFailedMessage(_ error: BackupReadError)` (5.1); `confirmTitle = "Replace everything with this backup?"`; `confirmMessage(exportedAt:programs:workouts:notes:calendar:locale:)` (5.2); `confirmButton = "Replace and restore"`; `restoreFailedTitle = "Couldn't restore this backup"`; `restoreFailedMessage = "Nothing was changed. Please try again."`; `restoring = "Restoring…"`; Cancel and OK reuse `SettingsText.cancel` / `SettingsText.ok` |

**B1:** `AppearanceMode` (cases, `storageKey`, `from(raw:)`) moves to `Engine/AppearanceMode.swift`, UIKit-free; its `label` stays a **Shared
extension** (`Shared/AppearanceMode+Label.swift`), so `ResolvedPreferences` is pure Engine and Shared keeps depending on Engine, never the reverse.

Proposed files: `Models/AppSchemaV1.swift` (V1 + plan), `Models/AppSchema.swift` (two lines), `Engine/AppearanceMode.swift` (moved),
`Engine/Backup/BackupDocument.swift` (document, preferences, `counts`), `BackupCodec.swift`, `BackupValidation.swift`, `Models/StoreCommit.swift`
(`replaceInScratch`), `Models/BackupSnapshotBuilder.swift`, `Models/BackupStore.swift`,
`Shared/BackupText.swift`, `Features/Settings/SettingsContent.swift` (draws the "BACKUP" header, the card and its one `SettingsDivider()`,
hence AC-19's 8 → 9; planner 3), `Features/Settings/BackupRows.swift` (only the two rows; the restore row owns the importer, dialog and alert, so
`SettingsView.swift` keeps one `.alert(` and one `.confirmationDialog(`), `Features/Settings/BackupImportAction.swift`, `Features/Settings/BackupFile.swift`, `App/RootView.swift`
(restore state, "Restoring…" route, `onRestore`, no context creation), `App/ShellView.swift` (passes `onRestore`), `App/DebugSeed/BackupSeed.swift`.

### 4.6 DEBUG (frozen clock, in-memory store, throwaway suite; `defaults delete seed` first)

A nil-by-default `@Entry settingsBackupPreview: BackupPreview?` (the `workoutSheetPreview` enum pattern; set only in the root's `#if DEBUG` block)
with cases `confirm`, `readFailed`, `restoring`.

| Seed + arguments | Shows |
|---|---|
| `-seed midProgram -tab settings` (existing) | D3 `settings` plus the BACKUP card under EQUIPMENT (2.1) |
| **`backup-confirm`** + `-tab settings` | `midProgram` data; the confirmation dialog up on first appearance over a document built from the seed's own rows by `BackupSnapshotBuilder` at the frozen clock **in `BackupRows`' DEBUG `onAppear` behind the `@Entry`, never in `body`** (NB6; `SettingsView` gains no fetch): "Backup from Sep 15, 2026, 12:00 PM: 1 program, 10 workouts, 0 notes. …" (5.2 row 1) |
| **`backup-failed`** + `-tab settings` | `midProgram` data; the read-failed alert up with `newerFormat(2)`'s text |
| **`backup-restoring`** | `midProgram` data; the root renders the "Restoring…" screen with no write in flight (preview only) |

---

## 5. Rules and formulas

### 5.1 Read and validation — `BackupCodec.read` (order matters: the first failing rule names the error)

| # | Rule | Error | User text (`BackupText.readFailedMessage`) |
|---|---|---|---|
| 0 | the file could not be read (scope, coordination, I/O) | `unreadable` | "The file couldn't be opened. Try again from Files." |
| 1 | bytes are not a JSON object with a string `app` and an integer `formatVersion` | `notABackup` | "This file isn't a HomeGymLog backup." |
| 2 | `app != "HomeGymLog"` | `otherApp(app)` | "This backup belongs to another app (\<app\>), not HomeGymLog." |
| 3 | `formatVersion > 1` | `newerFormat(v)` | "This backup was made by a newer version of HomeGymLog. Update the app, then try again." |
| 4 | `formatVersion < 1`, or the body fails to decode (missing table, wrong type, a date not ISO 8601, a non-finite number) | `undecodable(detail)` | "This backup is damaged and can't be restored." |
| 5 | an `id` repeated within a table | `duplicateID` | same |
| 6 | a non-nil `programID` / `sessionID` / `workoutID` / `exerciseID` with no row of that id in the parent table | `danglingReference` | same |
| 7 | two sessions of one program share an `index` (Home would throw `duplicateLogIndex`) | `duplicateSessionIndex` | same |
| 8 | two logs name the same `sessionID` (the schema's to-one) | `duplicateSessionLog` | same |
| 9 | `phase` / `status` raw not in its enum; `months ∉ {1,2,3,6}`; `frequency ∉ {3,4,5}`; `trainingWeekdays` not `frequency` distinct values in 0…6; `sessionLengthMinutes ∉ {20,30,45,60}` (`ProgramGenerator` allowed sets); `rpe` outside 6…10; `sets`, `reps`, `restSeconds`, `order`, `index`, `week` negative; a weight negative; `exercises[].order` repeated in a session; **two notes with the same `exerciseKey`** (NB4: `ExerciseNoteStore.note` fetches with `fetchLimit = 1` and no sort, so which duplicate wins is undefined; the store's one-note-per-key has a single writer) → `invalidValue("exerciseNotes", id, "exerciseKey")` | `invalidValue(table, id, field)` | same |
| 10 | more than one program with `archivedAt == nil` | `multipleCurrentPrograms(n)` | same |
| 11 | a session `completed` without a log whose `finishedAt != nil`; `skipped` with any log; `pending` with a finished log; a finished log with `restStartedAt` or `restEndsAt` set (`WorkoutLogStore.finish` invariants) | `statusMismatch(sessionID)` | same |

Tolerated on purpose: a missing, wrong-typed or out-of-range `preferences` object or field (5.7: per-key fallback, lenient decode, never a
rejection), nil parent ids (orphans, as the schema allows), unknown `exerciseKey`s (every screen reads the library optionally), any
`experience` string, `bodyWeightLb` of any non-negative value, `Date.distantPast`, unknown JSON keys, zero rows in any table (an empty backup is
valid: after restore the app shows onboarding). Worked, on `insertSampleGraph` (P 1 · S 3 · L 1 · E 2 · T 6 · N 1): as exported → valid;
`formatVersion` → 2 → `newerFormat(2)`; `app` → "Benchmark" → `otherApp("Benchmark")`; first byte `{` → `[` → `notABackup`; a set's
`exerciseID` → a fresh UUID → `danglingReference("loggedSets", …, "loggedExercises", …)`; session 1's `index` → 0 → `duplicateSessionIndex`;
a second log on session 0 → `duplicateSessionLog`; `rpe` 11 → `invalidValue("loggedSets", id, "rpe")`; session 0 `status` → "completed" while
its log's `finishedAt` is nil → `statusMismatch`; a second program with `archivedAt` nil → `multipleCurrentPrograms(2)`.

### 5.2 Confirm message — `BackupText.confirmMessage(exportedAt:programs:workouts:notes:calendar:locale:)`

"Backup from \<date\>, \<time\>: \<P\> program(s), \<W\> workout(s), \<N\> note(s). Everything on this phone is replaced: your program, its
history and your notes. Your settings are replaced too." Date = `Date.FormatStyle` abbreviated date ("Sep 15, 2026"), time = shortened ("12:00 PM";
en_US puts U+202F before "PM", gotchas Swift 2026-09-23: tests normalise), both in the given calendar's time zone and locale. Counts from
`BackupDocument.counts`: programs = `programs.count`; workouts = logs with `finishedAt != nil`; notes = `exerciseNotes.count`. Singular when the
count is 1 ("1 program", "1 workout", "1 note"), else plural, "0 notes" included.

| Row | Data (derivation) | Text |
|---|---|---|
| 1 | `midProgram` at Tue 2026-09-15 12:00: P 1; S 120 (`PhaseSplit.weeks(6)` = 24 × 5); L 10 = `completedIndexes.count`; E 50 (10 × `SplitPlans.exerciseCount(45)` = 5); T 150 (weeks 1–3 are Foundation: R = 23, ceil(0.35 × 23) = 9 Foundation weeks, `Phase.foundation.sets` = 3 → 10 × 5 × 3); N 0 | "Backup from Sep 15, 2026, 12:00 PM: 1 program, 10 workouts, 0 notes. Everything …" |
| 2 | `progress-history` at the same instant: `midProgram` + an archived 1-month 3-day program (12 sessions, all completed; 45 min → 5 exercises; weeks 1–2 Foundation 3 sets, week 3 Peak 4 sets, week 4 Deload 2 sets: 6·5·3 + 3·5·4 + 3·5·2 = 180 sets; 150 + 180 = 330): P 2, S 132, L 22, E 110, T 330, N 0 | "…: 2 programs, 22 workouts, 0 notes. …" |
| 3 | `insertSampleGraph` (log unfinished) exported at 2026-09-29 09:05 | "Backup from Sep 29, 2026, 9:05 AM: 1 program, 0 workouts, 1 note. …" |

### 5.3 File name — `BackupText.fileName(date:calendar:)`

`"HomeGymLog-backup-" + yyyy-MM-dd + ".json"` from the calendar's year / month / day components of the instant, zero-padded, ASCII digits, no
locale. Tue 2026-09-15 12:00 → `HomeGymLog-backup-2026-09-15.json`; 2026-01-05 → `…-2026-01-05.json`. Wall-clock: an export at 23:30 local on
Sep 15 is `…-09-15`, at 00:30 on Sep 16 it is `…-09-16`, whatever the UTC day; no arithmetic, so the two DST days (2026-03-08, 2026-11-01 in
America/New_York) change nothing.

### 5.4 Replace order — `BackupStore.replaceAll` (one scratch context, one save)

1. Fetch every `Program`; for each, `ProgramStore.delete` (sessions, their logs, exercises, sets, explicitly). 2. Fetch every remaining
`WorkoutLog` (orphans) → `WorkoutLogStore.delete`. 3. Fetch every remaining `LoggedExercise`, `LoggedSet`, `PlannedSession`, `ExerciseNote` →
`context.delete` row by row. 4. Insert from the document: programs, then sessions appended to their program (or inserted orphan), logs linked
to their session, exercises to their log, sets to their exercise, notes; every row keeps its `id` from the file. 5. `save()`. Steps 1–5 run
in **one synchronous main-actor pass with no `await` between the first delete and the save** (NB2, researcher Q3; pinned by a source scan the
way `MissedPromptSourceTests.automaticPassIsSynchronous` pins the skip pass). A throw at 5 propagates with the context's pending changes never
saved; `replaceInScratch` lets the context go out of scope. Every row read in this context was fetched here,
so the 26.5 "not-yet-loaded child after another context's delete" trap has no path (no other context reads during the gated routes).

Worked: the store holds `midProgram` (P 1 S 120 L 10 E 50 T 150 N 0); the document is 5.2 row 3's (P 1 S 3 L 1 E 2 T 6 N 1) → a fresh
context afterwards reads P 1 S 3 L 1 E 2 T 6 N 1, the note text "incline notch 2", the program's `id` equal to the file's; the root routes to
the workout (the in-progress log). Re-importing a store's own export leaves counts, ids and every field equal (AC-14, byte-identical re-export).

### 5.5 Frozen schema — `AppSchemaV1` (researcher Q1, binding)

`AppSchemaV1.models` = the six top-level classes, `versionIdentifier = Schema.Version(1, 0, 0)` (what `Schema([...])` already wrote into every
store); `AppMigrationPlan.schemas = [AppSchemaV1.self]`, `stages = []`; `AppSchema.schema = Schema(versionedSchema: AppSchemaV1.self)`;
`makeContainer` passes the plan. `AppSchema.schema.version == 1.0.0` after the change. Every `@Query`, predicate and the 33 test call sites
`ModelContainer(for: AppSchema.schema, …)` (grepped 2026-09-29) are untouched. V2, when it comes, copies the six classes into V1 as nested frozen
`@Model`s and points V2 at the top-level ones with a `.lightweight` stage.

### 5.6 Dates and encoding (researcher Q2, binding)

Dates: `ISO8601DateFormatter` `[.withInternetDateTime, .withFractionalSeconds]` through a `.custom` strategy both ways; the encoder always
writes the fraction; the decoder tries the fractional formatter first and **falls back to a plain `[.withInternetDateTime]` formatter** for a
string with no fraction (planner 2: the fractional formatter is believed to reject `"…T12:00:00Z"`, unverified; AC-12's test decides); **never**
`JSONDecoder.DateDecodingStrategy.iso8601` (rejects fractions on 17.5). **Precision contract: milliseconds.** A round trip is within 1 ms of the
original instant (measured ≤ 0.457 ms), whole-second instants exact, and re-encoding a decoded document gives identical bytes. Tests compare
re-encoded bytes or `abs(delta) ≤ 0.001`, never `Date ==`. `.sortedKeys` always (26.5 key order is not stable without it).

### 5.7 Preferences — `BackupPreferences.resolved()` (Q1 = B; total per key, INSIGHTS 2026-09-23 B2)

Exported: the eight keys as the app stores them (raw strings for the enums). Restored: when the `preferences` object is **present**, every key
is written, a missing or invalid field taking the column's fallback (the restore replaces settings wholesale, so the result is exactly what
the file describes); when the object is **absent**, nothing is written and this phone's preferences stay. No key is ever a reason to reject.

| Key (JSON key = storage key) | JSON type | Valid | Fallback, via the existing helper |
|---|---|---|---|
| `units` | string | "lb" / "kg" | lb (`WeightUnit(rawValue:) ?? .lb`, the existing reader shape) |
| `bodyWeightUnits` | string | "lb" / "kg" | lb (same) |
| `appearance` | string | "system" / "dark" / "light" | system (`AppearanceMode.from(raw:)`) |
| `missedDayPolicy` | string | "ask" / "shift" / "skip" | ask (`MissedDayPolicy.from(raw:)`) |
| `reminderEnabled` | bool | true / false | false (the m4-reminder default) |
| `reminderMinutes` | integer | 0…1439 (`ReminderPlan.validMinutes`) | 420 (`ReminderPlan.defaultMinutes`) |
| `hapticsEnabled` | bool | true / false | true (`FeedbackCues.defaultEnabled`) |
| `soundEnabled` | bool | true / false | true (`FeedbackCues.defaultEnabled`) |

Excluded, and why: the notification permission (system state; `ReminderPermission` reads it live, so a restored `reminderEnabled` on an
unasked phone simply shows "Allow notifications"); the DEBUG argument-domain keys `haptics` / `sound` and the `-seed` suite (launch-only). Worked:
`midProgram`'s export from the throwaway suite → `{appearance: "system", bodyWeightUnits: "lb", hapticsEnabled: true, missedDayPolicy: "ask",
reminderEnabled: false, reminderMinutes: 420, soundEnabled: true, units: "lb"}` (sorted keys); `reminder-on` → the same with `reminderEnabled:
true`. Hand cases: `units: "kg"` → kg; `"stone"` → lb; `appearance: "sepia"` → system; `reminderMinutes: 1440` → 420, `-1` → 420, `419` → 419;
`reminderEnabled: "yes"` (wrong type) → nil → false; `hapticsEnabled` missing → true; `preferences: 7` (not an object) → absent → nothing written.

---

## 6. Edge cases

| Case | Behaviour |
|---|---|
| Export at 23:59:59.900 local; file built after midnight | The name uses the instant the file is built (one `clock.now()` read), so the name and `exportedAt` agree |
| Backup made in Kyiv (UTC+3), restored in New York | Instants are preserved. `scheduledDate` is midnight Kyiv = 17:00 the previous day in New York, so `startOfDay` puts every session one calendar day earlier there; the same happens today when the user travels. Accepted, not corrected (7) |
| Restore across the two DST days | Nothing time-based in the import; `exportedAt` is an instant; the confirm message renders it in the local zone; no `day + minutes` anywhere |
| Backup with a pending session dated before today | Restored as missed; the Home prompt or the automatic policy acts on the next shell mount as after a relaunch |
| Backup with an in-progress log on an archived program (a stray) | Valid (rule 11 allows pending + unfinished log); routing ignores it, as today |
| Backup with no current program | Valid; after restore the root shows onboarding prefilled from the newest archived program (m4-settings §5.2) |
| Empty backup (six empty tables) | Valid; after restore: onboarding at A1 with defaults (nothing to prefill) |
| Same backup imported twice | Second import replaces identical rows; ids and fields equal; `ReminderHost` key unchanged → no notification churn |
| Re-import of this store's own export while the store has changed since | The changes since the export are lost (the dialog says so); nothing else |
| Unknown `exerciseKey` (a key removed in a later library) | Restored; screens show the raw key or skip the info (existing optional reads); swap and detail refuse it |
| `preferences` restored with `reminderEnabled: true` on a phone whose permission is not determined / denied | The row states of m4-reminder ("Allow notifications" / "Open iOS Settings"); no system prompt is triggered by a restore; the host's desired set is empty until allowed |
| `preferences` restored with `units: "kg"` on an lb phone | The restored Home renders kg at once (every reader is in `body`); the file's weights were pounds, so nothing is converted twice |
| `preferences` object absent (hand-trimmed file) | Rows restored, this phone's preferences untouched (5.7) |
| Duplicate note keys in the file | Rejected as damaged (rule 9, NB4): the app never writes two notes for one key |
| Save fails (store refuses) | Scratch context dropped; a fresh context reads the old graph; the main context was never touched (the researcher's measured shape) |

---

## 7. Out of scope

CSV export; merge or selective import; iCloud / CloudKit sync; a custom UTType or `CFBundleDocumentTypes` (opening a backup from Files into
the app); restoring the notification permission (system state); a "Last backup" row (Q6); an activity indicator while reading; time-zone re-anchoring of
`scheduledDate`; encryption or a passphrase; an automatic or scheduled backup; a V2 schema or any migration stage; deleting the temp file
after the share completes (no completion callback exists); localisation of the copy.

---

## 8. Acceptance criteria

**Screens** (iPhone 15 / iOS 17.5, `simctl ui appearance dark`, wait ≥ 2 s; check = matches by `/design-compare`; the `settings` crop 800×290 @
(2555, 4148) on the 5600 render; Settings launches add `-tab settings`; `defaults delete seed` first).

1. **`settings` (D3)**, `-seed midProgram -tab settings`: matches with m5-haptics AC-1's deviations. **New deviation to skip: a third card,
   "BACKUP" / "Export backup…" / "Restore from backup…", under EQUIPMENT (the prototype has none); it sits below the fold on the 6.1" screen, so
   a second shot after scrolling to the bottom checks the card itself** (header style = the other two headers; two accent action rows, one
   hairline, radius 16). **The scroll is a tap: covered by the plan's Step 9 scratch XCUITest, else user-run** (planner 4).
2. **Confirmation**, `-seed backup-confirm -tab settings` (no snapshot; spot check): the dialog reads "Replace everything with this backup?",
   the message of 5.2 row 1 verbatim, "Replace and restore" in the destructive style, "Cancel"; Settings behind it (the BACKUP card itself is below the fold: seeing it behind the
   dialog needs a scroll, Step 9 XCUITest or user-run, planner 4). With `-appearance light` (simulator dark): a light dialog (m4-settings AC-5's
   mechanism).
3. **Read failed**, `-seed backup-failed -tab settings`: the alert "Couldn't read this backup" / "This backup was made by a newer version of
   HomeGymLog. Update the app, then try again." / "OK" over unchanged Settings.
4. **Restoring**, `-seed backup-restoring`: a `bg` screen with "Restoring…" centred in `mu`; no tab pill, no shell.
5. **Regression**: `home`, `program`, `progress`, `missed`, `ob0`–`ob5`, every workout seed, `reminder-*`, `settings-restart`, `restarted`,
   `-units kg`, `-appearance light` unchanged (the card is the only visible addition, on Settings only).

**Behaviour, user-run or a scratch-copy XCUITest** (taps are refused here):

6. **Export**: `-seed midProgram -tab settings`, tap "Export backup…" → the share sheet with "HomeGymLog backup"; "Save to Files" → a file
   named `HomeGymLog-backup-2026-09-15.json` (the frozen day); its content decodes with `BackupCodec.read` and has 5.2 row 1's counts. Cancel
   the sheet → Settings unchanged. An unseeded launch names the file with today's date.
7. **Restore, cancel paths**: tap "Restore from backup…" → the picker; Cancel → Settings unchanged. Pick a non-backup JSON (`{"a":1}`) →
   AC-3's alert with "This file isn't a HomeGymLog backup."; pick a file with `"app":"Benchmark"` → "This backup belongs to another app
   (Benchmark), not HomeGymLog."; pick a damaged one (a dangling `exerciseID`) → "This backup is damaged and can't be restored."; pick a
   valid one and Cancel the dialog → nothing changed (Home, Program, Progress as before).
8. **Restore, confirm**: from `-seed progress-history -tab settings` pick the AC-6 file (`midProgram` only) → "Replace and restore" → a brief
   "Restoring…" → Home of the restored program (`home`); Progress "Dumbbell Bench Press" shows **only** the current program's points (the
   archived program is gone); Settings "Current" · "6-month program · 5 days"; the tab pill highlights Home. **Preferences:** from `-seed
   progress-history -tab settings -units kg -appearance light` (simulator dark) pick the same file (exported from the default suite: lb, System)
   → after the restore the screen is dark (System) and every weight is in lb; Settings reads System · lb; a file edited to `units: "kg"`,
   `appearance: "dark"`, `reminderEnabled: true` restored on a fresh simulator → kg everywhere, dark, and the Daily reminder on with "Allow
   notifications" (permission never restored). Pick a backup whose only program is
   archived → onboarding at A2 prefilled (`ob1`). Pick a **hand-made** backup containing an in-progress log on its current program (planner 5: the UI cannot
   export one, Settings is never mounted during a workout; the file is AC-14's sample document, whose log is unfinished, or `wo-start`'s rows
   exported by a unit test through `BackupSnapshotBuilder`) → the workout screen with every set pending; its rest card absent (no rest stored).
   The data half (a `wo-start` store exported, re-imported, in-progress predicate matching the same log id) is a unit test under AC-15.
9. **Reminders after restore** (device): with the reminder on and a backup whose pending days differ, the pending notification list
   (Settings → Notifications is not enough; use a debug print in the notifier or the m4-reminder recorder in a scratch test) equals the desired
   set for the restored rows within one reconcile.
10. **VoiceOver** (Inspector or device): after "Marcy home gym" / "150 lb stack": "BACKUP" → "Export backup…, button" → "Restore from backup…,
    button". The dialog's and alerts' buttons carry their visible titles. No hint, no third string (every spoken string is in `BackupText` or
    reused from `SettingsText`).

**Unit tests** (Engine and Shared suites plain; persistence suites `@MainActor`, fresh in-memory store per test, container held for the test):

11. **Schema**: `AppSchema.schema.version == Schema.Version(1, 0, 0)`; `AppMigrationPlan.schemas.count == 1`, `stages.isEmpty`; `AppSchemaV1.models`
    names exactly the six classes. **Fixture** `HomeGymLogTests/Support/Fixtures/unversioned-1.0.0.store` (+ `-wal`, `-shm`), written **once**
    by a throwaway test on the **26.5** runtime against HEAD's unversioned `AppSchema` **before** the V1 change lands (gotchas SwiftData
    2026-09-29: on 17.5 the rows stay in the `-wal`), committed, and **never regenerated**: it is the two-install migration test for every future
    schema version. It holds `insertSampleGraph`. The test locates the three files through **`#filePath`** (NB3, INSIGHTS 2026-09-25: never
    `Bundle.main`; `-wal` / `-shm` bundle copying is unverified), copies them to a temp URL, opens them with
    `AppSchema.schema` and `AppMigrationPlan`, reads P 1 · S 3 · L 1 · E 2 · T 6 · N 1, the note "incline notch 2", `rpeSkipped == false` on
    every set, then rolls back / releases before deleting the files (gotchas 2026-09-14). Runs on 17.5 and 26.5.
12. **Codec**: `encode` output has sorted keys and the 4.4 top-level key set; `read(encode(d)) == d` for the sample document up to dates within
    1 ms (5.6); re-encoding the decoded document equals the first bytes; a whole-second date is exact; `Date.distantPast` round-trips; a date with
    fractional seconds decodes on both runtimes; `"2026-09-15T12:00:00Z"` (no fraction) also decodes through the plain-formatter fallback (5.6); a 17-digit `Double` (`152.49999999999997`)
    is bit-identical after a round trip; `preferences` round-trips with all eight keys and with a nil object.
13. **Validation**: every row of 5.1 (rules 1–11) as its own case on mutated copies of the sample document, each asserting the exact
    `BackupReadError`; the tolerated list (nil parents, an unknown key, an empty document) returns nil; the rule order (a file failing 2 and 3
    reports `otherApp`). `BackupPreferences`: every hand case of 5.7 through `resolved()`, the two seed rows, a wrong-typed field and a
    non-object `preferences` decoding without error (Engine suite).
14. **Round trip through the store**: `insertSampleGraph` → `document(in:exportedAt:)` → encode → decode → `replaceAll` into a second store →
    `document` again → **byte-identical** encode (the researcher's test shape); counts, ids, `swappedFromKey`, `rpeSkipped`, `restEndsAt`,
    `archivedAt`, `startingWeightsLb` and note text equal.
15. **Replace over a populated store**: `midProgram` rows (P 1 S 120 L 10 E 50 T 150 N 0, derived in 5.2 row 1) replaced by the sample document →
    a fresh context reads P 1 S 3 L 1 E 2 T 6 N 1 and `ProgramStore.current` is the file's program id; the reverse direction reads `midProgram`'s
    counts; the `progress-history` rows (P 2 S 132 L 22 E 110 T 330 N 0, 5.2 row 2) exported and re-imported keep every count; a session's
    `program?.id`, a set's `exercise?.workout?.session?.id` chain resolve after the import.
16. **Failed replace**: `replaceAll(with:in:)` driven against a container reopened `allowsSave: false` (the `ProgramArchiveRollbackTests`
    technique) throws; a fresh writable context still reads the old graph; the container's main context has `hasChanges == false`; the scratch
    context inside `replaceInScratch` is gone without `rollback()`; a new `StoreCommitReplaceTests.swift` holds the `replaceInScratch` success and throw cases; the test rolls back its own pending state before deleting the store file (gotchas 2026-09-14).
17. **Summary and text**: `BackupDocument.counts` for 5.2 rows 1–3; `confirmMessage` for the three rows (U+202F normalised) plus singulars
    ("1 workout", "1 note"); `fileName` for 5.3's three dates and a 23:30 / 00:30 pair in America/New_York; `readFailedMessage` for all twelve
    error cases (the eight "damaged" cases share one string); every fixed string verbatim (labels end in U+2026).
18. **Seeds**: `backup-confirm` and `backup-failed` rows equal `midProgram`'s, `forcesMissedDayPrompt` false, `settingsBackupPreview` = `.confirm` /
    `.readFailed`, nil for every other seed; `backup-restoring` → `.restoring`; the confirm seed's document equals `BackupSnapshotBuilder.document`
    over its rows at Tue 2026-09-15 12:00 with 5.7's `midProgram` preferences.
19. **Static** (counts grepped 2026-09-29: `delete(model:` 0 lines under `HomeGymLog/`; `ModelContext(` in `Models/` only in `StoreCommit.swift`;
    `.alert(` and `.confirmationDialog(` 1 line each in `SettingsView.swift`; `SettingsDivider()` 8 lines in `SettingsContent.swift`;
    `rollback()` 2 lines, both in `StoreCommit.swift`). After: `delete(model:` still 0; `ModelContext(` in `Models/` still only `StoreCommit.swift`
    (`StoreCommitSourceTests` unchanged: `replaceInScratch` lives there, B2); `rollback()` still 2 (`FailedSavePolicySourceTests.rollbackOnlyInStoreCommit`
    unchanged); `RootView.swift` contains no `ModelContext(` and no `FetchDescriptor` (`SettingsSourceTests.rootViewHasNoFetch` unchanged); a
    new scan pins `BackupStore.replaceAll`'s body free of `await` (NB2); in `RootView.swift` the restore handler's lines between its
    `BackupStore.replaceAll(` call and the line clearing the restore state contain neither `currentPrograms` nor `activeLogs` nor `.first`
    (B3's handler rule; the same line-range scan shape as `FeedbackSourceTests`' Skip-order test); `Engine/AppearanceMode.swift` has no `import UIKit` and no `label`
    (B1);
    `.iso8601` as a date strategy appears nowhere in the app target; `.sortedKeys` on the one encoder line of `Engine/Backup/BackupCodec.swift`;
    `Engine/Backup/*.swift` import only Foundation; `"HomeGymLog-backup-"` appears once, in `Shared/BackupText.swift`; `Date()` nowhere new
    (`ClockUsageTests` green); `SeedNameScanTests.names` gains `"backup-confirm"`, `"backup-failed"`, `"backup-restoring"`. `DebugSeedTests.parses(seed:)` (`HomeGymLogTests/Seed/DebugSeedTests.swift:10-27`) gains a case for the three `backup-*` seeds with their 2026-09-15 clock, since its `default:` expects 2026-08-31 (verifier-1 finding 1). New `BackupSourceTests` (verifier-1 finding 3): the backup DTOs use `CodingKeys` with no raw values, so each JSON key is the case name, which equals the storage key. No quoted preference-key literal (`"appearance"`, `"missedDayPolicy"`, `"reminderEnabled"`, `"reminderMinutes"`, `"hapticsEnabled"`, `"soundEnabled"`) appears under `Engine/Backup/`, so the four reader scans stay unchanged.
    **Existing tests this slice changes:** `SettingsScreenSourceTests.filesScanned` (the file list gains `BackupFile.swift`,
    `BackupImportAction.swift`, `BackupRows.swift`); `.dividerCount` 8 → **9**; `.sectionHeaders` (a strengthening, not a break: it collects `SettingsText.` members only) → `["programSection", "equipmentSection",
    "backupSection"]` with `backupSection` read from `BackupText` (or the test's filter widened to `BackupText.section`); `.noLiteralCopy` unchanged (it rejects only
    `Text("` / `Button("` / `Label("` literals, which the new files never use; planner 6). **Reader scans (Q1 = B: `RootView` gains five `@AppStorage` bindings; it already has `units`, `appearance`,
    `bodyWeightUnits`):** `ReminderSourceTests.preferenceReaders` → `["App/ReminderHost.swift", "App/RootView.swift",
    "Features/Settings/SettingsView.swift"]`; `FeedbackSourceTests.hapticsReaders` → `+ "App/RootView.swift"`, `.soundReaders` → `+ "App/RootView.swift"`;
    `MissedPromptSourceTests` "appears in exactly two files" → three, adding `App/RootView.swift`; **B1:** `SettingsSourceTests.storageKeyLiterals`
    → the `"appearance"` literal's path becomes `Engine/AppearanceMode.swift`, and `.appearanceMechanism`'s no-UIKit filter names
    `Engine/AppearanceMode.swift`; `.appearanceReaders` unchanged (the root uses the key constant). No other existing test changes; the 33 `ModelContainer(for: AppSchema.schema, …)`
    sites compile unchanged.
20. Release build compiles (nothing DEBUG-only leaks: the preview enum and `BackupSeed` under `#if DEBUG`); the suites are green on iOS 17.5 and
    26.5; the App Privacy label stays "Data Not Collected" (no plist key, entitlement or capability added: `project.pbxproj` untouched).

---

## 9. Decisions (user-answered 2026-09-29)

| # | Decision |
|---|---|
| Q1 = **B** | The eight preferences (`units`, `bodyWeightUnits`, `appearance`, `missedDayPolicy`, `reminderEnabled`, `reminderMinutes`, `hapticsEnabled`, `soundEnabled`) ride in an optional `preferences` object and are written by the root only after the store save succeeded, each through its per-key fallback (5.7); appearance re-applies through the existing window override, reminders through the host's key, units through the `body` readers; the notification permission is never restored; the dialog says "Your settings are replaced too."; three reader scans gain `App/RootView.swift` (AC-19) |
| Q2 = **A** | Archived programs and their history are included |
| Q3 = **A** | A restore lands on Home of the restored data, no alert |
| Q4 = **A** | "BACKUP" / "Export backup…" / "Restore from backup…" |
| Q5 = **A** | The card sits below EQUIPMENT |
| Q6 = **A** | No "Last backup" row |
| Q7 = **A** | An in-progress log is restored as is and the workout resumes |

| Review | `docs/reviews/m5-export-architecture.md` applied: B1 (`AppearanceMode` → Engine, `label` a Shared extension), B2 (`StoreCommit.replaceInScratch` opens the scratch context; the root never does), B4 (`onRestore` closure through `ShellView`; the root sets Home), NB1–NB8 inline. **B3 resolved** (researcher addendum 2026-09-29): plain flag cleared in the same synchronous handler; the first render after it already holds the new rows on 17.5 and 26.5; the handler never reads a `@Query` after the save (on 17.5 it is still the deleted row); the hold fallback worked but never engaged and is not built. INSIGHTS entries to add (doc-writer): the review's seven "decisions to record" |

| Planner | `docs/plans/m5-export.md` "Spec issues" 1–7 aligned: `SettingsView` builds the export preferences (reader scans unchanged); the date decoder falls back to a plain formatter; header, card and divider in `SettingsContent`, `BackupRows` = rows only, divider count 9; AC-1/AC-2 scroll checks → Step 9 XCUITest or user; AC-8's in-progress backup is hand-made, the data half a unit test; `.noLiteralCopy` untouched; `id.uuidString` the last sort key in every table |

Nothing remains open.

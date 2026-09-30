# m5-export researcher report (2026-09-29)

**Direct answer.** Retrofit the schema as `AppSchemaV1: VersionedSchema` whose `models` lists the six existing top-level classes (no nested copies, no typealiases), `versionIdentifier = Schema.Version(1, 0, 0)`, plus `AppMigrationPlan` with one schema and `stages: []`; `AppSchema.schema` becomes `Schema(versionedSchema: AppSchemaV1.self)` and `makeContainer` passes the plan. Verified to open an unversioned on-disk store with every row intact on iOS 17.5 and 26.5 (the unversioned store already records version `1.0.0`), and nothing else in the codebase changes: `@Query`, `#Predicate<Program>` and the 40+ test call sites that build `ModelContainer(for: AppSchema.schema, …)` keep compiling and passing.
**Import** = decode and validate the whole file into Codable DTOs first (Engine), then in a scratch `ModelContext(container)`: per-row deletes through the existing explicit-cascade helpers, insert the new graph, one `save()`; on failure drop the context. Never `ModelContext.delete(model:)`: it throws `NSCocoaErrorDomain 134050` for `LoggedSet`, `LoggedExercise` and `PlannedSession` on both runtimes, and it writes to the store immediately, outside the save. **Export** = `ShareLink` with a `Transferable` `FileRepresentation(exportedContentType: .json)` (Save to Files, AirDrop, Mail from one sheet); **import** = `.fileImporter(allowedContentTypes: [.json])`. No plist key, no capability, App Privacy label unchanged.

## Configuration every claim was verified under

- Xcode 27.0 (27A266a), iOS 27.0 simulator SDK. Runtimes: iPhone 15 / iOS 17.5 and iPhone 17 / iOS 26.5 (xcodebuild test clones).
- A scratch copy of the repo at `36ef597` (branch `m5-export`) under the scratchpad, bundle id `com.zhabskyi.homegymlog.probe`. App target: Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency, deployment target 17.0. The scratch app target carried `Models/AppSchemaV1.swift` (the V1 below), the two-line `AppSchema.swift` change, and `Features/Settings/BackupShareProbe.swift` (a compile-only probe of the export and import APIs).
- Probes ran in the hosted test target `HomeGymLogTests` (no default isolation; `@MainActor` suites), file `HomeGymLogTests/Probe/ExportProbeTests.swift` of the scratch copy, against on-disk stores at temp URLs (`ModelConfiguration(schema:url:)`, SQLite in WAL mode). Every read-back after an action is a direct `FetchDescriptor`/`fetchCount` of the row type (the app's access path); `@Query` behaviour was probed with a real `@Query` view hosted in a `UIWindow`.
- Caveat on question 1: the versioned-open probes write with `Schema([six classes])`, release the container, and reopen the same file with V1 in one process. The two-install path (build A, then a versioned build over its store) was covered by the M3 researcher's D scenario (`docs/reviews/m3-logging-researcher.md`, addendum §3) with nested copies; the store metadata is the same (`NSStoreModelVersionIdentifiers = ("1.0.0")`, identical `NSStoreModelVersionHashesDigest`).
- Regression: the scratch copy's full suite (probes skipped) against the versioned `AppSchema`: iOS 26.5 — 1095 tests, 1061 passed; the 34 failures are all static source-scan suites (`ReminderSourceTests`, `FeedbackSourceTests`, `SettingsSourceTests`, `SeedNameScanTests`, `FailedSavePolicySourceTests`, `ColorsetContrastTests`, `ClockUsageTests`, `MissedPromptSourceTests`, `ProgressSourceTests`, `RestNotifierSourceTests`, `SettingsScreenSourceTests`) broken by the scratch copy itself (its `#filePath` root renders as `/privateApp/...`, and `BackupShareProbe.swift` adds Settings string literals); no persistence, engine or view test failed; iOS 17.5 — identical (1061 passed, the same 34 source-scan failures).
- Not probed: anything the share sheet or the document picker shows (taps are refused on this machine), iCloud Drive downloads (no iCloud account on the simulator). Marked unverified below.

## 1. Retrofit V1

**Verdict: works on 17.5 and 26.5 with no data loss; the codebase change is one new file and two lines.**

Shape (compiles in the app target with no warning, `nonisolated` not needed under MainActor default isolation; the M3 researcher only tried it with `nonisolated`, both are fine):

```swift
// Models/AppSchemaV1.swift
import Foundation
import SwiftData

/// The frozen shipped schema. Its models are the live top-level classes until a V2 exists; at that point copy the six
/// classes here as nested `@Model`s (verbatim stored properties, inverses pointing at the nested types) and point V2 at the
/// top-level ones with a `.lightweight` stage.
enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)   // = the default `Schema([...])` wrote into every existing store
    static var models: [any PersistentModel.Type] {
        [Program.self, PlannedSession.self, WorkoutLog.self, LoggedExercise.self, LoggedSet.self, ExerciseNote.self]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// Models/AppSchema.swift: the only two changed lines
static let schema = Schema(versionedSchema: AppSchemaV1.self)
return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])
```

Evidence (both runtimes unless noted):
- An unversioned store (HEAD's six models, `rpeSkipped` included) opened under V1 with the plan: `P=1 S=3 L=1 E=2 T=6 N=1`, every `rpeSkipped == false`; a write (`rpeSkipped = true`) saved and read back after reopening; a reopen with a plain `Schema([...])` and no plan (what the 40+ `ModelContainer(for: AppSchema.schema, configurations:)` test call sites do) read the same rows.
- `Schema.init(_ types:version:)` defaults `version` to `Version(1, 0, 0)` (SwiftData swiftinterface, iOS 27.0 SDK), so the unversioned store's metadata already reads `NSStoreModelVersionIdentifiers = ("1.0.0")`. `Schema(versionedSchema: AppSchemaV1.self).version == 1.0.0` and `AppSchema.schema.version == 1.0.0` after the change. Keep 1.0.0.
- A V1 declared as `Version(2, 0, 0)` over the same unversioned store also opened with all rows (the plan locates the store's version by entity hashes, and the metadata still said 1.0.0 afterwards). Do not rely on that; it only shows the identifier is not what is matched.
- Nested vs top-level: `models` only needs the metatypes, so the six classes stay top-level and every `@Query`, `#Predicate<Program>`, `FetchDescriptor<Program>` and `\Program.x` key path is unchanged. Typealiases inside the enum would be cosmetic. When V2 lands, V1 gets nested frozen copies and the entity names are the last path component (`AppSchemaV1.Program` → entity `Program`), as the M3 D probe showed.
- Availability: `VersionedSchema`, `SchemaMigrationPlan`, `MigrationStage`, `Schema.init(versionedSchema:)`, `ModelContainer.init(for:migrationPlan:configurations:)` are all iOS 17.0. No entitlement.
- Seeds and tests: `DebugSeed.makeContainer` and `makeTestStore()` go through `AppSchema.makeContainer(inMemory: true)`, so they pick up the plan with no edit (the full scratch suite ran that way).

Suggested tests: `AppSchema.schema.version == Schema.Version(1, 0, 0)`; `AppMigrationPlan.schemas.count == 1 && stages.isEmpty`; the fixture test of question 8.

React analogy: `AppSchemaV1` ≈ the initial Prisma migration file frozen in `migrations/`; the plan ≈ the ordered migration list; `Schema(versionedSchema:)` ≈ pointing the client at the latest migration.

## 2. Backup format and encoding

**Verdict: a plain Codable DTO mirror with `formatVersion` is the right approach; ISO 8601 with fractional seconds is millisecond-precise, not exact, so the brief's "so round-trips are exact" is wrong as stated.**

- `@Model` classes are not `Codable`: `PersistentModel` does not refine `Codable` ([PersistentModel](https://developer.apple.com/documentation/swiftdata/persistentmodel)), the macro rewrites stored properties into accessors, and relationships are object graphs. Apple has no "export SwiftData to JSON" doc; the DTO mirror is the forum consensus ([Forum: SwiftData and Codable](https://developer.apple.com/forums/thread/731529), blog-level otherwise) and matches this codebase's snapshot builders (rows → Engine values).
- Shape: flat tables with id references, mirroring the rows: `BackupDocument { formatVersion: Int (1), exportedAt: Date, programs: [ProgramDTO], sessions: [PlannedSessionDTO] (programID), workoutLogs: [WorkoutLogDTO] (sessionID?), loggedExercises: [LoggedExerciseDTO] (workoutID?), loggedSets: [LoggedSetDTO] (exerciseID?), exerciseNotes: [ExerciseNoteDTO] }`. Each DTO carries the row's `id: UUID`, raw strings for the enums (`phaseRaw`, `statusRaw`), `[PlannedExercise]` (already Codable), `[Int]`, `[String: Double]`, and `Double` pounds. Optional parent ids keep today's orphan-tolerant schema (all to-one relationships are optional).
- Dates: `ISO8601DateFormatter` with `[.withInternetDateTime, .withFractionalSeconds]` writes milliseconds. Measured round trip: 2 of 4 dates exact (the whole-second ones), all 4 within 1 ms (deltas +0.255 ms, −0.457 ms on 17.5; +0.376 ms, −0.457 ms on 26.5), re-formatting the decoded date gives the identical string, `Date.distantPast` (the models' default) writes `0001-01-01T00:00:00.000Z` and round-trips. The JSON default `.deferredToDate` (Double seconds since 2001) round-trips bit-exactly but is unreadable. Recommendation: keep ISO 8601 with fractional seconds and define the format contract as millisecond precision (tests compare at ≤ 1 ms or compare re-encoded bytes); pick `.deferredToDate` only if exactness outranks readability.
- Never use `JSONDecoder.DateDecodingStrategy.iso8601` for this file: it rejects fractional seconds on iOS 17.5 (decodes `"…T10:00:00Z"` only) and accepts them on 26.5. Use a `.custom` strategy around one `ISO8601DateFormatter` (verified on both).
- `UUID` encodes as its uppercase string natively. `Double`: JSON numbers round-trip bit-exactly on both runtimes (`42.3`, `37.5`, `0.30000000000000004`, `1e-07`, `152.49999999999997` all identical `bitPattern`).
- Encoder options: `.sortedKeys` is required for byte-stable output. Without it, encoding the same value twice in one process gave different bytes on 26.5 (swift-foundation's key order) and identical bytes on 17.5; with it both are stable. `.prettyPrinted` optional (a 6-month program is a few hundred KB either way), `.withoutEscapingSlashes` optional.
- Ownership: Engine owns the DTO types, `formatVersion`, the encoder/decoder configuration and validation (pure, unit-tested: `Engine/Backup/BackupDocument.swift`, `BackupCodec.swift`, `BackupValidation.swift`); Models owns rows ↔ DTOs (`Models/BackupSnapshotBuilder.swift`, like the other snapshot builders) and the writer (`Models/BackupStore.swift`). Formatting of the file name goes through a `*Text` helper in Shared as usual.

```swift
// Engine/Backup/BackupCodec.swift (compiles against iOS 17; strategies verified on 17.5 and 26.5)
enum BackupCodec {
    static let formatVersion = 1
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(iso.string(from: date))
        }
        return e
    }
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            guard let date = iso.date(from: s) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an ISO 8601 date: \(s)"))
            }
            return date
        }
        return d
    }
}
```

React analogy: the DTO document ≈ `JSON.stringify(store.getState())` with a `version` field; the builder ≈ a selector that flattens normalized entities.

## 3. Import atomicity

**Verdict: per-row deletes + inserts + one `save()` in a scratch `ModelContext(container)`, after full DTO validation; replace only. `delete(model:)` is out.**

`ModelContext.delete(model:where:includeSubclasses:)` (iOS 17.0; the doc abstract says "during the next save operation") measured on both runtimes:
- It runs against the store at once: after `delete(model: ExerciseNote.self)` and no save, `hasChanges == false` and a fresh context already reads 0 notes. It is not part of the next save, so it cannot be inside an all-or-nothing write.
- It throws `NSCocoaErrorDomain 134050 "Constraint trigger violation: Batch delete failed due to mandatory OTO nullify inverse on LoggedSet/exercise"` for `LoggedSet`, `LoggedExercise` and `PlannedSession` (each has a to-one whose inverse is a to-many cascade); it succeeds for `WorkoutLog`, `Program`, `ExerciseNote`. `delete(model: Program.self)` cascades the whole graph on both runtimes, 17.5 included (the batch path honours the rules the context path ignores), which is why a delete-everything through it "worked" in the M5 planning and would work in practice only by accident of ordering.

Replace shapes (a 3-session graph replaced by a 2-session one):
- Per-row: `ProgramStore.delete(program, in:)` for every program (it already deletes sessions, logs, exercises and sets explicitly), `WorkoutLogStore.delete` for any orphan log, then leftover rows of each type and the notes; insert the new graph; one `save()`. 5 ms (17.5) / 9 ms (26.5) for a 6-session graph. A fresh context then reads only the new graph. `transaction {}` is the same operations with the save at the end (`hasChanges == false` after); no extra isolation, so use `save()` like every other store writer.
- Mid-import (before the save) the writing context's own fetches already show the new graph (pending deletes excluded, pending inserts included). No other context sees anything until the save. Do the whole write synchronously on the main actor (no `await` between the first delete and the save) so no `body` can run in between.
- Failure (store reopened `allowsSave: false`, the INSIGHTS technique): `save()` throws Cocoa 513, the store is intact (a fresh writable context reads the old graph), but the writing context keeps `hasChanges == true` and its fetches are mixed (17.5: the new graph; 26.5: `P=2`, old program plus new). `rollback()` in that state: crashed the test host (no further log line; the pending-delete trap of gotchas 2026-09-13) on 17.5, survived and the context read the old graph again (`P=1 S=3`, `experience=old`, `hasChanges == false`) on 26.5. So the writer must be a context you can throw away.
- Scratch context: a replace-all saved from `ModelContext(container)` is seen by `mainContext.fetch` immediately (`P=1 S=2`, `hasChanges == false`), and a mounted `@Query` view refreshed from a scratch-context save on both runtimes (counts `1 → 2` after a scratch insert, `→ 3` after a main-context insert, `→ 1` after a scratch replace-all). Old `Program`/`PlannedSession` objects still registered in the main context kept reading their stale values (`months=1`, `experience=old`, `isDeleted=false`, `sessions.count=3`) and a session whose fields had never been read returned its values without trapping, on both runtimes. The 26.5 fault trap of gotchas 2026-09-13 ("backing data could no longer be found" for a not-yet-loaded child after another context's delete) did not reproduce here, but it is real elsewhere, so the UI must not keep reading old rows across the import.

Recommended import path:
1. Decode the whole file into `BackupDocument` (`JSONDecoder` fails atomically) and run `BackupValidation` (Engine, pure): `formatVersion == 1`; ids unique per table; every parent id resolves; at most one program with `archivedAt == nil`; at most one log with `finishedAt == nil`; `Phase`/`SessionStatus`/`SetStatus` raw values valid; `trainingWeekdays` in 0…6 with `count == frequency`; `rpe` nil or 6…10; `session.status == .completed` iff its log has `finishedAt`. Only a valid document reaches the store.
2. `RootView` sets `@State isRestoring = true`; its routes render a plain "Restoring…" view (the `isDiscarding` pattern of the workout screen), so no shell or workout view holds rows; a `.task(id: isRestoring)` then runs step 3 after that render.
3. `BackupStore.replaceAll(with: document, in: ModelContext(container))`: per-row deletes, inserts from DTOs, one `save()`. On throw: drop the context, show the error, `isRestoring = false`; the screen and the store still hold the old data. On success: `isRestoring = false`; the root's `@Query`s have re-fetched (question 5 of the probe), `currentPrograms.first` is the new `Program` instance and `ShellView` mounts fresh.
4. `ReminderHost` is keyed `.id(currentPrograms.first?.id)`, so a new program id remounts it and its reconcile runs (question 4).

Merge vs replace: replace only. Row ids from a backup may collide with existing rows; "at most one current program" (`ProgramStore.current` asserts ≤ 1 in DEBUG), one `WorkoutLog` per session and one note per key have single writers with no conflict rules; a merge would need rules nothing else in the app has. Present the import as destructive (confirmation dialog) and recommend exporting first.

React analogy: the scratch context ≈ a second DB connection running one transaction; dropping it on failure ≈ never dispatching the optimistic update.

## 4. In-progress workout, rest notification and reminders during import

- Reachability: Settings is only mounted while `RootView` routes to the shell, i.e. while the current program has no in-progress log. So no live workout, no live rest and no pending `rest-timer` notification exist at import time; nothing to tear down.
- A backup may legitimately contain an in-progress log (`finishedAt == nil`, "an in-progress workout must survive app kill"). After the save, `RootView`'s in-progress `@Query` matches it and routes to `WorkoutView`, whose `.task(id:)` calls `RestNotifier.reconcile(restEndsAt:…)`: a past `restEndsAt` cancels, a future one (a backup made moments ago) schedules. Reconciled from state, as designed; no import-specific code.
- Reminders: `ReminderHost` recomputes its `Equatable` key from a `@Query` of the program's sessions (`pendingDays`), `workoutInProgress`, the preferences and the permission status; `ReminderNotifier.reconcile` removes every pending and delivered `reminder-*` id not in the desired set before adding. A replaced program (new id) remounts the host through `.id(programID)`; a re-import of the same program id refreshes the query on save (the `@Query` refresh above), and an unchanged key means nothing to do. Read from the code, not probed with the notification center.
- Preferences are not in the store (`@AppStorage`: units, appearance, missed-day policy, reminder on/time, haptics, sound). The spec must say whether the backup carries them; if it does, put them in an optional `preferences` object applied after the store write, and the `ReminderHost` key changes cover the reminder side.
- Keep `ReminderHost` mounted during the restore: it reads `currentPrograms.first?.id`, a stored field of a possibly stale object, which returned the old value without trapping in the probe, then re-fetches.

## 5. File export API on iOS 17

**Verdict: `ShareLink` + a `Transferable` with `FileRepresentation(exportedContentType: .json)`; `.json`, file name `HomeGymLog-backup-2026-09-29.json`; no plist keys.**

| Option | iOS | What the user gets | Code |
|---|---|---|---|
| `.fileExporter(isPresented:document:contentType:defaultFilename:)` with `FileDocument` | 14.0 | Files picker only (Save to Files); no AirDrop, no Mail | a `FileDocument` type + state |
| `.fileExporter(isPresented:item:contentTypes:defaultFilename:onCompletion:onCancellation:)` with `Transferable` | 17.0 | Files picker only | the same `Transferable` as below |
| `ShareLink(item:preview:)` with a `Transferable` file | 16.0 | the share sheet: Save to Files, AirDrop, Mail, Messages… | one `Transferable`, one view |
| `UIActivityViewController` via `UIViewControllerRepresentable` | 6 | the same sheet | the most code, no gain |

Availability read from the iOS 27.0 SDK swiftinterfaces: `fileExporter` document overloads iOS 14.0 (deprecated in favour of Transferable), the `item:` overload iOS 17.0; `ShareLink` iOS 16.0; `FileRepresentation`, `SentTransferredFile`, `DataRepresentation`, `suggestedFileName(_ string:)` iOS 16.0, `suggestedFileName(_ closure:)` iOS 17.0; `Transferable: Sendable`. No capability or entitlement.

```swift
// Compile-verified in the app target (Swift 5, MainActor default isolation, deployment 17.0), no warnings.
import SwiftUI
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

struct BackupFile: Transferable {
    let fileName: String            // "HomeGymLog-backup-2026-09-29.json", date from AppClock
    let container: ModelContainer   // @unchecked Sendable

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let data = try await MainActor.run {            // rows are read on the main actor, then encoded in Engine
                try BackupCodec.encoder().encode(BackupSnapshotBuilder.document(from: file.container.mainContext, …))
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
            try? FileManager.default.removeItem(at: url)   // the previous export
            try data.write(to: url, options: [.atomic])
            return SentTransferredFile(url, allowAccessingOriginalFile: false)   // the system copies it
        }
        .suggestedFileName { $0.fileName }
    }
}

// In Settings: one row.
ShareLink(item: BackupFile(fileName: …, container: container),
          preview: SharePreview("HomeGymLog backup", image: Image(systemName: "doc.text"))) {
    Label("Export backup…", systemImage: "square.and.arrow.up")
}
```

- The `exporting` closure is `@Sendable async`; the store read hops to the main actor. Whether the system runs it when the sheet opens or only when an activity is chosen is unverified here (no UI probe); either way it is lazy relative to the Settings render.
- `.json` is `public.json` (conforms to `public.text`), so Files, Mail and AirDrop handle it with no declaration. A custom type (`com.zhabskyi.homegymlog.backup`) would need `UTExportedTypeDeclarations`; this project has `GENERATE_INFOPLIST_FILE = YES` and no `Info.plist` file, so that means the Xcode Info tab, which edits `project.pbxproj`: a user-approved change, and not needed. Opening a backup from Files into the app ("Open in HomeGymLog", `.onOpenURL`) needs `CFBundleDocumentTypes` (and `LSSupportsOpeningDocumentsInPlace` for in-place), the same kind of change; the `.fileImporter` button reaches every file in Files and iCloud Drive without it. Minimal no-plist option: `.json` + `ShareLink` + `.fileImporter`.
- Temp file: `tmp/` (`FileManager.default.temporaryDirectory`). `ShareLink` has no completion callback, so clean up by deleting the previous file before each export (above) and optionally any `HomeGymLog-backup-*.json` in `tmp/` at launch; the system may also purge `tmp/` while the app is not running ([File System Programming Guide, iOS file system layout](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html)).
- Unverified: the share sheet's row set and the displayed file name on 17.5 and 26.5 (taps refused on this machine); the user's MVP pass should check "Save to Files" names the file `HomeGymLog-backup-<date>.json`.

React analogy: `ShareLink` with a `Transferable` ≈ `navigator.share({ files: [new File(...)] })` where the `File` is built lazily.

## 6. File import API

**Verdict: `.fileImporter(isPresented:allowedContentTypes: [.json])` (iOS 14.0; the `onCancellation:` overload is iOS 17.0); start security-scoped access, read through `NSFileCoordinator`, stop access.**

```swift
// Compile-verified in the app target against iOS 17.
.fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { picked in
    guard case .success(let url) = picked else { return }        // .failure is rare; cancel does not call this
    let accessed = url.startAccessingSecurityScopedResource()     // false for files already inside the sandbox: still read
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    var coordinationError: NSError?
    var data: Data?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
        data = try? Data(contentsOf: readURL)
    }
    // hand `data` to BackupCodec.decoder() + BackupValidation, then RootView's restore
}
```

- Apple's `fileImporter` discussion: "This dialog provides security-scoped URLs. Call the `startAccessingSecurityScopedResource` method to access or bookmark the URLs, and the `stopAccessingSecurityScopedResource` method to release the access." `isPresented` is set to `false` before `onCompletion`; cancel never calls it ([fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:))). `UIDocumentPickerViewController` (what the modifier wraps): "The open and move operations provide security-scoped URLs… Always use file coordinators to read and write to external documents" ([UIDocumentPickerViewController](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller)).
- iCloud Drive files not yet downloaded: the picker is in open mode (not `asCopy`), so it hands back the iCloud URL. A coordinated read waits for the item to be available; the explicit alternative is `FileManager.default.startDownloadingUbiquitousItem(at:)` and polling `URLResourceValues.ubiquitousItemDownloadingStatus` ([startDownloadingUbiquitousItem(at:)](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:))). Both are unverified on the simulator (no iCloud account). Because a wait can be long, run the coordinated read off the main actor (a nonisolated `async` helper) and hop back with the `Data`; the file is small (hundreds of KB) so the decode can stay on the main actor.
- iOS 17 vs 26: the same API and the same security-scoped rules; the picker's look differs (Liquid Glass) and nothing else in the docs. Unverified in the UI.
- Do not persist the picked URL or a bookmark; the import is one-shot.

React analogy: `.fileImporter` ≈ `<input type="file" accept="application/json">`; the security scope ≈ a File System Access API handle you must hold while reading.

## 7. Privacy and data protection

- App Privacy label: unchanged, "Data Not Collected". Apple's label covers data the developer or partners collect (transmitted off device to them); a user-initiated export to Files, AirDrop or Mail sends the user's own file where the user chooses ([App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/); paraphrased, the page's text was not extractable here). Nothing in the app reads the file back except the user's own import.
- Privacy manifest (`m5-release`): the export/import code needs no required-reason entry as long as it never reads file timestamps. `Data.write`, `Data(contentsOf:)`, `FileManager.removeItem`, `fileExists`, `contentsOfDirectory` are not listed. Listed under `NSPrivacyAccessedAPICategoryFileTimestamp`: `creationDate`, `modificationDate`, `fileModificationDate`, `.contentModificationDateKey`, `.creationDateKey`, `getattrlist`, `stat`, `fstat`, `lstat` and friends; reasons `DDA9.1` (display to the user), `C617.1` (files in the app container), `3B52.1` (files the user granted through a document picker), `0A2A.1` (SDK wrapper) ([NSPrivacyAccessedAPIType](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)). So a "Last backup: <date>" row must come from a value the app stores itself at export time (UserDefaults), never from the file's attributes. Flag for `m5-release`: the app already uses `UserDefaults` through `@AppStorage`, which needs `NSPrivacyAccessedAPICategoryUserDefaults` with `CA92.1`.
- File protection: files an app creates default to Complete until first user authentication ("If you do not specify a protection level when creating a file, iOS applies the default protection level automatically… Complete until first user authentication (Default)", [Encrypting Your App's Files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files)); `tmp/` inherits it. `Data.write(options: .completeFileProtection)` compiles but buys nothing here (the share happens unlocked) and could stop a share extension reading the file; keep the default. The export is only readable by the app and the destination the user picks.
- Clean-up: the previous export is removed before the next one; `tmp/` is not backed up and may be purged by the system when the app is not running. Nothing else to retain.

## 8. Testability

**Round trip (in-memory container, hosted test target):**

```swift
@MainActor
@Test func backupRoundTrip() throws {
    let source = try makeTestStore()                       // in-memory, AppSchema.makeContainer(inMemory: true)
    try insertSampleGraph(in: source.context)
    let document = try BackupSnapshotBuilder.document(from: source.context, exportedAt: TestCalendar.day(2026, 9, 29))
    let data = try BackupCodec.encoder().encode(document)
    let decoded = try BackupCodec.decoder().decode(BackupDocument.self, from: data)
    let target = try makeTestStore()
    try BackupStore.replaceAll(with: decoded, in: target.context)   // per-row deletes (none here) + inserts + save
    let again = try BackupSnapshotBuilder.document(from: target.context, exportedAt: document.exportedAt)
    #expect(try BackupCodec.encoder().encode(again) == data)         // byte-identical: .sortedKeys + ms-precision dates
    withExtendedLifetime((source.container, target.container)) {}
}
```
Compare re-encoded bytes (verified stable on both runtimes with `.sortedKeys`) or DTOs with dates at ≤ 1 ms; never `Date ==` against the original rows. Add: replace-all over a populated store (counts and note text after), a failing replace with the `allowsSave: false` reopen pattern (fresh writable context still reads the old graph; the main context is untouched because the writer is a scratch context), a validation table (each invariant rejected), and a static source scan like `StoreCommitSourceTests` asserting `delete(model:` appears nowhere under `HomeGymLog/`.

**Fixture store opened by V1 (feasible):**
- Non-Swift files under the synchronized `HomeGymLogTests/` folder are copied into the test bundle: `probe-fixture.json` under `HomeGymLogTests/Support/Fixtures/` was found with `Bundle.allBundles.first { $0.bundlePath.hasSuffix(".xctest") }?.url(forResource: "probe-fixture", withExtension: "json")` on both runtimes.
- The fixture `HomeGymLogTests/Support/Fixtures/unversioned-1.0.0.store` must be written by today's unversioned `AppSchema` before the V1 change lands (a throwaway test on HEAD that writes a graph to a URL and copies the file out), then committed. Write it on the **26.5** runtime or checkpoint it: on 17.5 the store's `-wal` still held 98–148 KB after the container was released and a `.store`-only copy opened with `P=0 S=0 L=0 E=0 T=0 N=0`; on 26.5 the `-wal` was 0 bytes and the `.store`-only copy read every row. Copying `.store`, `-wal` and `-shm` together also works on both.
- The test copies the fixture from the bundle to a temp URL (the bundle is read-only), opens it with `ModelContainer(for: AppSchema.schema, migrationPlan: AppMigrationPlan.self, configurations: [ModelConfiguration(schema: AppSchema.schema, url: url)])`, asserts the counts and one `rpeSkipped` read, and rolls back or releases before deleting the file (gotchas SwiftData 2026-09-14).

## Unverified

- Share-sheet contents and the shown file name; when `FileRepresentation.exporting` runs; iCloud Drive not-yet-downloaded behaviour of a coordinated read; the picker's iOS 26 UI; `ReminderHost` remount after import (read from code); the App Privacy page wording (paraphrased).
- The `rollback()`-after-failed-replace outcome is reported as measured but the import design never calls it.

## Suggested entries

`insights/INSIGHTS.md` (Patterns):
- 2026-09-29 — Versioned schema retrofit: `AppSchemaV1.models` = the six top-level classes, `Version(1, 0, 0)` (what `Schema([...])` already wrote into every store), a one-schema plan with no stages, `AppSchema.schema = Schema(versionedSchema:)`; nothing else changes. V2 later = nested frozen copies in V1, top-level classes in V2, `.lightweight`.
- 2026-09-29 — Whole-store replace: validate the JSON into DTOs first; per-row deletes through the explicit-cascade helpers, inserts, one `save()` in a scratch `ModelContext(container)`; `@Query` refreshes from a scratch save on 17.5 and 26.5; on failure drop the context. Gate the routes with an `isRestoring` flag like `isDiscarding`.
- 2026-09-29 — Backup JSON: Codable DTO mirror (Engine), rows ↔ DTOs (Models), `.sortedKeys`, ISO 8601 with fractional seconds through a `.custom` strategy (ms precision by contract).

`insights/gotchas.md` (SwiftData):
- `ModelContext.delete(model:)` is an immediate batch delete (the store changes before any save; `hasChanges` stays false) and throws Cocoa 134050 for `LoggedSet`, `LoggedExercise`, `PlannedSession` on 17.5 and 26.5; it does cascade for `Program` on both. Never use it for import.
- On 17.5 a released container leaves its data in the `-wal`; a `.store`-only copy is empty. Copy `-wal`/`-shm` too, or write fixtures on 26.5.
`insights/gotchas.md` (Swift language / Foundation):
- `JSONDecoder` `.iso8601` rejects fractional seconds on 17.5 (accepts on 26.5); `JSONEncoder` without `.sortedKeys` is not byte-stable on 26.5.
`insights/gotchas.md` (Testing):
- `-only-testing:Target/Suite/function` (no `()`) selects nothing silently; use `Target/Suite`. Parallel Swift Testing suites lose lines from a read-append-write log; lock it.

## Sources

- SwiftData swiftinterface, iOS 27.0 SDK (`Schema.init(_:version:)` default `Version(1, 0, 0)`; `ModelContext.delete(model:where:includeSubclasses:)`; `transaction(block:)`; `VersionedSchema`; `SchemaMigrationPlan`; `ModelContainer: @unchecked Sendable`).
- [VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema), [SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan), [Schema.init(versionedSchema:)](https://developer.apple.com/documentation/swiftdata/schema/init(versionedschema:)), [ModelContext.delete(model:where:includeSubclasses:)](https://developer.apple.com/documentation/swiftdata/modelcontext/delete(model:where:includesubclasses:)), [ModelContext.transaction(block:)](https://developer.apple.com/documentation/swiftdata/modelcontext/transaction(block:)), [PersistentModel](https://developer.apple.com/documentation/swiftdata/persistentmodel)
- [fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)), [fileExporter(isPresented:item:contentTypes:defaultFilename:onCompletion:onCancellation:)](https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:item:contenttypes:defaultfilename:oncompletion:oncancellation:)), [ShareLink](https://developer.apple.com/documentation/swiftui/sharelink), [FileRepresentation.init(exportedContentType:shouldAllowToOpenInPlace:exporting:)](https://developer.apple.com/documentation/coretransferable/filerepresentation/init(exportedcontenttype:shouldallowtoopeninplace:exporting:)), [UIDocumentPickerViewController](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller), [startDownloadingUbiquitousItem(at:)](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:))
- [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [NSPrivacyAccessedAPIType](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), [App privacy details](https://developer.apple.com/app-store/app-privacy-details/), [Encrypting Your App's Files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files), [File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html)
- `docs/reviews/m3-logging-researcher.md` addendum (V1/V2 nested-copy plan over unversioned stores, two-install path), Swift Forums [761735](https://developer.apple.com/forums/thread/761735) and [769149](https://developer.apple.com/forums/thread/769149) (unversioned → versioned), [731529](https://developer.apple.com/forums/thread/731529) (SwiftData and Codable; forum-level, Apple's docs are silent).

---

## Addendum (2026-09-29): B3 — what the root's query holds on the first render after the restore state clears

**Direct answer.** On both 17.5 and 26.5 the first `body` pass after `isRestoring = false` already holds the new `Program` (`programs.first === old == false`, `experience == "new"`, 2 sessions); the shell-shaped child never rendered with the deleted row, so the 26.5 delete trap has no window here. The id-change hold is reliable on both runtimes but never engaged (the ids had already changed by the pass that evaluated it); keep it out unless a later probe shows a stale pass.

Configuration: scratch copy as above, hosted test target, `HomeGymLogTests/Probe/RootRestoreProbeTests.swift`; a `UIWindow` hosting a `RootView`-shaped view (`@Query(filter: archivedAt == nil)`, `@State isRestoring`, a child that reads `program.experience` and `program.sessions.count`) over an on-disk store; the handler (a `Task { @MainActor in … }` after one Restoring render) does the scratch-context per-row replace + `save()`, a `UserDefaults` write, then clears the flag, all synchronously; every `body` pass logs what it sees. Two runs per runtime (plain and fallback), on-disk store, 3-session graph replaced by a 2-session one.

Render log, both runtimes: `restoring=true holding=true ids=[old]` → handler saves and clears → `restoring=false ids=[new] first===old=false firstExperience=new` → child `experience=new sessions=2`. No pass with `restoring=false` and the old id on either runtime.

One difference worth a gotcha: **inside the handler, right after the scratch save, `programs` still returned the old id on 17.5** (`first===old=true`); on 26.5 it already returned the new one. The `@Query` value is refreshed for the next render pass, not synchronously for the handler that saved. So the handler must never branch on `programs` after the save (compute the "after" state from the DTOs, or wait for a render); the first render is right on both.

Fallback (`awaitingIDs = ids before the save; hold while awaitingIDs == programs.map(\.id); .onChange(of: ids) releases`): on both runtimes the first pass after the clear already saw `ids=[new]`, so `holding=false` with `awaiting=true`, and `.onChange(of: ids)` fired once and released it. Reliable, and harmless if added, but it protects nothing the probe could reach. Prefer the plain flag; if the architecture reviewer wants belt and braces, compare `persistentModelID`s the same way (unverified: not run, the `id: UUID` comparison is what was measured).

Not covered: `.id(programID)` remount timing of `ReminderHost` and any `@Query` in child views (those re-fetch on the same save and were shown to refresh in Q3's probe), a workout-in-progress log in the backup (the root then routes to `WorkoutView` on the same first pass, by the same query mechanism).

# m5-export — Swift concepts, for a React developer

New in this slice, in reading order. Earlier notes cover `Codable` decoding, `CodingKeys`, `Result`, `defer`, `await`,
`Binding(get:set:)`, enums with associated values and `.task(id:)`; they are not repeated here.

## 1. `VersionedSchema` and `SchemaMigrationPlan`: a migrations folder for SwiftData

A `VersionedSchema` names one frozen version of your models; a `SchemaMigrationPlan` lists the versions in order and
the steps between them. The container opens the store through the plan.

```swift
enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
```
`HomeGymLog/Models/AppSchemaV1.swift:7`, plan at `:16`, wired in `Models/AppSchema.swift:11`. React/Node analogy: the
first file in Prisma's `migrations/` folder plus the migration runner. **Surprise:** there is no migration *code* yet
(`stages` is empty). V1 only names what is already on disk, which is `1.0.0` by default, so existing installs open
unchanged. The real work starts with V2.

## 2. A scratch `ModelContext`: a second connection used as a transaction

`ModelContext(container)` makes a fresh working area on the same database as the main context. Changes in it are
invisible to the main one until `save()`. If you never save it, its changes simply vanish.

```swift
let scratch = ModelContext(container)
try write(scratch)
try scratch.save()
```
`Models/StoreCommit.swift:57`. React/Node analogy: opening a second DB connection, running `BEGIN … COMMIT` on it, and
just dropping the connection on error. **Surprise:** "rollback" here is doing nothing. Calling `rollback()` with pending
deletes crashed on iOS 17.5, so a failed restore relies on the scratch context going out of scope.

## 3. `JSONEncoder` options: sorted keys and a custom date format

`outputFormatting` controls the JSON text (`.sortedKeys`, `.prettyPrinted`). `dateEncodingStrategy = .custom` lets you
write each `Date` yourself, here as an ISO 8601 string with milliseconds.

```swift
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
encoder.dateEncodingStrategy = .custom { date, encoder in
    var container = encoder.singleValueContainer()
    try container.encode(fractional.string(from: date))
```
`Engine/Backup/BackupCodec.swift:11`. React analogy: `JSON.stringify(doc, replacer, 2)` with a replacer that turns
`Date`s into `toISOString()`. **Surprise:** without `.sortedKeys` the key order is not stable on iOS 26.5, so two exports
of the same data differed byte for byte. And the built-in `.iso8601` strategy rejects fractional seconds on 17.5.

## 4. `Transferable` and `FileRepresentation`: something the share sheet can carry

A `Transferable` type tells the system how to turn your value into data for sharing or drag and drop.
`FileRepresentation` says "hand over a file", and its closure runs only when the receiver actually asks for it.

```swift
static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .json) { file in
        SentTransferredFile(try await MainActor.run { try file.writeTemporaryFile() }, allowAccessingOriginalFile: false)
```
`Features/Settings/BackupFile.swift:17`. Web analogy: an object you can pass to `navigator.share({ files })`, except the
file is built lazily. **Surprise:** conforming to `Transferable` takes the type off the main actor, so the two helpers
that read the database had to be marked `@MainActor` explicitly (gotchas 2026-10-02).

## 5. `ShareLink`: a button that opens the share sheet

`ShareLink(item:)` is a ready-made button. Tapping it opens the system share sheet (Files, AirDrop, Mail) for any
`Transferable` item, and `SharePreview` sets the title and icon the sheet shows.

```swift
ShareLink(item: file, preview: SharePreview(BackupText.sharePreviewTitle, image: Image(systemName: "doc.text"))) {
    BackupActionLabel(text: BackupText.export)
}
```
`Features/Settings/BackupRows.swift:16`. Web analogy: a `<button onClick={() => navigator.share(...)}>` you don't have to
wire up. **Surprise:** it reports no completion, so the app can't know whether the file was actually saved. That's why
there is no "Last backup" row.

## 6. `.fileImporter`: the system file picker

`.fileImporter(isPresented:allowedContentTypes:)` shows the Files picker while a `Bool` is true and calls you back with
the picked URL or an error.

```swift
.fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
    switch result {
    case .success(let url): Task { show(await BackupImportAction.load(url: url)) }
```
`Features/Settings/BackupRows.swift:46`. Web analogy: `<input type="file" accept="application/json">`. **Surprise:**
Cancel calls nothing at all, and the URL you get is not freely readable (next section).

## 7. Security-scoped URLs and `NSFileCoordinator`: reading a file you don't own

A picked file lives outside the app's sandbox. You must call `startAccessingSecurityScopedResource()` before reading and
stop afterwards. `NSFileCoordinator` makes the read wait for iCloud to download the file and for other writers to finish.

```swift
let accessed = url.startAccessingSecurityScopedResource()
defer { if accessed { url.stopAccessingSecurityScopedResource() } }
```
`Features/Settings/BackupImportAction.swift:23`, coordinated read at `:27`. Web analogy: the File System Access API's
permission handle, which you must hold while reading. **Surprise:** the call returns `false` for a URL that is already
inside the sandbox, and that's fine. The code reads the file anyway, and the `defer` only stops access it actually
started (comment at `:21`).

## 8. `&` and `inout`: passing a variable for the callee to fill

Some Apple APIs report an error by writing into a variable you pass with `&`. That is Swift's `inout`: the function
gets write access to your variable.

```swift
var coordinationError: NSError?
NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
```
`Features/Settings/BackupImportAction.swift:25`. React analogy: passing a `useRef()` object so the callee can set
`.current`. **Surprise:** the `&` is required at the call site. Swift won't let a function change your variable unless
the call visibly says so.

## 9. `Task.detached`: work off the main actor

`Task.detached { … }` starts work that inherits nothing from the caller, not even its actor, so slow work such as a file
read that may wait for iCloud doesn't block the UI. `.value` awaits its result.

```swift
guard let data = await Task.detached(operation: { coordinatedRead(url) }).value else { return .failure(.unreadable) }
```
`Features/Settings/BackupImportAction.swift:10`. Web analogy: posting work to a Web Worker and awaiting its reply.
**Surprise:** a plain `Task { }` (as used at `BackupRows.swift:49`) runs on the main actor when started from a view.
Only `detached` escapes it, and the function it calls must be `nonisolated` (`:22`).

## 10. `presenting:`: a dialog driven by an optional

`.confirmationDialog` and `.alert` can take `presenting: value`. The dialog shows while `value` is non-nil and hands it
to the buttons, so the flag and the data can never disagree.

```swift
.confirmationDialog(BackupText.confirmTitle, isPresented: confirmShown, titleVisibility: .visible, presenting: pending) { document in
    Button(BackupText.confirmButton, role: .destructive) { onRestore(document) }
```
`Features/Settings/BackupRows.swift:54`, with `confirmShown` derived from `pending != nil` at `:94`. React analogy:
`{pending && <Dialog doc={pending} />}` instead of a separate `isOpen` state. **Surprise:** `role: .destructive` paints
the button red and, on iOS 26, the dialog becomes a popover with no Cancel button.

## What to read next

The next slice, `m5-live-activity`, puts the rest timer on the Lock Screen through a widget extension:
- [ActivityKit](https://developer.apple.com/documentation/activitykit)
- [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit)

# m5-release — security and privacy audit

Run 2026-10-04 against the uncommitted working tree of branch `m5-release` (on top of `e903fb5`) with the ten checks of
`.claude/skills/security-audit/SKILL.md`. Read-only: `grep`, `git log -p --all`, `find`, `plutil -p`, `codesign -d`,
and a visual read of the five store screenshots. `gitleaks` is not installed on this machine, so check 1 ran on the
skill's `git log -p` grep plus a tree scan.

## Verdict

**PASS — ship.** No blocking, high or medium finding. Three low notes, none of which needs a code change before the
archive; one is a documentation line for `insights/INSIGHTS.md` (check 10) that the main session should add.

## Findings

### Low

1. **Unbounded read of the picked backup file.** `HomeGymLog/Features/Settings/BackupImportAction.swift:28` reads the
   whole picked file with `Data(contentsOf:)` before `BackupCodec.read` looks at the header
   (`HomeGymLog/Engine/Backup/BackupCodec.swift:22`). A very large file the user picks by mistake (a video renamed
   `.json` passes the `.json` filter only if its UTI says so, but a multi-hundred-MB JSON does) is held entirely in
   memory and can get the app jetsammed instead of showing the "Couldn't read" alert. Only the user can trigger it,
   against themselves. Fix (optional): before the read, `try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize`
   (file size is not a required-reason API; only the timestamp keys are) and return `.failure(.unreadable)` above a
   generous ceiling such as 64 MB.
2. **The latest export lingers in the sandbox `tmp/`.** `HomeGymLog/Features/Settings/BackupFile.swift:38-45` deletes
   earlier `HomeGymLog-backup-*.json` files by name and writes the new one atomically into
   `FileManager.default.temporaryDirectory`; `ShareLink` has no completion (INSIGHTS, m5-export), so the newest file
   stays until the next export or until iOS purges `tmp/`. The file holds the whole training history in plain JSON,
   but `tmp/` is inside the app container and carries the container's default data-protection class, the same as the
   SwiftData store, so nothing is written to a weaker location. Fix (optional): sweep `tmp/` for
   `BackupText.isBackupFileName` matches once at launch (a two-line call from `HomeGymLogApp.init`) to shorten the
   window. Not a release blocker.
3. **Check 10 is undocumented.** No `isExcludedFromBackup` / `NSURLIsExcludedFromBackupKey` anywhere in the app, so the
   store rides in iCloud and encrypted device backups (the default, and the right call for a local-only app). The
   skill asks for this to be recorded in `insights/INSIGHTS.md`; today it is not (`grep -i "device backup"` finds
   nothing). Fix: one line in INSIGHTS, written by the main session (this audit did not edit INSIGHTS).

### Informational (no action)

- `DEVELOPMENT_TEAM = 4GKZ96A6QR` appears six times in `project.pbxproj` and once in `CLAUDE.md`; a team identifier is
  embedded in every signed binary and is not a secret. The contact address in `docs/release/privacy-policy.md:17` and
  `docs/release/support.md:27` is the published support contact, by design.
- `build/HomeGymLog.xcarchive` (2026-10-04 00:07) is signed with a development profile (`get-task-allow = true`,
  `embedded.mobileprovision` in both bundles). That is what `xcodebuild archive` with automatic signing produces; the
  App Store export re-signs with the distribution profile. `build/` is gitignored, so no profile reaches git.
- `HomeGymLogWidgets/` has no `PrivacyInfo.xcprivacy` and needs none: the extension imports only ActivityKit,
  WidgetKit, SwiftUI and AppIntents, touches no required-reason API (no `UserDefaults`, no file timestamps, no
  uptime/disk/keyboard APIs) and collects nothing. The `LiveActivityIntent` `perform()` runs in the app process, where
  the app's manifest applies.
- The skill's literal grep over `git log -p --all` returned 335 lines; every one is prose or test code containing the
  word "token" (pbxproj "token-and-value pins", `hits(_ token:)` helpers, "design token") or the skill text itself. No
  key, password, or private-key block.

## Release-slice specifics

| Item | Result |
|---|---|
| `HomeGymLog/PrivacyInfo.xcprivacy` | Tracking `false`, no tracking domains, no collected data types, one accessed API: `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1`. Correct and sufficient: every `UserDefaults` read or write in the app is one of the nine preference keys (`units`, `bodyWeightUnits`, `appearance`, `missedDayPolicy`, `reminderEnabled`, `reminderMinutes`, `hapticsEnabled`, `soundEnabled`, `liveActivityEnabled`) through `@AppStorage` or `RestActivityHandler.preference` (`App/RestActivityHandler.swift:65`). No App Group, no `suiteName` outside `#if DEBUG` (`App/HomeGymLogApp.swift:63-66`, the `-seed` throwaway suite). Verified present in the archived bundle (`plutil -p` matches the source). |
| `HomeGymLogSupport/Info.plist` | `ITSAppUsesNonExemptEncryption = false` is truthful: no `CryptoKit`, `CommonCrypto`, `Security`, `SecKey`, `SecItem`, `Keychain`, `encrypt`/`decrypt` anywhere; no `URLSession`/`URLRequest`/`Network`/`NWConnection`/`WebKit`/`CFNetwork`/`dataTask`; the merged archive plist carries the key as `false`. `UILaunchScreen → UIColorName = bg`. No `NSAppTransportSecurity`. |
| Outbound URLs | Exactly two literals, both `https://zhabskyio.github.io/homegymlog-site/...` (`Shared/SettingsText.swift:45-46`), opened by `Link(destination:)` in `Features/Settings/AboutRows.swift:11`, which hands the URL to the system (Safari); the app process opens no connection. The only other `URL(string:)` values are the two iOS Settings deep links (`App/ReminderPermission.swift:16`, `App/RestActivityCenter.swift:24`) via `openURL`. No `http://` literal anywhere. The same two URLs appear in `docs/release/app-store-metadata.md:13-14`. |
| Backup export | `BackupFile.writeTemporaryFile` (`Features/Settings/BackupFile.swift:27-33`) builds the document on the main actor, asserts it passes its own validation, writes to `FileManager.default.temporaryDirectory` with `.atomic`, hands the URL to `ShareLink` with `allowAccessingOriginalFile: false`. No Documents, no caches, no shared container. See Low 2 for the lingering newest file. |
| Backup import | `.fileImporter(allowedContentTypes: [.json])` → security-scoped, coordinated read off the main actor (`BackupImportAction.swift:22-31`, access stopped in `defer`) → `BackupCodec.read` (header check, full decode, `BackupValidation` rules 5–11: unique ids, dangling parents, session indexes, one log per session, value ranges, one current program, status/log agreement) → user confirmation (`BackupRows.swift:54-59`) → `BackupStore.replaceAll` in a scratch context (`Models/BackupStore.swift:9-14`). Nothing reaches a model context before validation and confirmation. Unknown exercise keys in a restored file are tolerated downstream: every `ExerciseLibrary.exercise(for:)` call in views and stats is optional-chained with a fallback (the one `!`, `Engine/ProgramGenerator.swift:110`, runs only on generator input validated at `:133`). Volume arithmetic is `Double` (`Engine/HomeStats.swift:76`), so a huge `reps` cannot overflow-trap. See Low 1 for the read size. |
| Notification bodies | Rest: "Rest over" / "Time for your next set." (`App/RestNotifier.swift:39-45`, `Shared/RestText.swift:13-14`). Reminder: "Training day" / "Your workout is planned for today." (`App/ReminderNotifier.swift:49-52`, `Shared/ReminderText.swift:13-14`). Fixed strings, no exercise, weight, note or body-weight interpolation; no `userInfo`. `AppNotificationDelegate` only chooses presentation options by identifier prefix. |
| Live Activity content | `RestActivityAttributes.ContentState` is two `Date`s and `nextText` (`HomeGymLogShared/RestActivityAttributes.swift`), where `nextText` is `"Next: "` + `RestText.next(...)` — "set 2 of 3" or an exercise name. The Lock Screen and island views draw only `RestActivityText` constants, the timer and `nextText` (`HomeGymLogWidgets/*.swift`). Nothing user-identifying; no `widgetURL`, no `Link`, no deep link. `NSSupportsLiveActivities = YES` on the app target only, matching the shipped feature. |
| `print(` outside DEBUG | None. `grep -rn "print(" HomeGymLog HomeGymLogShared HomeGymLogWidgets` matches only `fingerprint(` identifiers. No `Logger(`, `os_log`, `NSLog`, `debugPrint` or `dump(` either. |
| Secrets / provisioning in git | No `.p12`, `.mobileprovision`, `.cer`, `.pem`, `.key`, `.p8`, `.env` in the tree, in `git ls-files`, or in any commit's filename history (`git log --all --name-only`). `.gitignore` excludes `*.mobileprovision`, `*.p12`, `*.cer`, `build/`, `.claude/settings.local.json`. |
| Entitlements | No `*.entitlements` file in the repository and no `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj`. The archived app and appex carry only the three Xcode-injected keys (`application-identifier`, `com.apple.developer.team-identifier`, `get-task-allow`). No push, background modes, iCloud, App Groups or HealthKit. Live Activities and local notifications need no entitlement. |
| App Privacy "Data Not Collected" | Still true. No analytics, crash reporter, `identifierForVendor`, `advertisingIdentifier`, `AppTrackingTransparency`, `MetricKit`, `StoreKit`, or third-party SDK; no `Package.resolved`, all three `packageProductDependencies` arrays empty; imports are Apple frameworks only. The backup leaves the device only through the user's share-sheet choice; notifications and the Live Activity are local. `docs/release/app-store-metadata.md:10` and `privacy-policy.md` describe exactly this. The age-rating "web access → no" is right: `Link` opens Safari, the app embeds no browser. |
| Screenshots | `docs/release/screenshots/01-home.png` … `05-program.png` (1320 × 2868, RGB) were read visually: frozen 9:41 status bar, the `midProgram` / `wo-swipe` / `wo-rest` / `progress-history` seed data (Tue Sep 15 2026, "Pull" session, library exercise names, seeded weights, a synthetic calendar). No name, email, photo, note text or real date; `docs/tools/make-store-screenshots.sh` shoots only `-seed` launches with a throwaway `seed` defaults domain. |

## Verified clean

1. **Secrets in the repo** — history grep (filtered), tree and filename-history scans, `.gitignore` coverage; `gitleaks` unavailable (noted above).
2. **Network surface** — zero hits for every pattern in the skill plus `CFNetwork`, `dataTask`, `Socket`; no ATS keys; two `https` `Link`s handed to the system.
3. **Third-party code** — no SPM packages, no `Package.resolved`, Apple-only imports (Foundation, SwiftUI, SwiftData, WidgetKit, UserNotifications, ActivityKit, UniformTypeIdentifiers, AppIntents, UIKit, Observation, CoreTransferable, Charts, AVFAudio).
4. **Data at rest** — one on-disk `ModelConfiguration` in the app container (`Models/AppSchema.swift:10`); `UserDefaults` holds nine preferences only; no App Group, iCloud, Documents or `/tmp` writes beyond the export file in the sandbox `tmp/` (Low 2).
5. **Notifications** — two fixed title/body pairs, no interpolation, no `userInfo`.
6. **Entitlements and capabilities** — none in source; archive carries only Xcode's three injected keys; `NSSupportsLiveActivities` on the app target that ships the activity.
7. **Privacy strings and label** — no `NS...UsageDescription` needed or present (no HealthKit, photos, camera, microphone, location, contacts); "Data Not Collected" holds; `PrivacyInfo.xcprivacy` declares the one required-reason API actually used.
8. **Logging** — no `print(`, `Logger`, `os_log`, `NSLog`, `debugPrint`, `dump(` in any target.
9. **Input handling** — weights clamped to the equipment step range in `Engine/WeightFormula.swift:31`; body weight clamped in `Engine/RestartPrefill.swift:31` and the onboarding draft (`ProgramGenerator.bodyWeightRangeLb`); notes are plain `String` rendered by `Text`; imported data is header-checked, decoded, validated (rules 5–11) and user-confirmed before the model context (Low 1 for file size).
10. **Backups** — store included in iCloud/device backup by default; no exclusion anywhere (Low 3: record in INSIGHTS).

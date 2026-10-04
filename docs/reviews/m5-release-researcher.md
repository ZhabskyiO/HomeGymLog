# m5-release — researcher report (2026-10-03)

**Direct answer.** Ship the privacy manifest at `HomeGymLog/PrivacyInfo.xcprivacy` (lands at the app-bundle root with no project
edit; verified), give the three iOS 1024 slots opaque RGB PNGs made with `rsvg-convert` (the only tool here that emits RGB with
no alpha), and set `ITSAppUsesNonExemptEncryption`, portrait-only and the display name through build settings that all exist in
Xcode 27 (`INFOPLIST_KEY_*`, verified to land in Info.plist). The only item that needs a hand-made `Info.plist` is the launch
screen's `bg` background (no `INFOPLIST_KEY_` exists for `UILaunchScreen.UIColorName`; a merged plist works and was verified
to render `F4F2F3` / `0F0E10`). Screenshots: one 6.9" set (1320 × 2868, iPhone 17 Pro Max on 26.5) is sufficient and Apple
scales it; iPhone 15 shots (1179 × 2556) do **not** satisfy the requirement. A privacy policy URL is required for every app;
GitHub Pages from a private repo needs GitHub Pro, so publish from a public repo or elsewhere.

Verified under: Xcode 27.0 (27A266a), simulator SDK iOS 27.0, runtimes iOS 17.5 (iPhone 15, udid `3CAE4D76…`) and iOS 26.5
(iPhone 17 Pro Max, udid `5236ED20…`); Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (app target);
every build in a scratch copy of the repo at `<scratchpad>/repo` (rsync of the working tree, `.git`/`build` excluded). Hosted
tests ran in `HomeGymLogTests` (whose `Bundle.main` is the app bundle). Nothing under the real project was touched except this
file; the simulators were left as found (app uninstalled, status-bar overrides cleared, appearance restored to dark).

Aside (not asked): the scratch Release build of byte-identical sources printed six Swift concurrency warnings
(`Engine/RestartPrefill.swift:31,32`, `Features/Workout/WorkoutView.swift:91`, `Models/WorkoutLogStore.swift:220,288,291`,
"main actor-isolated … referenced from a nonisolated context"). CLAUDE.md records the last Release as "0 warnings"; worth a
look before an archive, unrelated to this slice.

---

## Q1 Privacy manifest — required, one file, verified at the bundle root

**Verdict.** Yes. Apple: "For each executable or dynamic library in an app that uses a required reason API, the bundle that
includes the executable or dynamic library needs to include a privacy manifest file that reports the API" and "Starting May 1,
2024, apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by App Store
Connect" ([Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)).
`UserDefaults` (and `@AppStorage`, which wraps it) is the `NSPrivacyAccessedAPICategoryUserDefaults` category. CA92.1, exact
text: "Declare this reason to access user defaults to read and write information that is only accessible to the app itself.
This reason does not permit reading information that was written by other apps or the system, or writing information that
can be accessed by other apps." ([NSPrivacyAccessedAPITypes](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes)).
The app uses `UserDefaults.standard` and its own `seed` suite only, no App Group → CA92.1 is the right code (1C8F.1 is App
Groups, C56D.1 SDKs, AC6B.1 MDM keys).

File name is fixed: "By default, the file is named `PrivacyInfo.xcprivacy`; this is the required file name for bundled
privacy manifests" ([Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)).
Four top-level keys: `NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes`, `NSPrivacyAccessedAPITypes`.

**Minimal XML** (what was built and read back; `plutil -lint` OK):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

**Widget extension.** The rule is per executable: the appex uses no required-reason API (the brief's grep: none in
`HomeGymLogWidgets/` or `HomeGymLogShared/`), so it needs no manifest. An empty-array manifest in it is harmless: the same XML
with `<key>NSPrivacyAccessedAPITypes</key><array/>` placed at `HomeGymLogWidgets/PrivacyInfo.xcprivacy` was copied to the appex
root (`CpResource … HomeGymLogWidgetsExtension.appex/PrivacyInfo.xcprivacy`) and the Release build stayed green. Optional;
include it if you want "every bundle has one" as a rule (it also future-proofs an `@AppStorage` in the widget).

**Placement verified (scratch Release, iOS 17.5 simulator, `CODE_SIGNING_ALLOWED=NO`):**

```
xcodebuild -scheme HomeGymLog -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' \
  -derivedDataPath <scratch>/DerivedData CODE_SIGNING_ALLOWED=NO build        # exit 0, BUILD SUCCEEDED
ls Release-iphonesimulator/HomeGymLog.app
  Assets.car  HomeGymLog  Info.plist  Metadata.appintents  PkgInfo  PlugIns  PrivacyInfo.xcprivacy  rest-over.caf
cmp HomeGymLog.app/PrivacyInfo.xcprivacy repo/HomeGymLog/PrivacyInfo.xcprivacy   # identical (plain copy, not compiled)
```
Build-log step: `CpResource …/HomeGymLog.app/PrivacyInfo.xcprivacy …/HomeGymLog/PrivacyInfo.xcprivacy (in target 'HomeGymLog')`
— the synchronized folder treats it like the `.caf` (gotcha 2026-09-24). The same file is in the unsigned device archive
(`Products/Applications/HomeGymLog.app/PrivacyInfo.xcprivacy`) and in the Debug test host.

**Hosted test read-back: yes.** `Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")` returned
`…/HomeGymLog.app/PrivacyInfo.xcprivacy` in the 17.5 test host, and `PropertyListSerialization.propertyList(from:format:)`
parsed it to `[String: Any]` with the four keys (scratch suite `ReleaseProbeTests`, 6/6 passed; code in Q9).

**ITMS-91053 / 91055.** ITMS-91053 "Missing API declaration" is the post-upload email/notice for a required-reason API with no
manifest entry; ITMS-91055 "Invalid API reason declaration" is a reason code that is not valid for its category. Both are
emitted by App Store Connect processing after upload (also surfaced by Organizer → Validate App). Apple's wording since
2024-05-01 is "aren't accepted"; developer reports describe 91053 arriving as a warning email with the build still processed
— treat it as blocking either way (unverified which behaviour applies in October 2026; no upload was made).
Sources: [Apple Forums thread 749940 (ITMS-91055)](https://developer.apple.com/forums/thread/749940),
[Apple Forums thread 750190 (ITMS-91053)](https://developer.apple.com/forums/thread/750190).

Tier/entitlement: none. App Privacy label: unchanged ("Data Not Collected" is about collection; the manifest declares API
reasons, not data types — `NSPrivacyCollectedDataTypes` stays empty).

---

## Q2 App icon — three opaque 1024 PNGs from `rsvg-convert`; mac slots harmless; extension needs no icon

**What the three slots expect.** Xcode docs: "iOS, iPadOS, tvOS, and watchOS apps can auto-generate all icon variations from
a single 1024×1024 pixel image"; "Provide your tinted app icon as a grayscale image. Provide your dark app icon with a
transparent background so the system-provided background can show through"; and "you must provide app icon imagery to use in
the App Store … Drag an icon image to the iOS 1,024pt image well"
([Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)).
HIG: square, unmasked layers, 1024 × 1024 px, sRGB/Display P3, "the system applies masking to produce rounded corners"
([App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)). So: **any** = opaque PNG (no alpha);
**dark** = PNG, alpha allowed (transparent background is Apple's own recommendation); **tinted** = grayscale PNG, alpha
allowed. Only the "any" 1024 doubles as the App Store icon and must be opaque. iOS 17 renders the "any" icon only; the dark and
tinted variants are read on iOS 18+ (the iOS 18 Home Screen appearance feature) — nothing to gate, the catalog handles it.
Note (HIG, 2025-06-09 revision): Apple now steers to Icon Composer layered `.icon` files for Liquid Glass; the flat PNG set
remains fully supported and is the right choice for an iOS 17 deployment target.

**App Store and alpha.** App Store Connect rejects an App Store icon with an alpha channel: error ITMS-90717 "Invalid App Store
Icon. The App Store Icon in the asset catalog in '….app' can't be transparent nor contain an alpha channel"
([Apple Forums thread 86829](https://developer.apple.com/forums/thread/86829)). actool does **not** warn at build time: a
genuinely transparent RGBA "any" icon compiled with zero warnings in the scratch Debug and Release builds (checked
`grep -i warning` on both logs; only the six Swift warnings). Pin it in a test (Q9).

**Leftover `mac` idiom entries.** Harmless for the iOS build: two scratch Release builds with the ten empty `mac` entries present
(once with the ios slots empty, once filled) produced no actool warning or error, and `assetutil --info Assets.car` lists only
`Idiom: phone` icon images (actool runs with `--target-device iphone --platform iphonesimulator`, so mac entries are never
compiled). App Store validation sees only the compiled `Assets.car`, so the entries cannot reach it (inference; validation not
run). Removing them is a `Contents.json` edit (allowed): delete the ten `"idiom" : "mac"` objects and keep the three
`universal`/`ios` ones. Do it for tidiness, not correctness. The widget's own `AppIcon.appiconset` is already ios-only.

**Local CLIs (this Mac), rendering a 1024 × 1024 SVG with a full-bleed opaque `rect`:**

| tool | command | result (`file` / `sips -g hasAlpha`) |
|---|---|---|
| `rsvg-convert` 2.60.0 (`/opt/homebrew/bin`) | `rsvg-convert -w 1024 -h 1024 -o icon.png icon.svg` | 1024 × 1024, **RGB, hasAlpha: no** |
| `rsvg-convert` with forced background | `rsvg-convert -w 1024 -h 1024 -b '#0F0E10' -o icon.png icon.svg` | 1024 × 1024, **RGB, hasAlpha: no** (opaque even if the SVG has transparent regions) |
| headless Chrome (existing recipe) | `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=1024,1024 --screenshot=icon.png "file:///abs/icon.svg"` | 1024 × 1024, **RGB, hasAlpha: no** (the Chrome binary accepts `file://`; only the browser *tools* refuse it) |
| `qlmanage -t -s 1024 -o . icon.svg` | writes `icon.svg.png` | 1024 × 1024, **RGBA, hasAlpha: yes** — unusable for "any" |
| `sips -s format png -z 1024 1024 icon.svg --out icon.png` | | 1024 × 1024, **RGBA, hasAlpha: yes** — unusable for "any" |
| `magick`/`convert`/`inkscape` | not installed | — |

Recommendation: `rsvg-convert … -b '<bg hex>'` for the "any" icon (deterministic, no browser), the same tool without `-b` for
dark (keeps transparency) and for tinted after a grayscale SVG. Verify each with `file icon.png` (expect `8-bit/color RGB` for
"any") and `sips -g pixelWidth -g pixelHeight -g hasAlpha icon.png`.

**Welcome tile from the same SVG — yes, no project edit.** A new folder `HomeGymLog/Assets.xcassets/WelcomeTile.imageset/` with
the SVG and this `Contents.json` was picked up by the scratch Release build (and the test host) with no `project.pbxproj`
change:

```json
{
  "images" : [ { "filename" : "WelcomeTile.svg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true }
}
```
`assetutil --info Assets.car` shows `WelcomeTile  AssetType: Vector` plus a rasterised fallback (`Image, Scale 3, 3072 × 3072`);
`UIImage(named: "WelcomeTile")` in the 17.5 test host returned size `(1024.0, 1024.0)` pt, scale 3. The point size is the SVG's
intrinsic `width`/`height`, so either author the tile SVG at `width="44" height="44"` or use
`Image("WelcomeTile").resizable().scaledToFit().frame(width: 44, height: 44)`. SVG assets with "Preserve Vector Data" are
supported since Xcode 12 / iOS 13 (no `#available` needed on iOS 17). React analogy: an imageset is an imported SVG module; the
asset catalog is the bundler that emits the raster fallbacks.

**Widget extension icon: not needed.** The appex's actool invocation carries no `--app-icon` (it passes `--accent-color
AccentColor --widget-background-color WidgetBackground --standalone-icon-behavior all`), its Info.plist has no `CFBundleIcons`,
and the Release build and the device archive are green with the three empty slots. iOS shows the containing app's icon for a
Live Activity. The extension's empty `AppIcon.appiconset` can stay or be deleted (a `Contents.json`-level change). Unverified:
App Store validation of an appex with an empty icon set (expected fine — extensions never carry App Store icons).

---

## Q3 Launch screen — today system white/black; `bg` needs a small merged Info.plist (verified)

**Today.** `UILaunchScreen = {}` (from `INFOPLIST_KEY_UILaunchScreen_Generation = YES`; xcspec: "sets the value of the
UILaunchScreen key … to an empty dictionary"). Captured with the app held before `main` (`xcrun simctl launch
--wait-for-debugger`, then `simctl io screenshot` after 2.5 s): every sampled pixel was **(255,255,255) in light and (0,0,0)
in dark** — the system background, not `bg` (`F4F2F3` = 244,242,243 / `0F0E10` = 15,14,16). A normal launch is too fast to
catch: eight back-to-back screenshots around `simctl launch` all showed the Home Screen or the running app.

**Build-setting route: none.** `UILaunchScreen` sub-keys are `UIColorName`, `UIImageName`, `UIImageRespectsSafeAreaInsets`,
`UINavigationBar`, `UITabBar`, `UIToolbar` ([UILaunchScreen](https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen)).
Xcode 27's build-setting catalogue (`CoreBuildSystem.xcspec`, `SWBProjectModel` strings) has only
`INFOPLIST_KEY_UILaunchScreen_Generation` and `INFOPLIST_KEY_UILaunchStoryboardName`; there is no
`INFOPLIST_KEY_UILaunchScreen_UIColorName` or any other sub-key setting. The General tab's "Launch Screen File" field only sets
the storyboard name.

**What works: a merged Info.plist (verified).** With `GENERATE_INFOPLIST_FILE = YES` *and* `INFOPLIST_FILE` set, Xcode merges the
file into the generated plist (this is exactly how the widget target already works). Scratch build with this file at
`HomeGymLogSupport/Info.plist` and `INFOPLIST_FILE = HomeGymLogSupport/Info.plist` on the **app target's two configurations
only**:

```xml
<plist version="1.0"><dict>
	<key>UILaunchScreen</key>
	<dict><key>UIColorName</key><string>bg</string></dict>
</dict></plist>
```
Result: built `Info.plist` kept all 66 generated lines plus `"UILaunchScreen" => { "UIColorName" => "bg" }`; the launch screen
sampled **(244,242,243) light / (15,14,16) dark** on iPhone 15 / 17.5. `UIColorName` is read from the asset catalog, iOS 14+,
no `#available`.

**Two traps, both reproduced:**
1. A file named `Info.plist` **inside the synchronized `HomeGymLog/` folder** fails the build: `error: Multiple commands produce
   '…/HomeGymLog.app/Info.plist'` (the folder copies it as a resource *and* the plist step writes it). The widget wizard avoided
   this with a `PBXFileSystemSynchronizedBuildFileExceptionSet` (`membershipExceptions = (Info.plist)`, gotcha 2026-10-02).
   For the app target the user would untick the file's Target Membership in the File inspector (Xcode writes the exception
   set), or put the file outside the synchronized folders (e.g. `HomeGymLogSupport/Info.plist` at the repo root, as probed).
2. `INFOPLIST_FILE=…` passed on the **xcodebuild command line applies to every target** and replaced the appex's plist (its
   `NSExtension` vanished → `simctl install` failed with "Failed to create app extension placeholder"). Scope it to the app
   target in the project (Build Settings → Packaging → Info.plist File, app target selected), never as a CLI override.

**Cost estimate.** Small: one 9-line plist, one GUI step (Build Settings → "Info.plist File" = its path, Release and Debug
rows), one GUI step only if the file sits inside `HomeGymLog/` (membership exception). Xcode's Info tab may also create the
file for you when a key without an `INFOPLIST_KEY_` mapping is added (community reports; **unverified** here — the GUI cannot be
scripted), and where it places it in a synchronized-folder project is unknown; prefer the explicit path. Expected pbxproj
diff to grep for afterwards: `INFOPLIST_FILE = HomeGymLogSupport/Info.plist;` twice, in the app target's configurations only
(the widget's two `INFOPLIST_FILE = HomeGymLogWidgets/Info.plist;` stay). React analogy: `UILaunchScreen` is the static HTML
shell served before the JS bundle hydrates; `UIColorName` is its `body { background }`.

---

## Q4 Release Info keys through the GUI — every key has an `INFOPLIST_KEY_` setting; verified shapes

All three keys exist as build settings in Xcode 27's `CoreBuildSystem.xcspec` (category "Info.plist Values", `ConditionFlavors =
(sdk)`): `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` (Boolean, display name "App Uses Non-Exempt Encryption"),
`INFOPLIST_KEY_ITSEncryptionExportComplianceCode` (String), `INFOPLIST_KEY_CFBundleDisplayName`,
`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`. With `GENERATE_INFOPLIST_FILE = YES` and no `Info.plist`, Xcode's Info
tab writes these as `INFOPLIST_KEY_*` build settings (that is what the wizard did for `NSSupportsLiveActivities` and the
orientation keys already in `project.pbxproj`); it does not create a file for a key that has a setting (GUI behaviour
inferred from the existing project rows; the setting names themselves are verified).

**Verified shape** — a 17.5 test run with the three settings passed as overrides produced, in the built app's Info.plist:
```
"ITSAppUsesNonExemptEncryption" => false
"UISupportedInterfaceOrientations~iphone" => [ 0 => "UIInterfaceOrientationPortrait" ]
"CFBundleDisplayName" => "HomeGymLog"
```
and the hosted test read `infoDictionary["ITSAppUsesNonExemptEncryption"]` as `0` (`as? Bool == false` passes) and
`infoDictionary["UISupportedInterfaceOrientations"]` as `["UIInterfaceOrientationPortrait"]` (the `~iphone` variant resolves).

Click paths for the user (then grep):
- **Encryption:** app target → Build Settings → search "Non-Exempt" → "App Uses Non-Exempt Encryption" = **No** (or Info tab →
  "+" → "App Uses Non-Exempt Encryption" → NO). Grep: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;` ×2 (app only). Apple:
  "If you don't have the ITSAppUsesNonExemptEncryption key in your app's Info.plist file, App Store Connect walks you through
  an export compliance questionnaire every time you upload a new version"
  ([ITSAppUsesNonExemptEncryption](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)).
  The app uses no encryption beyond the OS (no networking at all), so `NO` is accurate
  ([Complying with Encryption Export Regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)).
- **Portrait only:** app target → General → Deployment Info → iPhone Orientation: untick Landscape Left and Landscape Right.
  Grep: `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;` ×2. The leftover
  `…_iPad` row with four orientations is inert (`TARGETED_DEVICE_FAMILY = 1`), produced no warning, and may stay.
- **Display name:** app target → General → Identity → Display Name = `HomeGymLog` (Info tab "Bundle display name"). Grep:
  `INFOPLIST_KEY_CFBundleDisplayName = HomeGymLog;` ×2. Today `CFBundleName = HomeGymLog` already labels the Home Screen; setting
  the display name explicitly is belt-and-braces ("Use this key if you want a product name that's longer than CFBundleName" —
  [CFBundleDisplayName](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledisplayname)).

**Widget extension display name `HomeGymLogWidgets`.** For an extension that only hosts a Live Activity there is no widget
gallery entry (nothing to list), and the Live Activities switch lives under Settings → HomeGymLog with the app's name and
icon. I found no user-facing surface that shows the extension's `CFBundleDisplayName` (unverified by observation — Settings
cannot be navigated from the CLI here). Renaming it to `HomeGymLog` is harmless and cosmetic; not required.

**Version matching.** Both targets read `CFBundleShortVersionString 1.0` / `CFBundleVersion 1` (built plists checked). App Store
Connect flags a mismatch as **ITMS-90473 "CFBundleShortVersionString Mismatch"** (historically a warning, not a rejection), and
the Organizer's default "Manage version and build number" rewrites the build number of every bundle in the archive. Keep
`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` identical in both targets (a project-level setting, or bump both). Pin it in
`LiveActivityProjectTests`' style (Q9). Source: [Apple Forums thread 722517](https://developer.apple.com/forums/thread/722517)
(community; Apple has no current page for ITMS-90473 — unverified beyond that).

---

## Q5 Archive and upload — Organizer for the first upload; CLI verifies everything except the upload

**Recommendation.** First upload through Xcode: Product → Archive → Organizer → **Validate App** first, then **Distribute App
→ TestFlight & App Store** (or "TestFlight Internal Only" for the first build). Apple: "If you want to confirm your app is ready
to submit … select your archive and then click Validate App. Xcode will perform a limited, automated initial validation";
"Before you upload your app to the App Store for the first time, create an app record … If you haven't done this already,
Xcode asks you for the information it needs to create this record for you"
([Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)).
Validate App requires the app record: "If Xcode doesn't find an App Store Connect record for your app, the validation fails
with an App Store Connection Operation Error" ([Validate an archive of your app](https://help.apple.com/xcode/mac/current/en.lproj/dev37441e273.html)).
The first distribution also creates the **Apple Distribution** certificate (cloud-managed) and App Store profiles for both bundle
ids (`….ios` and `….ios.widgets` — the latter needs an explicit App ID, which automatic signing registers). These are
account-side changes the user should expect to be asked about once.

**Verified from the CLI (scratch, no upload, no portal access):**
```
# 1. unsigned archive: structure
xcodebuild archive -scheme HomeGymLog -destination 'generic/platform=iOS' -derivedDataPath … -archivePath unsigned.xcarchive CODE_SIGNING_ALLOWED=NO
  ** ARCHIVE SUCCEEDED **; dSYMs/HomeGymLog.app.dSYM, dSYMs/HomeGymLogWidgetsExtension.appex.dSYM;
  Products/Applications/HomeGymLog.app/PlugIns/HomeGymLogWidgetsExtension.appex; PrivacyInfo.xcprivacy at the app root
# 2. automatically signed archive WITHOUT -allowProvisioningUpdates (cached profiles only)
xcodebuild archive -scheme HomeGymLog -destination 'generic/platform=iOS' -derivedDataPath … -archivePath signed.xcarchive
  ** ARCHIVE SUCCEEDED **; Info.plist: SigningIdentity "Apple Development: ozhabskyi@icloud.com (XTAH95TW67)", Team 4GKZ96A6QR
codesign -dvvv HomeGymLog.app            → Identifier=com.zhabskyi.homegymlog.ios, Authority=Apple Development…, TeamIdentifier=4GKZ96A6QR, arm64 thin
codesign -dvvv …/HomeGymLogWidgetsExtension.appex → Identifier=com.zhabskyi.homegymlog.ios.widgets, same authority
security cms -D -i HomeGymLog.app/embedded.mobileprovision → "iOS Team Provisioning Profile: com.zhabskyi.homegymlog.ios", expires 2027-09-13
security cms -D -i …appex/embedded.mobileprovision → "iOS Team Provisioning Profile: *" (wildcard 4GKZ96A6QR.*), expires 2027-10-03
```
So the archive step itself is development-signed (as Xcode's is); distribution signing happens at export. The appex rides on
the team's wildcard development profile today — fine for Archive, but the App Store export will mint an explicit profile for
`….ios.widgets`. `-showBuildSettings -configuration Release -destination generic/platform=iOS` reports
`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`, `CODE_SIGN_STYLE = Automatic`, `CODE_SIGN_IDENTITY = Apple Development`; both shared
schemes' `ArchiveAction buildConfiguration = "Release"` (`HomeGymLog.xcscheme:99–102`). Expected symbols setting: leave
dwarf-with-dsym and `uploadSymbols` at its default YES ("For App Store exports, should the package include symbols? Defaults to
YES", `xcodebuild -help`).

**CLI export/upload (not run — it would create distribution assets on the account):**
```
xcodebuild -exportArchive -archivePath signed.xcarchive -exportOptionsPlist export.plist -exportPath out -allowProvisioningUpdates
# export.plist: method = app-store-connect; destination = export | upload; signingStyle = automatic; teamID = 4GKZ96A6QR;
#               uploadSymbols = YES (default); manageAppVersionAndBuildNumber = YES (default); testFlightInternalTestingOnly = YES for a team-only build
```
`xcodebuild -help` (Xcode 27): `method` options are `app-store-connect, release-testing, enterprise, debugging, developer-id,
mac-application, validation` (`app-store`, `ad-hoc`, `development` deprecated aliases); `destination` "export or upload …
Defaults to export". There is a `validation` method, i.e. `-exportArchive` can run the validation step headlessly. Credentials:
"-allowProvisioningUpdates … Requires a developer account to have been added in Xcode's Accounts settings **or** an App Store
Connect authentication key to be specified via `-authenticationKeyPath`, `-authenticationKeyID`, and
`-authenticationKeyIssuerID`" — so `destination upload` works with the signed-in Xcode account (the user's, already present)
and needs an API key only for unattended/CI use (upload path itself unverified here).

**altool.** Still shipped: `xcrun altool --help` → "Version 27.0.5 (2.1)", with `--validate-app <file>`, `--upload-package
<file>` (`--upload-app -f` is the older spelling) and both credential forms: `-u <apple id> -p <app-specific password>` (or
`-p @keychain:<item>`) or `--apiKey <id> --apiIssuer <issuer>` with the `.p8` in `~/.appstoreconnect/private_keys` or via
`--p8-file-path`. Apple deprecated altool for **notarization** (TN3147; notary service stopped accepting it 2023-11-01), not
for App Store validation/upload; Apple's current recommendation for uploads is Xcode or Transporter, and Organizer's Validate
App is the documented pre-upload check. `altool --validate-app` needs an exported `.ipa` (`destination export`). Source:
[altool(1)](https://keith.github.io/xcode-man-pages/altool.1.html) mirror plus the local `--help`.

---

## Q6 App Store Connect requirements — one 6.9" set; iPhone 15 shots do not qualify

**Screenshots** ([Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)):
- 6.9" display: 1320 × 2868, 1290 × 2796 or 1260 × 2736 (portrait). Listed "Optional" on the page but it is the size every
  smaller class scales from.
- 6.5" display: 1284 × 2778 or 1242 × 2688 — "**Required** if app runs on iPhone and screenshots for 6.9" display aren't
  provided. If screenshots with the accepted sizes aren't provided, scaled screenshots for 6.9" displays are used."
- 6.3" display (iPhone 17/16/15, 15 Pro): 1179 × 2556 or 1206 × 2622 — optional; "scaled screenshots for 6.5" displays are used"
  if absent. So **iPhone 15 shots (1179 × 2556) fill only the optional 6.3" row and do not satisfy the requirement.**
- Formats: PNG or JPEG, no alpha. iPad row: "Required if app runs on iPad" — not applicable (`TARGETED_DEVICE_FAMILY = 1`).

**Simulators present** (`xcrun simctl list devices available`): iPhone 17 Pro Max on iOS 26.5 (`5236ED20-CDE1-441F-9F48-54E856A3FB90`);
`simctl io screenshot` from it measured **1320 × 2868** — exactly the 6.9" size. iPhone 15 / 17.5 measured 1179 × 2556. Also
available: iPhone 16 Pro Max (18.0, 1320 × 2868), iPhone 15 Pro Max / 15 Plus (17.5, 1290 × 2796 — also an accepted 6.9" size,
useful if a 17.5 look is wanted for the store shots). Because the app is iOS 17-minimum, shooting on 26.5 shows iOS 26 chrome;
either is acceptable to Apple, pick one set and keep it consistent.

**Status bar override** — works on both runtimes (exit 0, `status_bar list` echoed the values):
```
xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
#  Time: 9:41, WiFi Bars: 3, Cell Bars: 4, Battery State: 2 (charged), Battery Level: 100 — on 3CAE4D76… (17.5) and 5236ED20… (26.5)
xcrun simctl status_bar <udid> clear       # restore (done)
```
(`--batteryState` accepts `charging|charged|discharging`; `--dataNetwork` and `--operatorName ''` are also available.)

**Privacy policy URL: mandatory.** App Store Connect: "A URL that links to your company's privacy policy. Required for iOS and
macOS apps" ([App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/));
App Review 5.1.1(i): "All apps must include a link to their privacy policy in the App Store Connect metadata field and within
the app in an easily accessible manner" — note the **in-app** link requirement too (a Settings row opening the URL).
**Support URL**: required; "must lead to actual contact information (legal address, email address, telephone number) … specify
the entire URL, including the protocol (for example, http://support.example.com)"
([Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)).
A `mailto:` is not a web URL and is not accepted by the field (format rule; **unverified** against the live form). A public
GitHub repo README or a GitHub Pages page qualifies as long as the page shows a contact (an email line is enough).

**GitHub Pages and private repos.** GitHub's plan matrix: GitHub Free for personal accounts lists "GitHub Pages in public
repositories"; Pages in private repositories is a GitHub Pro (and Team/Enterprise) feature
([GitHub's plans](https://docs.github.com/en/get-started/learning-about-github/githubs-plans)). Options for a one-page
policy, in order of least effort: (1) a separate tiny **public** repo (`homegymlog-site`) with Pages on → `https://<user>.github.io/homegymlog-site/privacy`;
(2) make the main repo public; (3) any free static host. The Pages site is public either way — "publish a GitHub Pages site
privately" is Enterprise Cloud only.

---

## Q7 App Review and metadata facts

- **App Privacy label.** First question: "Indicate whether you or your third-party partners collect data from your app" →
  "No, we do not collect data from this app" → label **Data Not Collected**; no further questions
  ([Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)).
  Definition: "'Collect' refers to transmitting data off the device in a way that allows you and/or your third-party partners
  to access it"; "Data that is processed only on device is not 'collected' and does not need to be disclosed"
  ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)). The JSON **export through `ShareLink`**
  is user-initiated and goes nowhere the developer can read, and **local notifications / the Live Activity** never leave the
  device → neither changes the answer. Answers are entered once per app and are required before the first submission (the
  app record shows "Missing" until done); they apply to TestFlight external builds too.
- **Age rating.** The 2025 questionnaire (new 13+/16+/18+ tiers, new topics "in-app controls, capabilities, medical or wellness
  topics, violent themes"; answers required for every app by 2026-01-31 — [Updated age ratings](https://developer.apple.com/news/?id=ks775ehf))
  has one fitness-relevant question: **Health or Wellness Topics** — "Content that provides self-care or lifestyle
  recommendations. May include: calorie tracking, dieting advice, or exercise recommendations" → **9+** when present;
  **Medical or Treatment Information** → 13+/16+ ([Age ratings](https://developer.apple.com/help/app-store-connect/reference/age-ratings/)).
  A generated strength program with prescribed sets/weights is arguably "exercise recommendations"; answering it honestly gives
  9+, answering "none" gives 4+. Decide deliberately and keep the description consistent (2.3 accurate metadata). The exact
  answer options (None / Infrequent / Frequent) could not be read off the page — **unverified**. Nothing else in the list
  (web access, UGC, chat, ads, gambling) applies.
- **Category.** Primary **Health & Fitness**, secondary none ([Choosing a category](https://developer.apple.com/app-store/categories/)).
- **Export compliance.** `ITSAppUsesNonExemptEncryption = NO` answers the questionnaire in advance (Q4); otherwise App Store
  Connect asks on every upload and the TestFlight build sits at "Missing Compliance" until answered.
- **Guidelines that bite.** 5.1.1 purpose strings: `UNUserNotificationCenter.requestAuthorization` has **no**
  `NS…UsageDescription` key (none exists for notifications), so nothing to add; asking in context (first rest / reminder toggle)
  is the recommended pattern. 1.4.1 medical: the app gives no medical data or diagnoses; avoid health claims in copy. 2.3.1:
  describe features exactly; 2.3.3 screenshots "should show the app in use, and not merely the title art, login page, or
  splash screen"; 2.3.7 names ≤ 30 chars, no trademarked terms in name/keywords. 4.2 minimum functionality: a generator +
  logger + stats + Live Activity is well past "repackaged website". 5.1.1(i): the privacy policy link must also be reachable
  **inside the app** ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- **TestFlight internal testing: no App Review.** "Up to 100 App Store Connect users … Does not require Beta App Review";
  external testing (up to 10,000) does. First build needs the export-compliance answer (pre-answered by the key) and, for
  external groups, Test Information (beta description, what to test, feedback email); builds expire after 90 days
  ([TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)). The user's
  own Apple ID is an App Store Connect user → internal tester on their iPhone 14 Pro Max with no review.

---

## Q8 Copy audit facts

Limits (App Store Connect Help, [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
and [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)):
**Name** 2–30 chars ("You can edit it until you submit the app to App Review"); **Subtitle** ≤ 30; **Promotional text** 170
(editable any time); **Description** 4000, plain text; **Keywords** **100 bytes** (not characters), comma-separated, each > 2
chars, no app or company names; **What's New** 4000, required for updates only; **Support URL** required (web page with
contact); **Marketing URL** optional.

**Reserving "HomeGymLog".** Availability cannot be checked offline. In App Store Connect: My Apps → **+** → **New App** →
Platforms iOS, Name `HomeGymLog`, Primary Language, Bundle ID `com.zhabskyi.homegymlog.ios` (the dropdown lists App IDs
registered on the team — the explicit one exists), SKU (free text, e.g. `homegymlog-ios-1`), User Access → **Create**. The
dialog refuses a name another developer uses ("You can use an app name for one app per localization"); creating the record is
the reservation ([Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)).
Xcode's Organizer can also create the record at first upload, but creating it first lets Validate App run.

**Apple words in copy.** Referential use of word marks is allowed in descriptions when the Apple mark "is not part of the
product name", appears less prominently, and is accurate ("for iPhone", "runs on iPhone"); never plural/possessive, spelled as
on the list ([Guidelines for Using Apple Trademarks](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html)).
On the [Apple Trademark List](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html): **iPhone**,
**Live Activities®**, **Dynamic Island®**, **TestFlight®**, **App Store®** are listed; **"Lock Screen" is not** (a plain feature
name). So "Rest timer on your Lock Screen and in the Dynamic Island with Live Activities" is fine in the description; keep all
of them out of the name, subtitle and keywords (2.3.7). Do not write "iPhone app" as the product name; "HomeGymLog for
iPhone" as a subtitle is permitted referential use but spends 20 of 30 characters.

---

## Q9 Tests — all five pinnable; probe suite ran 6/6 on iOS 17.5

Scratch suite `HomeGymLogTests/Static/ReleaseProbeTests.swift` (hosted target, `Bundle.main` = app bundle, confirmed again):
```
xcodebuild test -scheme HomeGymLog -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -derivedDataPath … \
  -parallel-testing-enabled NO -only-testing:HomeGymLogTests/ReleaseProbeTests \
  INFOPLIST_KEY_ITSAppUsesNonExemptEncryption=NO INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone=UIInterfaceOrientationPortrait \
  INFOPLIST_KEY_CFBundleDisplayName=HomeGymLog
  ✔ Test run with 6 tests in 1 suite passed — ** TEST SUCCEEDED **
```
What each pin looked like (the shapes that compiled and passed; use the house `FeedbackSourceTests.appSourceRoot` walk):

```swift
import Foundation
import ImageIO      // CGImageSource: no UIKit needed for dimensions and alpha
import Testing

// 1. privacy manifest — source tree (what is committed) and bundle (what ships)
let data = try Data(contentsOf: FeedbackSourceTests.appSourceRoot.appendingPathComponent("PrivacyInfo.xcprivacy"))
let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
#expect(plist["NSPrivacyTracking"] as? Bool == false)
#expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
let apis = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
#expect(apis.first?["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
#expect(apis.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
let shipped = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))   // app-bundle root

// 2. AppIcon: three ios slots, each with a file, 1024×1024, "any" opaque
struct IconSet: Decodable { let images: [IconImage] }
struct IconImage: Decodable { let idiom: String; let platform: String?; let filename: String?; let appearances: [[String: String]]? }
let dir = FeedbackSourceTests.appSourceRoot.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
let set = try JSONDecoder().decode(IconSet.self, from: Data(contentsOf: dir.appendingPathComponent("Contents.json")))
let ios = set.images.filter { $0.idiom == "universal" && $0.platform == "ios" }
#expect(ios.count == 3)
for image in ios {
    let name = try #require(image.filename)
    let source = try #require(CGImageSourceCreateWithURL(dir.appendingPathComponent(name) as CFURL, nil))
    let props = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    #expect(props[kCGImagePropertyPixelWidth] as? Int == 1024 && props[kCGImagePropertyPixelHeight] as? Int == 1024)
    if image.appearances == nil {            // the "any" slot is the App Store icon: ITMS-90717 rejects alpha
        #expect(props[kCGImagePropertyHasAlpha] as? Bool != true)   // RGB PNGs report nil, RGBA report true (observed)
    }
}
#expect(set.images.filter { $0.idiom == "mac" }.isEmpty)   // after the Contents.json clean-up

// 3. welcome tile imageset exists (source) and loads (bundle)
#expect(FileManager.default.fileExists(atPath: FeedbackSourceTests.appSourceRoot.appendingPathComponent("Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg").path))
// hosted, needs `import UIKit` and @MainActor: try #require(UIImage(named: "WelcomeTile"))

// 4./5. built Info.plist (hosted)
let info = try #require(Bundle.main.infoDictionary)
#expect(info["UISupportedInterfaceOrientations"] as? [String] == ["UIInterfaceOrientationPortrait"])   // ~iphone resolves
#expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)                                        // stored as 0
```
Observed values: `kCGImagePropertyHasAlpha` was `true` for the RGBA PNG and **absent (nil)** for the RGB ones, so test
`!= true`, not `== false`. Also pinnable in `LiveActivityProjectTests` style (pbxproj greps, read-only):
`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;` ×2, `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone =
UIInterfaceOrientationPortrait;` ×2, `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` equal across the 6 configuration blocks,
and (if Q3 is built) `INFOPLIST_FILE = HomeGymLogSupport/Info.plist;` ×2. These run on both runtimes; the hosted ones were
verified on 17.5 only (nothing runtime-specific in them).

---

## Unverified items (collected)

1. ITMS-91053 behaviour in Oct 2026 (hard reject vs warning email) — no upload performed.
2. App Store validation of the leftover `mac` icon entries and of the appex's empty `AppIcon` set (inference: not compiled, so
   invisible; expected to pass).
3. Xcode's Info-tab behaviour when adding a key with no `INFOPLIST_KEY_` mapping in a synchronized-folder project (community
   reports say it creates `Info.plist`; placement unknown) — the explicit `INFOPLIST_FILE` path was verified instead.
4. Whether `-exportArchive … destination upload` succeeds on Xcode's signed-in account alone (help text says yes; not run, to
   avoid creating distribution certificates/profiles on the account).
5. Where, if anywhere, iOS shows an extension's `CFBundleDisplayName` for a Live-Activity-only extension.
6. The age-rating answer options' exact labels for "Health or Wellness Topics".
7. That the Support URL field rejects `mailto:` (format rule; not tried on the live form).
8. ITMS-90473 severity today (warning historically).

## Suggested insights entries

`insights/INSIGHTS.md` (decisions/patterns):
- 2026-10-03 — Release Info keys live as `INFOPLIST_KEY_*` build settings (`ITSAppUsesNonExemptEncryption`,
  `UISupportedInterfaceOrientations_iPhone`, `CFBundleDisplayName`), set in Xcode's General/Info tabs; the one key with no
  setting is `UILaunchScreen.UIColorName`, which needs a 9-line merged `Info.plist` outside the synchronized folder
  (`HomeGymLogSupport/Info.plist`, `INFOPLIST_FILE` on the app target only). Verified launch background `F4F2F3`/`0F0E10`.
- 2026-10-03 — `PrivacyInfo.xcprivacy` at the root of the synchronized `HomeGymLog/` folder is copied to the app-bundle root
  with no project edit and is readable from the hosted tests via `Bundle.main`; the appex needs none (no required-reason API).
- 2026-10-03 — Store screenshots: one 6.9" set from iPhone 17 Pro Max / 26.5 (1320 × 2868) with
  `simctl status_bar override --time 9:41 …`; Apple scales to every smaller class. iPhone 15 shots do not satisfy the rule.

`insights/gotchas.md` (Xcode / build):
- 2026-10-03 — **`INFOPLIST_FILE=` (and any `INFOPLIST_KEY_*`) on the xcodebuild command line applies to every target**: it
  replaced the widget's Info.plist, dropped `NSExtension`, and `simctl install` failed with "Failed to create app extension
  placeholder". Scope `INFOPLIST_FILE` to the app target in the project; use CLI overrides only for keys harmless in the appex.
- 2026-10-03 — **An `Info.plist` inside a synchronized folder fails with "Multiple commands produce …/Info.plist"** unless a
  membership exception exists (the widget wizard added one; the app target has none). Put a hand-made plist outside the
  synchronized folders or untick its Target Membership in the File inspector.
- 2026-10-03 — **`qlmanage -t` and `sips` emit RGBA PNGs from an SVG; `rsvg-convert` (and headless Chrome) emit RGB.** The App
  Store icon must have no alpha (ITMS-90717) and actool never warns about it; check with `file icon.png` ("RGB" vs "RGBA").
- 2026-10-03 — **To screenshot the launch screen on the simulator use `simctl launch --wait-for-debugger`** (the short `-w`
  printed usage and launched nothing); the system holds the launch image until a debugger attaches. Eight back-to-back
  screenshots around a normal launch never caught it.
- 2026-10-03 — **A single-scale SVG imageset reports its intrinsic size** (`UIImage(named:)` → 1024 × 1024 pt from a 1024-unit
  SVG, scale 3); author the SVG at the point size you want or `.resizable().frame(…)`.

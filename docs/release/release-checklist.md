# HomeGymLog 1.0 — release checklist

The user's steps after the `m5-release` merge, in order (m5-release spec §2.6). Steps 3–7 are not part of the slice.
The two pages in this folder (`privacy-policy.md`, `support.md`) are byte copies of `ZhabskyiO/homegymlog-site`
(`privacy.md`, `support.md`) fetched at commit `dea6a296c542cbc2fcda285d82c3499ec0b03a66` (2026-10-03); refetch them
with `gh api repos/ZhabskyiO/homegymlog-site/contents/<file> --jq .content | base64 -d` if the site changes.

1. **Archive** (spec §5.8) green with the appex and both dSYMs: this slice's definition of done.

   ```
   rm -rf build/HomeGymLog.xcarchive
   xcodebuild archive -scheme HomeGymLog -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -archivePath build/HomeGymLog.xcarchive   # -allowProvisioningUpdates optional
   A=build/HomeGymLog.xcarchive; APPX=$A/Products/Applications/HomeGymLog.app
   ls $A/dSYMs; ls $APPX/PlugIns          # HomeGymLog.app.dSYM HomeGymLogWidgetsExtension.appex.dSYM; HomeGymLogWidgetsExtension.appex
   codesign -dvvv $APPX 2>&1 | grep -E "Identifier=|TeamIdentifier="; codesign -dvvv $APPX/PlugIns/HomeGymLogWidgetsExtension.appex 2>&1 | grep Identifier=
   ls $APPX/PrivacyInfo.xcprivacy; plutil -p $APPX/Info.plist | grep -E "UILaunchScreen|UIColorName|ITSAppUses|UISupportedInterfaceOrientations" -A1
   ```
   No `-exportArchive`, no upload.
2. ~~Create the public `homegymlog-site` repo~~ **done 2026-10-03** (GitHub Pages: `https://zhabskyio.github.io/homegymlog-site/privacy/` and `/support/`).
3. App Store Connect → **My Apps** → **+** → **New App**: Platforms **iOS**, Name **HomeGymLog**, Primary Language, Bundle ID
   `com.zhabskyi.homegymlog.ios`, SKU `homegymlog-ios-1`, User Access → **Create** (reserves the name).
4. Fill the record from `app-store-metadata.md` (name, subtitle, promotional text, keywords, description, category, App Privacy,
   age rating, Support and Privacy Policy URLs, copyright) and upload the five `screenshots/` PNGs to the 6.9" display row.
5. Xcode → **Product** → **Archive** → Organizer → select the archive → **Validate App** (needs the record from step 3).
6. **Distribute App** → **TestFlight Internal Only**; install the build on the iPhone 14 Pro Max through TestFlight.
7. After the MVP manual pass: **Submit for Review**.

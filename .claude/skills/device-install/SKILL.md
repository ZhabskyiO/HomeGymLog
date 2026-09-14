---
name: device-install
description: Build HomeGymLog and install it on the connected iPhone with the paid team's automatic signing, handling stale cached profiles, Developer Mode, and device trust prompts. Use when asked to run on the phone or device.
---

Install the app on the physical iPhone. Signs with the paid Individual team `4GKZ96A6QR`; one-year development
profiles (see `insights/gotchas.md`, "Apple developer account").

## Steps

1. Find the device: `xcrun devicectl list devices 2>/dev/null` (Xcode 15+). Need a row with state
   `connected` or `available (paired)`. If none, tell the user to plug in the phone, unlock it, and tap
   Trust, then stop.
2. Build for device with automatic signing:
   ```
   xcodebuild -scheme HomeGymLog -destination "platform=iOS,name=<device name>" \
     -configuration Debug -derivedDataPath build/DerivedData -allowProvisioningUpdates build 2>&1 \
     | tee build/last-device-build.log | grep -E "error:|Signing|BUILD (SUCCEEDED|FAILED)"
   ```
3. If the build reports "Developer Mode disabled" (xcodebuild shows it as "Timed out waiting for all
   destinations"), the phone needs Settings → Privacy & Security → Developer Mode → on → restart → Turn On.
   If it reports "Failed Registering Bundle Identifier … not available", the id collides with one already
   registered (App IDs compare case-insensitively); diagnose with
   `xcodebuild … PRODUCT_BUNDLE_IDENTIFIER=<candidate> build` before changing the project, then have the user
   change it in Xcode (never in the pbxproj).
   If signing fails otherwise: the usual causes are (a) no team selected in the target's Signing &
   Capabilities, (b) the yearly membership or the profile expired. Tell the user to open the project in
   Xcode, select the team `4GKZ96A6QR` (no "(Personal Team)" suffix) under Signing, and press Run once;
   Xcode handles the profile. Do not fiddle with certificates from the command line.
   After a successful build, read the embedded profile's expiry:
   ```
   security cms -D -i build/DerivedData/Build/Products/Debug-iphoneos/HomeGymLog.app/embedded.mobileprovision \
     > build/embedded.plist && /usr/libexec/PlistBuddy -c "Print :ExpirationDate" build/embedded.plist
   ```
   If it is 7 days after its `CreationDate`, a stale free-tier profile was reused: move the files in
   `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` to a scratch folder and build again.
4. If the build compiles but never finishes (log ends in `DVTDeviceOperation: Encountered a build number ""`), kill it
   after a few minutes (no `timeout` on macOS: `cmd & PID=$!; (sleep 240; kill $PID) & wait $PID`), then sign the
   compiled app by hand and install it, see gotchas "Xcode / build":
   ```
   APP=build/DerivedData/Build/Products/Debug-iphoneos/HomeGymLog.app
   ENT=$(find build/DerivedData -name "HomeGymLog.app.xcent" | head -1)
   ID=$(security find-identity -v -p codesigning | awk '/Apple Development/ {print $2; exit}')
   codesign --force --sign "$ID" --timestamp=none --generate-entitlement-der --entitlements "$ENT" "$APP"
   codesign --verify --deep --strict "$APP"
   ```
5. Install and launch:
   ```
   APP=$(find build/DerivedData/Build/Products/Debug-iphoneos -maxdepth 1 -name "*.app" | head -1)
   xcrun devicectl device install app --device <identifier> "$APP"
   xcrun devicectl device process launch --device <identifier> com.zhabskyi.homegymlog.ios
   ```
6. First install from a team the phone has not trusted yet needs trust: Settings → General → VPN & Device
   Management → tap the developer email → Trust. The launch error for this case reads "invalid code
   signature, inadequate entitlements or its profile has not been explicitly trusted". Give the steps
   only then, and ask the user to open the app from the home screen afterward.

## Report

Device name, build result, install result. If the app is on the phone but launch was refused, quote the
error and give the single fix. State the embedded profile's expiry date; warn only when it is under 30 days away.
If launch fails with "Locked", the install still worked: ask the user to unlock the phone and re-run the launch.

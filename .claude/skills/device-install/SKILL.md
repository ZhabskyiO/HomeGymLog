---
name: device-install
description: Build HomeGymLog and install it on the connected iPhone using the free Apple developer tier, handling the 7-day provisioning expiry and device trust prompts. Use when asked to run on the phone or device.
---

Install the app on the physical iPhone. Free-tier signing rules apply (see `insights/gotchas.md`).

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
   If signing fails otherwise: the usual causes on the free tier are (a) no team selected in the target's
   Signing & Capabilities, (b) the personal team's 7-day profile expired, (c) the 10 App ID limit.
   Tell the user to open the project in Xcode, select their personal team under Signing, and press Run
   once; Xcode handles the profile. Do not fiddle with certificates from the command line.
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
6. First install of a personal-team app on a phone needs trust: Settings → General → VPN & Device
   Management → tap the developer email → Trust. The launch error for this case reads "invalid code
   signature, inadequate entitlements or its profile has not been explicitly trusted". Give the steps
   only then, and ask the user to open the app from the home screen afterward.

## Report

Device name, build result, install result. If the app is on the phone but launch was refused, quote the
error and give the single fix. Remind the user the profile expires in 7 days only on the first install
of a session.

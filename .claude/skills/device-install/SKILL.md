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
3. If signing fails: the usual causes on the free tier are (a) no team selected in the target's
   Signing & Capabilities, (b) the personal team's 7-day profile expired, (c) the 10 App ID limit.
   Tell the user to open the project in Xcode, select their personal team under Signing, and press Run
   once; Xcode handles the profile. Do not fiddle with certificates from the command line.
4. Install and launch:
   ```
   APP=$(find build/DerivedData/Build/Products/Debug-iphoneos -maxdepth 1 -name "*.app" | head -1)
   xcrun devicectl device install app --device <identifier> "$APP"
   xcrun devicectl device process launch --device <identifier> com.zhabskyi.homegymlog
   ```
5. First install of a personal-team app on a phone needs trust: Settings → General → VPN & Device
   Management → tap the developer email → Trust. Say this only when the launch fails with an untrusted
   developer error.

## Report

Device name, build result, install result. If the app is on the phone but launch was refused, quote the
error and give the single fix. Remind the user the profile expires in 7 days only on the first install
of a session.

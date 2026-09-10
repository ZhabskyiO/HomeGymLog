---
name: security-audit
description: Security and privacy audit for HomeGymLog, a local-only iOS app: secrets in the repo, unexpected network code, data-at-rest protection, export and share handling, notification content, Info.plist privacy strings, entitlements, and App Privacy label truthfulness. Use before a release or when adding any capability.
---

Audit the app for the threats that actually apply to a local-first, no-backend iPhone app. Report
findings with evidence; do not pad with generic advice.

## Checks

1. **Secrets in the repo.** `git log -p --all | grep -inE "(api[_-]?key|secret|token|password|BEGIN (RSA|EC|OPENSSH) PRIVATE)"` and a scan of the tree for `.p12`, `.mobileprovision`, `.cer`, `.env`. If
   `gitleaks` is installed, run `gitleaks detect --no-banner`. Any hit is blocking.
2. **Network surface.** The v1 app makes no network calls. `grep -rnE "URLSession|URLRequest|Network\.|NWConnection|WebKit|WKWebView" --include=*.swift .` must return nothing outside tests. Any hit
   must be justified in `insights/INSIGHTS.md` or is a finding. Also check `Info.plist` for
   `NSAppTransportSecurity` exceptions; there should be none.
3. **Third-party code.** No SPM dependencies unless recorded in `CLAUDE.md`. Check `Package.resolved`
   and the project's package references.
4. **Data at rest.** The SwiftData store lives in the app container, which iOS encrypts when the device
   is locked. Confirm no copy of user data is written to a shared or unprotected location (`/tmp`, app
   group containers, `UserDefaults` holding workout history rather than settings only). Check that
   export files are written to a temporary directory and handed to the share sheet, not left in
   Documents indefinitely.
5. **Notifications.** Local notification bodies must not include anything the user would not want on a
   lock screen beyond "rest is over" or "training day". Check `UNMutableNotificationContent` usage.
6. **Entitlements and capabilities.** List everything in `*.entitlements` and Signing & Capabilities.
   Each must map to a feature the app actually ships (Live Activities, local notifications). Anything
   else is a finding. Verify `NSSupportsLiveActivities` only if the Live Activity exists.
7. **Privacy strings and label.** If HealthKit or photos are ever touched, the matching `NS...UsageDescription`
   must exist and be honest. Confirm the App Privacy answers ("Data Not Collected" for v1) remain true:
   no analytics, no crash reporter, no identifiers sent anywhere.
8. **Logging.** `grep -rn "print(" --include=*.swift .` outside tests; none should log set data, notes,
   or body weight in release. `os.Logger` with `privacy: .private` for anything user-specific.
9. **Input handling.** Numeric inputs (weights, reps, body weight) are clamped in the Engine, not only
   in the UI. Notes are plain text, never interpreted. Imported data, if any, is validated before it
   touches the model context.
10. **Backups.** Decide and document whether the store is included in iCloud device backup (default
    yes). It should be; note it in `insights/INSIGHTS.md` if not already.

## Report

Verdict line, then findings ordered by severity with file:line and the fix. Then a short "verified
clean" list naming the checks that passed, so the audit is auditable. Record any new decision in
`insights/INSIGHTS.md`.

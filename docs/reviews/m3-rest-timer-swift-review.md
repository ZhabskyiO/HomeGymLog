**Verdict: ship.** No data-loss, logic or Release-only problem found by reading. The writers are one save each with `SetSnapshot` + `RestSnapshot` restore, the "rest iff a pending set remains" rule has a single writer, the notifier guard is real and test-backed, and both `.onChange` handlers sit inside the timeline closure once each. The items below are non-blocking; item 1 is a two-line hardening worth applying now.

Nothing new is Release-only: `.silent()` lives inside the `#if DEBUG` seed branch, `restNotifier` is a plain optional stored property, the `#Preview` is under `#if DEBUG`, and `RestNotificationCenter.system()` touches `UNUserNotificationCenter.current()` only inside the closures. The main session's Release build should confirm.

## Blocking

None.

## Non-blocking

**1. `/Users/zhabskyi/AppleApps/HomeGymLog/HomeGymLog/Features/Workout/WorkoutView.swift:120` reads the log before the `isDiscarding` guard.**
`observeRestEnd` guards `!isDiscarding`, but its argument `RestTimer.display(restStartedAt: log.restStartedAt, …)` is evaluated first. Scenario: Exit → Discard, then a scene-phase change (Control Center, app switcher) is delivered in the frame between the delete save and the root query dropping the log; on 26.5 reading a deleted row's field can trap ("backing data could no longer be found", gotchas SwiftData). Practically unreachable by a user, but the fix is free:
```swift
if phase == .active {
    notifier.removeDelivered()
    guard !isDiscarding else { return }
    observeRestEnd(resting: RestTimer.display(…) != nil)
}
```
React analogy: check the "is unmounting" ref before touching props the unmount already invalidated.

**2. Accessibility: the hidden "Rest" title (`RestOverlay.swift:19–21`).** `.accessibilityHidden(true)` on a SwiftUI `Text` does remove it from VoiceOver's traversal on iOS 17 in my experience; XCUITest's snapshot walks the raw hierarchy and is known to keep reporting such elements, so this is most likely an XCUITest-only artefact. **Unverified** (no VoiceOver on the simulator). The smallest shape that removes the question for both readers: make the title and the countdown one element and leave "Next:" as its own stop (`children: .ignore` drops the children from both trees; `.combine` would keep the hidden title's text out but still expose two nodes to XCUITest):
```swift
VStack(alignment: .leading, spacing: 0) {
    Text(RestText.title).font(.system(size: 12)).foregroundStyle(Theme.mu)
    Text(RestText.clock(seconds: seconds))
        .font(.system(size: 34, weight: .bold)).tracking(-1).monospacedDigit().foregroundStyle(Theme.tx)
}
.accessibilityElement(children: .ignore)
.accessibilityLabel(RestText.title)
.accessibilityValue(RestText.spoken(seconds: seconds))
.accessibilityAddTraits(.updatesFrequently)
Text("Next: " + RestText.next(rest.next)) …
```
Proof on both runtimes: in the Step 10 scratch copy, `app.staticTexts.matching(NSPredicate(format: "label == 'Rest'")).count == 1` on 17.5 and 26.5; on the device with VoiceOver, swiping through the card gives exactly "Rest, 1 minute 2 seconds" → "Next: set 2 of 3" → "Add 30 seconds, button" → "Skip rest, button".

**3. Runtime-only risk for the main session: `.onChange(of: rest != nil, initial: true)` inside the timeline closure (`WorkoutView.swift:76`).** P2 probed the plain form; `initial: true` writes `lastSeenRestEnd` during first appearance. The plan named this shape unprobed. Check: `xcrun simctl spawn <udid> log stream --predicate 'eventMessage CONTAINS "Modifying state"'` while launching `-seed wo-rest`; expect nothing. If it logs, the plan's fallback (`.onAppear { observeRestEnd(resting: rest != nil) }` inside the closure) is a one-line swap and the cold-launch `.active` scene-phase call already covers the mount row anyway.

**4. Light-mode shadow (`RestOverlay.swift:53`).** A theme-aware shadow is cheap: `@Environment(\.colorScheme) private var colorScheme` and `.shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 25, y: -20)`. It is also unverified visually (no light snapshot exists) and M5 owns the light audit, so I would leave it for M5 unless the AC-3 spot check reads as a defect; if applied now, re-shoot `ac3-light`.

**5. The 0.3 s swap animation also animates every other change in the same save (`WorkoutLoggingContent.swift:85`).** `.animation(value: rest != nil)` covers the whole content, so on a rest *start* the RPE card leaving and row 2 becoming Active crossfade with the card sliding in. Spec 4.5 already lists the start direction as unverified (user AC-5); the plan's fallback (`rest == nil ? .easeInOut(duration: 0.3) : nil`) animates only the end. No action until AC-5 is seen.

**6. Tests.** No assertion that cannot fail; containers are bound everywhere (`withExtendedLifetime` in `RestCommitRollbackTests.swift:69`, `defer` in `WorkoutSeedTests.restInstants`, `TestStore` held in the writer suites). AC-24 (`RestNotifierTests.supersededRun`) does fail without the guard: the first task is released last and would append 12:01:32. Minor: `RestEndRuleTests.swift:34–35` and `:42–43` are duplicate lines with different comments ("Skip" / "swipe on E1S2", "relaunch" / "return"); harmless, drop one of each or vary an input. `SchemaSourceTests.restInstantsStayOptional` also rejects the equally valid `var restStartedAt: Date? = nil`; fine as a pin, but its doc comment should say "declared without a default" so a future edit is not surprised. `RestNotifierSourceTests` line-order rule is semantically required (inside the seed branch), not brittle.

**7. Readability.** Comments are truthful and every new concept carries a React line (`useRef`, stale fetch, AbortController, visibilitychange, sticky footer). `WorkoutView.body` is 73 lines, `RestOverlay.body` about 45. Two small nits: `RestTimer.observeEnd` (`Engine/RestTimer.swift:59–64`) could be one expression, `let announce = lastSeenEndsAt.map { restEndsAt == $0 && !resting && now >= $0 } ?? false`, though the if/else reads fine for a newcomer; and `RestOverlay` runs its own 1 Hz timeline inside the outer one (spec 4.4 asks for it), which a reader may take for a mistake, so a half-line "the outer timeline only decides `rest`; this one draws the label and ring" in the doc comment would help.

Checked and sound, for the record: `session == nil` / `restSeconds ≤ 0` clear instead of start (`WorkoutLogStore.swift:163–173`); `skipSet` replaces a live rest, `logSet`/`saveAndLogSet`/`nextExercise` clear in the same save; `addRestTime` throws first for `seconds ≤ 0` then `at < endsAt`; the finished-log nil invariant holds by construction since every writer that can retire the last pending set clears; ties are consistent (`now == restEndsAt` → not resting, `decide` → cancel, `addRestTime` → false, `observeEnd` → announce); `remainingSeconds`/`remainingFraction` cannot trap on any finite `Date`; `.task(id: isDiscarding ? nil : log.restEndsAt)` never reads the log after Discard; `onDisappear` cancel covers Exit and Done.

---

Main session disposition (2026-09-14): items 1, 2, 6 and the item 7 doc-comment line sent to the implementer after the test-writer; item 3's log-stream check run after the fixes; item 4 left for the M5 light audit; item 5 waits for the user's AC-5 check (fallback named in the plan).

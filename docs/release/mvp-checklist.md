# MVP manual pass — iPhone 14 Pro Max

Every acceptance criterion that the slices deferred to "the user's MVP pass" or marked user-run / device-only, in the order you would
meet them on the phone. Sources: CLAUDE.md Milestones, each spec's §8, `insights/INSIGHTS.md`. Written 2026-10-04.

**Build:** `main` at `d4a8bdf` (version 1.0 (1)), installed with `/device-install` or the TestFlight build from the m5-release archive.
**Resetting state:** delete the app and reinstall. That clears the store, every preference, and iOS's Notifications and Live Activities
permissions for the app (no other way resets a permission prompt). Seeded `-seed` states do not exist on device, so every check below uses
real taps on a real program. Checks that need a missed training day (the Missed day section) need a training day to pass with no workout,
so plan them for day two; the three-missed check needs three.
**Already verified on device (2026-09-11), not repeated:** m2-program-tab AC-9a (returning to the Program tab resets to today), chip and
day taps, the week-24 scroll-and-return, sheet dismissal.

## 1. Install & first launch

- [ ] **m5-release AC-20** — Look at the Home Screen → the icon is the white dumbbell-"H" on red.
- [ ] **m5-release AC-20** — Cold launch → the app's background colour (not white, not black) shows before the first screen.
- [ ] **m5-release AC-20** — iOS Settings → HomeGymLog → it lists Live Activities and Notifications.
- [ ] **m3-logging AC-27** — Install over the build already on the phone → opens with no store error; program, history, Home tiles and the Program card unchanged.
- [ ] **m2-onboarding AC-8** — Tap through onboarding with defaults → the summary step, then "Start program" lands on Home with no extra navigation.
- [ ] **m2-onboarding AC-9** — On the days step, deselect one day → Continue dims and does nothing; reselect any day → enabled; a fifth day with four selected swaps out the earliest.
- [ ] **m2-onboarding AC-10** — Pick kg on the first step → body weight shows 82 kg and Dumbbell Bench Press 18.1 kg later; back to lb → 180 / 40 lb.
- [ ] **m2-onboarding AC-11** — Kill the app on the "About you" step, relaunch → the first step with defaults.
- [ ] **m5-release AC-20** — VoiceOver on the welcome step → the first stop is "Your gym. Your program."; it never stops on the icon tile.

## 2. Home

- [ ] **m2-home AC-6** — Tap "Progress ›" → the Progress tab opens and the pill highlights it; back to Home → unchanged.
- [ ] **m2-home AC-7** — Tap a row's ⓘ → that exercise's info sheet; Done closes it; so does a tap on the dim.
- [ ] **m2-home AC-9** — With kg chosen in onboarding → Home reads "kg this week" and the bench row 18.1 kg.
- [ ] **m3-logging AC-13** — "Start workout" → the workout screen with the clock counting from 00:00; kill and relaunch → it reopens there.

## 3. Program tab

- [ ] **m2-program-tab AC-9** — Tap a week chip → border, phase line, day row and card change together and that week's default day is selected; tap a day → only the day fill and the card change.
- [ ] **m2-program-tab AC-10** — Scroll the chips to the last week and tap it → "Deload · 2 × 12 · −30% load", its Monday selected; Home and back → the current week re-selected, flush with the left edge.
- [ ] **m2-program-tab AC-11** — ⓘ on a row of a far week → the sheet; Done → the same week and day still selected.

## 4. Workout

- [ ] **m3-logging AC-14** — Swipe the active row right past ~90 pt → the RPE card; tap 7 → "RPE 7", next row active, hint gone. A short (~60 pt) swipe springs back. A vertical drag on a row scrolls and never logs.
- [ ] **m3-logging AC-15** — On the RPE card, "Next exercise ›" does nothing; "Skip" → "✓ logged", next row active, no card; relaunch keeps it. Skipping the rating of the very last set → the summary.
- [ ] **m3-logging AC-16** — Swipe left → the adjust sheet; + weight, − reps, "Save & log set" → the row shows the new values ✓ with the RPE card and the remaining rows carry them; a tap on the dim closes with nothing written; + at the top weight and − at 1 rep do nothing.
- [ ] **m3-logging AC-17** — Adjust sheet → "Skip set" → "– skipped" with the edited values, next row active at the original target, no RPE card.
- [ ] **m3-logging AC-18** — "Next exercise ›" after one logged set → the other sets skipped, exercise 2 shows with the first segment green; on exercise 5 → the summary.
- [ ] **m3-logging AC-19** — Exit with nothing logged → Home at once. After a logged set → the confirmation; Cancel keeps the workout; Discard → Home with the log gone. From a workout started on a missed Program card, Exit lands on the Program tab at today's week.
- [ ] **m3-logging AC-20** — Exit → Discard after a logged set → no flash of "SESSION COMPLETE" between the workout and Home (the discarding flag is already in; report any flash).
- [ ] **m3-logging AC-21** — Done on the summary → Home with the tiles, week strip and records updated; no frame of the Program tab even if you came from there.
- [ ] **m3-logging AC-22** — Start a missed session from its Program card, log every set, Done → Home counts it; the Program card reads "Completed" with no button.
- [ ] **m3-logging AC-23** — VoiceOver: the active row offers the "Log set" and "Adjust set" actions, each doing what the swipe does; Skip rating, the RPE numbers, steppers, sheet buttons, Next exercise, Exit, Done and both "Start workout" read as buttons.
- [ ] **m3-logging AC-24** — Log a full 15-set workout → no visible hitch on a commit, scrolling from a row works, the summary appears without a stall.
- [ ] **m3-logging AC-25** — Kill the app (a) after set 2's RPE, (b) with the RPE card up, (c) after skipping a rating, (d) with the sheet open → each relaunch reopens the same exercise and set; the card is back in (b), gone in (c); the sheet is closed with nothing written in (d); the clock shows real elapsed time.
- [ ] **m3-logging AC-26** — Kill on the summary → relaunch shows the same numbers and duration; Done lands on Home with the session completed.
- [ ] **m3-exercise-tools AC-9** — "Add note" → type "Seat notch 3" → Done → the bar reads "Notes ·"; reopen → the text is there; clear → "Add note"; type again, kill mid-word, relaunch → the text up to the last keystroke; the note is back on the same exercise in a later workout.
- [ ] **m3-exercise-tools AC-10** — With the keyboard up the note sheet grows and Done stays visible after six lines; a drag on the content hides only the keyboard; a drag from the top edge closes the sheet; nothing typed is lost.
- [ ] **m3-exercise-tools AC-11** — Swap on exercise 1 → the empty sheet ("Every Back exercise is already in this workout."); after logging set 1 → Swap dimmed and inert (also during the RPE card and the rest); on exercise 4 → a list of candidates.
- [ ] **m3-exercise-tools AC-12** — Pick a swap → the header, equipment and rows change, no pill; Swap again lists the original exercise and not the new one; kill and relaunch keep it; the summary and today's Program card name the new exercise.
- [ ] **m3-exercise-tools AC-13 / AC-18** — Rate the last set of exercise 3; while the rest counts, Swap exercise 4 → the card reads "Next: <new exercise> · set 1" with the countdown unbroken, no hitch.
- [ ] **m3-exercise-tools AC-14** — Swap exercise 5, then Exit → Discard → Home's Today card lists the swapped exercise; Start again shows it, with the original among its candidates.
- [ ] **m3-exercise-tools AC-15** — On an exercise with a previous best the "↑ +X from your last" pill shows; it stays while the adjust sheet is open; after saving a lower weight and rating, the pill is gone on set 2; an exercise never trained has no pill.
- [ ] **m3-exercise-tools AC-16** — VoiceOver: name + ⓘ is one button with hint "Shows form cues and notes"; Swap is a button (dimmed when disabled); each candidate reads "Name, equipment, weight unit"; the bar button is "Add note", or "Notes" with hint "Edit your note"; the pill reads "Up 10 lb from your last …"; "Next exercise ›" is absent while resting.
- [ ] **m3-exercise-tools AC-17** — Type a 6-line note at speed → no dropped characters or caret jumps; autocorrect accepts a suggestion; emoji input works.
- [ ] **m3-exercise-tools AC-19** — Type a note during a live rest → the countdown behind the sheet never stutters.

## 5. Rest timer

- [ ] **m3-rest-timer AC-5** — Rate set 1 → the rest card replaces the bar, "1:15" counting down to "0:01", then the bar slides back (~0.3 s) with the next row still active; on a fresh install the notification prompt appears over the card with the countdown continuing behind it; the last set of exercise 1 shows "Next: Seated Low Row · set 1".
- [ ] **m3-rest-timer AC-6** — Swipe the next set during a rest → the RPE card, rest card gone; background the app → no "Rest over" banner. A left swipe opens the adjust sheet over the running card; "Skip set" → a fresh "1:15" / "Next: set 3 of 3".
- [ ] **m3-rest-timer AC-7** — +30s at ~"1:02" → "1:32" and a visibly fuller ring; two quick +30s then background → one banner at the extended end, never earlier; Skip removes the card at once; Exit → Cancel leaves the card intact; a short brush on the row springs back.
- [ ] **m3-rest-timer AC-8** — Skip set starts a rest; rating the final set of exercise 5 → the summary, no card.
- [ ] **m3-rest-timer AC-9** — Kill mid-rest (~0:40 left) → relaunch shows the real time left and ring; relaunch after the end → no card; nothing left in Notification Center.
- [ ] **m3-rest-timer AC-10 / AC-15** — Fresh install, Don't Allow the prompt → rests count and end normally, no banner ever, no second prompt.
- [ ] **m3-rest-timer AC-11** — VoiceOver: "+30s" / "Skip" read "Add 30 seconds" / "Skip rest"; the countdown is one element read on focus ("1 minute 2 seconds"), never per second; the active row keeps "Log set" / "Adjust set"; a rest running out announces "Rest over" exactly once; Skip, +30s and a swipe announce nothing. Tall content scrolls until the active row sits fully above the card.
- [ ] **m3-rest-timer AC-12 / AC-13** — Lock the phone mid-rest → "Rest over / Time for your next set." banner with sound, within ~1 s of the in-app end (compare across two rests); unlock and return → gone from Notification Center.
- [ ] **m3-rest-timer AC-14** — Kill the app mid-rest with the phone unlocked → the banner still fires at the end.
- [ ] **m3-rest-timer AC-16** — Exit → Discard mid-rest, then background past the end → no banner. Skip, then background → no banner.
- [ ] **m3-rest-timer AC-17** — A full 15-set workout with rests → no stutter in the countdown, a swipe (including mid-rest) or scrolling.
- [ ] **m5-haptics AC-5** — Set logged: a swipe past 90 pt → one buzz as it snaps back; a short brush → none; "Save & log set" → one; the VoiceOver "Log set" action → one; Skip set, RPE taps, Skip rating, Next exercise, Swap, note keystrokes → none; Haptics off → none; iOS System Haptics off → none with the toggle still on.
- [ ] **m5-haptics AC-6** — Music on AirPods, let a rest run out → one two-beat buzz and the chime through the AirPods, music continuing at the same volume; Ring/Silent to silent → chime gone, buzz stays; Haptics off → chime only; Sound off → buzz only; both off → neither (card still leaves); VoiceOver on → "Rest over" spoken plus both; the first chime lands with the buzz, not after it.
- [ ] **m5-haptics AC-7** — Skip a live rest → one buzz + chime, no "Rest over" spoken; +30s → nothing then, one cue at the extended end or its Skip; a swipe or Save & log mid-rest → the set buzz only.
- [ ] **m5-haptics AC-8** — Rate the last set → the summary with one buzz, no chime; kill before Done and relaunch onto the summary → no buzz; Haptics off → none.
- [ ] **m5-haptics AC-9** — Lock mid-rest → the "Rest over" banner with sound and the system buzz, once; return → no extra buzz or chime. Sound off, repeat → the banner shows and wakes the screen with no sound and no buzz. Kill mid-rest, relaunch after the end → nothing.

## 6. Live Activity

- [ ] **m5-live-activity AC-32** — The first device build registers the `com.zhabskyi.homegymlog.ios.widgets` App ID by itself and the extension installs with the app (no signing error in Xcode).
- [ ] **m5-live-activity AC-26** — Start a rest, lock the phone → the Lock Screen shows the ring, "Rest", the counting m:ss, "Next: set 2 of 3", "+30s" and "Skip" on a card; the time matches the in-app card within a second; Light and Dark follow the device; VoiceOver reads "Rest", the time, the Next line, "Add 30 seconds, button", "Skip rest, button".
- [ ] **m5-live-activity (INSIGHTS, no AC number)** — With a rest running and the app in the background, long-press the Dynamic Island → the expanded view shows the ring, title, countdown, Next line and both buttons; the compact island shows the timer glyph and m:ss. (The spec header says the 14 Pro Max has no island; it does.)
- [ ] **m5-live-activity AC-27** — App in the background, phone unlocked: tap "+30s" on the Lock Screen card → the countdown jumps by 30 within a second; open the app → the card shows the same end and "Rest over" arrives once at the extended instant. Tap "Skip" → the activity disappears; open the app → no card, no chime, no haptic.
- [ ] **m5-live-activity AC-28** — Swipe the app away mid-rest, tap "+30s" on the Lock Screen → the countdown jumps, the banner fires at the extended instant, launching the app resumes with the longer rest. **If the tap does nothing:** record it; the recorded fallback is plan Step R (remove the two buttons, keep tap-to-open).
- [ ] **m5-live-activity AC-29** — Let a rest run out with the phone locked → the "Rest over" banner, and the activity reads "Rest over" with no buttons (if it still draws the countdown, record it under the U4 fallback); unlock and open the app → the activity is gone within a second.
- [ ] **m5-live-activity AC-30** — Settings → Lock Screen timer off → the next rest shows no activity, card and banner unchanged. iOS Settings → HomeGymLog → Live Activities off, return → the row reads "Live Activities are off in iOS Settings" with "Open iOS Settings", which lands on that page; allow, return → the pair is gone; turn Lock Screen timer back on.
- [ ] **m5-live-activity AC-31** — With the phone locked (not yet unlocked by Face ID), tap "+30s" → nothing; after unlocking it works.

## 7. Missed day (needs a training day with no workout)

- [ ] **m4-missed-day AC-12** — Home shows the "MISSED SESSION" card; tap "Do it today · shift program" → the card goes, the Today card is the missed session, the Program tab gained a week at the end and the missed day is now a rest cell; starting it shows today's week in the summary.
- [ ] **m4-missed-day AC-13** — (Fresh missed day) tap "Skip it · stay on schedule" → the card goes, Home unchanged, the Program card reads "Skipped" with no buttons.
- [ ] **m4-missed-day AC-14** — With three missed sessions, Skip → the card names the next missed one; Skip → the next; Skip → none. Or Shift on the first → the card goes and all three re-slot forward in order.
- [ ] **m4-missed-day AC-15** — Tap the dim → the card goes and nothing behind it fires; a finger drag of 80 pt or more down dismisses it; a 40 pt drag springs back (check the spring feel); a long drag starting on Skip or on the shift button dismisses without skipping or shifting; a plain tap on each button still acts once; a tap in the card's bottom padding does nothing.
- [ ] **m4-missed-day AC-16** — Program tab, the missed card: its shift button → today's cell with the session and "Start workout" only; its skip button → "Skipped", no buttons, selection unchanged.
- [ ] **m4-missed-day AC-17** — VoiceOver with the card up: kicker, title, body read in order; two buttons with their exact labels; the escape gesture (two-finger Z) dismisses; **focus never leaves the card**. If it escapes, the recorded fallback is `.isModal` on the host's outer root.
- [ ] **m4-settings AC-14** — With the prompt showing, Settings → Missed a day → "Always shift" → back on Home no prompt and the Today card is the missed session; a one-line banner "Shifted <name> to today" at the top goes by itself after ~3 s, a tap dismisses it at once, leaving Home at ~1 s and returning shows it still there; "Always skip" on a fresh missed day → no prompt and the Program card "Skipped", banner "Skipped <name>"; dismiss the prompt by a dim tap then pick "Always shift" → the shift still runs; Reduce Motion on → no animation; VoiceOver announces the banner once and reads it as a button.

## 8. Progress

- [ ] **m4-progress AC-9** — Tap another chip → Best, Since start, the line and the from/to dates change for that exercise; back to the first → as before; nothing written.
- [ ] **m4-progress AC-10** — Tap a chip, go to Program and back → still selected; relaunch → the first chip.
- [ ] **m4-progress AC-11** — After a finished workout with a heavier set → that exercise's chart gains the point, Best and Since start move, today's calendar cell is green and the count grew by one.
- [ ] **m4-progress AC-12** — After a shift → the missed day is a rest cell and today is highlighted; after a skip → the day shows in grey.
- [ ] **m4-progress (INSIGHTS, no AC number)** — A real finger scroll of the chip row is smooth and a tap after scrolling selects the right chip.
- [ ] **m4-progress AC-13** — VoiceOver order: title → chips (buttons, the selected one reads "selected") → Best → Since start → the chart container ("<exercise>, N sessions, X to Y lb"), then each dot ("Aug 31, 37.5 lb") with no line or rule element → from/to → month → "N completed" → cells (day number, value). Does VoiceOver stop on the container before its dots?

## 9. Settings

- [ ] **m4-settings AC-9** — Device in Light: tap "Dark" → every tab and the pill dark, including Home's ⓘ sheet; "System" → light again; device in Dark, "Light" → light. Relaunch → the choice survives with no flash of the other scheme.
- [ ] **m4-settings AC-10** — Tap "kg" → equipment, Home ("kg this week"), Program rows and Progress values in kg; "lb" → back; a workout started in kg shows kg rows and the adjust stepper still moves one real plate step per tap.
- [ ] **m4-settings AC-11** — "Build a new program…" → the "Build a new program?" dialog with a red "Archive and start over"; Cancel → nothing changes, still on Settings.
- [ ] **m4-settings AC-12** — "Archive and start over" → onboarding at "How long?" prefilled; Back → the first step with your units; Continue through, "Start program" → the shell opens on **Home** with a fresh program (0 done); Progress still shows the old program's points and completed days; Settings "Current" reads the new program; no missed-day prompt.
- [ ] **m4-reminder AC-5** — Fresh install: Daily reminder on → the system prompt at once; Allow → "7:00 AM on training days" and a "Reminder time" row; off → no row. Fresh install again, Don't Allow → "Notifications are off in iOS Settings" with "Open iOS Settings".
- [ ] **m4-reminder AC-6** — Change the time to 6:30 PM → the subtitle reads "6:30 PM on training days".
- [ ] **m4-reminder AC-7 / AC-18** — "Open iOS Settings" → the Settings app on HomeGymLog's notifications page; allow there, return → the row switches to the on state by itself; the next training day notifies.
- [ ] **m4-reminder AC-16** — With the reminder on and a training day tomorrow → the notification arrives at the chosen time ("Training day" / "Your workout is planned for today.") with the default sound; tapping it opens the app (killed → Home; backgrounded → where it was).
- [ ] **m4-reminder AC-17** — Finish a session before the reminder time → no notification that day; after a skip or shift → no reminder for the past day, and the moved session's day gets one if its time is still ahead.
- [ ] **m4-reminder AC-19** — A reminder arriving while the app is open shows as a banner; a rest timer ending in the foreground still shows no banner.
- [ ] **m4-reminder AC-8 (c)** — With the reminder on, lock the phone during a real rest → the "Rest over" banner still arrives once; the reminder is not disturbed by it.
- [ ] **m5-haptics AC-9 (reminder)** — Sound off with a training day tomorrow → the reminder banner arrives silent, both with the phone locked and with the app open at fire time; Sound on → the default sound.
- [ ] **m4-reminder AC-9** — VoiceOver: the toggle reads "Daily reminder, Off, switch button, off" / "…, 7:00 AM on training days, switch button, on" / "…, Notifications are off in iOS Settings, …" / "…, Notifications not allowed yet, …"; the picker reads "Reminder time" with its value; the two action rows are buttons; no hints.
- [ ] **m5-haptics AC-10** — VoiceOver: "Haptics, Set logged, rest finished, workout done, switch button, on" and "Sound, Rest finished, daily reminder, switch button, on" (then "off" after a double-tap); Haptics then Sound close the card after the reminder rows.
- [ ] **m5-release AC-20** — Scroll Settings to the bottom → "ABOUT" with "Privacy policy", "Support" and "Version · 1.0 (1)" fully above the tab pill; "Privacy policy" and "Support" open the live pages in Safari.
- [ ] **m4-settings AC-15 + m5-export AC-10 + m5-release AC-20** — VoiceOver order: title → "Appearance" → System / Dark / Light (selected one reads "selected") → "Units" → lb / kg → the reminder rows → Haptics → Sound → Lock Screen timer → "PROGRAM" → "Current" with its value → "Missed a day" pop-up button with its value → "Build a new program…" button → "EQUIPMENT" → three label/value pairs → "BACKUP" → "Export backup…, button" → "Restore from backup…, button" → "ABOUT" → "Privacy policy, link" → "Support, link" → "Version, 1.0 (1)". No hints, no third string.

## 10. Backup

- [ ] **m5-export AC-6** — "Export backup…" → the share sheet titled "HomeGymLog backup"; Save to Files → `HomeGymLog-backup-<today>.json`; also try AirDrop and Mail; Cancel the sheet → Settings unchanged.
- [ ] **m5-export AC-7** — "Restore from backup…" → the Files picker (including iCloud Drive); Cancel → unchanged. Pick a non-backup JSON → "Couldn't read this backup" / "This file isn't a HomeGymLog backup."; pick a valid one and Cancel the dialog → nothing changed.
- [ ] **m5-export AC-8** — Pick a valid backup → "Replace everything with this backup?" → "Replace and restore" → a brief "Restoring…" → Home of the restored program with the pill on Home; Progress shows only that program; Settings "Current" matches; units and appearance follow the file (a file saved in lb / System lands dark-or-light by the device and in lb).
- [ ] **m5-export AC-9** — With the reminder on, restore a backup whose training days differ → the next reminder arrives on a day of the restored program, none on the old program's days.

## 11. Rotation

- [ ] **m5-release AC-20** — Rotate the phone during a workout and on the summary → nothing changes (portrait only).

## 12. Light theme

- [ ] **m5-light-theme AC-15** — Device in Dark, app set to Light → every tab, Home's ⓘ sheet, the Program card's ⓘ, the Missed-a-day menu, the restart dialog and the discard alert are light; switch back to System and Dark **while a sheet is open** → the open sheet follows too.
- [ ] **m5-light-theme AC-17** — Outdoors at 100 % brightness in Light: Program "Completed" / "Missed", Progress "+5 lb", the missed-day kicker, the progression pill and the ✓ in the week strip are readable; the greens still read as green and the ambers as amber beside the red buttons.

## Report back

Write "pass" or what you saw next to each failed item (which step, what the screen showed, a screenshot if quick). Anything failed becomes a
fix slice before the App Store submission; the two items with a recorded fallback (Live Activity AC-28 → Step R, Missed day AC-17 →
`.isModal` on the outer root) take that fallback unless you prefer otherwise.

**Could not locate:** CLAUDE.md and INSIGHTS call m5-light-theme AC-17 "VoiceOver", but the spec's AC-17 is the outdoor legibility check
(listed above as written) and that spec has no VoiceOver AC. CLAUDE.md names m4-reminder "AC-8(c) a real rest timer in the background";
the spec's AC-8 has no part (c), so the item above is worded from its rest-coexistence intent. The m5-live-activity spec has no AC for the
expanded Dynamic Island on device (only the simulator's compact-island AC-4); the item above comes from the CLAUDE.md / INSIGHTS note.

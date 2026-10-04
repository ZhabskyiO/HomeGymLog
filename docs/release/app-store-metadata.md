# HomeGymLog — App Store Connect metadata (version 1.0)

Paste-ready text for the App Store Connect record (m5-release spec §2.4). Each field sits in a fenced block whose info
string is the field id; `HomeGymLogTests/Static/StoreMetadataTests.swift` pins the limits (characters are Unicode
scalars; keywords are counted in bytes). Recount after any edit.

| Item | Value |
|---|---|
| Category | Primary **Health & Fitness**; no secondary |
| App Privacy | "Indicate whether you or your third-party partners collect data from your app" → **No, we do not collect data from this app** → label **Data Not Collected** (the shared backup file and local notifications do not change it) |
| Age rating | Health or Wellness Topics → **yes** (the app prescribes exercise programs); every other topic (medical/treatment, violence, sexual content, profanity, horror, gambling, contests, alcohol/tobacco/drugs, UGC, web access, chat, ads, in-app purchases, parental/in-app controls) → no / none. Expected result **9+** |
| Export compliance | Pre-answered by `ITSAppUsesNonExemptEncryption = NO` (`HomeGymLogSupport/Info.plist`); if asked: the app uses no encryption and makes no network connection |
| Support URL | https://zhabskyio.github.io/homegymlog-site/support/ |
| Privacy Policy URL | https://zhabskyio.github.io/homegymlog-site/privacy/ |
| Marketing URL | none |
| What's New | none (1.0) |
| Version / build | 1.0 / 1 (both targets, `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`) |
| Copyright | `2026 <Your Name>` (placeholder, typed in App Store Connect) |

## Name (30)

```name
HomeGymLog
```

## Subtitle (30)

```subtitle
Strength program for home gyms
```

## Promotional text (170)

```promotional-text
Answer five questions and get a phased strength program built around your dumbbells, bench and home gym. Log every set with a swipe and watch your top weights climb.
```

## Keywords (100 bytes, comma-separated, each term 3+ characters)

```keywords
home gym,strength,workout log,dumbbell,training plan,sets,reps,rest timer,progress,personal record
```

## Description (4000)

"Lock Screen", "Dynamic Island", "Live Activities" and "iPhone" are referential uses, allowed in the description only.

```description
HomeGymLog turns five answers into a phased strength program and then logs every set you lift. It is built for one specific home setup: adjustable dumbbells from 5 to 52.5 lb, an adjustable bench and a Marcy MWM-8147 home gym with a 150 lb weight stack. Every exercise, weight and progression in the app fits that equipment.

SET UP IN A MINUTE
Choose how long you want to train (1, 2, 3 or 6 months), how many days a week (3 to 5), your session length and your starting weights. HomeGymLog generates a Foundation, Build, Peak and Deload plan with the sets, reps and weights for every session.

LOG WITHOUT TYPING
Swipe right to log a set at its target, swipe left to adjust the weight or reps. Rate how hard a set felt, swap an exercise for another on the same muscle group, and keep notes per exercise. A rest timer starts after each set, with a notification when rest is over and a countdown on your Lock Screen and in the Dynamic Island with Live Activities.

SEE YOUR PROGRESS
Your top weight per exercise across programs, new personal records, your training streak and a calendar of completed sessions.

LIFE HAPPENS
Missed a day? Shift the program to today or skip the session and stay on schedule. A daily reminder, if you turn it on, tells you when a workout is planned.

YOUR DATA STAYS YOURS
Everything is stored on your iPhone. No account, no sign-in, no ads, no analytics. Export a JSON backup whenever you want and restore it on a new phone.

Free, with light and dark appearance and weights in lb or kg.
```

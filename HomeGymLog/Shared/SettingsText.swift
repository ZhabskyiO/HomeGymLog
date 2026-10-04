import Foundation

/// Every string the Settings tab shows or speaks (spec 4.3). Labels are the visible text, so VoiceOver never needs a
/// second wording; nothing here reads a model or the clock. Equipment values are derived from `EquipmentKind`, never typed,
/// so a change to the rack moves the screen with it.
enum SettingsText {
    static let title = "Settings"
    static let appearance = "Appearance"
    static let units = "Units"
    static let reminder = "Daily reminder"
    static let haptics = "Haptics"
    static let hapticsSubtitle = "Set logged, rest finished, workout done"
    static let sound = "Sound"
    static let soundSubtitle = "Rest finished, daily reminder"
    /// The Live Activity switch (m5-live-activity §2.3); its denied row reuses `ReminderText.openSettings`.
    static let lockScreenTimer = "Lock Screen timer"
    static let lockScreenTimerSubtitle = "Rest countdown as a Live Activity"
    static let lockScreenTimerDenied = "Live Activities are off in iOS Settings"

    static let programSection = "PROGRAM"
    static let current = "Current"
    static let missedDay = "Missed a day"
    /// Ends in a horizontal ellipsis (U+2026), like every "opens a confirmation" label.
    static let restart = "Build a new program…"
    static let restartTitle = "Build a new program?"
    static let restartMessage = "Your current program is archived and stays in Progress. You'll answer the setup questions again."
    static let restartConfirm = "Archive and start over"
    static let cancel = "Cancel"
    static let archiveFailedTitle = "Couldn't archive your program"
    static let archiveFailedMessage = "Your program could not be archived. Please try again."
    static let ok = "OK"

    static let equipmentSection = "EQUIPMENT"
    static let dumbbells = "Dumbbells"
    static let bench = "Bench"
    static let benchDetail = "Flat · incline"
    static let marcy = "Marcy home gym"

    /// The ABOUT card (m5-release §2.7, §5.9): guideline 5.1.1(i)'s in-app privacy-policy link, support, and the version.
    /// The two URLs live here and nowhere else in the app; the same strings are in `docs/release/app-store-metadata.md`.
    static let aboutSection = "ABOUT"
    static let privacyPolicy = "Privacy policy"
    static let support = "Support"
    static let version = "Version"
    static let privacyPolicyURL = URL(string: "https://zhabskyio.github.io/homegymlog-site/privacy/")!
    static let supportURL = URL(string: "https://zhabskyio.github.io/homegymlog-site/support/")!

    /// "1.0 (1)" from the bundle's short version and build; "—" (U+2014) when either is missing or empty. Total.
    static func versionText(short: String?, build: String?) -> String {
        guard let short, !short.isEmpty, let build, !build.isEmpty else { return "\u{2014}" }
        return "\(short) (\(build))"
    }

    /// "6-month program · 5 days" (spec 5.1); frequency is always 3, 4 or 5, so the plural never varies.
    static func currentProgram(months: Int, frequency: Int) -> String {
        "\(ProgramSummaryText.title(months: months)) · \(frequency) days"
    }

    /// The Missed-a-day row's value.
    static func policy(_ policy: MissedDayPolicy) -> String {
        switch policy {
        case .ask: return "Ask me each time"
        case .shift: return "Always shift"
        case .skip: return "Always skip"
        }
    }

    /// "5–52.5 lb" / "2.3–23.8 kg" (an en dash, U+2013), from the dumbbell grid's own bounds.
    static func dumbbellRange(unit: WeightUnit) -> String {
        let low = WeightDisplay.text(lb: EquipmentKind.dumbbell.minLb, unit: unit)
        let high = WeightDisplay.text(lb: EquipmentKind.dumbbell.maxLb, unit: unit)
        return "\(low)–\(high) \(unit.rawValue)"
    }

    /// "150 lb stack" / "68 kg stack": the stack is a whole number in both units.
    static func marcyDetail(unit: WeightUnit) -> String {
        "\(WeightDisplay.wholeText(lb: EquipmentKind.marcy.maxLb, unit: unit)) \(unit.rawValue) stack"
    }
}

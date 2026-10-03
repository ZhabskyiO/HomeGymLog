import SwiftUI

/// Lays out the Settings tab from plain values and the preference bindings (spec 2.1–2.4). Nothing here reads the store,
/// the clock or `UserDefaults`: a tap moves the binding the screen owns.
struct SettingsContent: View {
    /// Immutable fields of the current program, for the Current row.
    let months: Int
    let frequency: Int
    @Binding var appearance: AppearanceMode
    @Binding var units: WeightUnit
    @Binding var policy: MissedDayPolicy
    /// The Daily reminder rows' inputs (m4-reminder spec 2.1): the two preferences, the formatted subtitle, the row state
    /// and the two permission actions.
    @Binding var reminderEnabled: Bool
    @Binding var reminderTime: Date
    let reminderSubtitle: String
    let reminderState: ReminderRowState
    let onAllowNotifications: () -> Void
    let onOpenNotificationSettings: () -> Void
    /// The Haptics and Sound preferences (m5-haptics 2.1).
    @Binding var hapticsEnabled: Bool
    @Binding var soundEnabled: Bool
    let onRestart: () -> Void
    /// The backup card's inputs (m5-export 2.1): the lazily built export file and the restore hand-off to the root.
    let backupFile: BackupFile
    let onRestore: (BackupDocument) -> Void

    /// Room under the last card so it scrolls clear of the floating pill (m5-export: at maximum scroll "Restore from
    /// backup…" sat behind it). The scroll view ends at the bottom safe area while the pill floats above it, so the pill's
    /// height plus a gap leaves a visible gap. Settings only; the other tabs keep their own spacing.
    private static let bottomPadding = FloatingTabBar.height + 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(SettingsText.title)
                .font(.system(size: 28, weight: .bold)).tracking(-0.8).foregroundStyle(Theme.tx)
                .padding(.bottom, 16)
            preferencesCard
            SettingsSectionHeader(title: SettingsText.programSection)
            programCard
            SettingsSectionHeader(title: SettingsText.equipmentSection)
            equipmentCard
            SettingsSectionHeader(title: BackupText.section)
            backupCard
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, Self.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var preferencesCard: some View {
        SettingsCard {
            SettingsControlRow(label: SettingsText.appearance) {
                SegmentedPicker(options: AppearanceMode.allCases.map { (value: $0, label: $0.label) },
                                selection: $appearance, style: .settings)
            }
            SettingsDivider()
            SettingsControlRow(label: SettingsText.units) {
                SegmentedPicker(options: WeightUnit.allCases.map { (value: $0, label: $0.rawValue) },
                                selection: $units, style: .settings)
            }
            SettingsDivider()
            ReminderRows(enabled: $reminderEnabled, time: $reminderTime, subtitle: reminderSubtitle, state: reminderState,
                         onAllow: onAllowNotifications, onOpenSettings: onOpenNotificationSettings)
            SettingsDivider()
            SettingsToggleRow(label: SettingsText.haptics, subtitle: SettingsText.hapticsSubtitle, isOn: $hapticsEnabled)
            SettingsDivider()
            SettingsToggleRow(label: SettingsText.sound, subtitle: SettingsText.soundSubtitle, isOn: $soundEnabled)
        }
    }

    private var programCard: some View {
        SettingsCard {
            SettingsValueRow(label: SettingsText.current,
                             value: SettingsText.currentProgram(months: months, frequency: frequency))
            SettingsDivider()
            SettingsControlRow(label: SettingsText.missedDay) {
                MissedDayPolicyPicker(policy: $policy)
            }
            SettingsDivider()
            Button(action: onRestart) {
                Text(SettingsText.restart)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var backupCard: some View {
        SettingsCard {
            BackupExportRow(file: backupFile)
            SettingsDivider()
            BackupRestoreRow(onRestore: onRestore, preferences: backupFile.preferences)
        }
    }

    private var equipmentCard: some View {
        SettingsCard {
            SettingsValueRow(label: SettingsText.dumbbells, value: SettingsText.dumbbellRange(unit: units))
            SettingsDivider()
            SettingsValueRow(label: SettingsText.bench, value: SettingsText.benchDetail)
            SettingsDivider()
            SettingsValueRow(label: SettingsText.marcy, value: SettingsText.marcyDetail(unit: units))
        }
    }
}

/// "PROGRAM" / "EQUIPMENT" / "BACKUP": 22 pt above, 8 pt below (spec 2).
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold)).tracking(0.4).foregroundStyle(Theme.mu)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }
}

/// An `sf` card with square-cornered rows clipped to radius 16. `@ViewBuilder` ≈ children passed to a container component.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// The 1 pt hairline between rows; never after the last one.
struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(Theme.bd).frame(height: 1)
    }
}

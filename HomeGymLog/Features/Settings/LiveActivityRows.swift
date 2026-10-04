import SwiftUI

/// The Lock Screen timer rows (m5-live-activity spec 2.3): the switch with its two-line label, then, only when the app's
/// Live Activities are off in iOS, a hairline and "Open iOS Settings". Reads no `@AppStorage`, store or clock: the screen
/// passes the binding and the state (≈ a controlled component).
struct LiveActivityRows: View {
    @Binding var enabled: Bool
    let state: LiveActivityRowState
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // The label folds into the switch, so VoiceOver reads "Lock Screen timer, <subtitle>, switch button".
            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SettingsText.lockScreenTimer)
                        .font(.system(size: 15)).foregroundStyle(Theme.tx)
                    Text(subtitle)
                        .font(.system(size: 12)).foregroundStyle(Theme.mu)
                }
            }
            .tint(Theme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            if state == .denied {
                SettingsDivider()
                ReminderActionRow(title: ReminderText.openSettings, action: onOpenSettings)
            }
        }
    }

    private var subtitle: String {
        if state == .denied { return SettingsText.lockScreenTimerDenied }
        return SettingsText.lockScreenTimerSubtitle
    }
}

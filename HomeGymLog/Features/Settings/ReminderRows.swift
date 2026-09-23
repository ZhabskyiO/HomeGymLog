import SwiftUI

/// The Daily reminder rows (spec 2.1): the toggle with its two-line label, then, while it is on, one second row chosen by
/// `state` (the time picker, "Open iOS Settings" or "Allow notifications"). Reads no `@AppStorage`, store or clock: the
/// screen passes the two bindings, the formatted subtitle and the state (≈ a controlled component).
struct ReminderRows: View {
    @Binding var enabled: Bool
    /// The stored minutes as a `Date` today; the screen converts both ways.
    @Binding var time: Date
    let subtitle: String
    let state: ReminderRowState
    let onAllow: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // The two-line label folds into the switch, so VoiceOver reads "Daily reminder, <subtitle>, switch button".
            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SettingsText.reminder)
                        .font(.system(size: 15)).foregroundStyle(Theme.tx)
                    Text(subtitle)
                        .font(.system(size: 12)).foregroundStyle(Theme.mu)
                }
            }
            .tint(Theme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            if state != .off {
                SettingsDivider()
            }
            switch state {
            case .scheduled:
                SettingsControlRow(label: ReminderText.timeLabel) {
                    DatePicker(ReminderText.timeLabel, selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            case .denied:
                ReminderActionRow(title: ReminderText.openSettings, action: onOpenSettings)
            case .unasked:
                ReminderActionRow(title: ReminderText.allow, action: onAllow)
            case .off:
                EmptyView()
            }
        }
    }
}

/// A full-width accent action in the "Build a new program…" style.
private struct ReminderActionRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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

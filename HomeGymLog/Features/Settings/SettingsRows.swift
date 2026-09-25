import SwiftUI

/// A read-only row: label on the left, value on the right (spec 2). One accessibility element with an explicit label and
/// value, so VoiceOver reads "Current, 6-month program · 5 days" as a pair (AC-15).
struct SettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15)).foregroundStyle(Theme.tx)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14)).foregroundStyle(Theme.mu)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

/// A row whose trailing side holds a control. Deliberately **not** one accessibility element: combining would fold the
/// control into the row and break AC-15's order (finding 17).
struct SettingsControlRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15)).foregroundStyle(Theme.tx)
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// A preference switch with a two-line label (m5-haptics 2.1; the `ReminderRows` toggle shape). The label and subtitle sit
/// inside the `Toggle`'s label, so VoiceOver reads one switch: "Haptics, Set logged, rest finished, workout done, switch
/// button, on". `@Binding` ≈ a controlled input's `value` + `onChange` pair passed down as one prop.
struct SettingsToggleRow: View {
    let label: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15)).foregroundStyle(Theme.tx)
                Text(subtitle)
                    .font(.system(size: 12)).foregroundStyle(Theme.mu)
            }
        }
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// The Missed-a-day policy control: a trailing pop-up button showing the current choice (spec 2.2). A `Menu`, not
/// `Picker(.menu)`, because that style ignores `.font` on its label on iOS 17.5 and the value would not match the 14 pt `mu`
/// of every other row (screenshot-verified). The label and value are explicit so VoiceOver reads the row, not just the value.
struct MissedDayPolicyPicker: View {
    @Binding var policy: MissedDayPolicy

    var body: some View {
        Menu {
            // A Picker inside a Menu keeps the system check mark on the current choice.
            Picker(SettingsText.missedDay, selection: $policy) {
                ForEach(MissedDayPolicy.allCases, id: \.self) { option in
                    Text(SettingsText.policy(option)).tag(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(SettingsText.policy(policy))
                    .font(.system(size: 14))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.mu)
        }
        .accessibilityLabel(SettingsText.missedDay)
        .accessibilityValue(SettingsText.policy(policy))
    }
}

import SwiftUI

/// What the Home banner says after an automatic missed-day action, plus a token bumped once per result (spec 2.7). The token
/// drives the announcement and the 3 s timer, so an identical text shown twice still restarts both. Screen state only.
struct MissedDayBanner: Equatable {
    let text: String
    let token: Int
}

/// The one-line banner over Home's content: an accent dot and the text on an `sf` card. One accessibility element, a button
/// labelled by its text (tap = dismiss, no hint). Drawing is all it does; the tap handler comes from the host.
struct MissedActionBanner: View {
    let text: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tx)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sf, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bd, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 15, y: 10)
        }
        .buttonStyle(.plain)
        // The Button is already one element with the button trait; an `.accessibilityElement(children: .ignore)` wrapper
        // here would add a second element with the same label (seen in the scratch-copy XCUITest).
        .accessibilityLabel(text)
    }
}

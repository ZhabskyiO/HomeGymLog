import SwiftUI

/// A full-width secondary button: 50 pt, radius 13, `sf2`, `tx` 15 pt semibold. Serves the missed-session prompt's "Skip it"
/// and the Program card's shift and skip, so they match by construction. The label is the spoken text (no hint).
struct SecondaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.tx)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.sf2, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }
}

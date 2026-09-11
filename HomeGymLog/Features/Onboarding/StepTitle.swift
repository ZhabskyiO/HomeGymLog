import SwiftUI

/// Title and subtitle shared by steps 1–4.
struct StepTitle: View {
    let title: String
    let subtitle: String
    var bottomSpacing: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Theme.tx)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.mu)
        }
        .padding(.top, 26)
        .padding(.bottom, bottomSpacing)
    }
}

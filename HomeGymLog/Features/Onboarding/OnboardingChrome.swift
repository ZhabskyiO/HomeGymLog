import SwiftUI

/// Back button (or an equal spacer on step 0) and the five progress dots.
struct OnboardingHeader: View {
    let step: Int
    let onBack: () -> Void

    var body: some View {
        HStack {
            if step > 0 {
                Button(action: onBack) {
                    Text("‹")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.tx)
                        .frame(width: 36, height: 36)
                        .background(Theme.sf, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { dot in
                    Circle()
                        .fill(step >= dot ? Theme.accent : Theme.sf2)
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .frame(height: 36)
    }
}

/// The pinned CTA over a fade from the background, so content scrolls under it.
struct OnboardingFooter: View {
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 40)
        .background(
            LinearGradient(stops: [.init(color: Theme.bg.opacity(0), location: 0), .init(color: Theme.bg, location: 0.3), .init(color: Theme.bg, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

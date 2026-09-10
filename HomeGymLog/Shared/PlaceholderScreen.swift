import SwiftUI

/// Stand-in content for a tab until its real screen lands.
struct PlaceholderScreen: View {
    let tab: AppTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(tab.label)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.tx)
                Text("Coming in milestone \(tab.placeholderMilestone)")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mu)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    PlaceholderScreen(tab: .home)
}

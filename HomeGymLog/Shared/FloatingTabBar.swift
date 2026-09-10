import SwiftUI

/// The floating pill from the prototype: 64 pt tall, full radius, `sf` fill, hairline border, soft shadow.
/// `@Binding` ≈ receiving `[value, setValue]` from the parent.
struct FloatingTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == selected
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        TabIcon(tab: tab)
                        Text(tab.label)
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? Theme.accent : Theme.mu)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 64)
        .background(Theme.sf)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.bd, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 15, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 26)
    }
}

#Preview {
    struct Host: View {
        @State private var selected: AppTab = .home
        var body: some View {
            VStack { Spacer(); FloatingTabBar(selected: $selected) }
                .background(Theme.bg)
        }
    }
    return Host()
}

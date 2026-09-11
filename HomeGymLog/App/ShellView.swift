import SwiftUI

/// The tab shell (M1's root; the router in RootView shows it once a program exists). `TabView(selection:)` keeps every tab's `NavigationStack` mounted, like tabs that
/// hide panels with display:none instead of unmounting them. The system bar is hidden on every tab
/// and the pill is supplied as a bottom safe-area inset so content scrolls under it.
struct ShellView: View {
    @State private var selected: AppTab = .home   // ≈ useState

    var body: some View {
        TabView(selection: $selected) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    PlaceholderScreen(tab: tab)
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(tab)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selected: $selected)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Theme.bg.ignoresSafeArea())
    }
}

#Preview {
    ShellView()
}

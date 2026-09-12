import SwiftUI
import SwiftData

/// The tab shell. `TabView(selection:)` keeps every tab's `NavigationStack` mounted, like tabs that hide
/// panels with display:none instead of unmounting them. The system bar is hidden on every tab and the pill
/// is supplied as a bottom safe-area inset so content scrolls under it.
struct ShellView: View {
    /// The current program, for its immutable fields only (id, frequency, session length). Screens that
    /// need live rows own their own `@Query`; a view depending on this reference alone never re-renders (iOS 17).
    let program: Program
    @State private var selected: AppTab = .home   // ≈ useState; passed down as a Binding for "Progress ›"
    /// Nil outside a debug launch that asked for a starting tab; no `#if` in the view.
    @Environment(\.initialTab) private var initialTab

    var body: some View {
        TabView(selection: $selected) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    screen(for: tab)
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
        .onAppear { if let initialTab { selected = initialTab } }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(program: program, selectedTab: $selected).id(program.id)   // ≈ key={program.id}: resets @State with the program
        case .program: ProgramView(program: program, selectedTab: $selected).id(program.id)
        default: PlaceholderScreen(tab: tab)
        }
    }
}

#if DEBUG
#Preview {
    let calendar = AppClock.live().calendar
    let container = try! DebugSeed.midProgram.makeContainer(calendar: calendar)
    return ShellView(program: try! ProgramStore.current(in: container.mainContext)!)
        .modelContainer(container)
        .environment(\.appClock, DebugSeed.midProgram.clock(calendar: calendar))
}
#endif

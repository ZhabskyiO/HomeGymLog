import SwiftUI
import SwiftData

/// The tab shell. `TabView(selection:)` keeps every tab's `NavigationStack` mounted, like tabs that hide
/// panels with display:none instead of unmounting them. The system bar is hidden on every tab and the pill
/// is supplied as a bottom safe-area inset so content scrolls under it.
struct ShellView: View {
    /// The current program, for its immutable fields only (id, frequency, session length). Screens that
    /// need live rows own their own `@Query`; a view depending on this reference alone never re-renders (iOS 17).
    let program: Program
    /// Owned by `RootView`, which outlives this view while a workout replaces the shell. `@Binding` ≈ a
    /// `value` + `onChange` prop pair from the parent.
    @Binding var selected: AppTab

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
        // After the inset, so the missed-session scrim also covers the floating bar (inside a tab it would not). The host
        // draws nothing unless the prompt shows. `.id` ≈ key={program.id}: its `now` and silence reset with the program.
        .overlay {
            MissedPromptHost(program: program, selected: selected).id(program.id)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Theme.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(program: program, selectedTab: $selected).id(program.id)   // ≈ key={program.id}: resets @State with the program
        case .program: ProgramView(program: program, selectedTab: $selected).id(program.id)
        case .progress: ProgressTabView(program: program, selectedTab: selected).id(program.id)
        case .settings: SettingsView(program: program, selectedTab: $selected).id(program.id)
        }
    }
}

#if DEBUG
#Preview {
    let calendar = AppClock.live().calendar
    let container = try! DebugSeed.midProgram.makeContainer(calendar: calendar)
    return ShellView(program: try! ProgramStore.current(in: container.mainContext)!, selected: .constant(.home))
        .modelContainer(container)
        .environment(\.appClock, DebugSeed.midProgram.clock(calendar: calendar))
}
#endif

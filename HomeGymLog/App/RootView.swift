import SwiftUI
import SwiftData

/// Routes from live queries, with no navigation: the workout while the current program has an in-progress log,
/// else the shell while a program is current, else onboarding. Saving a start, a discard or a finish flips the
/// route by itself (≈ a live useQuery selector). The root owns the selected tab, so it survives the shell being
/// unmounted while a workout shows (≈ lifting state above a component that unmounts).
struct RootView: View {
    @Query(filter: ProgramStore.currentPredicate) private var currentPrograms: [Program]
    /// The earliest in-progress log of the current program wins; orphan and archived-program logs never match.
    @Query(filter: WorkoutSnapshotBuilder.inProgressPredicate, sort: \WorkoutLog.startedAt) private var activeLogs: [WorkoutLog]
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue
    @State private var selectedTab: AppTab = .home
    /// Set once the debug `initialTab` has been applied, so a later route switch cannot re-apply it.
    @State private var appliedInitialTab = false
    /// Nil outside a debug launch that asked for a starting tab; no `#if` in the view.
    @Environment(\.initialTab) private var initialTab
    @Environment(\.modelContext) private var modelContext
    /// A DEBUG seed's prepared draft, or nil for a real launch.
    let seedDraft: OnboardingDraft?

    var body: some View {
        // if/else, not a ternary: a ternary needs one View type; @ViewBuilder wraps every branch.
        Group {
            if let log = activeLogs.first {
                // Replaces the shell rather than covering it, so a launch into a workout shows no shell frame.
                // `.id` ≈ key={log.id}: a different log gets fresh screen state.
                WorkoutView(log: log, onDone: { finish(log, at: $0) }).id(log.id)
            } else if let program = currentPrograms.first {
                ShellView(program: program, selected: $selectedTab)
            } else {
                OnboardingView(initialDraft: seedDraft ?? OnboardingDraft(units: WeightUnit(rawValue: unitsRaw) ?? .lb))
            }
        }
        .onAppear {
            // A Group applies this to whichever branch appears, so it re-runs on every route switch; the flag makes
            // it run once (≈ a useRef "has run" flag).
            if !appliedInitialTab {
                appliedInitialTab = true
                if let initialTab { selectedTab = initialTab }
            }
        }
    }

    /// Done on the summary: Home first, so the shell never mounts on the old tab for a frame, then the single writer
    /// of completion. A failed save rolled back, so the summary simply stays on screen (never blank in Release).
    private func finish(_ log: WorkoutLog, at end: Date) {
        selectedTab = .home
        do {
            try WorkoutLogStore.finish(log, at: end, in: modelContext)
        } catch {
            assertionFailure("Finish workout failed: \(error)")
        }
    }
}

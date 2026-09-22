import SwiftUI
import SwiftData
// The only UIKit import in the app: the Appearance preference is applied to the scene's windows, because
// `.preferredColorScheme` does not reach alerts and confirmation dialogs on iOS 17.5 (gotchas SwiftUI 2026-09-22).
import UIKit

/// Routes from live queries, with no navigation: the workout while the current program has an in-progress log,
/// else the shell while a program is current, else onboarding. Saving a start, a discard or a finish flips the
/// route by itself (≈ a live useQuery selector). The root owns the selected tab, so it survives the shell being
/// unmounted while a workout shows (≈ lifting state above a component that unmounts).
struct RootView: View {
    @Query(filter: ProgramStore.currentPredicate) private var currentPrograms: [Program]
    /// The earliest in-progress log of the current program wins; orphan and archived-program logs never match.
    @Query(filter: WorkoutSnapshotBuilder.inProgressPredicate, sort: \WorkoutLog.startedAt) private var activeLogs: [WorkoutLog]
    /// Every archived program (one row per restart). Unsorted on purpose: a sort descriptor on the optional `archivedAt` is
    /// unverified on iOS 17.5, so the newest is picked in Swift below (B2).
    @Query(filter: ProgressSnapshotBuilder.archivedProgramPredicate) private var archivedPrograms: [Program]
    @AppStorage("units") private var unitsRaw = WeightUnit.lb.rawValue
    /// The Appearance preference. Read here, below `.defaultAppStorage`, so a seeded launch and an `-appearance` launch
    /// argument reach it (≈ context read below the provider, not above it).
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    /// Onboarding's separate body-weight unit; read here only to rebuild the draft after a restart.
    @AppStorage("bodyWeightUnits") private var bodyWeightUnitsRaw = WeightUnit.lb.rawValue
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
                // No `.id` here: `OnboardingView` copies the draft once with `State(initialValue:)`, so a later root render
                // rebuilds this value and SwiftUI ignores it (≈ useState(initialProp) ignoring later props).
                OnboardingView(initialDraft: seedDraft ?? prefillDraft() ?? OnboardingDraft(units: units))
            }
        }
        .onAppear {
            // A Group applies this to whichever branch appears, so it re-runs on every route switch; the flag makes
            // it run once (≈ a useRef "has run" flag).
            if !appliedInitialTab {
                appliedInitialTab = true
                if let initialTab { selectedTab = initialTab }
            }
            applyAppearance(AppearanceMode.from(raw: appearanceRaw))
        }
        // ≈ useEffect(applyAppearance, [appearance]): the whole window restyles, including sheets, alerts and dialogs.
        .onChange(of: appearanceRaw) { _, raw in
            applyAppearance(AppearanceMode.from(raw: raw))
        }
    }

    private var units: WeightUnit { WeightUnit(rawValue: unitsRaw) ?? .lb }

    /// After "Build a new program…", onboarding opens prefilled from the newest archived program (spec 5.2); nil on a first
    /// run, when nothing has ever been archived. Never a fetch: the rows come from the query above.
    private func prefillDraft() -> OnboardingDraft? {
        guard let newest = archivedPrograms.max(by: { ($0.archivedAt ?? .distantPast) < ($1.archivedAt ?? .distantPast) }) else {
            return nil
        }
        let answers = RestartPrefill.answers(months: newest.months, frequency: newest.frequency,
                                             trainingWeekdays: newest.trainingWeekdays,
                                             sessionLengthMinutes: newest.sessionLengthMinutes,
                                             bodyWeightLb: newest.bodyWeightLb, experience: newest.experience,
                                             startingWeightsLb: newest.startingWeightsLb)
        return OnboardingDraft(answers: answers, units: units,
                               bodyWeightUnit: WeightUnit(rawValue: bodyWeightUnitsRaw) ?? .lb)
    }

    /// Sets the chosen style on every window of every connected scene. Idempotent, so the `Group`'s `onAppear` re-running
    /// on each route switch costs nothing. `.preferredColorScheme` is deliberately not used anywhere in the app.
    private func applyAppearance(_ mode: AppearanceMode) {
        let style = style(for: mode)
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    /// The app's only `UIUserInterfaceStyle`: kept private here so `AppearanceMode` stays UIKit-free (NB7).
    private func style(for mode: AppearanceMode) -> UIUserInterfaceStyle {
        switch mode {
        case .system: return .unspecified
        case .dark: return .dark
        case .light: return .light
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

import SwiftUI
import SwiftData

/// App entry point. Builds the SwiftData container once into a `Result` so a failure to open the store can be
/// shown instead of trapping (debug builds still crash, loudly). A DEBUG `-seed` launch swaps in an in-memory
/// container, a throwaway preferences suite, a frozen clock and a silent rest notifier; everything below the root is identical.
@main
struct HomeGymLogApp: App {
    private let containerResult: Result<ModelContainer, Error>
    private let clock: AppClock
    private let defaults: UserDefaults
    private let seedDraft: OnboardingDraft?
    /// All nil unless a Debug launch argument set them (see `App/DebugSeed/`); always nil in Release.
    private let preselection: ProgramTabPreselection?
    private let initialTab: AppTab?
    private let dragPreview: CGFloat?
    private let sheetPreview: WorkoutSheetPreview?
    /// Nil except a DEBUG `-seed` launch, which silences rest notifications; every other launch keeps the environment's
    /// live default.
    private let restNotifier: RestNotifier?

    init() {
        let live = AppClock.live()   // the only place the real clock is read
        // Plain locals decided first; the seed branch below only exists in Debug builds.
        var makeContainer: () throws -> ModelContainer = { try AppSchema.makeContainer(inMemory: false) }
        var clock = live
        var defaults = UserDefaults.standard
        var seedDraft: OnboardingDraft? = nil
        var preselection: ProgramTabPreselection? = nil
        var initialTab: AppTab? = nil
        var dragPreview: CGFloat? = nil
        var sheetPreview: WorkoutSheetPreview? = nil
        var restNotifier: RestNotifier? = nil
        #if DEBUG
        do {
            if let seed = try DebugSeed.parse(arguments: ProcessInfo.processInfo.arguments) {
                let suite = UserDefaults(suiteName: "seed")!
                suite.removePersistentDomain(forName: "seed")
                defaults = suite
                clock = seed.clock(calendar: live.calendar)
                seedDraft = seed.initialDraft(calendar: live.calendar)
                makeContainer = { try seed.makeContainer(calendar: live.calendar) }
                dragPreview = seed.workoutDragPreview
                sheetPreview = seed.workoutSheetPreview
                restNotifier = .silent()   // seeds freeze the clock: screenshot-only, never a real notification
            }
            // Outside the seed branch: the selection arguments work on their own too.
            preselection = DebugProgramSelection.parse(arguments: ProcessInfo.processInfo.arguments)
            initialTab = DebugInitialTab.parse(arguments: ProcessInfo.processInfo.arguments)
        } catch {
            fatalError("Unknown -seed argument: \(error). Valid: \(DebugSeed.allCases.map(\.rawValue).joined(separator: ", "))")
        }
        #endif
        containerResult = Result(catching: makeContainer)
        self.clock = clock
        self.defaults = defaults
        self.seedDraft = seedDraft
        self.preselection = preselection
        self.initialTab = initialTab
        self.dragPreview = dragPreview
        self.sheetPreview = sheetPreview
        self.restNotifier = restNotifier
        #if DEBUG
        if case .failure(let error) = containerResult {
            fatalError("SwiftData store failed to open: \(error)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case .success(let container):
                RootView(seedDraft: seedDraft)
                    .modelContainer(container)
                    .environment(\.appClock, clock)
                    .defaultAppStorage(defaults)
                    .environment(\.programTabPreselection, preselection)
                    .environment(\.initialTab, initialTab)
                    .environment(\.workoutDragPreview, dragPreview)
                    .environment(\.workoutSheetPreview, sheetPreview)
                    // ≈ a provider that overrides a context value only when a prop is set; otherwise the live default stays.
                    .transformEnvironment(\.restNotifier) { value in
                        if let override = restNotifier { value = override }
                    }
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}

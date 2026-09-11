import SwiftUI
import SwiftData

/// App entry point. Builds the SwiftData container once into a `Result` so a failure to open the store can be
/// shown instead of trapping (debug builds still crash, loudly). A DEBUG `-seed` launch swaps in an in-memory
/// container, a throwaway preferences suite, and a frozen clock; everything below the root is identical.
@main
struct HomeGymLogApp: App {
    private let containerResult: Result<ModelContainer, Error>
    private let clock: AppClock
    private let defaults: UserDefaults
    private let seedDraft: OnboardingDraft?

    init() {
        let live = AppClock.live()   // the only place the real clock is read
        // Plain locals decided first; the seed branch below only exists in Debug builds.
        var makeContainer: () throws -> ModelContainer = { try AppSchema.makeContainer(inMemory: false) }
        var clock = live
        var defaults = UserDefaults.standard
        var seedDraft: OnboardingDraft? = nil
        #if DEBUG
        do {
            if let seed = try DebugSeed.parse(arguments: ProcessInfo.processInfo.arguments) {
                let suite = UserDefaults(suiteName: "seed")!
                suite.removePersistentDomain(forName: "seed")
                defaults = suite
                clock = seed.clock(calendar: live.calendar)
                seedDraft = seed.initialDraft(calendar: live.calendar)
                makeContainer = { try seed.makeContainer(calendar: live.calendar) }
            }
        } catch {
            fatalError("Unknown -seed argument: \(error). Valid: \(DebugSeed.allCases.map(\.rawValue).joined(separator: ", "))")
        }
        #endif
        containerResult = Result(catching: makeContainer)
        self.clock = clock
        self.defaults = defaults
        self.seedDraft = seedDraft
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
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}

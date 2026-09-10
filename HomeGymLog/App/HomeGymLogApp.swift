import SwiftUI
import SwiftData

/// App entry point. The SwiftData container is built once here into a `Result` so a failure to open
/// the store can be shown instead of trapping (debug builds still crash, loudly).
@main
struct HomeGymLogApp: App {
    private let containerResult: Result<ModelContainer, Error>

    init() {
        containerResult = Result { try AppSchema.makeContainer(inMemory: false) }
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
                RootView().modelContainer(container)
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}

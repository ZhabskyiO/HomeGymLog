import Foundation

/// What a Live Activity button asks the app to do.
nonisolated enum RestActivityAction: Sendable {
    case addRest
    case skipRest
}

/// The process-wide handle the two Live Activity intents call. The app installs `handler` in `App.init` (it captures the
/// app's one `ModelContainer`); in the widget extension's process it stays nil, so an intent run there does nothing.
/// React analogy: a module-level callback registry (`let onAction = null`) the root assigns once at startup.
nonisolated enum LiveActivityIntentHooks {
    /// The installed handler; nil until `App.init` runs (and always in the extension).
    @MainActor static var handler: (@MainActor (RestActivityAction) async -> Void)?
    /// The last handler run, so the next one starts only after it finished (serialized runs, spec B1).
    @MainActor static var inFlight: Task<Void, Never>?
}

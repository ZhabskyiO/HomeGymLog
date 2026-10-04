import AppIntents
import Foundation

/// The Live Activity's "+30s" button. The system runs a `LiveActivityIntent` in the app's process (launching it without
/// a scene when needed); `perform()` hops to the main actor, finds the handler the app installed and hands it the action.
/// React analogy: a server action the button posts to; the app owns the real work. Nothing here throws or shows UI.
nonisolated struct AddRestTimeIntent: LiveActivityIntent {
    /// A literal on purpose: the build's App Intents metadata extractor rejects any other initializer ("must be
    /// initialized with a call to its initializer or a string literal"); a test pins it to `RestActivityText.addAccessibility`.
    static let title: LocalizedStringResource = "Add 30 seconds"
    /// Kept out of Shortcuts and Spotlight: the action only makes sense from the activity (spec §9 item 9).
    static var isDiscoverable: Bool { false }

    init() {}

    func perform() async throws -> some IntentResult {
        let handler = await MainActor.run { LiveActivityIntentHooks.handler }
        await handler?(.addRest)
        return .result()
    }
}

/// The Live Activity's "Skip" button; the same shape as `AddRestTimeIntent`.
nonisolated struct SkipRestIntent: LiveActivityIntent {
    /// A literal for the same reason; pinned to `RestActivityText.skipAccessibility` by a test.
    static let title: LocalizedStringResource = "Skip rest"
    static var isDiscoverable: Bool { false }

    init() {}

    func perform() async throws -> some IntentResult {
        let handler = await MainActor.run { LiveActivityIntentHooks.handler }
        await handler?(.skipRest)
        return .result()
    }
}

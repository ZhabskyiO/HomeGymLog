import Foundation

/// The Appearance preference: System / Dark / Light (spec 4.3). Raw strings so `@AppStorage(AppearanceMode.storageKey)`
/// stores the value directly, like `WeightUnit` does for `units`. Deliberately UIKit-free (NB7): the switch to a
/// `UIUserInterfaceStyle` is private to `RootView`, the one file that touches windows. An Engine type since m5-export
/// (B1), so the backup's `ResolvedPreferences` stays pure; its words live in `Shared/AppearanceMode+Label.swift`.
/// Analogy: the string union `'system' | 'dark' | 'light'` kept in localStorage, with the theme applier elsewhere.
nonisolated enum AppearanceMode: String, CaseIterable, Sendable {
    case system, dark, light

    /// The `UserDefaults` key. Typed once here so the literal never appears anywhere else in the app (AC-22).
    static let storageKey = "appearance"

    /// A stored raw value, falling back to `.system` for anything unknown (a hand-edited or future value).
    static func from(raw: String) -> AppearanceMode {
        AppearanceMode(rawValue: raw) ?? .system
    }
}

import Foundation

/// The Appearance preference: System / Dark / Light (spec 4.3). Raw strings so `@AppStorage(AppearanceMode.storageKey)`
/// stores the value directly, like `WeightUnit` does for `units`. Deliberately UIKit-free (NB7): the switch to a
/// `UIUserInterfaceStyle` is private to `RootView`, the one file that touches windows.
/// Analogy: the string union `'system' | 'dark' | 'light'` kept in localStorage, with the theme applier elsewhere.
nonisolated enum AppearanceMode: String, CaseIterable, Sendable {
    case system, dark, light

    /// The `UserDefaults` key. Typed once here so the literal never appears anywhere else in the app (AC-22).
    static let storageKey = "appearance"

    /// The segment label, and the spoken string (AC-15).
    var label: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    /// A stored raw value, falling back to `.system` for anything unknown (a hand-edited or future value).
    static func from(raw: String) -> AppearanceMode {
        AppearanceMode(rawValue: raw) ?? .system
    }
}

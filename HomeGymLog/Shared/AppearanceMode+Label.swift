import Foundation

/// The words for each appearance mode stay in Shared, beside every other `*Text` helper, while the type itself is Engine
/// (m5-export B1). An `extension` adds members to a type declared elsewhere (≈ a module augmentation in TypeScript); its
/// members do not inherit the type's `nonisolated`, so it is spelled here (gotchas Swift 2026-09-23).
extension AppearanceMode {
    /// The segment label, and the spoken string (AC-15).
    nonisolated var label: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}

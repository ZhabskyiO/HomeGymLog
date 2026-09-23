import Foundation

/// The four top-level tabs, in display order.
enum AppTab: String, CaseIterable, Identifiable {
    case home, program, progress, settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Home"
        case .program: return "Program"
        case .progress: return "Progress"
        case .settings: return "Settings"
        }
    }
}

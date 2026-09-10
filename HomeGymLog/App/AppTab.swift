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

    /// Milestone that replaces this tab's placeholder with the real screen.
    var placeholderMilestone: Int {
        switch self {
        case .home, .program: return 2
        case .progress, .settings: return 4
        }
    }
}

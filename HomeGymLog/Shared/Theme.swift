import SwiftUI

/// Design tokens. Every color is an asset-catalog set with light and dark variants, so the whole
/// shell follows the system appearance with no state. No raw hex in views.
enum Theme {
    static let bg = Color("bg")
    static let sf = Color("sf")
    static let sf2 = Color("sf2")
    static let tx = Color("tx")
    static let mu = Color("mu")
    static let bd = Color("bd")
    static let accent = Color("AccentColor")
    static let success = Color("success")
    static let warning = Color("warning")

    static func phaseColor(_ phase: Phase) -> Color {
        switch phase {
        case .foundation: return Color("phaseFoundation")
        case .build: return accent
        case .peak: return warning
        case .deload: return Color("phaseDeload")
        }
    }
}

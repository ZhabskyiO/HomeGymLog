import WidgetKit
import SwiftUI

/// The widget extension's entry point (≈ the root component the OS mounts): one Live Activity, the rest timer. No Home
/// Screen widget (spec §7).
@main
struct HomeGymLogWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestLiveActivity()
    }
}

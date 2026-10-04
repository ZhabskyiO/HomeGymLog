import ActivityKit
import SwiftUI
import WidgetKit

/// The rest timer's Live Activity (spec §2.2): the Lock Screen / banner view and the Dynamic Island. The system calls these
/// closures with the activity's current `ContentState` (≈ a render function the OS calls with serialized props) and
/// counts the timer down by itself, so nothing here reads a clock or needs an update to tick.
struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            RestActivityLockScreenView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color("sf"))
                .activitySystemActionForegroundColor(Color("tx"))
        } dynamicIsland: { context in
            RestActivityIsland.make(context)
        }
    }
}

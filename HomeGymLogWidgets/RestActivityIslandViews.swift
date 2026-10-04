import ActivityKit
import SwiftUI
import WidgetKit

/// The Dynamic Island presentations (spec §2.2). The island is always black, so its text uses fixed light colors, not the
/// themed sets. Compact and minimal hold text and symbols only: a `Button(intent:)` there compiles silently and is not
/// allowed (researcher P5; pinned by a source scan).
enum RestActivityIsland {
    static func make(_ context: ActivityViewContext<RestActivityAttributes>) -> DynamicIsland {
        let state = context.state
        let isStale = context.isStale
        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                if !isStale { RestActivityRing(interval: state.interval) }
            }
            DynamicIslandExpandedRegion(.center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(RestActivityText.title).font(.system(size: 12)).foregroundStyle(.secondary)
                    Text(state.nextText).font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
            }
            DynamicIslandExpandedRegion(.trailing) {
                if isStale {
                    Text(RestActivityText.restOver).font(.headline).foregroundStyle(.white)
                } else {
                    Text(timerInterval: state.interval, pauseTime: nil, countsDown: true, showsHours: false)
                        .font(.title2.bold()).monospacedDigit().foregroundStyle(.white)
                        .frame(width: 70, alignment: .trailing)
                }
            }
            DynamicIslandExpandedRegion(.bottom) {
                if !isStale { RestActivityButtons(vertical: false) }
            }
        } compactLeading: {
            Image(systemName: "timer").foregroundStyle(Color("AccentColor"))
        } compactTrailing: {
            if isStale {
                Image(systemName: "checkmark").foregroundStyle(Color("AccentColor"))
            } else {
                Text(timerInterval: state.interval, pauseTime: nil, countsDown: true, showsHours: false)
                    .monospacedDigit().multilineTextAlignment(.trailing).foregroundStyle(.white)
                    .frame(width: 48)
            }
        } minimal: {
            Image(systemName: "timer").foregroundStyle(Color("AccentColor"))
        }
        .keylineTint(Color("AccentColor"))
    }
}

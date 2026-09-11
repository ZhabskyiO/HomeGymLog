import SwiftUI

/// Date, greeting, and the "Week N · Phase" pill.
struct HomeHeader: View {
    let dateLabel: String
    let greeting: String
    let week: CurrentWeek?

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel).font(.system(size: 13)).foregroundStyle(Theme.mu)
                Text(greeting).font(.system(size: 28, weight: .bold)).tracking(-0.8).foregroundStyle(Theme.tx)
            }
            Spacer()
            if let week {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.phaseColor(week.phase)).frame(width: 8, height: 8)
                    Text(HomeText.weekPill(week)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.tx)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.sf, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .padding(.top, 8)
    }
}

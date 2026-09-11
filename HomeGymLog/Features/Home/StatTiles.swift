import SwiftUI

/// Streak, sessions, and week volume. Three equal columns via maxWidth: .infinity (never containerRelativeFrame).
struct StatTiles: View {
    let streak: Int
    let completed: Int
    let total: Int
    let volumeText: String
    let volumeCaption: String

    var body: some View {
        HStack(spacing: 8) {
            StatTile(value: "\(streak)", caption: "day streak")
            StatTile(value: "\(completed)", suffix: "/\(total)", caption: "sessions")
            StatTile(value: volumeText, caption: volumeCaption)
        }
    }
}

struct StatTile: View {
    let value: String
    var suffix: String? = nil
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text(value).font(.system(size: 26, weight: .bold))
             + Text(suffix ?? "").font(.system(size: 14, weight: .medium)).foregroundColor(Theme.mu))
                .tracking(-0.5)
                .foregroundStyle(Theme.tx)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(caption).font(.system(size: 11.5)).foregroundStyle(Theme.mu)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 14))
    }
}

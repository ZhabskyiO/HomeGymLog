import SwiftUI

/// Shown when nothing is scheduled today (or today's session is done): points at the next session.
struct RestDayCard: View {
    let next: SessionSummary
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("REST DAY").font(.system(size: 12, weight: .bold)).tracking(0.5).foregroundStyle(Theme.mu)
            Text("Recover. Next up: \(next.name)").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.tx)
            Text("\(HomeText.dayLabel(next.scheduledDate, calendar: calendar)) · \(HomeText.sessionMeta(exercises: next.exercises.count, sets: next.sets, reps: next.reps, minutes: nil))")
                .font(.system(size: 13)).foregroundStyle(Theme.mu)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 18))
    }
}

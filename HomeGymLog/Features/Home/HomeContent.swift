import SwiftUI

/// Lays out the Home tab from already-mapped values. Everything derived is computed once per render.
struct HomeContent: View {
    let input: HomeStatsInput
    let today: Date
    let unit: WeightUnit
    let calendar: Calendar
    let sessionLengthMinutes: Int
    let onProgress: () -> Void
    let onInfo: (Exercise) -> Void
    /// Receives today's session index; the screen that owns the rows starts it.
    let onStart: (Int) -> Void

    var body: some View {
        let sessions = input.sessions
        let greeting = HomeStats.greeting(hour: calendar.component(.hour, from: today))
        let week = HomeStats.currentWeek(sessions: sessions, today: today, calendar: calendar)
        let streak = HomeStats.streak(sessions: sessions, today: today, calendar: calendar)
        let completed = HomeStats.completedCount(sessions: sessions)
        let volume = HomeStats.weekVolumeLb(sessions: sessions, logs: input.logs, today: today, calendar: calendar)
        let strip = HomeStats.weekStrip(sessions: sessions, today: today, calendar: calendar)
        let todaySession = HomeStats.todaySession(sessions: sessions, today: today, calendar: calendar)
        let next = HomeStats.nextSession(sessions: sessions, today: today, calendar: calendar)
        let records = HomeStats.recentRecords(sessions: sessions, logs: input.logs)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HomeHeader(dateLabel: HomeText.dayLabel(today, calendar: calendar), greeting: HomeText.greeting(greeting), week: week)
                StatTiles(streak: streak, completed: completed, total: sessions.count,
                          volumeText: VolumeText.weekVolume(lb: volume, unit: unit), volumeCaption: VolumeText.caption(unit: unit))
                    .padding(.top, 18)
                WeekStrip(days: strip, letters: HomeText.weekStripLetters(calendar: calendar))
                    .padding(.top, 18)
                if let todaySession {
                    TodayCard(session: todaySession, sessionLengthMinutes: sessionLengthMinutes, unit: unit, onInfo: onInfo,
                              onStart: { onStart(todaySession.index) })
                        .padding(.top, 20)
                } else if let next {
                    RestDayCard(next: next, calendar: calendar)
                        .padding(.top, 20)
                }
                if !records.isEmpty {
                    RecentRecords(records: records, unit: unit, calendar: calendar, onProgress: onProgress)
                        .padding(.top, 18)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

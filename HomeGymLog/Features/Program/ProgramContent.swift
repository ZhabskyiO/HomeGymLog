import SwiftUI

/// Lays out the Program tab from already-mapped values. Every derived value is computed once per render.
/// The screen writes nothing; taps only report a new selection upward.
struct ProgramContent: View {
    let summaries: [SessionSummary]
    let selection: ProgramSelection
    let today: Date
    let unit: WeightUnit
    let calendar: Calendar
    let months: Int
    let frequency: Int
    let scrollToken: Int
    let onSelectWeek: (Int) -> Void
    let onSelectDay: (Int, Int) -> Void
    let onInfo: (Exercise) -> Void

    var body: some View {
        let chips = ProgramTabStats.weekChips(sessions: summaries, calendar: calendar)
        let focus = ProgramTabStats.focus(selection: selection, sessions: summaries, today: today, calendar: calendar)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Program")
                    .font(.system(size: 28, weight: .bold)).tracking(-0.8).foregroundStyle(Theme.tx)
                Text(ProgramTabText.subtitle(months: months, splitName: SplitPlans.info(frequency: frequency)?.name ?? ""))
                    .font(.system(size: 13)).foregroundStyle(Theme.mu)
                    .padding(.top, 2)
                if let focus {
                    week(focus, chips: chips)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func week(_ focus: ProgramFocus, chips: [WeekChip]) -> some View {
        let cells = ProgramTabStats.dayCells(sessions: summaries, week: focus.week, calendar: calendar)
        let selected = cells.indices.contains(focus.day) ? cells[focus.day] : nil

        WeekChipRow(chips: chips, selectedWeek: focus.week, scrollToken: scrollToken, onSelect: onSelectWeek)
            .padding(.horizontal, -18)   // bleed to the screen edges; the row re-adds the 18 pt inset itself
            .padding(.top, 18)
        if let phase = chips.first(where: { $0.week == focus.week })?.phase {
            PhaseLine(phase: phase).padding(.top, 14)
        }
        ProgramDayRow(cells: cells, letters: HomeText.weekStripLetters(calendar: calendar), selectedDay: focus.day,
                      onSelect: { onSelectDay(focus.week, $0) })
            .padding(.top, 12)
        if let session = selected?.session {
            SessionCard(session: session, state: HomeStats.sessionState(session, today: today, calendar: calendar),
                        unit: unit, calendar: calendar, onInfo: onInfo)
                .padding(.top, 16)
        } else {
            RestCard().padding(.top, 16)
        }
    }
}

/// The selected week's phase: a colour swatch, the phase name, and its set × rep scheme.
struct PhaseLine: View {
    let phase: Phase

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.phaseColor(phase)).frame(width: 8, height: 8)
            Text(phase.rawValue).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tx)
            Text("· \(ProgramTabText.phaseScheme(phase))").font(.system(size: 13)).foregroundStyle(Theme.mu)
        }
    }
}

/// Shown when the selected day holds no session.
struct RestCard: View {
    var body: some View {
        Text(ProgramTabText.restDay)
            .font(.system(size: 14)).foregroundStyle(Theme.mu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
    }
}

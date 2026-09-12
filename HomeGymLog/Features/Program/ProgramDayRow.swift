import SwiftUI

/// The selected week's seven days, Monday first. No "today" marker exists here (the prototype has none);
/// "Today" only appears as the card's status.
struct ProgramDayRow: View {
    let cells: [ProgramDayCell]
    let letters: [String]
    let selectedDay: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Button { onSelect(index) } label: {
                    dayLabel(cell, index: index)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayLabel(_ cell: ProgramDayCell, index: Int) -> some View {
        let isSelected = index == selectedDay
        return VStack(spacing: 6) {
            Text(letters.indices.contains(index) ? letters[index] : "")
                .font(.system(size: 11, weight: .semibold))
            Text("\(cell.dayNumber)")
                .font(.system(size: 15, weight: .bold)).monospacedDigit()
            Circle().fill(dotColor(cell, isSelected: isSelected)).frame(width: 6, height: 6)
        }
        .foregroundStyle(isSelected ? Color.white : Theme.tx)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isSelected ? Theme.accent : Theme.sf, in: RoundedRectangle(cornerRadius: 12))
    }

    /// A completed session keeps its green dot even when selected; any other session is white on the accent
    /// fill and muted otherwise; a rest day has no dot.
    private func dotColor(_ cell: ProgramDayCell, isSelected: Bool) -> Color {
        guard let session = cell.session else { return .clear }
        if session.status == .completed { return Theme.success }
        return isSelected ? .white : Theme.mu
    }
}

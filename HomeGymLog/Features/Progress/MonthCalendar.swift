import SwiftUI

/// The calendar card for the month containing today (spec 2.3, 5.5): title and completed count, Monday-first letters, then
/// leading blanks and one square per day. `LazyVGrid` with seven flexible columns ≈ CSS `grid-template-columns: repeat(7,
/// 1fr)`; `.aspectRatio(1)` ≈ `aspect-ratio: 1`. A cell is one accessibility element (day number + state), never a control.
struct MonthCalendar: View {
    let month: ProgressMonth
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(ProgressText.monthTitle(year: month.year, month: month.month, calendar: calendar))
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.tx)
                Spacer()
                Text(ProgressText.completed(n: month.completedCount))
                    .font(.system(size: 12)).foregroundStyle(Theme.mu)
            }
            HStack(spacing: 4) {
                ForEach(Array(HomeText.weekStripLetters(calendar: calendar).enumerated()), id: \.offset) { _, letter in
                    Text(letter).font(.system(size: 10.5)).foregroundStyle(Theme.mu).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            .padding(.top, 12)
            LazyVGrid(columns: columns, spacing: 4) {
                // Negative ids so a blank never shares an id with a day number.
                ForEach(-month.leadingBlanks..<0, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
                }
                ForEach(month.cells, id: \.dayNumber) { cell in
                    MonthDayCell(cell: cell)
                }
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// One day square: fill, number colour and border by state (plan §2 cell style; missed `warning` and skipped `mu` deviate
/// from the prototype's `tx`, decision D3).
private struct MonthDayCell: View {
    let cell: ProgressDayCell

    var body: some View {
        Text("\(cell.dayNumber)")
            .font(.system(size: 12, weight: cell.isToday ? .bold : .medium))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(fill, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(cell.isToday ? Theme.accent : .clear, lineWidth: 1.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(cell.dayNumber)")
            .accessibilityValue(ProgressText.cellValue(state: cell.state) ?? "")
    }

    private var fill: Color {
        switch cell.state {
        case .completed: return Theme.success
        case .rest: return .clear
        case .today, .scheduled, .missed, .skipped: return Theme.sf2
        }
    }

    private var textColor: Color {
        if cell.state == .completed { return .white }
        if cell.isToday { return Theme.accent }
        switch cell.state {
        case .missed: return Theme.warning
        case .skipped, .rest: return Theme.mu
        case .scheduled, .today, .completed: return Theme.tx
        }
    }
}

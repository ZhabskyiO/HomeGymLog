import SwiftUI

/// Monday–Sunday of the current calendar week: a letter over a 28 pt circle per day.
struct WeekStrip: View {
    let days: [WeekStripDay]
    let letters: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 6) {
                    Text(letters.indices.contains(index) ? letters[index] : "")
                        .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? Theme.tx : Theme.mu)
                    ZStack {
                        Circle().fill(fill(day))
                        Circle().strokeBorder(border(day), lineWidth: 1.5)
                        Text(mark(day)).font(.system(size: 11, weight: .bold)).foregroundStyle(markColor(day))
                    }
                    .frame(width: 28, height: 28)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func mark(_ day: WeekStripDay) -> String {
        switch day.state {
        case .completed: return "✓"
        case .rest: return "·"
        default: return "\(day.dayNumber)"
        }
    }

    private func fill(_ day: WeekStripDay) -> Color {
        switch day.state {
        case .completed: return Theme.success
        case .rest: return .clear
        default: return Theme.sf
        }
    }

    private func border(_ day: WeekStripDay) -> Color {
        day.isToday ? Theme.accent : .clear
    }

    private func markColor(_ day: WeekStripDay) -> Color {
        switch day.state {
        case .completed: return .white
        case .today: return Theme.accent
        case .missed: return Theme.warning
        case .scheduled, .skipped: return Theme.mu
        case .rest: return day.isToday ? Theme.accent : Theme.sf2
        }
    }
}

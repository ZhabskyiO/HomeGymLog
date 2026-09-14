import SwiftUI

/// One set of the displayed exercise (spec 2.3): mark circle, weight × reps, and the right-hand label. The active row
/// has the accent border; rows after the focus set are drawn at 45 %.
struct SetRow: View {
    let number: Int
    let set: WorkoutSetValue
    let row: SetRowState
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            SetMark(number: number, kind: row.kind)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(WeightDisplay.text(lb: set.weightLb, unit: unit))
                    .font(.system(size: 22, weight: .bold)).monospacedDigit().foregroundStyle(Theme.tx)
                    .fixedSize(horizontal: true, vertical: false)
                Text(unit.rawValue).font(.system(size: 12)).foregroundStyle(Theme.mu)
                Text("×").font(.system(size: 14)).foregroundStyle(Theme.mu).padding(.horizontal, 4)
                Text("\(set.reps)")
                    .font(.system(size: 22, weight: .bold)).monospacedDigit().foregroundStyle(Theme.tx)
                    .fixedSize(horizontal: true, vertical: false)
                Text("reps").font(.system(size: 12)).foregroundStyle(Theme.mu)
            }
            Spacer(minLength: 8)
            Text(WorkoutText.rowLabel(row.kind))
                .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.mu)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(row.kind == .active ? Theme.accent : Color.clear, lineWidth: 1.5))
        .opacity(row.dimmed ? 0.45 : 1)
    }
}

/// The 26 pt circle: ✓ on `success` (done), – on `sf2` (skipped), the set number on accent (active) or `sf2` (waiting).
private struct SetMark: View {
    let number: Int
    let kind: SetRowKind

    var body: some View {
        Text(symbol)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: 26, height: 26)
            .background(fill, in: Circle())
    }

    private var symbol: String {
        switch kind {
        case .done: return "✓"
        case .skipped: return "–"
        case .active, .waiting: return "\(number)"
        }
    }

    private var fill: Color {
        switch kind {
        case .done: return Theme.success
        case .active: return Theme.accent
        case .skipped, .waiting: return Theme.sf2
        }
    }

    private var foreground: Color {
        switch kind {
        case .done, .active: return Color.white
        case .skipped, .waiting: return Theme.mu
        }
    }
}

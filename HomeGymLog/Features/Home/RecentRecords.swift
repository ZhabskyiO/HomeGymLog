import SwiftUI

/// Up to four most recent personal records, with a link to the Progress tab.
struct RecentRecords: View {
    let records: [PersonalRecord]
    let unit: WeightUnit
    let calendar: Calendar
    let onProgress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent records").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.tx)
                Spacer()
                Button(action: onProgress) {
                    Text("Progress ›").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: 8) {   // at most four (HomeStats.recentRecords), equal widths
                ForEach(records, id: \.exerciseKey) { record in
                    PRCard(record: record, unit: unit, calendar: calendar)
                }
            }
        }
    }
}

struct PRCard: View {
    let record: PersonalRecord
    let unit: WeightUnit
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text(WeightDisplay.text(lb: record.weightLb, unit: unit)).font(.system(size: 17, weight: .bold))
             + Text(" \(unit.rawValue)").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.mu))
                .foregroundStyle(Theme.tx)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(ExerciseLibrary.exercise(for: record.exerciseKey)?.name ?? record.exerciseKey)
                .font(.system(size: 11)).lineLimit(3).foregroundStyle(Theme.tx).padding(.top, 2)
            Text(HomeText.shortDate(record.date, calendar: calendar)).font(.system(size: 10.5)).foregroundStyle(Theme.mu).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 12))
    }
}

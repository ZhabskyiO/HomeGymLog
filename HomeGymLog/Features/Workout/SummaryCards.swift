import SwiftUI

/// Volume and duration, two equal tiles.
struct SummaryTiles: View {
    let volume: String
    let volumeCaption: String
    let duration: String

    var body: some View {
        HStack(spacing: 8) {
            SummaryTile(value: volume, caption: volumeCaption)
            SummaryTile(value: duration, caption: "duration")
        }
    }
}

private struct SummaryTile: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .bold)).tracking(-1).monospacedDigit().foregroundStyle(Theme.tx)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(.system(size: 12)).foregroundStyle(Theme.mu)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// "Muscles worked" with one wrapping chip per muscle, in exercise order. With no done set it shows only the title.
struct MusclesCard: View {
    let muscles: [MuscleGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Muscles worked").font(.system(size: 13)).foregroundStyle(Theme.mu)
            if !muscles.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(muscles, id: \.self) { muscle in
                        Text(muscle.rawValue)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tx)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Theme.sf2, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// "PERSONAL RECORDS": one row per record, the name left and "prev → **new**" right, on an accent gradient.
struct RecordsCard: View {
    let records: [SummaryRecord]
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERSONAL RECORDS")
                .font(.system(size: 12, weight: .bold)).tracking(0.6).foregroundStyle(Theme.accent)
            ForEach(records, id: \.exerciseKey) { record in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(WorkoutText.exerciseName(key: record.exerciseKey))
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tx)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    (Text("\(WorkoutText.recordPrevious(record.previousBestLb, unit: unit)) → ")
                        + Text(WorkoutText.recordNew(record.weightLb, unit: unit)).fontWeight(.bold))
                        .font(.system(size: 14)).monospacedDigit().foregroundStyle(Theme.tx)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0.08)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1.5))
    }
}

/// Shown when the workout set no record.
struct NoRecordsCard: View {
    var body: some View {
        Text(WorkoutText.noRecords)
            .font(.system(size: 13)).foregroundStyle(Theme.mu)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
    }
}

import SwiftUI

/// A6: the generated program preview held on the draft.
struct GeneratedProgramStep: View {
    let summary: ProgramSummary
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR PROGRAM")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.accent)
                .padding(.top, 26)
                .padding(.bottom, 4)
            Text(ProgramSummaryText.title(months: summary.months))
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Theme.tx)
                .padding(.bottom, 18)
            VStack(alignment: .leading, spacing: 0) {
                PhaseBar(ranges: summary.phases, height: 8)
                    .padding(.bottom, 12)
                VStack(spacing: 8) {
                    ForEach(summary.phases, id: \.firstWeek) { range in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.phaseColor(range.phase)).frame(width: 8, height: 8)
                            Text(range.phase.rawValue).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.tx)
                            Spacer()
                            Text(ProgramSummaryText.weekRange(range)).font(.system(size: 13.5)).foregroundStyle(Theme.mu)
                            Text(ProgramSummaryText.scheme(range.phase)).font(.system(size: 13.5)).foregroundStyle(Theme.mu)
                                .frame(minWidth: 64, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(16)
            .background(Theme.sf, in: RoundedRectangle(cornerRadius: 16))
            HStack(alignment: .top, spacing: 8) {
                tile(value: "\(summary.totalSessions)", suffix: nil, label: "sessions")
                tile(value: "\(summary.frequency)", suffix: "/wk", label: summary.splitName)
                tile(value: "\(summary.sessionLengthMinutes)", suffix: " min", label: "per session")
            }
            .padding(.top, 10)
            .fixedSize(horizontal: false, vertical: true)
            (Text("First session · ").foregroundColor(Theme.mu)
             + Text(ProgramSummaryText.firstSession(summary, calendar: calendar)).foregroundColor(Theme.tx).fontWeight(.semibold))
                .font(.system(size: 13))
                .padding(.top, 16)
        }
    }

    private func tile(value: String, suffix: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text(value).font(.system(size: 20, weight: .bold))
             + Text(suffix ?? "").font(.system(size: 13, weight: .medium)))
                .foregroundStyle(Theme.tx)
            Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.mu).lineLimit(2).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Theme.sf, in: RoundedRectangle(cornerRadius: 12))
    }
}

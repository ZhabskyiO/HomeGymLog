import SwiftUI

/// The horizontally scrolling week chips. Bleeds to both screen edges; the selected chip is outlined in the
/// accent and scrolled **minimally** into view on every appear (`anchor: nil` moves the row only as far as it
/// must, so a chip already on screen never shifts). Analogy: `scrollIntoView({ block: "nearest" })`.
struct WeekChipRow: View {
    let chips: [WeekChip]
    let selectedWeek: Int
    /// Bumped by the screen's appear-reset; changing it re-runs the scroll even when the week is unchanged.
    let scrollToken: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chips, id: \.week) { chip in
                        chipButton(chip).id(chip.week)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            }
            .onAppear { scrollToSelected(proxy) }
            .onChange(of: scrollToken) { _, _ in scrollToSelected(proxy) }
        }
    }

    /// Deferred by one main-actor turn: on iOS 17 a `scrollTo` inside `onAppear` runs before the row has been
    /// laid out, and then "minimal" is measured against a viewport that does not exist yet — the row jumps
    /// even when the selected chip was already fully visible.
    private func scrollToSelected(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            proxy.scrollTo(selectedWeek, anchor: nil)
        }
    }

    private func chipButton(_ chip: WeekChip) -> some View {
        Button { onSelect(chip.week) } label: {
            VStack(spacing: 6) {
                Text(ProgramTabText.weekChipCaption)
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.mu)
                Text("\(chip.week)")
                    .font(.system(size: 17, weight: .bold)).monospacedDigit().foregroundStyle(Theme.tx)
                // A window with no session draws no bar; the space is kept so every chip is the same height.
                RoundedRectangle(cornerRadius: 2)
                    .fill(chip.phase.map { Theme.phaseColor($0) } ?? .clear)
                    .frame(width: 26, height: 3)
            }
            .frame(width: 58)
            .padding(.top, 9)
            .padding(.bottom, 8)
            .background(Theme.sf, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(chip.week == selectedWeek ? Theme.accent : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week \(chip.week)")
    }
}

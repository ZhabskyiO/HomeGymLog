import SwiftUI

/// The horizontally scrolling exercise chips (`WeekChipRow`'s shape). Bleeds to both screen edges; the selected chip is
/// filled with the accent and scrolled **minimally** into view on appear (`anchor: nil` ≈ `scrollIntoView({ inline:
/// "nearest" })`), so a chip already on screen never moves. Not the iOS 17 scroll-position binding: on iOS 17.5 it jumps a
/// visible chip to the leading edge (gotchas SwiftUI 2026-09-16).
struct ExerciseChipRow: View {
    let keys: [String]
    let selectedKey: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(keys, id: \.self) { key in
                        chip(key).id(key)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
            }
            .onAppear {
                // Deferred one main-actor turn: on iOS 17 a scroll inside onAppear runs before layout (gotchas SwiftUI 2026-09-11).
                Task { @MainActor in
                    if let selectedKey { proxy.scrollTo(selectedKey, anchor: nil) }
                }
            }
        }
    }

    private func chip(_ key: String) -> some View {
        let selected = key == selectedKey
        return Button { onSelect(key) } label: {
            Text(ProgressText.chipLabel(key: key))
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(selected ? Color.white : Theme.tx)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selected ? Theme.accent : Theme.sf, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

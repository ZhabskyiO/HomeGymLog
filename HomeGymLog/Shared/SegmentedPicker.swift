import SwiftUI

/// The prototype's three segmented controls. `selection` is a Binding ≈ value + setter passed from the parent.
struct SegmentedPicker<T: Hashable>: View {
    enum Style {
        /// A1 units / small: 3 pt inset on `sf`, selected accent, others transparent with `mu` text.
        case pill
        /// A3 frequency: 4 pt inset on `sf`, tall equal-width segments.
        case wide
        /// A4 experience and length: equal-width `sf2` chips with `tx` text, selected accent.
        case chip
    }

    let options: [(value: T, label: String)]
    @Binding var selection: T
    var style: Style = .pill
    /// Container color override, e.g. `Theme.sf2` when the picker sits on an `sf` card.
    var container: Color? = nil

    var body: some View {
        HStack(spacing: style == .pill ? 3 : 6) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: labelSize, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : unselectedText)
                        .padding(.horizontal, style == .pill ? 16 : 0)
                        .padding(.vertical, verticalPadding)
                        .frame(maxWidth: style == .pill ? nil : .infinity)
                        .background(isSelected ? Theme.accent : unselectedBackground, in: RoundedRectangle(cornerRadius: segmentRadius))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(style == .chip ? 0 : (style == .pill ? 3 : 4))
        .background(container ?? (style == .chip ? Color.clear : Theme.sf), in: RoundedRectangle(cornerRadius: style == .pill ? 10 : 14))
    }

    private var labelSize: CGFloat { style == .wide ? 15 : 13 }
    private var verticalPadding: CGFloat { style == .pill ? 7 : (style == .wide ? 11 : 10) }
    private var segmentRadius: CGFloat { style == .pill ? 8 : (style == .wide ? 10 : 9) }
    private var unselectedText: Color { style == .chip ? Theme.tx : Theme.mu }
    private var unselectedBackground: Color { style == .chip ? Theme.sf2 : Color.clear }
}

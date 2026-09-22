import SwiftUI

/// The prototype's four segmented controls. `selection` is a Binding ≈ value + setter passed from the parent.
struct SegmentedPicker<T: Hashable>: View {
    enum Style {
        /// A1 units / small: 3 pt inset on `sf`, selected accent, others transparent with `mu` text.
        case pill
        /// A3 frequency: 4 pt inset on `sf`, tall equal-width segments.
        case wide
        /// A4 experience and length: equal-width `sf2` chips with `tx` text, selected accent.
        case chip
        /// Settings rows (Appearance, Units): a compact `sf2` container whose selected segment is an `sf` card with `tx`
        /// text, never accent, and whose segments hug their labels so the control sits beside a row label.
        case settings
    }

    let options: [(value: T, label: String)]
    @Binding var selection: T
    var style: Style = .pill
    /// Container color override, e.g. `Theme.sf2` when the picker sits on an `sf` card.
    var container: Color? = nil

    var body: some View {
        HStack(spacing: segmentSpacing) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: labelSize, weight: .semibold))
                        .foregroundStyle(isSelected ? selectedText : unselectedText)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .frame(maxWidth: isEqualWidth ? .infinity : nil)
                        .background(isSelected ? selectedBackground : unselectedBackground,
                                    in: RoundedRectangle(cornerRadius: segmentRadius))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(containerPadding)
        .background(container ?? containerBackground, in: RoundedRectangle(cornerRadius: containerRadius))
    }

    private var segmentSpacing: CGFloat {
        switch style {
        case .pill, .settings: return 3
        case .wide, .chip: return 6
        }
    }

    private var labelSize: CGFloat {
        switch style {
        case .wide: return 15
        case .settings: return 12.5
        case .pill, .chip: return 13
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .pill: return 16
        case .settings: return 12
        case .wide, .chip: return 0
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .pill: return 7
        case .wide: return 11
        case .chip: return 10
        case .settings: return 5
        }
    }

    private var segmentRadius: CGFloat {
        switch style {
        case .pill: return 8
        case .wide: return 10
        case .chip: return 9
        case .settings: return 7
        }
    }

    /// `.pill` and `.settings` segments hug their labels; the other two split the row evenly.
    private var isEqualWidth: Bool {
        switch style {
        case .pill, .settings: return false
        case .wide, .chip: return true
        }
    }

    private var selectedText: Color {
        style == .settings ? Theme.tx : Color.white
    }

    private var selectedBackground: Color {
        style == .settings ? Theme.sf : Theme.accent
    }

    private var unselectedText: Color { style == .chip ? Theme.tx : Theme.mu }

    private var unselectedBackground: Color { style == .chip ? Theme.sf2 : Color.clear }

    private var containerPadding: CGFloat {
        switch style {
        case .chip: return 0
        case .pill, .settings: return 3
        case .wide: return 4
        }
    }

    private var containerRadius: CGFloat {
        switch style {
        case .pill: return 10
        case .settings: return 9
        case .wide, .chip: return 14
        }
    }

    private var containerBackground: Color {
        switch style {
        case .chip: return Color.clear
        case .settings: return Theme.sf2
        case .pill, .wide: return Theme.sf
        }
    }
}

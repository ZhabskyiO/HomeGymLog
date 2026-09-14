import SwiftUI

/// Round − / + button, as in the prototype's steppers: `sf2` by default, `sf` on the adjust sheet's `sf2` tiles.
struct StepperButton: View {
    let symbol: String
    var size: CGFloat = 34
    /// Declared before `action`: the memberwise init follows declaration order, so
    /// `StepperButton(symbol:size:fill:) { … }` compiles with the trailing closure.
    var fill: Color = Theme.sf2
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: size > 32 ? 18 : 17))
                .foregroundStyle(Theme.tx)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "+" ? "Increase" : "Decrease")
    }
}

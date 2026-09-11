import SwiftUI

/// Round − / + button on `sf2`, as in the prototype's steppers.
struct StepperButton: View {
    let symbol: String
    var size: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: size > 32 ? 18 : 17))
                .foregroundStyle(Theme.tx)
                .frame(width: size, height: size)
                .background(Theme.sf2, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "+" ? "Increase" : "Decrease")
    }
}

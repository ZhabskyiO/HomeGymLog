import SwiftUI

/// "Start workout": 50 pt, radius 13, accent, 16 pt bold white. Shared by Home's Today card and the Program card so
/// both look identical by construction; the caller reports the tap up to the screen that owns the session query.
struct StartWorkoutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Start workout")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }
}

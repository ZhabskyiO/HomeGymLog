import SwiftUI

/// Shown in release builds when the on-disk store cannot be opened. Copy and recovery come in M4.
struct StoreErrorView: View {
    let error: Error

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Couldn't open your data")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.tx)
            Text(error.localizedDescription)
                .font(.system(size: 15))
                .foregroundStyle(Theme.mu)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
    }
}

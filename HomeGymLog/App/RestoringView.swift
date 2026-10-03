import SwiftUI

/// The root's backup-restore state (m5-export spec 2.4), one enum so a stale flag can never sit beside a stale document
/// (≈ a discriminated union in `useState`). `restoring` carries the validated document until the save runs; `failed`
/// carries the alert's message over the shell.
enum RootRestoreState {
    case idle
    case restoring(BackupDocument)
    case failed(String)

    /// True while the routes must give way to `RestoringView`: no shell, workout or onboarding holds a row being replaced.
    var isRestoring: Bool {
        if case .restoring = self { return true }
        return false
    }
}

/// The plain screen shown for the one save of a restore: `bg` with "Restoring…" centred in 15 pt `mu`. No tab pill.
struct RestoringView: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Text(BackupText.restoring)
                .font(.system(size: 15))
                .foregroundStyle(Theme.mu)
        }
    }
}

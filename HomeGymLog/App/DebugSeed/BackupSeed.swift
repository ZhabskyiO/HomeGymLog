#if DEBUG
import Foundation

extension DebugSeed {
    /// The backup presentation each `backup-*` seed opens with (m5-export 4.6); nil for every other seed, so the
    /// environment value stays at its nil default.
    var settingsBackupPreview: BackupPreview? {
        switch self {
        case .backupConfirm: return .confirm
        case .backupFailed: return .readFailed
        case .backupRestoring: return .restoring
        default: return nil
        }
    }
}
#endif

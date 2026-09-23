import Foundation
import SwiftData

/// "Archive and start over": the one write behind the restart confirmation, split out of the view so its outcome is a unit
/// test rather than a tap (AC-13). No `assertionFailure` here on purpose — the failed-save test drives this function against
/// a read-only store, and an assert would trap it in Debug; the screen asserts when it handles `.failed`.
@MainActor
enum RestartAction {
    enum Outcome: Equatable {
        /// `archivedAt` was written and saved: the root's current-program query is now empty.
        case archived
        /// The program was already archived (a stale or double tap). Nothing was written.
        case alreadyArchived
        /// The save failed and was rolled back; the message is what the alert shows.
        case failed(String)
    }

    static func run(program: Program, at date: Date, in context: ModelContext) -> Outcome {
        do {
            return try ProgramStore.archive(program, at: date, in: context) ? .archived : .alreadyArchived
        } catch {
            return .failed(SettingsText.archiveFailedMessage)
        }
    }
}

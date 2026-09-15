import Foundation
import SwiftData

/// One note per exercise key, enforced by fetch-then-insert.
enum ExerciseNoteStore {
    /// The stored note for `key`, or nil if none has been saved.
    static func note(forExerciseKey key: String, in context: ModelContext) throws -> ExerciseNote? {
        var descriptor = FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.exerciseKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Updates the existing note for `key` or inserts one, then saves (one call per keystroke in the detail sheet; the
    /// text is stored as typed, "" included). The two branches follow the failed-save policy (INSIGHTS: insert writers
    /// rehearse, field writers restore):
    /// - **Update** (a row exists): a field writer. On a failed save it rolls back, then puts back `text` and `updatedAt`,
    ///   and rethrows (`StoreCommit.commit`). It never rehearses.
    /// - **Insert** (the first keystroke for a key): the row is first saved and deleted in a scratch context on the same
    ///   container, so a refusing store throws before this context changes and the screen's notes query never holds an
    ///   unsaved row (on 26.5 a failed insert undone in place stays in same-context fetches). That keystroke costs three
    ///   saves (~3 ms on the 17.5 simulator, ~20 ms on 26.5), once per key.
    /// Accepted edge, as for `WorkoutLogStore.start`: a rehearsal whose insert saved but whose delete was refused leaves
    /// the typed text stored; the next keystroke's fetch finds that row and updates it.
    @discardableResult
    static func save(text: String, forExerciseKey key: String, updatedAt: Date, in context: ModelContext) throws -> ExerciseNote {
        if let existing = try note(forExerciseKey: key, in: context) {
            let oldText = existing.text
            let oldUpdatedAt = existing.updatedAt
            existing.text = text
            existing.updatedAt = updatedAt
            try StoreCommit.commit(context) {
                existing.text = oldText
                existing.updatedAt = oldUpdatedAt
            }
            return existing
        }
        try StoreCommit.rehearseInsert(in: context.container) { scratch in
            let rehearsal = ExerciseNote(exerciseKey: key, text: text, updatedAt: updatedAt)
            scratch.insert(rehearsal)
            return { scratch.delete(rehearsal) }
        }
        let note = ExerciseNote(exerciseKey: key, text: text, updatedAt: updatedAt)
        context.insert(note)
        // Last resort only (the rehearsal just saved the same row): `commitInsert` deletes it before `rollback()`, which
        // crashes on 17.5 while an insert is pending.
        try StoreCommit.commitInsert(context) { context.delete(note) }
        return note
    }
}

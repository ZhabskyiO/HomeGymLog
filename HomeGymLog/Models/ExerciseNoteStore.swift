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

    /// Updates the existing note for `key` or inserts one, then saves.
    @discardableResult
    static func save(text: String, forExerciseKey key: String, updatedAt: Date, in context: ModelContext) throws -> ExerciseNote {
        if let existing = try note(forExerciseKey: key, in: context) {
            existing.text = text
            existing.updatedAt = updatedAt
            try context.save()
            return existing
        }
        let note = ExerciseNote(exerciseKey: key, text: text, updatedAt: updatedAt)
        context.insert(note)
        try context.save()
        return note
    }
}

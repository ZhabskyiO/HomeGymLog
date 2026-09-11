import Foundation
import SwiftData

/// One free-text note per exercise key. Uniqueness is enforced by `ExerciseNoteStore`, not the schema.
@Model
final class ExerciseNote {
    var id: UUID = UUID()
    var exerciseKey: String = ""
    var text: String = ""
    var updatedAt: Date = Date.distantPast

    init(exerciseKey: String, text: String, updatedAt: Date) {
        self.exerciseKey = exerciseKey
        self.text = text
        self.updatedAt = updatedAt
    }
}

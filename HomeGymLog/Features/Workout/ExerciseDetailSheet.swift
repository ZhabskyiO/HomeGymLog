import SwiftUI

/// The workout's exercise detail sheet (spec 2.2): the shared `ExerciseInfoSheet` layout with a Notes editor slotted before
/// Done. Owns only the draft text; every change is handed to `onChange`, which saves it at once (kill-safe, researcher
/// fact 3), so Done, a swipe down and a top-edge drag lose nothing.
struct ExerciseDetailSheet: View {
    let exercise: Exercise
    let onChange: (String) -> Void
    let onDone: () -> Void
    /// Seeded once from the stored note when the sheet opens (≈ `useState(initialText)`: later prop changes never reseed it).
    @State private var text: String

    init(exercise: Exercise, initialText: String, onChange: @escaping (String) -> Void, onDone: @escaping () -> Void) {
        self.exercise = exercise
        self.onChange = onChange
        self.onDone = onDone
        _text = State(initialValue: initialText)
    }

    var body: some View {
        ExerciseInfoSheet(exercise: exercise, onDone: onDone) {
            NotesEditor(text: $text)
        }
        // ≈ useEffect(save, [text]), except it does not run on mount: opening the sheet writes nothing (gotchas SwiftUI).
        .onChange(of: text) { _, new in onChange(new) }
    }
}

/// "Notes" and a multi-line editor with an overlay placeholder. A `TextEditor`, never a vertical `TextField`, whose padding
/// does not take focus (researcher fact 1). `$text` is a `Binding` (≈ passing `value` and `onChange` as one prop).
private struct NotesEditor: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ExerciseToolsText.notesTitle)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.tx)
                .padding(.top, 16)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 14)).foregroundStyle(Theme.tx)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 70)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .accessibilityLabel(ExerciseToolsText.notesTitle)
                if text.isEmpty {
                    // Drawn under the caret at the editor's text inset; not a separate accessibility element.
                    Text(ExerciseToolsText.notePlaceholder)
                        .font(.system(size: 14)).foregroundStyle(Theme.mu)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .background(Theme.sf2, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.bd, lineWidth: 1.5))
            .padding(.top, 8)
        }
    }
}

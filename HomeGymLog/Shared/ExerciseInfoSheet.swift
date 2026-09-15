import SwiftUI

/// Muscle, equipment, and form cues for one exercise, with an optional slot before Done. No images until real assets
/// exist. Home and Program show it with no slot; the workout's detail sheet fills the slot with its Notes editor, so there
/// is one layout and one place for the cue styling. `Notes` is a generic view type (≈ a component taking a `children`
/// render prop whose type is fixed at the call site); `EmptyView` when nothing is slotted.
struct ExerciseInfoSheet<Notes: View>: View {
    let exercise: Exercise
    let onDone: () -> Void
    private let notes: Notes
    /// 12 pt below a slotted section (prototype), 16 pt below the cues when nothing is slotted (the Home/Program layout).
    private let doneSpacing: CGFloat

    /// The sheet with `notes` between the cues and Done.
    init(exercise: Exercise, onDone: @escaping () -> Void, @ViewBuilder notes: () -> Notes) {
        self.exercise = exercise
        self.onDone = onDone
        self.notes = notes()
        doneSpacing = 12
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(exercise.muscle.rawValue) · \(exercise.equipment)").font(.system(size: 12)).foregroundStyle(Theme.mu)
                Text(exercise.name).font(.system(size: 22, weight: .bold)).tracking(-0.5).foregroundStyle(Theme.tx).padding(.top, 2)
                Text("Form cues").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.tx).padding(.top, 16)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(exercise.cues.enumerated()), id: \.offset) { index, cue in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.accent)
                            Text(cue).font(.system(size: 14)).lineSpacing(3).foregroundStyle(Theme.tx)
                        }
                    }
                }
                .padding(.top, 8)
                notes
                Button(action: onDone) {
                    Text("Done").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, doneSpacing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.sf)
    }
}

extension ExerciseInfoSheet where Notes == EmptyView {
    /// The sheet with nothing slotted: the Home and Program info sheet.
    init(exercise: Exercise, onDone: @escaping () -> Void) {
        self.exercise = exercise
        self.onDone = onDone
        notes = EmptyView()
        doneSpacing = 16
    }
}

extension View {
    /// The exercise info sheet with its four presentation modifiers, shared by Home and Program so both
    /// screens present it identically. Analogy: a wrapper component around a shared `<Modal>`.
    func exerciseInfoSheet(item: Binding<Exercise?>) -> some View {
        sheet(item: item) { exercise in
            ExerciseInfoSheet(exercise: exercise, onDone: { item.wrappedValue = nil })
                .presentationDetents([.fraction(0.78)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.hidden)
                .presentationBackground(Theme.sf)
        }
    }
}

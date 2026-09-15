import SwiftUI

/// The adjust sheet's editable copy of one set. Nothing is stored until "Save & log set" or "Skip set".
struct AdjustDraft: Equatable {
    /// The set being adjusted; the write finds its row by this id.
    let setID: UUID
    /// 1-based, for the "Adjust set 2" title.
    let setNumber: Int
    /// The exercise's load grid; nil for an unknown key, which makes both weight buttons no-ops.
    let kind: EquipmentKind?
    /// Pounds, whatever the display unit.
    var weightLb: Double
    var reps: Int
}

/// The swap sheet's contents, computed once at the Swap tap: the exercise row it rewrites, its key then, and the candidates
/// with the weights a pick writes.
struct SwapDraft: Equatable {
    let exerciseID: UUID
    let exerciseKey: String
    let candidates: [SwapCandidate]
}

/// Which sheet a DEBUG seed opens as the workout screen first appears (`-seed wo-adjust`, `wo-detail`, `wo-swap`,
/// `wo-swap-rdl`). A production type so the screen needs no `#if`; nil means normal behaviour and is the only value outside
/// a seeded Debug launch.
enum WorkoutSheetPreview: Equatable {
    case adjust, detail, swap
}

/// Every sheet the workout screen can show, as one optional value (≈ a single modal union instead of several
/// `isOpen` flags). A sheet's editable draft lives in the sheet's own `@State`, never in the case: a changing item id
/// re-presents the sheet.
enum WorkoutSheet: Identifiable, Equatable {
    case adjust(AdjustDraft)
    /// The exercise detail sheet with notes for one library key.
    case detail(exerciseKey: String)
    /// The swap sheet for one exercise row.
    case swap(SwapDraft)

    /// Distinct per case, so switching cases never reuses a presented sheet.
    var id: String {
        switch self {
        case .adjust(let draft): return "adjust-\(draft.setID)"
        case .detail(let key): return "detail-\(key)"
        case .swap(let draft): return "swap-\(draft.exerciseID)"
        }
    }
}

/// The body of the workout's one `.sheet(item:)`: each case's view with its own presentation modifiers, so the screen keeps
/// a single line (≈ the modal switch as its own component, handlers passed as props).
struct WorkoutSheetContent: View {
    let item: WorkoutSheet
    let unit: WeightUnit
    /// The stored note for a `.detail` item's key ("" when none), read by the screen from its query rows; it seeds the
    /// editor once when the sheet opens.
    let noteText: String
    let onSaveAndLog: (AdjustDraft) -> Void
    let onSkipSet: (AdjustDraft) -> Void
    /// Receives the exercise key and the editor's full text on every change.
    let onNoteChange: (String, String) -> Void
    /// Done.
    let onClose: () -> Void
    /// A candidate row: the draft it came from and the picked candidate.
    let onPick: (SwapDraft, SwapCandidate) -> Void

    var body: some View {
        switch item {
        case .adjust(let draft):
            AdjustSheet(initial: draft, unit: unit, onSave: onSaveAndLog, onSkip: onSkipSet)
                .workoutSheetChrome(.height(251))
        case .detail(let key):
            if let exercise = ExerciseLibrary.exercise(for: key) {
                ExerciseDetailSheet(exercise: exercise, initialText: noteText, onChange: { onNoteChange(key, $0) }, onDone: onClose)
                    .workoutSheetChrome(.fraction(0.78))
            }
        case .swap(let draft):
            SwapSheet(draft: draft, unit: unit, onPick: { onPick(draft, $0) })
                .workoutSheetChrome(.height(SwapSheet.height(candidateCount: draft.candidates.count)))
        }
    }
}

private extension View {
    /// The presentation every workout sheet shares: one fixed detent, top radius 28, no drag indicator, `sf` behind.
    func workoutSheetChrome(_ detent: PresentationDetent) -> some View {
        presentationDetents([detent])
            .presentationCornerRadius(28)
            .presentationDragIndicator(.hidden)
            .presentationBackground(Theme.sf)
    }
}

import Foundation

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

/// Every sheet the workout screen can show, as one optional value (≈ a single modal union instead of several
/// `isOpen` flags). `.detail` and `.swap` join in m3-exercise-tools.
enum WorkoutSheet: Identifiable, Equatable {
    case adjust(AdjustDraft)

    var id: UUID {
        switch self {
        case .adjust(let draft): return draft.setID
        }
    }
}

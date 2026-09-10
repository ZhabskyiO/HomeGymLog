import Foundation

// Engine types are `nonisolated`: the app target defaults to MainActor isolation, but the Engine is pure
// logic that tests and (later) background work call from anywhere. React analogy: plain data modules
// with no React import.

/// Training phase. Raw values are stored in SwiftData as strings.
nonisolated enum Phase: String, CaseIterable, Codable, Sendable {
    case foundation = "Foundation"
    case build = "Build"
    case peak = "Peak"
    case deload = "Deload"

    /// Sets per exercise in this phase.
    var sets: Int {
        switch self {
        case .foundation: return 3
        case .build: return 4
        case .peak: return 4
        case .deload: return 2
        }
    }

    /// Target reps per set in this phase.
    var reps: Int {
        switch self {
        case .foundation: return 12
        case .build: return 10
        case .peak: return 8
        case .deload: return 12
        }
    }

    /// Rest between sets, in seconds.
    var restSeconds: Int {
        switch self {
        case .foundation: return 75
        case .build: return 90
        case .peak: return 120
        case .deload: return 60
        }
    }

    /// Load multiplier as a whole percent (100 = ×1.0), so weight math stays in integers.
    var multiplierPercent: Int {
        switch self {
        case .foundation: return 100
        case .build: return 100
        case .peak: return 105
        case .deload: return 70
        }
    }
}

/// Lifecycle of a planned session. `completed` is derived from its workout log finishing;
/// `skipped` is stored because nothing else records it.
nonisolated enum SessionStatus: String, CaseIterable, Codable, Sendable {
    case pending, completed, skipped
}

/// Lifecycle of one logged set.
nonisolated enum SetStatus: String, CaseIterable, Codable, Sendable {
    case pending, done, skipped
}

/// Muscle groups used by the exercise library and the swap sheet.
nonisolated enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
}

/// One exercise slot inside a planned session. Stored as an embedded Codable value on the session,
/// so any field added later must be optional (embedded values get no lightweight migration).
nonisolated struct PlannedExercise: Codable, Hashable, Sendable {
    /// 0-based position within the session.
    var order: Int
    /// Stable library key, e.g. "dbBench".
    var exerciseKey: String
    /// Target load in pounds, always loadable on the exercise's equipment.
    var targetWeightLb: Double
}

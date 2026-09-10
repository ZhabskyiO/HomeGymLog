import Foundation

/// One exercise the app knows about. The library is fixed at ship time; logs reference `key`.
nonisolated struct Exercise: Identifiable, Hashable, Sendable {
    /// Stable identifier used everywhere in storage, e.g. "dbBench". Never renamed.
    let key: String
    var id: String { key }
    let name: String
    let muscle: MuscleGroup
    /// Human-readable equipment description shown in the UI, e.g. "Marcy · high pulley".
    let equipment: String
    /// Library default starting weight in pounds; always loadable on `kind`.
    let defaultWeightLb: Double
    /// Which load grid applies.
    let kind: EquipmentKind
    /// Three short form cues.
    let cues: [String]
}

/// The 18 exercises, in the prototype's order.
nonisolated enum ExerciseLibrary {
    static let all: [Exercise] = [
        Exercise(key: "dbBench", name: "Dumbbell Bench Press", muscle: .chest, equipment: "Dumbbells + bench", defaultWeightLb: 40, kind: .dumbbell,
                 cues: ["Feet planted, shoulder blades pinned to the bench.", "Lower to chest level, elbows ~45°.", "Press up and slightly in; don't clank the bells."]),
        Exercise(key: "inclineDb", name: "Incline Dumbbell Press", muscle: .chest, equipment: "Dumbbells + bench (incline)", defaultWeightLb: 35, kind: .dumbbell,
                 cues: ["Bench at 30°, ribs down.", "Lower to upper chest.", "Drive through and finish over the shoulders."]),
        Exercise(key: "chestPress", name: "Seated Chest Press", muscle: .chest, equipment: "Marcy · press arms", defaultWeightLb: 90, kind: .marcy,
                 cues: ["Handles at mid-chest height.", "Press straight forward, elbows soft at lockout.", "Control the return, stack never slams."]),
        Exercise(key: "pecDeck", name: "Pec Deck Fly", muscle: .chest, equipment: "Marcy · butterfly arms", defaultWeightLb: 70, kind: .marcy,
                 cues: ["Elbows level with shoulders.", "Squeeze pads together, pause 1s.", "Open only to a light stretch."]),
        Exercise(key: "latPull", name: "Lat Pulldown", muscle: .back, equipment: "Marcy · high pulley", defaultWeightLb: 100, kind: .marcy,
                 cues: ["Lean back 10–15°, chest up.", "Pull the bar to upper chest, elbows down.", "Let the lats stretch fully at the top."]),
        Exercise(key: "lowRow", name: "Seated Low Row", muscle: .back, equipment: "Marcy · low pulley", defaultWeightLb: 90, kind: .marcy,
                 cues: ["Sit tall, knees slightly bent.", "Pull to the belly, elbows tight.", "Shoulders back — no shrugging."]),
        Exercise(key: "dbRow", name: "One-arm Dumbbell Row", muscle: .back, equipment: "Dumbbell + bench", defaultWeightLb: 45, kind: .dumbbell,
                 cues: ["Hand on bench, back flat.", "Row to the hip, not the chest.", "Full stretch at the bottom."]),
        Exercise(key: "shoulderPress", name: "Seated Shoulder Press", muscle: .shoulders, equipment: "Dumbbells + bench (upright)", defaultWeightLb: 30, kind: .dumbbell,
                 cues: ["Bells at ear height to start.", "Press up and in; don't flare the ribs.", "Lower slowly to ear height."]),
        Exercise(key: "latRaise", name: "Dumbbell Lateral Raise", muscle: .shoulders, equipment: "Dumbbells", defaultWeightLb: 15, kind: .dumbbell,
                 cues: ["Slight forward lean.", "Lead with elbows to shoulder height.", "Pause, then lower for 2 counts."]),
        Exercise(key: "curl", name: "Dumbbell Curl", muscle: .arms, equipment: "Dumbbells", defaultWeightLb: 25, kind: .dumbbell,
                 cues: ["Elbows pinned at your sides.", "Curl and rotate pinky up.", "Lower under control — no swinging."]),
        Exercise(key: "pushdown", name: "Triceps Pushdown", muscle: .arms, equipment: "Marcy · high pulley", defaultWeightLb: 60, kind: .marcy,
                 cues: ["Elbows glued to ribs.", "Push to full lockout.", "Return only to 90°."]),
        Exercise(key: "skull", name: "Dumbbell Skullcrusher", muscle: .arms, equipment: "Dumbbells + bench", defaultWeightLb: 25, kind: .dumbbell,
                 cues: ["Arms vertical, bells over forehead.", "Bend only at the elbows.", "Extend to lockout, squeeze."]),
        Exercise(key: "goblet", name: "Goblet Squat", muscle: .legs, equipment: "Dumbbell", defaultWeightLb: 50, kind: .dumbbell,
                 cues: ["Bell at chest, elbows down.", "Sit between the heels.", "Stand tall — knees track over toes."]),
        Exercise(key: "rdl", name: "Dumbbell Romanian Deadlift", muscle: .legs, equipment: "Dumbbells", defaultWeightLb: 50, kind: .dumbbell,
                 cues: ["Soft knees, hips back.", "Bells slide down the thighs.", "Stop at hamstring stretch, drive hips forward."]),
        Exercise(key: "legExt", name: "Leg Extension", muscle: .legs, equipment: "Marcy · leg developer", defaultWeightLb: 70, kind: .marcy,
                 cues: ["Pad above the ankles.", "Extend to full lockout, pause.", "Lower for 2 counts."]),
        Exercise(key: "legCurl", name: "Leg Curl", muscle: .legs, equipment: "Marcy · leg developer", defaultWeightLb: 50, kind: .marcy,
                 cues: ["Hips stay down.", "Curl heels to glutes.", "Slow, controlled return."]),
        Exercise(key: "split", name: "Bulgarian Split Squat", muscle: .legs, equipment: "Dumbbells + bench", defaultWeightLb: 30, kind: .dumbbell,
                 cues: ["Rear foot on bench.", "Drop straight down, front knee over ankle.", "Push through the whole front foot."]),
        Exercise(key: "lunge", name: "Dumbbell Walking Lunge", muscle: .legs, equipment: "Dumbbells", defaultWeightLb: 30, kind: .dumbbell,
                 cues: ["Long stride, torso upright.", "Back knee kisses the floor.", "Drive through front heel."]),
    ]

    static let byKey: [String: Exercise] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })

    /// Looks an exercise up by its stable key; nil for an unknown key.
    static func exercise(for key: String) -> Exercise? {
        byKey[key]
    }
}
